import { fileIo as fs } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { common } from '@kit.AbilityKit';
import Long from 'long';
import { UserDocument } from '../models/UserDocument';
import { DocumentVersion } from '../models/DocumentVersion';

const VERSIONS_DIR = 'versions';
const MAX_VERSIONS_PER_DOC = 20;

/**
 * 文档版本管理服务
 * 本地文件存储每个文档的历史快照,文件路径:filesDir/versions/<docId>.json
 * 每个文档保留最近 MAX_VERSIONS_PER_DOC 版,超出删最旧。
 */
export class VersionService {
  /**
   * 保存当前文档为一份快照
   */
  static async saveVersion(context: common.UIAbilityContext, doc: UserDocument): Promise<void> {
    if (!doc.id) return;
    try {
      const versions = await VersionService.readVersions(context, doc.id);
      const now = Long.fromNumber(Date.now());
      const version = new DocumentVersion();
      version.id = `${doc.id}_${now.toString()}`;
      version.docId = doc.id;
      version.content = doc.content;
      version.title = doc.title;
      version.createdAt = now;

      versions.push(version);
      // 保留最近 N 版
      const toKeep = versions.length > MAX_VERSIONS_PER_DOC
        ? versions.slice(versions.length - MAX_VERSIONS_PER_DOC)
        : versions;
      VersionService.writeVersions(context, doc.id, toKeep);
    } catch (e) {
      console.error('[Version] saveVersion failed: ' + (e as Error).message);
    }
  }

  /**
   * 列出某文档所有版本(按时间倒序)
   */
  static async listVersions(context: common.UIAbilityContext, docId: string): Promise<DocumentVersion[]> {
    const versions = await VersionService.readVersions(context, docId);
    return versions.sort((a: DocumentVersion, b: DocumentVersion) =>
      b.createdAt.compare(a.createdAt));
  }

  /**
   * 把某版本恢复到 UserDocument(只构造对象,不落库;落库由调用方处理)
   */
  static toDocument(version: DocumentVersion, base: UserDocument): UserDocument {
    const doc = new UserDocument();
    doc.id = base.id;
    doc.ownerId = base.ownerId;
    doc.title = version.title;
    doc.content = version.content;
    doc.createdAt = base.createdAt;
    doc.updatedAt = Long.fromNumber(Date.now());
    doc.isPublic = base.isPublic;
    doc.sharedWith = base.sharedWith;
    return doc;
  }

  /**
   * 清空某文档所有版本
   */
  static async clearVersions(context: common.UIAbilityContext, docId: string): Promise<void> {
    try {
      const path = VersionService.getFilePath(context, docId);
      if (fs.accessSync(path)) {
        fs.unlinkSync(path);
      }
    } catch (e) {
      // 文件不存在等,忽略
    }
  }

  // ==================== 内部实现 ====================

  private static getDir(context: common.UIAbilityContext): string {
    const dir = context.filesDir + '/' + VERSIONS_DIR;
    try {
      if (!fs.accessSync(dir)) {
        fs.mkdirSync(dir, true);
      }
    } catch (e) {
      // 已存在则忽略
    }
    return dir;
  }

  private static getFilePath(context: common.UIAbilityContext, docId: string): string {
    // docId 可能含特殊字符,转 base32-ish 安全文件名
    const safe = docId.replace(/[^a-zA-Z0-9_-]/g, '_');
    return VersionService.getDir(context) + '/' + safe + '.json';
  }

  private static readVersions(context: common.UIAbilityContext, docId: string): Promise<DocumentVersion[]> {
    return new Promise<DocumentVersion[]>((resolve: (v: DocumentVersion[]) => void) => {
      try {
        const path = VersionService.getFilePath(context, docId);
        if (!fs.accessSync(path)) {
          resolve([]);
          return;
        }
        const text = fs.readTextSync(path);
        const arr = JSON.parse(text) as Object[];
        const versions: DocumentVersion[] = [];
        if (arr) {
          for (let i = 0; i < arr.length; i++) {
            versions.push(DocumentVersion.fromJson(arr[i] as Record<string, Object>));
          }
        }
        resolve(versions);
      } catch (e) {
        resolve([]);
      }
    });
  }

  private static writeVersions(context: common.UIAbilityContext, docId: string, versions: DocumentVersion[]): void {
    try {
      const path = VersionService.getFilePath(context, docId);
      const arr: Object[] = [];
      for (let i = 0; i < versions.length; i++) {
        arr.push(versions[i].toJson());
      }
      const file = fs.openSync(path, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      try {
        fs.writeSync(file.fd, JSON.stringify(arr));
      } finally {
        fs.closeSync(file);
      }
    } catch (e) {
      console.error('[Version] writeVersions failed: ' + (e as Error).message);
    }
  }
}
