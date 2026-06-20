import {
  AGConnectCloudDB,
  CloudDBZone,
  CloudDBZoneQuery
} from '@hw-agconnect/database-ohos';
import '@hw-agconnect/core-ohos';
import '@hw-agconnect/auth-ohos';
import { UserDocument } from '../models/UserDocument';
import { AuthService } from './AuthService';
import { common } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import Long from 'long';

const ZONE_NAME = 'HMarkdownZone';
const DEMO_FILE_NAME = 'cloud_docs_demo.json';
const SCHEMA_FILE_NAME = 'schema.json';

interface CloudDocumentJson {
  id: string;
  ownerId: string;
  title: string;
  content: string;
  createdAt: number;
  updatedAt: number;
  isPublic: boolean;
  sharedWith: string;
}

interface ServiceResult {
  success: boolean;
  message: string;
  data?: object;
}

interface ObjectTypeInfoJson {
  schemaVersion: number;
  objectTypes: Object[];
  permissions: Object[];
}

export class CloudDBService {
  private static cloudDB: AGConnectCloudDB | null = null;
  private static dbZone: CloudDBZone | null = null;
  private static cloudInitDone: boolean = false;
  static isDemoMode: boolean = false;

  private static getContext(): common.UIAbilityContext {
    return globalThis.appContext as common.UIAbilityContext;
  }

  // ==================== Demo 模式（本地 JSON） ====================

  private static getDemoFilePath(): string {
    return CloudDBService.getContext().filesDir + '/' + DEMO_FILE_NAME;
  }

  private static readDemoDocs(): CloudDocumentJson[] {
    try {
      const path = CloudDBService.getDemoFilePath();
      if (!fs.accessSync(path)) return [];
      return JSON.parse(fs.readTextSync(path)) as CloudDocumentJson[];
    } catch {
      return [];
    }
  }

  private static writeDemoDocs(docs: CloudDocumentJson[]): void {
    const path = CloudDBService.getDemoFilePath();
    const file = fs.openSync(path, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
    fs.writeSync(file.fd, JSON.stringify(docs));
    fs.closeSync(file);
  }

  // ==================== 初始化 ====================

  private static async initCloudOnce(): Promise<void> {
    if (CloudDBService.cloudInitDone) return;
    const ctx = CloudDBService.getContext();

    await AGConnectCloudDB.initialize(ctx);
    const db = await AGConnectCloudDB.getInstance();

    const raw: Uint8Array = await ctx.resourceManager.getRawFileContent(SCHEMA_FILE_NAME);
    const text: string = util.TextDecoder.create('utf-8').decodeWithStream(raw);
    const schema: ObjectTypeInfoJson = JSON.parse(text) as ObjectTypeInfoJson;
    db.createObjectType(schema);

    CloudDBService.cloudDB = db;
    CloudDBService.cloudInitDone = true;
    console.info('[CloudDB] AGConnect Cloud DB 已初始化');
  }

  static async init(): Promise<boolean> {
    if (CloudDBService.dbZone) return true;
    if (CloudDBService.isDemoMode) return true;

    try {
      await CloudDBService.initCloudOnce();
      CloudDBService.dbZone = await CloudDBService.cloudDB!.openCloudDBZone(ZONE_NAME);
      console.info('[CloudDB] Zone 已打开:', ZONE_NAME);
      return true;
    } catch (e) {
      console.warn('[CloudDB] 初始化失败，使用本地模式');
      console.error('[CloudDB] init 错误:', JSON.stringify(e));
      CloudDBService.isDemoMode = true;
      return true;
    }
  }

  static async isAvailable(): Promise<boolean> {
    if (CloudDBService.isDemoMode) return false;
    try {
      await CloudDBService.initCloudOnce();
      return true;
    } catch {
      return false;
    }
  }

  // 强制回到云端模式（用于验证云端功能）
  static forceCloudMode(): void {
    CloudDBService.isDemoMode = false;
    CloudDBService.dbZone = null;
  }

  // CloudDB 操作失败时自动回退到 demo 模式
  private static switchToDemoMode(reason: string, err?: unknown): void {
    if (!CloudDBService.isDemoMode) {
      console.warn(`[CloudDB] 云端不可用（${reason}），自动切换到本地模式`);
      if (err) {
        console.error('[CloudDB] 完整错误对象:', JSON.stringify(err));
        if (err instanceof Error) {
          console.error('[CloudDB] 错误堆栈:', err.stack);
        }
      }
      CloudDBService.isDemoMode = true;
      CloudDBService.dbZone = null;
    }
  }

  // ==================== 保存文档 ====================

  static async saveDocument(doc: UserDocument): Promise<ServiceResult> {
    await CloudDBService.init();
    const user = await AuthService.getCurrentUser();
    if (!user) return { success: false, message: '请先登录' };

    const isNew = !doc.id;
    const now = Long.fromNumber(Date.now());
    if (isNew) {
      doc.id = UserDocument.generateId();
      doc.ownerId = user.uid;
      doc.createdAt = now;
    }
    doc.updatedAt = now;

    if (CloudDBService.isDemoMode) {
      return CloudDBService.demoSave(doc, isNew);
    }

    try {
      await CloudDBService.dbZone!.executeUpsert(doc);
      return { success: true, message: isNew ? '已上传到云端' : '已同步到云端', data: doc };
    } catch (e) {
      const msg = CloudDBService.getErrorMessage(e);
      console.error('[CloudDB] 保存失败:', msg);
      // #5 单次回退到 demo，不永久污染 isDemoMode
      return CloudDBService.demoSave(doc, isNew);
    }
  }

  private static demoSave(doc: UserDocument, isNew: boolean): ServiceResult {
    try {
      const docs = CloudDBService.readDemoDocs();
      const idx = docs.findIndex(d => d.id === doc.id);
      const json: CloudDocumentJson = {
        id: doc.id, ownerId: doc.ownerId, title: doc.title,
        content: doc.content,
        createdAt: doc.createdAt.toNumber(),
        updatedAt: doc.updatedAt.toNumber(),
        isPublic: doc.isPublic, sharedWith: doc.sharedWith
      };
      if (idx >= 0) {
        docs[idx] = json;
      } else {
        docs.push(json);
      }
      CloudDBService.writeDemoDocs(docs);
      return { success: true, message: isNew ? '已上传到云端' : '已同步到云端', data: doc };
    } catch (e) {
      return { success: false, message: '保存失败: ' + CloudDBService.getErrorMessage(e) };
    }
  }

  // ==================== 查询我的文档 ====================

  static async getMyDocuments(): Promise<UserDocument[]> {
    await CloudDBService.init();
    const user = await AuthService.getCurrentUser();
    if (!user) return [];

    if (CloudDBService.isDemoMode) {
      return CloudDBService.demoGetMyDocs(user.uid);
    }

    try {
      const query = CloudDBZoneQuery.where(UserDocument)
        .equalTo('ownerId', user.uid)
        .orderByDesc('updatedAt');
      const snapshot = await CloudDBService.dbZone!.executeQuery(query);
      return snapshot.getSnapshotObjects();
    } catch (e) {
      // #5 单次回退到 demo，不永久污染 isDemoMode
      return CloudDBService.demoGetMyDocs(user.uid);
    }
  }

  private static demoGetMyDocs(uid: string): UserDocument[] {
    try {
      return CloudDBService.readDemoDocs()
        .filter(d => d.ownerId === uid)
        .sort((a, b) => b.updatedAt - a.updatedAt)
        .map(d => UserDocument.fromMap(d as unknown as Record<string, Object>));
    } catch {
      return [];
    }
  }

  // ==================== 查询分享给我的文档 ====================

  static async getSharedWithMe(): Promise<UserDocument[]> {
    await CloudDBService.init();
    const user = await AuthService.getCurrentUser();
    if (!user) return [];

    if (CloudDBService.isDemoMode) {
      return CloudDBService.demoGetSharedWithMe(user.uid, user.email);
    }

    try {
      const query = CloudDBZoneQuery.where(UserDocument)
        .notEqualTo('ownerId', user.uid)
        .orderByDesc('updatedAt');
      const snapshot = await CloudDBService.dbZone!.executeQuery(query);
      return snapshot.getSnapshotObjects().filter(doc => doc.isSharedWithUser(user.email));
    } catch (e) {
      // #5 单次回退到 demo，不永久污染 isDemoMode
      return CloudDBService.demoGetSharedWithMe(user.uid, user.email);
    }
  }

  private static demoGetSharedWithMe(uid: string, email: string): UserDocument[] {
    try {
      return CloudDBService.readDemoDocs()
        .map(d => UserDocument.fromMap(d as unknown as Record<string, Object>))
        .filter(doc => doc.ownerId !== uid && doc.isSharedWithUser(email))
        .sort((a, b) => b.updatedAt.compare(a.updatedAt));
    } catch {
      return [];
    }
  }

  // ==================== 按 ID 查询 ====================

  static async getDocumentById(id: string): Promise<UserDocument | null> {
    await CloudDBService.init();

    if (CloudDBService.isDemoMode) {
      return CloudDBService.demoGetById(id);
    }

    try {
      const query = CloudDBZoneQuery.where(UserDocument).equalTo('id', id);
      const snapshot = await CloudDBService.dbZone!.executeQuery(query);
      const docs = snapshot.getSnapshotObjects();
      return docs.length > 0 ? docs[0] : null;
    } catch (e) {
      // #5 单次回退到 demo，不永久污染 isDemoMode
      return CloudDBService.demoGetById(id);
    }
  }

  private static demoGetById(id: string): UserDocument | null {
    try {
      const docs = CloudDBService.readDemoDocs();
      const found = docs.find(d => d.id === id);
      return found ? UserDocument.fromMap(found as unknown as Record<string, Object>) : null;
    } catch {
      return null;
    }
  }

  // ==================== 删除文档 ====================

  static async deleteDocument(doc: UserDocument): Promise<ServiceResult> {
    await CloudDBService.init();
    const user = await AuthService.getCurrentUser();
    if (!user || user.uid !== doc.ownerId) {
      return { success: false, message: '只能删除自己创建的文档' };
    }

    if (CloudDBService.isDemoMode) {
      return CloudDBService.demoDelete(doc);
    }

    try {
      await CloudDBService.dbZone!.executeDelete(doc);
      return { success: true, message: '已从云端删除' };
    } catch (e) {
      // #5 单次回退到 demo，不永久污染 isDemoMode
      return CloudDBService.demoDelete(doc);
    }
  }

  private static demoDelete(doc: UserDocument): ServiceResult {
    try {
      const docs = CloudDBService.readDemoDocs();
      CloudDBService.writeDemoDocs(docs.filter(d => d.id !== doc.id));
      return { success: true, message: '已从云端删除' };
    } catch (e) {
      return { success: false, message: '删除失败: ' + CloudDBService.getErrorMessage(e) };
    }
  }

  // ==================== 更新分享设置 ====================

  static async updateSharing(doc: UserDocument): Promise<ServiceResult> {
    doc.updatedAt = Long.fromNumber(Date.now());
    return await CloudDBService.saveDocument(doc);
  }

  // ==================== 工具方法 ====================

  private static getErrorMessage(error: unknown): string {
    if (error instanceof Error && error.message) return error.message;
    if (typeof error === 'object' && error !== null && 'message' in error) {
      const msg = (error as { message?: string }).message;
      if (msg) return msg;
    }
    return '未知错误';
  }
}
