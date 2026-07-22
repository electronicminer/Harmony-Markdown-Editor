import { UserDocument } from '../models/UserDocument';

/**
 * 笔记全文检索服务
 * 本地内存过滤:在传入的文档列表里按关键词匹配 title + content
 * 数据量小(学生笔记几十到几百篇),O(n) 遍历足够
 */
export class SearchService {
  /**
   * 检索文档
   * @param docs 待检索的文档列表(通常为 myDocs)
   * @param keyword 关键词(多个空格分隔的词,AND 关系)
   * @returns 匹配的文档(保持原顺序)
   */
  static search(docs: UserDocument[], keyword: string): UserDocument[] {
    const trimmed = keyword.trim().toLowerCase();
    if (!trimmed) return docs;
    const words = trimmed.split(' ').filter(w => w.length > 0);
    if (words.length === 0) return docs;

    return docs.filter((doc: UserDocument) => {
      const hay = (doc.title + ' ' + doc.content).toLowerCase();
      // 所有词都要命中(AND)
      return words.every((w: string) => hay.indexOf(w) !== -1);
    });
  }
}
