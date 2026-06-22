# Harmony Markdown Editor

<div align="center">

[![HarmonyOS](https://img.shields.io/badge/HarmonyOS-NEXT-76CE65?style=flat-square&logo=harmonyos)](https://developer.harmonyos.com/)
[![API Version](https://img.shields.io/badge/API-15%20(5.0.3)-blue?style=flat-square)](https://developer.harmonyos.com/)
[![Language](https://img.shields.io/badge/Language-ArkTS-purple?style=flat-square)](https://developer.harmonyos.com/cn/docs/documentation/doc-guides/arkts-overview-0000001828699769)
[![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)](LICENSE)

**基于 HarmonyOS NEXT 的原生 Markdown 编辑器** — ArkUI 原生渲染，集成 AI 写作助手与华为云同步

</div>

---

## 目录

- [截图](#截图)
- [项目概览](#项目概览)
- [核心功能](#核心功能)
  - [Markdown 渲染引擎](#markdown-渲染引擎)
  - [编辑器](#编辑器)
  - [AI 写作助手](#ai-写作助手)
  - [云端同步与分享](#云端同步与分享)
  - [用户系统](#用户系统)
  - [界面主题](#界面主题)
- [项目结构](#项目结构)
- [环境要求](#环境要求)
- [快速开始](#快速开始)
- [使用指南](#使用指南)
- [配置 AGConnect](#配置-agconnect)
- [技术栈](#技术栈)
- [Star 历史](#star-历史)
- [贡献者](#贡献者)
- [许可证](#许可证)

---

## 项目概览

Harmony Markdown Editor 是一款运行在 HarmonyOS NEXT 上的纯原生 Markdown 编辑与阅读应用。与市面上基于 WebView 的方案不同，本项目的 Markdown 渲染引擎直接调用 ArkUI 组件绘制，实现真正的原生渲染体验。

项目由两部分组成：

| 模块 | 路径 | 说明 |
|------|------|------|
| **Markdown** | `Markdown/` | 独立可发布的 Markdown 渲染库（已发布至 ohpm） |
| **Entry** | `entry/` | 完整的编辑器应用，集成渲染库、AI 助手、云端同步等 |


## 截图

### 浅色模式

![浅色模式首页](screen/1%20(1).png)

### 深色模式

![深色模式](screen/1%20(2).png)
![深色模式](screen/1%20(3).png)
![深色模式](screen/1%20(4).png)
![深色模式](screen/1%20(5).png)


## 核心功能

### Markdown 渲染引擎

基于 `marked` 解析器的 ArkTS 移植版本，支持完整的 GFM（GitHub Flavored Markdown）规范。通过 **TaskPool 多线程**在子线程完成词法分析和解析，主线程仅负责 UI 渲染，确保大文档渲染不卡顿。

**支持的元素：**

| 元素 | 语法 | 状态 |
|------|------|------|
| 标题 | `# ~ ######` | ✅ |
| 段落 | 普通文本 | ✅ |
| 粗体 | `**text**` | ✅ |
| 斜体 | `*text*` | ✅ |
| 删除线 | `~~text~~` | ✅ |
| 行内代码 | `` `code` `` | ✅ |
| 代码块 | ```` ``` ```` (带语法高亮) | ✅ |
| 有序列表 | `1. item` (支持嵌套) | ✅ |
| 无序列表 | `- item` (支持嵌套) | ✅ |
| 引用块 | `> quote` | ✅ |
| 表格 | `\| col \| col \|` | ✅ |
| 分隔线 | `---` | ✅ |
| 图片 | `![alt](url)` (可点击) | ✅ |
| 超链接 | `[text](url)` (可点击) | ✅ |
| LaTeX 公式 | `$...$` / `$$...$$` (本地渲染) | ✅ |
| HTML 标签 | 部分支持 | ⏳ |
| 任务列表 | `- [ ] task` | ⏳ |

**可扩展性：**

- 支持注册自定义 Block 和 Inline 渲染器
- 支持注册 `marked` 插件扩展语法
- 主题系统支持自定义颜色和字体样式

### 编辑器

- **分屏预览**：编辑区与预览区同步显示，左侧编辑右侧实时预览
- **三种视图模式**：分屏对比 ↔ 仅编辑 ↔ 仅预览，点击工具栏循环切换
- **悬浮工具栏**：毛玻璃效果悬浮在编辑器顶部，包含 H1/H2、加粗、斜体、代码块、链接、图片、有序/无序列表等快捷插入按钮
- **撤销 / 重做**：最多保留 100 步历史操作
- **自动保存 + 状态指示**：可配置开关与保存间隔（秒级），后台定时写入文件；状态栏实时显示「● 未保存」橙色脏标或「✓ 已自动保存 HH:MM:SS」时间戳，关闭文档时若有未保存修改会弹出确认对话框
- **文件操作**：
  - 从系统文件选择器打开 `.md` 文件
  - 保存 / 另存为到指定路径（外部 URI 直接写入，私有目录采用「先写 .tmp 再 rename」的原子写策略）
  - 启动时自动恢复上次打开的文件（可选）
- **字数统计**：实时显示单词数和字符数
- **拖拽分栏**：编辑区与预览区之间的分隔线支持拖拽调整比例
- **AI 面板集成**：启用后编辑器右侧展开 AI 聊天面板，形成三栏布局

### AI 写作助手

支持 OpenAI 兼容格式的 API 服务，接入后可实现以下功能：

- **对话式交互**：在 AI 面板中直接提问，AI 返回回答或文档修改建议；面板带「思考中」加载指示
- **多步执行计划（AgentPlan）**：AI 可一次性返回多个有序步骤（`steps[]`），按顺序依次应用到文档；同时向下兼容旧版单步 `action` 字段
- **操作确认机制**：AI 提出修改方案后，需用户点击「允许执行 (Act)」才会实际修改文档，点击「拒绝」放弃，避免误操作
- **支持的文档操作**：
  - `replace_content` — 替换指定文本
  - `append_content` — 文档末尾追加内容
  - `insert_content` — 光标位置插入内容
  - `delete_content` — 删除指定文本
- **快捷操作按钮**：语法帮助、优化写作、表格模板、代码块模板
- **可配置项**：API URL、API Key、模型名称、系统提示词；设置面板内置「测试连接」按钮验证连通性

> **注意**：使用前需在设置中自行配置兼容 OpenAI 格式的 API 地址与密钥。

### 云端同步与分享

用户认证和云存储基于华为 **AGConnect**（AppGallery Connect）服务：

- **云端文档库**：文档存储在华为 Cloud DB 上，同一账号跨设备同步
- **文档分享**：
  - 每个文档拥有唯一 ID，可将 ID 分享给他人
  - 支持**公开分享**（任何人凭 ID 可查看）
  - 支持按**邮箱添加协作者**，协作者可在"分享给我"列表查看
- **连接容灾**：Cloud DB 不可用时自动降级为本地 JSON 文件存储，数据不丢失
- **上传映射**：自动维护本地文件 URI 与云端文档 ID 的映射关系

### 用户系统

- **注册 / 登录**：邮箱验证码注册与登录（华为 AGConnect Auth）
- **密码管理**：密码强度检测（大小写字母、数字、特殊字符至少 3 种），支持密码重置
- **个人资料**：自定义昵称、个性签名、头像颜色（12 种颜色可选）
- **Token 管理**：自动维护登录态，支持退出登录

### 界面主题

- **深色 / 浅色模式**：支持手动切换
- **跟随系统**：可设置为跟随 HarmonyOS 系统深色模式自动切换
- **毛玻璃设计**：导航栏和工具栏采用 `backdropBlur` 毛玻璃效果
- **安全区域适配**：状态栏和导航栏做了 `expandSafeArea` 适配
- **字体**：全局使用 HarmonyOS Sans 系统字体


## 结构总览

```
Harmony-Markdown-Editor/
├── AppScope/                              # 应用级配置（bundleName、图标、标签）
│   └── app.json5
│
├── entry/                                 # 主应用模块（可执行 HAP）
│   ├── src/main/
│   │   ├── ets/
│   │   │   ├── Plugin.ets                  # 编辑器侧 LaTeX tokenizer 扩展
│   │   │   ├── entryability/
│   │   │   │   └── EntryAbility.ets       # Ability 生命周期，AGConnect 初始化
│   │   │   ├── entrybackupability/
│   │   │   │   └── EntryBackupAbility.ets # 备份恢复扩展
│   │   │   ├── pages/
│   │   │   │   ├── Index.ets             # 首页：Markdown 预览 + 文件导航
│   │   │   │   ├── Editor.ets            # 编辑器：分屏编辑预览 + AI 面板 + 保存状态
│   │   │   │   ├── CloudDocsPage.ets     # 云文档列表：我的文档 / 分享给我的
│   │   │   │   ├── RegisterPage.ets      # 登录 & 注册 & 用户资料
│   │   │   │   ├── ProfilePage.ets       # 个人资料编辑
│   │   │   │   └── PasswordResetPage.ets # 密码重置
│   │   │   ├── components/
│   │   │   │   ├── AIChatPanel.ets       # AI 对话面板（含多步计划确认卡片）
│   │   │   │   ├── ShareDialog.ets       # 文档分享对话框
│   │   │   │   └── CompletionPanel.ets   # 自动补全面板（预留）
│   │   │   ├── models/
│   │   │   │   └── UserDocument.ts       # Cloud DB 文档数据模型
│   │   │   └── utils/
│   │   │       ├── AuthService.ts        # 华为 AGConnect Auth 封装
│   │   │       ├── CloudDBService.ts     # 华为 Cloud DB 封装（含本地降级）
│   │   │       ├── AIService.ets         # AI API 调用（含 AgentPlan 多步规整）
│   │   │       ├── AIConfig.ets          # AI 配置状态管理
│   │   │       ├── PreferencesUtil.ets   # 偏好设置持久化（含云文档 ID 映射）
│   │   │       └── MarkdownCompletions.ts # Markdown 语法自动补全（预留）
│   │   └── resources/                    # 资源文件（string、color、media、rawfile）
│   └── oh-package.json5
│
├── Markdown/                              # Markdown 渲染库（独立 ohpm 包）
│   ├── src/main/ets/
│   │   ├── Markdown.ets                  # 渲染库主组件（@ComponentV2）
│   │   ├── MarkdownLite.ets              # 轻量版本（v2 旧版，已废弃）
│   │   ├── Index.ets                     # 导出入口
│   │   ├── component/                    # 各元素原生渲染组件
│   │   │   ├── MarkdownComponent.ets     # 根组件，遍历 Token 分发渲染
│   │   │   ├── Heading.ets              # 标题
│   │   │   ├── Paragraph.ets            # 段落
│   │   │   ├── Code.ets                 # 代码块
│   │   │   ├── Table.ets                # 表格
│   │   │   ├── MList.ets                # 列表（有序/无序）
│   │   │   ├── BlockQuote.ets           # 引用块
│   │   │   ├── Inline.ets               # 行内样式（粗体/斜体/代码/链接/图片）
│   │   │   ├── Hr.ets                   # 分割线
│   │   │   ├── Html.ets                 # HTML 标签
│   │   │   └── Latex.ets                # LaTeX 数学公式
│   │   ├── config/                       # 主题配置
│   │   │   ├── DefaultTheme.ets          # 默认亮/暗主题（参考 JetBrains UI 配色）
│   │   │   └── MarkdownTheme.ets         # 主题类型定义
│   │   ├── core/                         # marked 解析器 ArkTS 移植
│   │   │   ├── marked.ts                # 主入口，导出 Marked 实例
│   │   │   ├── Lexer.ts                 # 词法分析器
│   │   │   ├── Parser.ts                # 解析器
│   │   │   ├── Tokenizer.ts             # 分词器
│   │   │   ├── Renderer.ts              # HTML 渲染器
│   │   │   ├── TextRenderer.ts          # 纯文本渲染器
│   │   │   ├── Hooks.ts                 # 生命周期钩子
│   │   │   ├── Instance.ts              # Marked 核心实例
│   │   │   ├── Tokens.ts                # Token 类型定义
│   │   │   ├── rules.ts                 # 正则规则
│   │   │   ├── helpers.ts               # 辅助函数
│   │   │   ├── defaults.ts              # 默认配置
│   │   │   ├── MarkedOptions.ts          # 配置选项类型
│   │   │   ├── analyzer/
│   │   │   │   └── HighlightAnalyzer.ets # 代码语法高亮分析器
│   │   │   └── plugins/
│   │   │       └── latex.ets             # 数学公式插件
│   │   ├── extensions.ets               # 扩展机制
│   │   ├── merge.ts                     # 深度合并工具
│   │   └── utils.ets                    # 工具函数（含 TaskPool 解析入口）
│   └── oh-package.json5
│
├── screen/                                # 应用截图
├── oh-package.json5                       # 项目级 ohpm 配置
├── build-profile.json5                    # HarmonyOS 构建配置
└── hvigorfile.ts                          # Hvigor 构建脚本
```


## 环境要求

| 项目 | 要求 |
|------|------|
| 操作系统 | Windows 10/11, macOS, Linux |
| IDE | DevEco Studio 5.0+ |
| SDK | HarmonyOS SDK API 15 (5.0.3) |
| 目标设备 | HarmonyOS 手机 / 平板 / 模拟器 |
| 运行时 | HarmonyOS NEXT |
| 语言 | ArkTS |

### 兼容性

| 平台 | 支持 | 备注 |
|------|------|------|
| HarmonyOS 手机 | ✅ | 主力适配 |
| HarmonyOS 平板 | ✅ | 分屏体验更佳 |
| HarmonyOS 模拟器 | ✅ | 开发调试 |
| Android / iOS | ❌ | ArkUI 专属 |


## 快速开始

### 1. 克隆仓库

```bash
git clone https://github.com/electronicminer/Harmony-Markdown-Editor.git
```

### 2. DevEco Studio 打开

启动 DevEco Studio，选择 **File > Open**，选中项目根目录。IDE 会自动同步依赖。

### 3. 配置签名

**File > Project Structure > Signing Configs**，勾选 Automatically generate signing，或自行配置证书文件。

### 4. 配置华为云服务（可选）

如需使用云端同步功能，需参考[配置 AGConnect](#配置-agconnect) 章节完成华为云服务配置。

### 5. 运行

连接真机或启动模拟器，在 DevEco Studio 中选择目标设备，点击 **Run**。


## 使用指南

### 首页浏览

启动应用后进入首页，默认加载内置的示例 Markdown 文档并实时渲染。首页功能：

| 按钮 | 功能 |
|------|------|
| ⚙️ | 打开设置（视图模式、深色模式、自动保存、AI 配置等） |
| 🌙/☀️ | 切换深色/浅色主题 |
| 📂 | 从设备选择 `.md` 文件打开 |
| + | 新建空白文档进入编辑器 |
| ✏️ | 编辑当前预览的文档 |
| ☁️ | 进入云文档管理列表 |
| 👤 | 登录 / 注册 / 个人中心 |

### 编辑器操作

编辑器采用分屏布局，支持三种视图模式：

| 模式 | 说明 | 切换键 |
|------|------|--------|
| 分屏 | 左侧编辑 + 右侧实时预览，可拖拽调整比例 | 🌗 |
| 仅编辑 | 全屏编辑 | ✏️ |
| 仅预览 | 全屏预览渲染效果 | 👁️ |

**工具栏：**

- **Undo / Redo**：撤销和重做操作
- **H1 / H2**：插入一级/二级标题
- **Bold / Italic**：加粗 / 斜体
- **Code**：代码块
- **Link / Image**：链接 / 图片
- **UL / OL**：无序列表 / 有序列表

### 云端文档

1. 在首页点击 👤 进入登录页，使用邮箱验证码注册或登录
2. 打开或创建一个文档进入编辑器
3. 点击 ☁️ 按钮将当前文档上传到云端
4. 在首页点击 ☁️ 进入云文档管理页面

**文档分享：**

- 在文档列表中点击 **分享**，复制文档 ID 发送给他人
- 可**按邮箱添加协作者**，协作者登录后可在"分享给我"列表查看
- 开启**公开访问**后，任何人凭文档 ID 即可查看

### AI 助手

编辑器内点击 🤖 按钮展开 AI 面板。首次使用时需在 **设置 > AI 配置** 中配置 API 信息：

- **API URL**：兼容 OpenAI 格式的 API 地址
- **API Key**：你的 API 密钥
- **模型名称**：如 `gpt-3.5-turbo`、`gpt-4` 等
- **系统提示词**：自定义 AI 的行为角色

配置完成后点击 **测试连接** 验证连通性。

**工作流程：**

1. 在 AI 面板输入问题或指令
2. AI 回复普通文字，或给出文档修改建议（支持一次返回多步操作）
3. 如果是修改建议，会弹出确认卡片，列出本次将依次执行的所有步骤
4. 点击 **允许执行 (Act)** 按顺序应用全部步骤，**拒绝**放弃

### 设置项

| 设置 | 说明 |
|------|------|
| 默认视图模式 | 分屏 / 仅编辑 / 仅预览 |
| 跟随系统深色模式 | 自动跟随系统主题切换 |
| 深色模式 | 手动切换（跟随系统开启时禁用） |
| 启动时打开上次文件 | 下次启动自动恢复上次文档 |
| 自动保存 | 定时自动保存文档 |
| 自动保存间隔 | 保存频率（秒） |
| AI 配置 | API URL / Key / 模型 / 系统提示词 |


## 配置 AGConnect

要启用云端同步和用户认证功能，需在华为 AppGallery Connect 上创建应用并开通相关服务。

### 步骤

1. 登录 [AppGallery Connect](https://developer.huawei.com/consumer/cn/service/josp/agc/index.html)
2. 创建应用，包名填写 `com.wzq123.makedown_editor1223456.huawei`
3. 开通 **Authentication**：
   - 启用 **邮箱验证码** 登录方式
4. 开通 **Cloud DB**：
   - 创建数据库区 `HMarkdownZone`
   - 新建对象类型 `UserDocument`，包含字段：

| 字段名 | 类型 | 说明 |
|--------|------|------|
| `id` | String | 文档唯一 ID |
| `ownerId` | String | 创建者 UID |
| `title` | String | 标题 |
| `content` | String | Markdown 正文 |
| `createdAt` | Number | 创建时间戳 |
| `updatedAt` | Number | 更新时间戳 |
| `isPublic` | Boolean | 是否公开 |
| `sharedWith` | String | 协作者邮箱列表（逗号分隔） |

5. 下载 `agconnect-services.json` 放入 `entry/src/main/resources/rawfile/`

> **注意**：Cloud DB 不可用时，应用会自动降级为本地 JSON 文件存储，不影响正常使用。


## 技术栈

| 类别 | 技术 |
|------|------|
| 语言 | [ArkTS](https://developer.harmonyos.com/cn/docs/documentation/doc-guides/arkts-overview-0000001828699769) |
| UI 框架 | [ArkUI](https://developer.harmonyos.com/cn/docs/documentation/doc-guides/arkui-overview-0000001828699809)（声明式 UI） |
| 认证服务 | [华为 AGConnect Auth](https://developer.huawei.com/consumer/cn/doc/development/AppGallery-connect-Guides/agc-auth-service-introduction-0000001053732609) |
| 云数据库 | [华为 Cloud DB](https://developer.huawei.com/consumer/cn/doc/development/AppGallery-connect-Guides/agc-clouddb-introduction-0000001054373458) |
| Markdown 解析 | 基于 `marked` 的自定义 ArkTS 渲染管线 |
| 多线程 | TaskPool（子线程解析 Markdown） |
| 数据持久化 | Preferences 键值存储 + 本地 JSON 文件 |
| 文件操作 | Core File Kit（fileIo） |
| 网络请求 | Network Kit（http） |
| 构建工具 | Hvigor |
| 备份恢复 | HarmonyOS Backup Extension |


## Star 历史

[![Star History Chart](https://api.star-history.com/svg?repos=electronicminer/Harmony-Markdown-Editor&type=Date)](https://star-history.com/#electronicminer/Harmony-Markdown-Editor&Date)


## 贡献者

欢迎任何形式的贡献 — 提交 Issue、Pull Request，或在 [GitHub Discussions](https://github.com/electronicminer/Harmony-Markdown-Editor/discussions) 参与讨论。


## 许可证

本项目基于 MIT 许可证开源。详见 [LICENSE](LICENSE)。

```
MIT License

Copyright (c) 2026 electronicminer

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
