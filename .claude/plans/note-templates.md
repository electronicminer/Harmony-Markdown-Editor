# 校园笔记模板库 + 一键生成

## 目标
内置多类校园专用笔记模板,首页/编辑器一键选择,生成标准化 markdown 笔记骨架填入文档,免去手搭结构。

## 设计

### 1. 模板数据 — 新增 `entry/src/main/ets/utils/NoteTemplates.ets`
导出接口 + 模板数组(8 类校园专用):
```ts
export interface NoteTemplate {
  id: string;
  name: string;
  icon: string;
  description: string;
  content: string; // markdown 骨架,含占位提示
}
export const NOTE_TEMPLATES: NoteTemplate[] = [ ... ];
```

8 类(可裁剪):
| 图标 | 名称 | 用途 |
|---|---|---|
| 📝 | 课堂笔记(康奈尔法) | 要点/记录/总结/复习四区 |
| 🔬 | 实验报告 | 目的/原理/步骤/数据/结论 |
| 📖 | 读书笔记 | 书目/摘要/摘录/感悟 |
| 📋 | 复习提纲 | 知识点/重点/易错/真题 |
| 💬 | 小组讨论记录 | 议题/观点/决议/待办 |
| 📅 | 学习计划 | 目标/周计划/打卡 |
| 🎤 | 答辩/演讲提纲 | 主题/结构/要点/Q&A |
| 🧮 | 理科公式笔记 | 概念/公式(LaTeX)/例题/易错 |

每模板 content 为 markdown 字符串,含 `[占位]` 和 `- ` 列表骨架。

### 2. 模板选择对话框 — 新增 `entry/src/main/ets/components/TemplateDialog.ets`
`@CustomDialog`,风格对齐 ShareDialog(毛玻璃、圆角 32、深色适配)。内部 `Grid` 2 列展示模板卡片(图标 + 名称 + 描述),点击触发 `onSelect: (t: NoteTemplate) => void` 回调并关闭。

### 3. 首页入口(主)— `Index.ets`
导航栏在 `+`(新建)旁加一个「📝」`GlassButton`。点击打开 `TemplateDialog`。选中模板后:
```ts
router.pushUrl({ url: 'pages/Editor', params: { content: t.content, isDark: this.isDark } });
```
复用 Editor 现有 `aboutToAppear` 接收 `params['content']` 的逻辑,无需改 Editor 的加载链路。

### 4. 编辑器入口(辅)— `Editor.ets`
工具栏右侧按钮组加「📝」按钮。点击打开 `TemplateDialog`。选中模板后调 `this.insertText(t.content)` 插入光标处(复用现有 `insertText`,会自动 recordHistory + 置脏标)。

## 改动文件清单
| 文件 | 改动 |
|---|---|
| `entry/src/main/ets/utils/NoteTemplates.ets` | **新增** 8 类模板数据 |
| `entry/src/main/ets/components/TemplateDialog.ets` | **新增** 模板选择对话框 |
| `entry/src/main/ets/pages/Index.ets` | 导航栏加 📝 按钮 + 对话框控制器 + 选中跳转 |
| `entry/src/main/ets/pages/Editor.ets` | 工具栏加 📝 按钮 + 对话框控制器 + 选中插入 |

## 模板内容示例(2 个,其余同类)

**课堂笔记(康奈尔)**:
```md
# 课堂笔记 - [课程名]

**日期**:YYYY/MM/DD  **讲师**:
**章节主题**:

## 核心要点
-

## 课堂记录
-

## 总结与思考
-

## 待办与复习
- [ ]
```

**理科公式笔记**:
```md
# [章节标题]

## 关键概念
-

## 重要公式
行内示例:$E = mc^2$

块级示例:
$$\int_a^b f(x)\,dx = F(b) - F(a)$$

## 例题
1.

## 易错点
-
```

## 不在本次范围
- AI 自动填充模板(模板是空骨架,手填;后续可加「AI 补全」按钮走现有 AIService)
- 用户自定义/新增模板(预设 8 类)
- 模板预览页(选中即生成,简化;对话框里已显示描述)
