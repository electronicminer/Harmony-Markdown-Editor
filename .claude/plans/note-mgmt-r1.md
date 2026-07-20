# 第一轮:标签分类 + 版本回溯 + 全文检索

## 范围(本轮)
- ✅ 标签分类:笔记支持多标签,按标签筛选
- ✅ 版本回溯:每次保存自动存历史快照,可查看/恢复
- ✅ 全文检索:本地按关键词检索标题+正文+标签
- ⏸ 不做:AES 加密、多媒体优化、权限级别细化、真向量检索(后续轮)

## 数据层改动

### 1. Cloud DB schema 扩展 - `rawfile/schema.json` + `makedown_AI_5_cn.json`
给 UserDocument 加字段:
| 字段 | 类型 | 说明 |
|---|---|---|
| `tags` | String | 标签,逗号分隔(如 `高数,第三章,重点`) |
| `isEncrypted` | Boolean | 是否加密(本轮预留字段,默认 false,暂不实装加密) |

> 注意:Cloud DB schema 修改需在 AGC 控制台同步,否则云端查询失败会自动降级本地模式(现有逻辑已支持)。

### 2. 新增版本快照 - `models/DocumentVersion.ts`
```ts
export class DocumentVersion {
  id: string;          // = docId + '_' + timestamp
  docId: string;
  content: string;
  title: string;
  createdAt: Long;
  // 序列化/反序列化辅助
}
```
**存储**:本地 JSON 文件(`filesDir/versions/<docId>.json`),每个文档保留最近 N=20 版,超出删最旧。
**触发**:Editor.saveDocument / cloudSave 成功后,异步写一份快照。
**理由**:版本数据量大,不入 Cloud DB;本地优先,云同步可后续做。

### 3. 检索索引 - 复用 PreferencesUtil
检索不需要单独索引,直接遍历本地 docs demo 文件 + 云端查询结果做内存过滤:
- 输入关键词 -> 遍历文档 `title + content + tags` 做大小写不敏感 `includes` 匹配
- 数据量小(学生笔记几十到几百篇),O(n) 遍历足够,无需倒排索引

## 工具层

### 4. `utils/TagsUtil.ets`(新增)
- `parseTags(tagsStr): string[]` -- 逗号分隔解析
- `joinTags(tags: string[]): string`
- `suggestTags(): string[]` -- 返回用户历史用过的标签(从偏好读)

### 5. `utils/VersionService.ts`(新增)
- `saveVersion(doc: UserDocument): Promise<void>` -- 写快照
- `listVersions(docId: string): Promise<DocumentVersion[]>` -- 按时间倒序
- `restoreVersion(version: DocumentVersion): UserDocument` -- 转回 doc
- `pruneVersions(docId: string, keep: number)` -- 保留最近 N 版

### 6. `utils/SearchService.ts`(新增)
- `searchDocs(keyword: string): Promise<UserDocument[]>` -- 查本地 demo docs + 云端 myDocs(传入),内存过滤

## UI 层

### 7. Editor - 标签编辑
- 顶部状态栏旁加「🏷️ 标签」按钮 -> 弹出标签编辑器(输入 + 历史 tag chips)
- 保存文档时把 tags 一起存

### 8. CloudDocsPage - 标签筛选 + 搜索
- 顶部加搜索框(输入关键词实时过滤)
- 搜索框下方加标签 chips 横滚条(点击筛选该标签)
- 列表项加标签显示

### 9. 版本回溯 UI
- Editor 工具栏或菜单加「⏱️ 历史」按钮 -> 弹出版本列表对话框
- 列表项:时间 + 内容预览(前 50 字)
- 点击某版本:预览 + 「恢复此版本」按钮 -> 覆盖当前文档(会再存一个新快照)

## 改动文件清单
| 文件 | 改动 |
|---|---|
| `entry/src/main/resources/rawfile/schema.json` | 加 tags / isEncrypted 字段 |
| `makedown_AI_5_cn.json` | 同步加字段(根目录,AGC schema 副本) |
| `entry/src/main/ets/models/UserDocument.ts` | 加 tags / isEncrypted 字段 + fromMap 解析 |
| `entry/src/main/ets/models/DocumentVersion.ts` | **新增** 版本快照模型 |
| `entry/src/main/ets/utils/TagsUtil.ets` | **新增** 标签解析/历史 |
| `entry/src/main/ets/utils/VersionService.ts` | **新增** 版本存取 |
| `entry/src/main/ets/utils/SearchService.ts` | **新增** 全文检索 |
| `entry/src/main/ets/utils/PreferencesUtil.ets` | 加历史标签存取方法 |
| `entry/src/main/ets/components/TagEditor.ets` | **新增** 标签编辑对话框 |
| `entry/src/main/ets/components/VersionHistoryDialog.ets` | **新增** 版本列表对话框 |
| `entry/src/main/ets/pages/Editor.ets` | 保存时写 tags+版本;加历史/标签入口 |
| `entry/src/main/ets/pages/CloudDocsPage.ets` | 加搜索框 + 标签筛选 + 列表项标签 |

## 风险与注意
- **Cloud DB schema 变更**:如果 AGC 控制台没同步加字段,云端 upsert 会失败 -> 现有 `switchToDemoMode` 自动降级本地,数据不丢但变成单机。建议你登录 AGC 控制台同步加 `tags` / `isEncrypted` 字段。本轮代码会兼容「云端无此字段」的情况(读时 `tags ?? ''`)。
- **版本快照体积**:每版一份完整 content,大文档 N=20 版可能占数 MB。本地存储,可接受;若文档超大后续可做 diff 存储。
- **检索数据源**:本轮只检索「我的云文档」(本地 demo 或云端查询结果),不检索「分享给我」的(可后续加)。

## 不在范围
- AES 加密实装(isEncrypted 字段预留)
- 多媒体加载优化
- 权限级别细化(查看/编辑/可再分享)
- 真向量检索
