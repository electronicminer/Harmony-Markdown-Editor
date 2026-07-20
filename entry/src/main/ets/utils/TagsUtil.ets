/**
 * 标签工具:解析/合并/历史建议
 */

/**
 * 把标签字符串解析为数组(逗号或中文逗号分隔)
 */
export function parseTags(tagsStr: string): string[] {
  if (!tagsStr) return [];
  return tagsStr
    .split(/[,，]/)
    .map(t => t.trim())
    .filter(t => t.length > 0);
}

/**
 * 把标签数组合并为字符串
 */
export function joinTags(tags: string[]): string {
  return tags.map(t => t.trim()).filter(t => t.length > 0).join(',');
}

/**
 * 添加一个标签(去重,不区分大小写)
 */
export function addTag(tags: string[], tag: string): string[] {
  const normalized = tag.trim();
  if (!normalized) return tags;
  const exists = tags.some(t => t.toLowerCase() === normalized.toLowerCase());
  if (exists) return tags;
  return [...tags, normalized];
}

/**
 * 移除一个标签
 */
export function removeTag(tags: string[], tag: string): string[] {
  return tags.filter(t => t.toLowerCase() !== tag.toLowerCase());
}

/**
 * 从多个文档中收集所有用过的标签(去重,按使用次数排序)
 */
interface TagDoc {
  tags?: string;
  getTags?: () => string[];
}
export function collectTags(docs: TagDoc[]): string[] {
  const counter: Map<string, number> = new Map();
  for (const d of docs) {
    let tags: string[] = [];
    if (d.getTags) {
      tags = d.getTags();
    } else if (d.tags) {
      tags = parseTags(d.tags);
    }
    for (const t of tags) {
      const key = t.toLowerCase();
      counter.set(key, (counter.get(key) || 0) + 1);
    }
  }
  // 按使用次数倒序
  const arr: string[] = [];
  Array.from(counter.keys()).sort((a, b) => (counter.get(b) || 0) - (counter.get(a) || 0))
    .forEach(k => arr.push(k));
  return arr;
}
