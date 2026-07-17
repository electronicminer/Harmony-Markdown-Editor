# AI 助手多模态输入(图片→Markdown)

## 目标
让 AIChatPanel 支持从相册选择图片(手写笔记、公式、表格等)随消息发送给 vision 大模型,模型返回的 Markdown(含 LaTeX `$...$`/`$$...$$`)复用现有渲染管线展示。技术路径:多模态大模型直出(OpenAI vision 兼容)。图片来源:仅相册(PhotoViewPicker)。

## 设计要点

### 1. 数据结构改造 — [AIService.ets](entry/src/main/ets/utils/AIService.ets)
`ChatMessage` 增加可选 `images` 字段(不破坏现有 string content):
```ts
export interface ChatMessage {
  role: 'system' | 'user' | 'assistant';
  content: string;
  images?: string[]; // data URL:data:image/jpeg;base64,...  仅 user 消息会有
}
```
**序列化策略(在 `AIService.chat` 内)**:遍历 messages,把每条消息转成 OpenAI vision 格式:
- 当前轮(最后一条带 images 的 user 消息):`content` 输出为数组 `[{type:'text',text}, ...images.map(i => ({type:'image_url',image_url:{url:i}}))]`
- 历史轮(非当前的 user 消息若残留 images):把 images 替换为文本占位 `[已上传图片×N]` 拼到 content 末尾,**不再发 base64**,避免多轮对话 token 爆炸
- assistant / system 消息:照常 string content

`ChatRequestBody.messages` 类型相应放开为 `ChatMessage[]`(序列化时 content 已是 string | array,JSON.stringify 直接支持)。

### 2. 系统提示词增强 — [AIService.ets:119](entry/src/main/ets/utils/AIService.ets#L119)
在注入的 `[IMPORTANT INSTRUCTIONS FOR AI AGENT]` 块末尾追加图片处理引导:
> 若用户消息含图片(手写笔记/公式/表格/截图),请将图片内容转换为 Markdown。数学公式用 `$...$`(行内)或 `$$...$$`(块级);表格用 GFM 表格;其余文字正常转写。仅当用户明确要求"修改文档"时才返回 JSON plan,纯转写识别直接返回 Markdown 文本。

### 3. 新增图片工具 — `entry/src/main/ets/utils/ImageUtil.ets`
封装「相册选图 → 解码 → 等比压缩 → JPEG → base64 data URL」全流程:
```ts
export async function pickImageAsDataUrl(maxLongEdge = 1600, quality = 80): Promise<string | null>
```
实现链路:
1. `new picker.PhotoViewPicker()` + `new picker.PhotoSelectOptions()`(`MIMEType = picker.PhotoViewMIMETypes.IMAGE`,`maxSelectNumber = 1`)→ `select()` 拿 uri
2. `image.createImageSource(uri)` → `getImageInfo()` 取原始宽高
3. 等比计算 desiredSize(长边 ≤ maxLongEdge)→ `createPixelMap({ desiredSize })` 一步缩放
4. `image.createImagePacker().packing(pixelMap, { format:'image/jpeg', quality })` → ArrayBuffer
5. `new util.Base64Helper().encodeToStringSync(new Uint8Array(buffer))` → 拼 `data:image/jpeg;base64,...`
6. `packer.release()` / `pixelMap.release()` 释放资源

压缩参数说明:长边 1600px + JPEG 80 质量,单图约 200–500KB,base64 后 ~300–700KB,兼顾清晰度与 token 成本。

### 4. UI 改造 — [AIChatPanel.ets](entry/src/main/ets/components/AIChatPanel.ets)

**新增状态**:
```ts
@State pendingImages: string[] = [];   // 待发送的 data URL
@State isPickingImage: boolean = false;
```

**输入栏**([AIChatPanel.ets:423](entry/src/main/ets/components/AIChatPanel.ets#L423) 的 Row):TextInput 左侧加一个 📎 圆形按钮,点击调 `pickImageAsDataUrl()`,成功后 push 进 `pendingImages`。

**缩略图预览条**:输入栏上方新增条件渲染的 Row,`ForEach(pendingImages)` 每张显示 64×64 圆角缩略图 + 右上角 ✕ 删除按钮。

**用户消息气泡**([AIChatPanel.ets:262](entry/src/main/ets/components/AIChatPanel.ets#L262)):若 `item.images?.length` ,在 Text 下方用 Row + ForEach 渲染小缩略图(80×80,圆角)。

**发送逻辑**([AIChatPanel.ets:63](entry/src/main/ets/components/AIChatPanel.ets#L63) `sendMessage`):
- 组建 userMessage 时带上 `images: this.pendingImages`
- push 后清空 `pendingImages = []`
- 注意:现有代码末尾又拼了一条重复的 `{role:'user',content:currentInput}`(见 [L91-97](entry/src/main/ets/components/AIChatPanel.ets#L91)),这是已存在的小问题;本次让图片只随 userMessage 走一次,顺带去掉那条重复拼接,保持 messages 干净。

### 5. 配置提示 — [Index.ets](entry/src/main/ets/pages/Index.ets) AIConfigDialog
在 API URL 输入区上方加一行说明文字:「多模态(图片识别)需模型支持 vision,如 gpt-4o、gemini-2.0 等」。纯提示,不做强制校验(兼容 API 多数已支持)。

## 改动文件清单
| 文件 | 改动 |
|---|---|
| `entry/src/main/ets/utils/AIService.ets` | ChatMessage 加 images;chat() 序列化为 vision 数组格式;历史图片占位化;系统提示词追加图片引导 |
| `entry/src/main/ets/utils/ImageUtil.ets` | **新增** pickImageAsDataUrl 全流程 |
| `entry/src/main/ets/components/AIChatPanel.ets` | 📎 按钮、缩略图预览条、消息气泡缩略图、sendMessage 带图与去重 |
| `entry/src/main/ets/pages/Index.ets` | AIConfigDialog 加一行多模态说明 |

## 风险与注意
- **ArkUI Image 对 data URL 的支持**:`Image(src)` 支持 `data:image/...;base64,...` 字符串;若个别设备异常,缩略图可改存 PixelMap(但 @State 持有 PixelMap 生命周期麻烦),先用 data URL。
- **大图内存**:pendingImages 在 state 中持 base64,一次最多选 1 张(本次 maxSelectNumber=1),可控;后续若放开多张需评估。
- **模型不支持 vision**:API 会返回错误信息,现有 `response.error` 通路会正常展示给用户,无需特殊处理。
- **权限**:PhotoViewPicker 是系统选择器,无需在 module.json5 申请相册权限(选图返回临时 uri 可读)。`ohos.permission.INTERNET` 已有。
- **公式识别质量**:取决于用户配置的模型能力,非代码层问题;提示词已强调用 LaTeX。

## 不在本次范围
- 相机拍照(用户选「仅相册」)
- 图片消息持久化(当前对话历史本身未持久化)
- 专用 OCR 路径(华为 ML Kit / Mathpix)
- 多图发送(先单图,maxSelectNumber=1;结构已支持数组,后续放开即可)
