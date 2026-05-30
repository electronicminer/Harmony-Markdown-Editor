import { UserDocument } from '../models/UserDocument';
import { AuthService } from './AuthService';
import { common } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';

const ZONE_NAME = 'HMarkdownZone';
const DEMO_FILE_NAME = 'cloud_docs_demo.json';

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
  static isDemoMode: boolean = false;

  private static getContext(): common.UIAbilityContext {
    return globalThis.appContext as common.UIAbilityContext;
  }

  private static getDemoFilePath(): string {
    return CloudDBService.getContext().filesDir + '/' + DEMO_FILE_NAME;
  }

  private static readDemoDocs(): CloudDocument[] {
    try {
      const path = CloudDBService.getDemoFilePath();
      if (!fs.accessSync(path)) return [];
      const content = fs.readTextSync(path);
      return JSON.parse(content) as CloudDocument[];
    } catch (e) {
      return [];
    }
  }

  private static writeDemoDocs(docs: CloudDocument[]): void {
    const path = CloudDBService.getDemoFilePath();
    const file = fs.openSync(path, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
    fs.writeSync(file.fd, JSON.stringify(docs));
    fs.closeSync(file);
  }

  static async init(): Promise<boolean> {
    if (CloudDBService.isDemoMode) {
      CloudDBService.initialized = true;
      return true;
    }
    if (CloudDBService.initialized) return true;
    try {
      const agConnectCloudDB: object = globalThis.requireNativeModule('agconnect.clouddb') as object;
      const cloudDBModule: object = (agConnectCloudDB as Record<string, object>)['AGConnectCloudDB'] as object;
      const apiModule: object = globalThis.requireNativeModule('agconnect.api') as object;
      const apiInstance: object = (apiModule as Record<string, object>)['AGCApi']['instance'] as object;
      CloudDBService.cloudDB = (cloudDBModule as Record<string, Function>)['instance'](apiInstance) as object;
      const config: object = {
        name: ZONE_NAME,
        accessMode: 1,
        syncMode: 2,
        persistenceEnabled: true
      };
      CloudDBService.zone = await (CloudDBService.cloudDB as Record<string, Function>)['openCloudDBZone'](config, true) as object;
      CloudDBService.initialized = true;
      return true;
    } catch (e) {
      console.warn('[CloudDB] Init failed, falling back to demo mode');
      CloudDBService.isDemoMode = true;
      CloudDBService.initialized = true;
      return true;
    }
  }

  private static async ensureInit(): Promise<boolean> {
    if (!CloudDBService.initialized) {
      return await CloudDBService.init();
    }
    return true;
  }

  static async saveDocument(doc: UserDocument): Promise<ServiceResult> {
    await CloudDBService.ensureInit();

    if (CloudDBService.isDemoMode) {
      const user = await AuthService.getCurrentUser();
      if (!user) return { success: false, message: '请先登录' };

      const isNew = !doc.id;
      if (isNew) {
        doc.id = UserDocument.generateId();
        doc.ownerId = user.uid;
        doc.createdAt = Date.now();
      }
      doc.updatedAt = Date.now();

      try {
        const docs = CloudDBService.readDemoDocs();
        const idx = docs.findIndex(d => d.id === doc.id);
        const cloudDoc: CloudDocument = {
          id: doc.id, ownerId: doc.ownerId, title: doc.title,
          content: doc.content, createdAt: doc.createdAt, updatedAt: doc.updatedAt,
          isPublic: doc.isPublic, sharedWith: doc.sharedWith
        };
        if (idx >= 0) {
          docs[idx] = cloudDoc;
        } else {
          docs.push(cloudDoc);
        }
        CloudDBService.writeDemoDocs(docs);
        return { success: true, message: isNew ? '已上传到云端' : '已同步到云端', data: doc };
      } catch (e) {
        return { success: false, message: '保存失败: ' + CloudDBService.getErrorMessage(e) };
      }
    }

    if (!CloudDBService.zone) {
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
      await (CloudDBService.zone as Record<string, Function>)['executeUpsert'](cloudDoc);
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
    await CloudDBService.ensureInit();

    if (CloudDBService.isDemoMode) {
      const user = await AuthService.getCurrentUser();
      if (!user) return [];
      try {
        const docs = CloudDBService.readDemoDocs();
        return docs
          .filter(d => d.ownerId === user.uid)
          .sort((a, b) => b.updatedAt - a.updatedAt)
          .map(d => UserDocument.fromMap(d as unknown as Record<string, Object>));
      } catch (e) {
        return [];
      }
    }

    if (!CloudDBService.zone) return [];

    const user = await AuthService.getCurrentUser();
    if (!user) return [];

    try {
      const query: object = (CloudDBService.zone as Record<string, Function>)['createQuery']() as object;
      (query as Record<string, Function>)['equalTo']('ownerId', user.uid);
      (query as Record<string, Function>)['orderByDesc']('updatedAt');
      const result: object = await (CloudDBService.zone as Record<string, Function>)['executeFindAll'](query) as object;
      return CloudDBService.parseResults(result);
    } catch (e) {
      console.error('[CloudDB] Query my docs failed:', JSON.stringify(e));
      return [];
    }
  }

  static async getSharedWithMe(): Promise<UserDocument[]> {
    await CloudDBService.ensureInit();

    if (CloudDBService.isDemoMode) {
      const user = await AuthService.getCurrentUser();
      if (!user) return [];
      try {
        const docs = CloudDBService.readDemoDocs();
        return docs
          .filter(d => d.ownerId !== user.uid)
          .filter(d => {
            const doc = UserDocument.fromMap(d as unknown as Record<string, Object>);
            return doc.isSharedWithUser(user.uid);
          })
          .sort((a, b) => b.updatedAt - a.updatedAt)
          .map(d => UserDocument.fromMap(d as unknown as Record<string, Object>));
      } catch (e) {
        return [];
      }
    }

    if (!CloudDBService.zone) return [];

    const user = await AuthService.getCurrentUser();
    if (!user) return [];

    try {
      const query: object = (CloudDBService.zone as Record<string, Function>)['createQuery']() as object;
      (query as Record<string, Function>)['notEqualTo']('ownerId', user.uid);
      (query as Record<string, Function>)['orderByDesc']('updatedAt');
      const result: object = await (CloudDBService.zone as Record<string, Function>)['executeFindAll'](query) as object;
      const allDocs = CloudDBService.parseResults(result);
      return allDocs.filter(doc => doc.isSharedWithUser(user.uid));
    } catch (e) {
      console.error('[CloudDB] Query shared docs failed:', JSON.stringify(e));
      return [];
    }
  }

  static async getDocumentById(id: string): Promise<UserDocument | null> {
    await CloudDBService.ensureInit();

    if (CloudDBService.isDemoMode) {
      try {
        const docs = CloudDBService.readDemoDocs();
        const found = docs.find(d => d.id === id);
        return found ? UserDocument.fromMap(found as unknown as Record<string, Object>) : null;
      } catch (e) {
        return null;
      }
    }

    if (!CloudDBService.zone) return null;

    try {
      const query: object = (CloudDBService.zone as Record<string, Function>)['createQuery']() as object;
      (query as Record<string, Function>)['equalTo']('id', id);
      const result: object = await (CloudDBService.zone as Record<string, Function>)['executeFindAll'](query) as object;
      const docs = CloudDBService.parseResults(result);
      return docs.length > 0 ? docs[0] : null;
    } catch (e) {
      console.error('[CloudDB] Get doc by id failed:', JSON.stringify(e));
      return null;
    }
  }

  static async deleteDocument(doc: UserDocument): Promise<ServiceResult> {
    await CloudDBService.ensureInit();

    if (CloudDBService.isDemoMode) {
      const user = await AuthService.getCurrentUser();
      if (!user || user.uid !== doc.ownerId) {
        return { success: false, message: '只能删除自己创建的文档' };
      }
      try {
        const docs = CloudDBService.readDemoDocs();
        const filtered = docs.filter(d => d.id !== doc.id);
        CloudDBService.writeDemoDocs(filtered);
        return { success: true, message: '已从云端删除' };
      } catch (e) {
        return { success: false, message: '删除失败: ' + CloudDBService.getErrorMessage(e) };
      }
    }

    if (!CloudDBService.zone) {
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
      await (CloudDBService.zone as Record<string, Function>)['executeDelete'](cloudDoc);
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
    if (CloudDBService.isDemoMode) return true;
    try {
      const module: object = globalThis.requireNativeModule('agconnect.clouddb') as object;
      return module !== undefined;
    } catch {
      return false;
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
