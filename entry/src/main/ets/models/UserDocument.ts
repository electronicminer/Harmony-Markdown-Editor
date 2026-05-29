export class UserDocument {
  id: string = '';
  ownerId: string = '';
  title: string = '';
  content: string = '';
  createdAt: number = 0;
  updatedAt: number = 0;
  isPublic: boolean = false;
  sharedWith: string = '';

  static fromMap(map: Record<string, Object>): UserDocument {
    const doc = new UserDocument();
    doc.id = String(map['id'] || '');
    doc.ownerId = String(map['ownerId'] || '');
    doc.title = String(map['title'] || '');
    doc.content = String(map['content'] || '');
    doc.createdAt = Number(map['createdAt'] || 0);
    doc.updatedAt = Number(map['updatedAt'] || 0);
    doc.isPublic = Boolean(map['isPublic'] || false);
    doc.sharedWith = String(map['sharedWith'] || '');
    return doc;
  }

  static generateId(): string {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    let result = '';
    const timestamp = Date.now().toString(36);
    result += timestamp;
    for (let i = 0; i < 8; i++) {
      result += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return result;
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

  isSharedWithUser(uid: string): boolean {
    if (this.isPublic) return true;
    if (!this.sharedWith) return false;
    const uids = this.sharedWith.split(',').map(s => s.trim());
    return uids.includes(uid);
  }

  addSharedUser(uid: string): void {
    const uids = this.sharedWith ? this.sharedWith.split(',').map(s => s.trim()) : [];
    if (!uids.includes(uid)) {
      uids.push(uid);
      this.sharedWith = uids.join(',');
    }
  }

  removeSharedUser(uid: string): void {
    const uids = this.sharedWith ? this.sharedWith.split(',').map(s => s.trim()) : [];
    const filtered = uids.filter(u => u !== uid);
    this.sharedWith = filtered.join(',');
  }
}
