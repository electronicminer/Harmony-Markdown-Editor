import { UserDocument } from '../models/UserDocument';
import { AuthService } from './AuthService';

const ZONE_NAME = 'HMarkdownZone';

interface CloudDocument {
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

export class CloudDBService {
  private static initialized: boolean = false;
  private static cloudDB: object | null = null;
  private static zone: object | null = null;

  static async init(): Promise<boolean> {
    if (CloudDBService.initialized) return true;
    try {
      // @ts-ignore
      const agConnectCloudDB = globalThis.requireNativeModule('agconnect.clouddb') ||
        (await import('@hw-agconnect/clouddb-ohos'));
      CloudDBService.cloudDB = agConnectCloudDB.AGConnectCloudDB.getInstance(
        (await import('@hw-agconnect/api-ohos')).default.getInstance()
      );
      const config = {
        name: ZONE_NAME,
        accessMode: 1, // public
        syncMode: 2, // device-cloud two-way sync
        persistenceEnabled: true
      };
      // @ts-ignore
      CloudDBService.zone = await CloudDBService.cloudDB.openCloudDBZone(config, true);
      CloudDBService.initialized = true;
      return true;
    } catch (e) {
      console.error('[CloudDB] Init failed:', JSON.stringify(e));
      CloudDBService.initialized = false;
      return false;
    }
  }

  private static async ensureInit(): Promise<boolean> {
    if (!CloudDBService.initialized) {
      return await CloudDBService.init();
    }
    return true;
  }

  static async saveDocument(doc: UserDocument): Promise<ServiceResult> {
    const ok = await CloudDBService.ensureInit();
    if (!ok || !CloudDBService.zone) {
      return { success: false, message: '云端服务未就绪，请检查 Cloud DB 配置' };
    }
    const user = await AuthService.getCurrentUser();
    if (!user) {
      return { success: false, message: '请先登录' };
    }

    const isNew = !doc.id;
    if (isNew) {
      doc.id = UserDocument.generateId();
      doc.ownerId = user.uid;
      doc.createdAt = Date.now();
    }
    doc.updatedAt = Date.now();

    try {
      const cloudDoc: CloudDocument = {
        id: doc.id,
        ownerId: doc.ownerId,
        title: doc.title,
        content: doc.content,
        createdAt: doc.createdAt,
        updatedAt: doc.updatedAt,
        isPublic: doc.isPublic,
        sharedWith: doc.sharedWith
      };
      // @ts-ignore
      await CloudDBService.zone.executeUpsert(cloudDoc);
      return {
        success: true,
        message: isNew ? '已上传到云端' : '已同步到云端',
        data: doc
      };
    } catch (e) {
      console.error('[CloudDB] Save failed:', JSON.stringify(e));
      return { success: false, message: '保存失败: ' + CloudDBService.getErrorMessage(e) };
    }
  }

  static async getMyDocuments(): Promise<UserDocument[]> {
    const ok = await CloudDBService.ensureInit();
    if (!ok || !CloudDBService.zone) return [];

    const user = await AuthService.getCurrentUser();
    if (!user) return [];

    try {
      // @ts-ignore
      const query = CloudDBService.zone.createQuery();
      query.equalTo('ownerId', user.uid);
      query.orderByDesc('updatedAt');
      // @ts-ignore
      const result = await CloudDBService.zone.executeFindAll(query);
      return CloudDBService.parseResults(result);
    } catch (e) {
      console.error('[CloudDB] Query my docs failed:', JSON.stringify(e));
      return [];
    }
  }

  static async getSharedWithMe(): Promise<UserDocument[]> {
    const ok = await CloudDBService.ensureInit();
    if (!ok || !CloudDBService.zone) return [];

    const user = await AuthService.getCurrentUser();
    if (!user) return [];

    try {
      // @ts-ignore
      const query = CloudDBService.zone.createQuery();
      query.notEqualTo('ownerId', user.uid);
      query.orderByDesc('updatedAt');
      // @ts-ignore
      const result = await CloudDBService.zone.executeFindAll(query);
      const allDocs = CloudDBService.parseResults(result);
      return allDocs.filter(doc => doc.isSharedWithUser(user.uid));
    } catch (e) {
      console.error('[CloudDB] Query shared docs failed:', JSON.stringify(e));
      return [];
    }
  }

  static async getDocumentById(id: string): Promise<UserDocument | null> {
    const ok = await CloudDBService.ensureInit();
    if (!ok || !CloudDBService.zone) return null;

    try {
      // @ts-ignore
      const query = CloudDBService.zone.createQuery();
      query.equalTo('id', id);
      // @ts-ignore
      const result = await CloudDBService.zone.executeFindAll(query);
      const docs = CloudDBService.parseResults(result);
      return docs.length > 0 ? docs[0] : null;
    } catch (e) {
      console.error('[CloudDB] Get doc by id failed:', JSON.stringify(e));
      return null;
    }
  }

  static async deleteDocument(doc: UserDocument): Promise<ServiceResult> {
    const ok = await CloudDBService.ensureInit();
    if (!ok || !CloudDBService.zone) {
      return { success: false, message: '云端服务未就绪' };
    }

    const user = await AuthService.getCurrentUser();
    if (!user || user.uid !== doc.ownerId) {
      return { success: false, message: '只能删除自己创建的文档' };
    }

    try {
      const cloudDoc: CloudDocument = {
        id: doc.id,
        ownerId: doc.ownerId,
        title: doc.title,
        content: doc.content,
        createdAt: doc.createdAt,
        updatedAt: doc.updatedAt,
        isPublic: doc.isPublic,
        sharedWith: doc.sharedWith
      };
      // @ts-ignore
      await CloudDBService.zone.executeDelete(cloudDoc);
      return { success: true, message: '已从云端删除' };
    } catch (e) {
      console.error('[CloudDB] Delete failed:', JSON.stringify(e));
      return { success: false, message: '删除失败: ' + CloudDBService.getErrorMessage(e) };
    }
  }

  static async updateSharing(doc: UserDocument): Promise<ServiceResult> {
    doc.updatedAt = Date.now();
    return await CloudDBService.saveDocument(doc);
  }

  static isAvailable(): boolean {
    try {
      // @ts-ignore
      const module = globalThis.requireNativeModule('agconnect.clouddb');
      return module !== undefined;
    } catch {
      try {
        // @ts-ignore
        require('@hw-agconnect/clouddb-ohos');
        return true;
      } catch {
        return false;
      }
    }
  }

  private static parseResults(result: object | object[]): UserDocument[] {
    if (!result) return [];
    const arr = Array.isArray(result) ? result : [result];
    return arr.map((item: object) => {
      if (item instanceof UserDocument) return item;
      return UserDocument.fromMap(item as Record<string, Object>);
    });
  }

  private static getErrorMessage(error: unknown): string {
    if (error instanceof Error && error.message) return error.message;
    if (typeof error === 'object' && error !== null && 'message' in error) {
      const msg = (error as { message?: string }).message;
      if (msg) return msg;
    }
    return '未知错误';
  }
}
