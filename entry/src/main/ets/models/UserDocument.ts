import { cloudDatabase } from '@kit.CloudFoundationKit';
import { util } from '@kit.ArkTS';

export class UserDocument extends cloudDatabase.DatabaseObject {
  id: string = '';
  ownerId: string = '';
  title: string = '';
  content: string = '';
  createdAt: number = 0;
  updatedAt: number = 0;
  isPublic: boolean = false;
  sharedWith: string = '';

  naturalbase_ClassName(): string {
    return 'UserDocument';
  }

  static fromMap(map: Record<string, Object>): UserDocument {
    const doc = new UserDocument();
    doc.id = String(map['id'] || '');
    doc.ownerId = String(map['ownerId'] || '');
    doc.title = String(map['title'] || '');
    doc.content = String(map['content'] || '');
    doc.createdAt = Number(map['createdAt'] || 0);
    doc.updatedAt = Number(map['updatedAt'] || 0);
    if (typeof map['isPublic'] === 'boolean') {
      doc.isPublic = map['isPublic'] as boolean;
    } else {
      doc.isPublic = String(map['isPublic']) === 'true' || map['isPublic'] === 1;
    }
    doc.sharedWith = String(map['sharedWith'] || '');
    return doc;
  }

  static generateId(): string {
    return `${Date.now().toString(36)}-${util.generateRandomUUID()}`;
  }

  getDisplayTitle(): string {
    if (this.title) return this.title;
    const firstLine = this.content.split('\n')[0] || '';
    return firstLine.replace(/^#+\s*/, '').trim() || 'Untitled';
  }

  getFormattedDate(): string {
    if (!this.updatedAt) return '';
    const date = new Date(this.updatedAt);
    const month = (date.getMonth() + 1).toString().padStart(2, '0');
    const day = date.getDate().toString().padStart(2, '0');
    const hours = date.getHours().toString().padStart(2, '0');
    const minutes = date.getMinutes().toString().padStart(2, '0');
    return `${month}-${day} ${hours}:${minutes}`;
  }

  isSharedWithUser(userEmail: string): boolean {
    if (this.isPublic) return true;
    if (!this.sharedWith) return false;
    const emails = this.sharedWith.split(',').map(s => s.trim().toLowerCase());
    return emails.includes(userEmail.toLowerCase());
  }

  addSharedUser(email: string): void {
    const normalized = email.trim().toLowerCase();
    const emails = this.sharedWith ? this.sharedWith.split(',').map(s => s.trim().toLowerCase()) : [];
    if (!emails.includes(normalized)) {
      emails.push(normalized);
      this.sharedWith = emails.join(',');
    }
  }

  removeSharedUser(email: string): void {
    const normalized = email.trim().toLowerCase();
    const emails = this.sharedWith ? this.sharedWith.split(',').map(s => s.trim().toLowerCase()) : [];
    const filtered = emails.filter(u => u !== normalized);
    this.sharedWith = filtered.join(',');
  }
}
