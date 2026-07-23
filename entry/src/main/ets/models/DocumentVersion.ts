import Long from 'long';

/**
 * 文档历史版本快照
 * 存储位置:本地文件 filesDir/versions/<docId>.json,不入 Cloud DB
 */
export class DocumentVersion {
  id: string;          // 版本唯一 ID
  docId: string;        // 所属文档 ID
  content: string;     // 该版本正文
  title: string;       // 该版本标题
  createdAt: Long = Long.ZERO;  // 快照时间

  constructor() {
    this.id = '';
    this.docId = '';
    this.content = '';
    this.title = '';
  }

  static fromJson(map: Record<string, Object>): DocumentVersion {
    const v = new DocumentVersion();
    v.id = String(map['id'] || '');
    v.docId = String(map['docId'] || '');
    v.content = String(map['content'] || '');
    v.title = String(map['title'] || '');
    const c = map['createdAt'];
    if (typeof c === 'number') {
      v.createdAt = Long.fromNumber(c);
    } else if (typeof c === 'string') {
      v.createdAt = Long.fromString(c);
    } else if (Long.isLong(c)) {
      v.createdAt = c as Long;
    } else {
      v.createdAt = Long.ZERO;
    }
    return v;
  }

  toJson(): Record<string, Object> {
    return {
      'id': this.id,
      'docId': this.docId,
      'content': this.content,
      'title': this.title,
      'createdAt': this.createdAt.toNumber()
    };
  }

  /** 格式化时间为可读串:MM-DD HH:mm:ss */
  getFormattedTime(): string {
    if (!this.createdAt || this.createdAt.isZero()) return '';
    const d = new Date(this.createdAt.toNumber());
    const p = (n: number): string => n < 10 ? '0' + n : '' + n;
    return `${p(d.getMonth() + 1)}-${p(d.getDate())} ${p(d.getHours())}:${p(d.getMinutes())}:${p(d.getSeconds())}`;
  }

  /** 内容预览(前 max 字) */
  getPreview(max: number = 60): string {
    const clean = this.content.replace(/\n+/g, ' ').trim();
    return clean.length > max ? clean.substring(0, max) + '…' : clean;
  }
}
