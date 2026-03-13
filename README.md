# Harmony Markdown Editor
#此为鸿蒙应用开发课程设计，同时开展此课程的同学暂时不要直接用来作为自己的课设哦~

一款深度集成 AI 能力、专为 HarmonyOS 设计与开发的下一代 Markdown 编辑器。它继承了鸿蒙的"原子化服务"、"统一生态"与"自然交互"理念，在界面和动效上做到原汁原味，同时将 AI 深度融入写作工作流，重新定义智能书写体验。

---

## 目录

- [项目特性](#项目特性)
- [截图展示](#截图展示)
- [项目架构](#项目架构)
- [环境要求](#环境要求)
- [快速开始](#快速开始)
- [使用方法](#使用方法)
- [部署平台](#部署平台)
- [许可证](#许可证)

---

## 项目特性

### Markdown 渲染引擎

- 基于 `marked` 解析器实现的原生 ArkUI 组件级渲染，非 WebView 方案，性能更优
- 完整支持 GFM (GitHub Flavored Markdown) 语法规范
- 支持以下 Markdown 元素的原生渲染：
  - 标题 (H1 - H6)
  - 粗体、斜体、删除线、行内代码
  - 代码块（含语法高亮）
  - 有序列表与无序列表（支持多级嵌套）
  - 引用块 (Blockquote)
  - 表格 (Table)
  - 分隔线
  - 图片与超链接
  - LaTeX 数学公式
  - HTML 标签（部分支持）
- 支持自定义主题配色与深色模式主题
- 支持自定义 Block / Inline 渲染器扩展

### 编辑器功能

- 实时分屏预览：编辑与预览同步展示，所见即所得
- 三种视图切换：分屏对比、仅编辑、仅预览
- 悬浮工具栏：一键插入标题、加粗、斜体、代码块、链接、图片、列表等格式
- 撤销 / 重做：支持最多 100 步历史记录
- 自动保存：可配置保存间隔，后台定时保存
- 文件管理：打开本地 `.md` 文件、另存为指定路径
- PDF 导出：通过内置 Web 组件实现打印导出
- 字数与字符数实时统计
- 拖拽分隔线：自由调整编辑区与预览区的宽度比例

### AI 智能写作助手

- 内置 AI 聊天面板，支持接入任何 OpenAI 兼容格式的 API
- Plan-Act 工作模式：AI 提出修改方案，用户确认后自动执行
- 支持的 AI 操作类型：
  - `replace_content` -- 替换指定文本内容
  - `append_content` -- 在文档末尾追加内容
  - `insert_content` -- 在光标位置插入内容
  - `delete_content` -- 删除指定文本内容
- 快捷操作按钮：语法帮助、优化写作、表格模板、代码块模板
- 可在设置中配置 API URL、API Key、模型名称与系统提示词
- 连接测试功能：保存前可验证 API 连通性

### 界面与交互

- 符合 HarmonyOS 设计规范的原生 UI 体验
- 玻璃态 (Glassmorphism) 悬浮导航栏，支持背景模糊与阴影效果
- 深色模式 / 浅色模式切换，支持跟随系统主题
- 流畅的动画过渡效果
- 安全区域适配（状态栏、导航栏）
- HarmonyOS Sans 字体

---

## 截图展示

### 浅色模式

![浅色模式](screen/1%20(1).png)

![深色模式](screen/1%20(3).png)

![深色模式](screen/1%20(5).png)
### 深色模式

![深色模式](screen/1%20(2).png)

![深色模式](screen/1%20(4).png)



---

## 项目架构

```
Harmony-Markdown-Editor/
├── AppScope/                    # 应用全局配置
├── entry/                       # 主模块 (Entry)
│   └── src/main/ets/
│       ├── pages/
│       │   ├── Index.ets        # 首页：Markdown 预览 + 导航
│       │   └── Editor.ets       # 编辑器：分屏编辑 + AI 面板
│       ├── components/
│       │   └── AIChatPanel.ets  # AI 聊天面板组件
│       ├── utils/
│       │   ├── AIService.ets    # AI 服务：API 调用与响应解析
│       │   ├── AIConfig.ets     # AI 配置管理
│       │   └── PreferencesUtil.ets  # 偏好设置持久化工具
│       └── entryability/
│           └── EntryAbility.ets # 应用入口 Ability
├── Markdown/                    # Markdown 渲染库模块
│   └── src/main/ets/
│       ├── Markdown.ets         # 主组件：解析与渲染入口
│       ├── Index.ets            # 模块导出与类型定义
│       ├── component/           # 渲染组件集合
│       │   ├── MarkdownComponent.ets  # 组件调度器
│       │   ├── Heading.ets      # 标题渲染
│       │   ├── Paragraph.ets    # 段落渲染
│       │   ├── Code.ets         # 代码块渲染
│       │   ├── Table.ets        # 表格渲染
│       │   ├── MList.ets        # 列表渲染
│       │   ├── BlockQuote.ets   # 引用块渲染
│       │   ├── Inline.ets       # 行内元素渲染
│       │   ├── Hr.ets           # 分隔线渲染
│       │   ├── Html.ets         # HTML 标签渲染
│       │   └── Latex.ets        # LaTeX 公式渲染
│       ├── config/              # 主题配置
│       │   ├── DefaultTheme.ets # 默认主题定义
│       │   └── MarkdownTheme.ets# 主题接口
│       ├── core/                # 解析核心
│       │   ├── parseInlineToken.ets  # 行内 Token 解析
│       │   ├── analyzer/
│       │   │   └── HighlightAnalyzer.ets  # 语法高亮分析器
│       │   └── plugins/
│       │       └── latex.ets    # LaTeX 插件
│       └── extensions.ets       # 扩展注册
└── screen/                      # 截图资源
```

---

## 环境要求

| 项目     | 要求                         |
| -------- | ---------------------------- |
| 操作系统 | Windows 10/11, macOS         |
| IDE      | DevEco Studio 5.0 及以上     |
| SDK      | HarmonyOS SDK API 15 (5.0.3) |
| 运行时   | HarmonyOS                    |
| 语言     | ArkTS (TypeScript 严格模式)  |

---

## 快速开始

### 1. 克隆仓库

```bash
git clone https://github.com/electronicminer/Harmony-Markdown-Editor.git
```

### 2. 使用 DevEco Studio 打开项目

1. 打开 DevEco Studio
2. 选择 `File` > `Open`，导航到克隆的项目目录
3. 等待 IDE 完成项目同步与依赖下载

### 3. 配置签名

1. 进入 `File` > `Project Structure` > `Signing Configs`
2. 勾选 `Automatically generate signature` 或手动配置签名证书

### 4. 运行项目

1. 连接 HarmonyOS 真机或启动模拟器
2. 选择目标设备
3. 点击 `Run` 按钮（或按 `Shift + F10`）编译并安装应用

---

## 使用方法

### 基本编辑

1. 启动应用后进入首页，默认展示一份示例 Markdown 文档的渲染效果
2. 点击顶部导航栏的编辑按钮进入编辑器，或点击 `+` 按钮新建空白文档
3. 编辑器默认以分屏模式运行，左侧为编辑区，右侧为实时预览区
4. 使用顶部工具栏的快捷按钮可快速插入 Markdown 格式语法
5. 长按拖拽分隔线可调整左右面板的宽度比例

### 视图切换

- 点击顶部导航栏的视图切换按钮，可在三种模式之间循环切换：
  - **分屏对比** -- 编辑区 + 预览区同时显示
  - **仅编辑** -- 全屏编辑模式
  - **仅预览** -- 全屏预览模式

### 文件操作

- **打开文件**：在首页点击文件夹按钮，从设备存储中选择 `.md` 文件
- **保存文件**：在编辑器中点击保存按钮，首次保存时弹出路径选择器
- **自动保存**：在设置中开启自动保存并设置间隔时间（单位为秒）

### 主题设置

- 点击深色/浅色模式切换按钮可手动切换主题
- 在设置中开启"跟随系统深色模式"后，应用将自动匹配系统主题

### 使用 AI 助手

1. 在编辑器顶部导航栏点击 AI 按钮开启 AI 面板
2. 首次使用前需在设置中配置 AI 参数：
   - **API URL**：填入 OpenAI 兼容格式的 API 地址（如 `https://api.openai.com/v1/chat/completions`）
   - **API Key**：填入对应的 API 密钥
   - **模型名称**：填入要使用的模型（如 `gpt-3.5-turbo`、`gpt-4` 等）
   - **系统提示词**：可自定义 AI 的角色定位和行为规则
3. 点击"测试连接"验证配置是否正确
4. 在 AI 面板中输入问题或修改指令，AI 将给出回复
5. 当 AI 提出文档修改方案时，面板中会弹出操作确认卡片
6. 点击"允许执行 (Act)"按钮即可将修改自动应用到文档

### 偏好设置

进入设置对话框可配置以下选项：

- 默认视图模式（分屏对比 / 仅编辑 / 仅预览）
- 跟随系统深色模式
- 深色模式手动开关
- 启动时打开上次文件
- 自动保存及保存间隔
- AI 配置

---

## 部署平台

### HarmonyOS 真机部署

本项目专为 HarmonyOS 平台开发，支持部署到以下设备：

- **平板**：运行 HarmonyOS 的华为平板（如 MatePad 系列），编辑器的分屏布局在大屏设备上体验更佳

部署步骤：

1. 使用 DevEco Studio 构建 Release 版本的 HAP 包
2. 通过 USB 连接目标设备，使用 IDE 直接安装
3. 或将 HAP 包通过 AppGallery Connect 提交审核后上架分发

### HarmonyOS 模拟器

DevEco Studio 内置模拟器支持快速调试：

1. 在 DevEco Studio 中打开 `Tools` > `Device Manager`
2. 创建或启动 HarmonyOS 模拟器
3. 选择模拟器作为运行目标，点击 `Run` 部署应用

### 兼容性说明

| 平台             | 支持状态 | 备注                          |
| ---------------- | -------- | ----------------------------- |
| HarmonyOS 手机   | 部分支持 | 未适配大小与比例              |
| HarmonyOS 平板   | 完全支持 | 推荐在pad端使用               |
| HarmonyOS 模拟器 | 完全支持 | 开发调试使用                  |
| Android / iOS    | 不支持   | 使用 ArkUI 原生框架，不跨平台 |

---

## 技术栈

- **开发语言**：ArkTS (TypeScript 严格模式下的鸿蒙方言)
- **UI 框架**：ArkUI 声明式 UI (Component V1 + V2)
- **Markdown 解析**：基于 `marked` 的自定义渲染管线
- **并发模型**：TaskPool 多线程解析，主线程不阻塞
- **数据持久化**：Preferences 轻量级键值存储
- **文件操作**：Core File Kit (fileIo)
- **网络请求**：Network Kit (http) -- 用于 AI API 调用
- **构建工具**：Hvigor

---

## 许可证

本项目基于 [MIT License](LICENSE) 开源。

```
MIT License

Copyright (c) 2026 electronicminer
```
