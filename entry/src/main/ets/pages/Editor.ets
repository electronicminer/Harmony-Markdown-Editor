import { Markdown } from '@lidary/markdown';
import { common, ConfigurationConstant } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { util } from '@kit.ArkTS';
import { promptAction, router } from '@kit.ArkUI';
import { picker, fileIo as fs } from '@kit.CoreFileKit';
import { webview } from '@kit.ArkWeb';
import { marked } from '@lidary/markdown';

import { PreferencesUtil } from '../utils/PreferencesUtil';
import { AIConfig, AIConfigClass } from '../utils/AIConfig';
import { AIChatPanel } from '../components/AIChatPanel';
import { AgentPlan, AgentStep } from '../utils/AIService';
import { CloudDBService } from '../utils/CloudDBService';
import { AuthService } from '../utils/AuthService';
import { UserDocument } from '../models/UserDocument';
import { ShareDialog } from '../components/ShareDialog';
import Long from 'long';
// 自动补全功能导入（已注释）
// import { CompletionItem, filterCompletions, checkTrigger, TriggerInfo, CompletionItemType } from '../utils/MarkdownCompletions';

// #1 退出未保存确认对话框（风格对齐 ShareDialog）
@CustomDialog
struct ExitConfirmDialog {
  controller: CustomDialogController;
  isDark: boolean = false;
  onSaveAndExit: () => void = () => {};
  onDiscardAndExit: () => void = () => {};

  build() {
    Column({ space: 16 }) {
      Text('未保存的更改')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.isDark ? '#E5FFFFFF' : '#E5000000')
      Text('当前文档有未保存的更改，是否保存后再退出？')
        .fontSize(14)
        .fontColor(this.isDark ? '#99FFFFFF' : '#99000000')
        .lineHeight(22)
      Row({ space: 12 }) {
        Button('取消')
          .fontSize(15)
          .fontColor(this.isDark ? '#E5FFFFFF' : '#E5000000')
          .backgroundColor(this.isDark ? '#33FFFFFF' : '#0D000000')
          .type(ButtonType.Capsule)
          .height(44)
          .layoutWeight(1)
          .onClick(() => this.controller.close())
        Button('不保存')
          .fontSize(15)
          .fontColor(Color.White)
          .backgroundColor('#F4222D')
          .type(ButtonType.Capsule)
          .height(44)
          .layoutWeight(1)
          .shadow({ radius: 12, color: 'rgba(244,34,45,0.3)', offsetY: 4 })
          .onClick(() => {
            this.controller.close();
            this.onDiscardAndExit();
          })
        Button('保存并退出')
          .fontSize(15)
          .fontColor(Color.White)
          .backgroundColor('#0A59F7')
          .type(ButtonType.Capsule)
          .height(44)
          .layoutWeight(1)
          .shadow({ radius: 12, color: 'rgba(10,89,247,0.3)', offsetY: 4 })
          .onClick(() => {
            this.controller.close();
            this.onSaveAndExit();
          })
      }
      .width('100%')
    }
    .width('90%')
    .padding(24)
    .borderRadius(32)
    .backgroundColor(this.isDark ? 'rgba(36,36,36,0.95)' : 'rgba(240, 244, 255, 0.95)')
    .backdropBlur(80)
  }
}

// #10 未登录上传引导登录对话框（风格对齐 ShareDialog）
@CustomDialog
struct LoginPromptDialog {
  controller: CustomDialogController;
  isDark: boolean = false;

  build() {
    Column({ space: 16 }) {
      Text('需要登录')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.isDark ? '#E5FFFFFF' : '#E5000000')
      Text('上传到云端需要先登录账号，是否前往登录？')
        .fontSize(14)
        .fontColor(this.isDark ? '#99FFFFFF' : '#99000000')
        .lineHeight(22)
      Row({ space: 12 }) {
        Button('取消')
          .fontSize(15)
          .fontColor(this.isDark ? '#E5FFFFFF' : '#E5000000')
          .backgroundColor(this.isDark ? '#33FFFFFF' : '#0D000000')
          .type(ButtonType.Capsule)
          .height(44)
          .layoutWeight(1)
          .onClick(() => this.controller.close())
        Button('去登录')
          .fontSize(15)
          .fontColor(Color.White)
          .backgroundColor('#0A59F7')
          .type(ButtonType.Capsule)
          .height(44)
          .layoutWeight(1)
          .shadow({ radius: 12, color: 'rgba(10,89,247,0.3)', offsetY: 4 })
          .onClick(() => {
            this.controller.close();
            router.pushUrl({ url: 'pages/RegisterPage' });
          })
      }
      .width('100%')
    }
    .width('90%')
    .padding(24)
    .borderRadius(32)
    .backgroundColor(this.isDark ? 'rgba(36,36,36,0.95)' : 'rgba(240, 244, 255, 0.95)')
    .backdropBlur(80)
  }
}

@Entry
@Component
struct Editor {
  @State markdownText: string = '# Hello World\n\nStart writing your Markdown here...'
  @State isDark: boolean = false
  @State isLoading: boolean = false
  @State isExporting: boolean = false
  private fileName: string = 'saved_markdown.md';
  private fileUri: string = '';
  private controller: TextAreaController = new TextAreaController()
  private webController: webview.WebviewController = new webview.WebviewController();
  @State selectionStart: number = 0
  @State selectionEnd: number = 0
  @State wordCount: number = 0
  @State charCount: number = 0
  @State autoSave: boolean = false
  @State autoSaveInterval: number = 60
  @State viewMode: number = 0 // 0: Split, 1: Edit Only, 2: Preview Only
  @State hasUnsavedChanges: boolean = false // #1 dirty flag
  @State followSystem: boolean = false
  @StorageProp('currentColorMode') @Watch('onSystemModeChange') currentSystemMode: number = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT
  private autoSaveTimer: number = -1;
  
  // 拖拽分栏权重
  @State editorWeight: number = 1
  @State previewWeight: number = 1
  @State aiWeight: number = 1
  // #7 拖拽起始快照
  private dragStartEditorWeight: number = 1
  private dragStartPreviewWeight: number = 1
  private dragStartAiWeight: number = 1

  // 撤销/重做历史
  private undoStack: string[] = []
  private redoStack: string[] = []
  private maxHistory: number = 100
  @State canUndo: boolean = false
  @State canRedo: boolean = false
  private typingTimer: number = -1;
  @State aiEnabled: boolean = false;
  private aiConfig: AIConfigClass = new AIConfigClass();
  @State aiConfigVersion: number = 0; // 用于强制触发含 config 的子组件更新
  private context: common.UIAbilityContext = {} as common.UIAbilityContext;

  // 云文档
  @State cloudDocId: string = '';
  @State isCloudSyncing: boolean = false;
  @State cloudDocForShare: UserDocument = new UserDocument();
  private shareDialogController: CustomDialogController = new CustomDialogController({
    builder: ShareDialog({
      doc: this.cloudDocForShare,
      isDark: this.isDark,
      onRefresh: () => {}
    }),
    autoCancel: true,
    alignment: DialogAlignment.Center,
    customStyle: true
  });

  // #1 退出确认对话框控制器
  private exitConfirmController: CustomDialogController = new CustomDialogController({
    builder: ExitConfirmDialog({
      isDark: this.isDark,
      onSaveAndExit: () => {
        this.saveDocument(true);
        router.back();
      },
      onDiscardAndExit: () => {
        router.back();
      }
    }),
    autoCancel: true,
    alignment: DialogAlignment.Center,
    customStyle: true
  });

  // #10 登录提示对话框控制器
  private loginPromptController: CustomDialogController = new CustomDialogController({
    builder: LoginPromptDialog({
      isDark: this.isDark
    }),
    autoCancel: true,
    alignment: DialogAlignment.Center,
    customStyle: true
  });

  // ==================== 自动补全功能（已注释） ====================
  // @State showCompletion: boolean = false;
  // @State completions: CompletionItem[] = [];
  // @State selectedCompletionIndex: number = 0;
  // @State completionOffsetX: number = 0;
  // @State completionOffsetY: number = 0;
  // private currentTrigger: TriggerInfo | null = null;

  onSystemModeChange() {
    if (this.followSystem) {
      this.isDark = this.currentSystemMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    }
  }

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, Object>;
    if (params) {
      if (params['content']) {
        this.markdownText = params['content'] as string;
      }
      if (params['uri']) {
        this.fileUri = params['uri'] as string;
        // 检查该文件之前是否已上传到云端，恢复 cloudDocId
        const context = getContext(this) as common.UIAbilityContext;
        PreferencesUtil.getCloudDocId(context, this.fileUri).then(id => {
          if (id) this.cloudDocId = id;
        });
      }
      if (params['isDark'] !== undefined) {
        this.isDark = params['isDark'] as boolean;
      }
      if (params['viewMode'] !== undefined) {
        this.viewMode = params['viewMode'] as number;
      }
      if (params['cloudDocId']) {
        this.cloudDocId = params['cloudDocId'] as string;
      }
    } else {
      // 如果没有参数，尝试从偏好设置加载主题
      const context = getContext(this) as common.UIAbilityContext;
      PreferencesUtil.getIsDark(context).then(isDark => {
        this.isDark = isDark;
      });
      PreferencesUtil.getDefaultViewMode(context).then(mode => {
        this.viewMode = mode;
      });
      PreferencesUtil.getFollowSystem(context).then(follow => {
        this.followSystem = follow;
        if (this.followSystem) {
          this.isDark = this.currentSystemMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
        }
      });
    }

    // 加载自动保存设置
    const context = getContext(this) as common.UIAbilityContext;
    PreferencesUtil.getAutoSave(context).then(val => {
      this.autoSave = val;
      if (this.autoSave) {
        PreferencesUtil.getAutoSaveInterval(context).then(interval => {
          this.autoSaveInterval = interval;
          this.startAutoSave();
        })
      }
    })
    
    if (!this.markdownText || this.markdownText === '# Hello World\n\nStart writing your Markdown here...') {
       // 初始化时尝试加载保存的文档，如果没有则加载默认文档
       this.loadDocument()
    } else {
      this.updateCounts(this.markdownText);
    }
    // 初始状态推入撤销栈
    this.recordHistory(this.markdownText)
  }

  recordHistory(text: string) {
    if (this.typingTimer !== -1) {
      clearTimeout(this.typingTimer)
      this.typingTimer = -1
    }
    if (this.undoStack.length === 0 || this.undoStack[this.undoStack.length - 1] !== text) {
      if (this.undoStack.length >= this.maxHistory) {
        this.undoStack.shift()
      }
      this.undoStack.push(text)
      this.redoStack = [] // 发生新修改时，清空重做栈
      this.updateHistoryState()
    }
  }

  updateHistoryState() {
    this.canUndo = this.undoStack.length > 1
    this.canRedo = this.redoStack.length > 0
  }

  undo() {
    if (this.canUndo) {
      const current = this.undoStack.pop()
      if (current !== undefined) {
        this.redoStack.push(current)
      }
      const previous = this.undoStack[this.undoStack.length - 1]
      this.markdownText = previous
      this.updateCounts(previous)
      this.updateHistoryState()
    }
  }

  redo() {
    if (this.canRedo) {
      const next = this.redoStack.pop()
      if (next !== undefined) {
        this.undoStack.push(next)
        this.markdownText = next
        this.updateCounts(next)
      }
      this.updateHistoryState()
    }
  }

  updateCounts(text: string) {
    this.charCount = text.length;
    this.wordCount = text.trim() === '' ? 0 : text.trim().split(/\s+/).length;
  }

  aboutToDisappear() {
    // #6 清理所有定时器
    if (this.typingTimer !== -1) {
      clearTimeout(this.typingTimer);
      this.typingTimer = -1;
    }
    if (this.autoSaveTimer !== -1) {
      clearInterval(this.autoSaveTimer);
      this.autoSaveTimer = -1;
    }
  }

  // #9 onPageHide 时刷新待保存内容
  onPageHide(): void {
    if (this.typingTimer !== -1) {
      clearTimeout(this.typingTimer);
      this.typingTimer = -1;
      // 如果有未保存更改，立即刷新
      if (this.hasUnsavedChanges && this.autoSave) {
        this.performAutoSave();
      }
    }
  }

  startAutoSave() {
    if (this.autoSaveTimer !== -1) {
      clearInterval(this.autoSaveTimer);
      this.autoSaveTimer = -1;
    }
    if (this.autoSave && this.autoSaveInterval > 0) {
      this.autoSaveTimer = setInterval(() => {
        this.performAutoSave();
      }, this.autoSaveInterval * 1000);
    }
  }

  async performAutoSave(): Promise<void> {
    if (this.fileUri) {
      try {
        // #3 原子写：先写临时文件，再 rename
        const tmpUri = this.fileUri + '.tmp';
        const file = fs.openSync(tmpUri, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
        fs.writeSync(file.fd, this.markdownText);
        fs.closeSync(file);
        fs.renameSync(tmpUri, this.fileUri);
        this.hasUnsavedChanges = false;
        console.info('Auto saved to uri');
      } catch (e) {
        console.error('Auto save failed', e);
      }
    } else {
      this.saveDocument(true);
    }
  }

  loadDocument() {
    const context = getContext(this) as common.UIAbilityContext;
    const filesDir = context.filesDir;
    const filePath = filesDir + '/' + this.fileName;

    try {
      if (fs.accessSync(filePath)) {
        // Load from saved file
        const content = fs.readTextSync(filePath);
        this.markdownText = content;
        this.updateCounts(content);
      } else {
        this.loadDefaultDocument();
      }
    } catch (e) {
      console.error("Failed to load document:", e);
      this.loadDefaultDocument(); // Fallback
    }
  }

  loadDefaultDocument() {
    try {
      // 使用新的API获取上下文
      const context = getContext(this) as common.UIAbilityContext
      context.resourceManager.getRawFileContent("mark_test.md", (error: BusinessError, value: Uint8Array) => {
        if (error != null) {
          console.error("error is " + error);
        } else {
          // 使用新的文本解码API
          const textDecoder = new util.TextDecoder();
          this.markdownText = textDecoder.decodeToString(value)
          this.updateCounts(this.markdownText);
        }
      });
    } catch (e) {
      console.error("Failed to load default document:", e)
    }
  }

  insertText(text: string) {
    const start = this.selectionStart;
    const end = this.selectionEnd;
    const currentText = this.markdownText;

    const before = currentText.substring(0, start);
    const after = currentText.substring(end);

    const newText = before + text + after;
    this.markdownText = newText;
    this.recordHistory(newText);
    this.updateCounts(this.markdownText);
    this.selectionStart = start + text.length;
    this.selectionEnd = this.selectionStart;
    this.controller.caretPosition(this.selectionStart);
  }

  // ==================== 自动补全功能（已整体注释禁用） ====================
  // checkAndShowCompletion / updateCompletionPosition / hideCompletion /
  // applyCompletion / completionUp / completionDown / completionConfirm /
  // getCompletionIcon 已禁用，避免影响现有编辑与预览主流程。

  applyFormat(prefix: string, suffix: string) {
    const start = this.selectionStart;
    const end = this.selectionEnd;
    const currentText = this.markdownText;
    
    const before = currentText.substring(0, start);
    const selected = currentText.substring(start, end);
    const after = currentText.substring(end);
    
    const newText = before + prefix + selected + suffix + after;
    this.markdownText = newText;
    this.recordHistory(newText);
    this.updateCounts(this.markdownText);
    
    if (start === end) {
      this.selectionStart = start + prefix.length;
      this.selectionEnd = this.selectionStart;
    } else {
      this.selectionStart = start;
      this.selectionEnd = end + prefix.length + suffix.length;
    }
    this.controller.caretPosition(this.selectionEnd);
  }

  onBackPress(): boolean | void {
    // #1 退出未保存确认
    if (this.hasUnsavedChanges) {
      this.exitConfirmController.open();
      return true; // 阻止默认返回行为
    }
    this.saveDocument(true);
    return false;
  }

  // #1, #3 原子写保存文档（本地内部存储）
  saveDocument(silent: boolean = false) {
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const filesDir = context.filesDir;
      const filePath = filesDir + '/' + this.fileName;
      const tmpPath = filePath + '.tmp';

      // #3 原子写：先写临时文件，再 rename
      const file = fs.openSync(tmpPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      fs.writeSync(file.fd, this.markdownText);
      fs.closeSync(file);
      fs.renameSync(tmpPath, filePath);

      this.hasUnsavedChanges = false; // #1 reset dirty flag

      if (!silent) {
        promptAction.showToast({
          message: '已保存',
          duration: 1500
        });
      }
    } catch (e) {
      console.error("Failed to save document:", e);
      if (!silent) {
        promptAction.showToast({
          message: '保存失败',
          duration: 1500
        });
      }
    }
  }

  async saveFile() {
    try {
      let uri = this.fileUri;
      if (!uri) {
        const documentSavePicker = new picker.DocumentViewPicker();
        const documentSaveOptions = new picker.DocumentSaveOptions();
        documentSaveOptions.newFileNames = ['new_markdown.md'];
        const result = await documentSavePicker.save(documentSaveOptions);
        if (result && result.length > 0) {
          uri = result[0];
          this.fileUri = uri;
        } else {
          return; // User cancelled
        }
      }

      // #3 原子写：先写临时文件，再 rename
      const tmpUri = uri + '.tmp';
      const file = fs.openSync(tmpUri, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      fs.writeSync(file.fd, this.markdownText);
      fs.closeSync(file);
      fs.renameSync(tmpUri, uri);

      this.hasUnsavedChanges = false; // #1 reset dirty flag

      promptAction.showToast({
        message: '保存成功',
        duration: 1500
      });
    } catch (e) {
      console.error('Save file failed:', e);
      promptAction.showToast({
        message: '保存失败',
        duration: 1500
      });
    }
  }

  async cloudSave(): Promise<void> {
    // #11 提前置位防抖标志，避免 double-click 穿透
    if (this.isCloudSyncing) return;
    this.isCloudSyncing = true;

    const user = await AuthService.getCurrentUser();
    if (!user) {
      this.isCloudSyncing = false;
      // #10 未登录上传引导登录 dialog
      this.loginPromptController.open();
      return;
    }

    // 如果有本地文件但 cloudDocId 还是空的，立即从持久化映射中恢复
    if (!this.cloudDocId && this.fileUri) {
      const context = getContext(this) as common.UIAbilityContext;
      const existingId = await PreferencesUtil.getCloudDocId(context, this.fileUri);
      if (existingId) {
        this.cloudDocId = existingId;
      }
    }

    // 如果已有云端文档，先查出原文档保留元数据；否则新建
    let doc: UserDocument;
    if (this.cloudDocId) {
      const existing = await CloudDBService.getDocumentById(this.cloudDocId);
      if (existing) {
        doc = existing;
      } else {
        doc = new UserDocument();
        doc.id = this.cloudDocId;
        doc.ownerId = user.uid;
        doc.createdAt = Long.fromNumber(Date.now());
      }
    } else {
      doc = new UserDocument();
    }
    doc.content = this.markdownText;
    doc.title = this.markdownText.split('\n')[0]?.replace(/^#+\s*/, '').trim() || 'Untitled';

    const result = await CloudDBService.saveDocument(doc);
    this.isCloudSyncing = false;

    if (result.success && result.data) {
      const savedDoc = result.data as UserDocument;
      if (!this.cloudDocId || this.cloudDocId !== savedDoc.id) {
        this.cloudDocId = savedDoc.id;
      }
      // 持久化映射
      if (this.fileUri) {
        const context = getContext(this) as common.UIAbilityContext;
        PreferencesUtil.saveCloudDocId(context, this.fileUri, savedDoc.id);
      }
      promptAction.showToast({ message: result.message, duration: 1500 });
    } else {
      promptAction.showToast({ message: result.message, duration: 2000 });
    }
  }

  async openShareDialog(): Promise<void> {
    if (!this.cloudDocId) {
      promptAction.showToast({ message: '请先保存到云端', duration: 2000 });
      return;
    }
    const doc = await CloudDBService.getDocumentById(this.cloudDocId);
    if (doc) {
      this.cloudDocForShare = doc;
      this.shareDialogController.open();
    } else {
      promptAction.showToast({ message: '未找到云端文档', duration: 2000 });
    }
  }



  @Builder
  GlassIconButton(icon: string, action: () => void, fontSize: number = 20) {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      Text(icon)
        .fontSize(fontSize)
        .fontColor(this.isDark ? '#E5FFFFFF' : '#E5000000')
        .offset({ y: -1 })
    }
    .width(44)
    .height(44)
    .backgroundColor(this.isDark ? 'rgba(255, 255, 255, 0.1)' : 'rgba(0, 0, 0, 0.05)')
    .backdropBlur(50)
    .shadow(ShadowStyle.OUTER_DEFAULT_XS)
    .onClick(action)
    .animation({ duration: 200, curve: Curve.EaseInOut })
  }

  @Builder
  ToolButton(label: string, action: () => void) {
    Button({ type: ButtonType.Capsule, stateEffect: true }) {
      Text(label)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.isDark ? '#E5FFFFFF' : '#E5000000')
    }
    .height(36)
    .padding({ left: 16, right: 16 })
    .backgroundColor(this.isDark ? 'rgba(255, 255, 255, 0.1)' : 'rgba(0, 0, 0, 0.05)')
    .backdropBlur(50)
    .onClick(action)
    .animation({ duration: 200, curve: Curve.EaseInOut })
  }

  @Builder
  UndoButton() {
    Button({ type: ButtonType.Capsule, stateEffect: true }) {
      Text('Undo')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.canUndo ? (this.isDark ? '#E5FFFFFF' : '#E5000000') : (this.isDark ? '#66FFFFFF' : '#66000000'))
    }
    .height(36)
    .padding({ left: 16, right: 16 })
    .backgroundColor(this.isDark ? 'rgba(255, 255, 255, 0.1)' : 'rgba(0, 0, 0, 0.05)')
    .backdropBlur(50)
    .enabled(this.canUndo)
    .onClick(() => this.undo())
    .animation({ duration: 200, curve: Curve.EaseInOut })
  }

  @Builder
  RedoButton() {
    Button({ type: ButtonType.Capsule, stateEffect: true }) {
      Text('Redo')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.canRedo ? (this.isDark ? '#E5FFFFFF' : '#E5000000') : (this.isDark ? '#66FFFFFF' : '#66000000'))
    }
    .height(36)
    .padding({ left: 16, right: 16 })
    .backgroundColor(this.isDark ? 'rgba(255, 255, 255, 0.1)' : 'rgba(0, 0, 0, 0.05)')
    .backdropBlur(50)
    .enabled(this.canRedo)
    .onClick(() => this.redo())
    .animation({ duration: 200, curve: Curve.EaseInOut })
  }

  @Builder
  DividerBar(onDragStart: () => void, onDrag: (offset: number) => void) {
    Stack() {
       Column()
         .width(4)
         .height(32)
         .backgroundColor(this.isDark ? '#33FFFFFF' : '#1A000000')
         .borderRadius(2)
    }
    .width(16)
    .height('100%')
    .backgroundColor('transparent')
    .gesture(
      PanGesture({ direction: PanDirection.Horizontal })
        .onActionStart((_event) => {
          // #7 拖拽开始时记录初始权重值
          onDragStart();
        })
        .onActionUpdate((event) => {
          onDrag(event.offsetX)
        })
    )
  }

  /**
   * 转义正则元字符
   */
  private escapeRegExp(s: string): string {
    return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  }

  /**
   * 把锚点编译成「空白宽松」正则源：连续空白(含换行) -> \s+，其余字符精确匹配
   */
  private toLooseSource(anchor: string): string {
    const trimmed = anchor.trim();
    // 按空白切分后逐段转义，再用 \s+ 连接
    const parts = trimmed.split(/\s+/).filter((p): boolean => p.length > 0);
    return parts.map((p): string => this.escapeRegExp(p)).join('\\s+');
  }

  /**
   * 定位锚点在 text 中的范围（第 occurrence 次出现）。
   * 三级回退：精确匹配 -> 空白宽松匹配 -> 首尾行范围匹配。
   * 返回 { start, len }，未找到返回 { start: -1, len: 0 }。
   */
  private locateAnchor(text: string, anchor: string, occurrence: number): Record<string, number> {
    const notFound: Record<string, number> = { 'start': -1, 'len': 0 };
    if (!anchor) {
      return notFound;
    }
    const nth = occurrence && occurrence > 0 ? occurrence : 1;

    // 1) 精确匹配
    let from = 0;
    let idx = -1;
    for (let i = 0; i < nth; i++) {
      idx = text.indexOf(anchor, from);
      if (idx === -1) {
        break;
      }
      from = idx + anchor.length;
    }
    if (idx !== -1) {
      return { 'start': idx, 'len': anchor.length };
    }

    // 2) 空白宽松匹配
    try {
      const loose = new RegExp(this.toLooseSource(anchor), 'g');
      let m: RegExpExecArray | null = loose.exec(text);
      let count = 0;
      while (m !== null) {
        count++;
        if (count === nth) {
          return { 'start': m.index, 'len': m[0].length };
        }
        if (m[0].length === 0) {
          loose.lastIndex++;
        }
        m = loose.exec(text);
      }
      // 出现次数不足时退回第一处
      if (count > 0) {
        const first = new RegExp(this.toLooseSource(anchor)).exec(text);
        if (first !== null) {
          return { 'start': first.index, 'len': first[0].length };
        }
      }
    } catch (e) {
      // 正则构造失败则忽略，进入下一级
    }

    // 3) 首尾行范围匹配：用锚点的首个非空行与末个非空行框定整段
    const lines = anchor.split('\n').map((l): string => l.trim()).filter((l): boolean => l.length > 0);
    if (lines.length >= 2) {
      const firstLine = lines[0];
      const lastLine = lines[lines.length - 1];
      const startIdx = text.indexOf(firstLine);
      if (startIdx !== -1) {
        const lastIdx = text.indexOf(lastLine, startIdx + firstLine.length);
        if (lastIdx !== -1) {
          const end = lastIdx + lastLine.length;
          return { 'start': startIdx, 'len': end - startIdx };
        }
      }
    }

    return notFound;
  }

  /**
   * 定位操作范围。无 endAnchor 时等同 locateAnchor；
   * 有 endAnchor 时返回 [anchor 起点, endAnchor 终点] 的整段范围。
   */
  private locateRange(text: string, anchor: string, endAnchor: string, occurrence: number): Record<string, number> {
    const start = this.locateAnchor(text, anchor, occurrence);
    if (start.start === -1 || !endAnchor) {
      return start;
    }
    // 在 anchor 之后查找 endAnchor
    const afterStart = start.start + start.len;
    const tail = text.substring(afterStart);
    const endLoc = this.locateAnchor(tail, endAnchor, 1);
    if (endLoc.start === -1) {
      return start; // 找不到结束锚点，退化为只覆盖起始锚点
    }
    const end = afterStart + endLoc.start + endLoc.len;
    return { 'start': start.start, 'len': end - start.start };
  }

  handleApplyPlan(plan: AgentPlan) {
    if (!plan || !plan.steps || plan.steps.length === 0) {
      return;
    }

    let currentText = this.markdownText;
    let applied = 0;
    let failed = 0;

    for (const step of plan.steps) {
      const anchor: string = (step.anchor ?? '').replace(/\\n/g, '\n');
      const endAnchor: string = (step.endAnchor ?? '').replace(/\\n/g, '\n');
      const content: string = (step.content ?? '').replace(/\\n/g, '\n');
      const occurrence: number = step.occurrence ?? 1;

      switch (step.action) {
        case 'replace':
        case 'replace_content': {
          const loc = this.locateRange(currentText, anchor, endAnchor, occurrence);
          if (loc.start !== -1) {
            currentText = currentText.substring(0, loc.start) + content + currentText.substring(loc.start + loc.len);
            applied++;
          } else {
            failed++;
          }
          break;
        }
        case 'delete':
        case 'delete_content': {
          const loc = this.locateRange(currentText, anchor, endAnchor, occurrence);
          if (loc.start !== -1) {
            currentText = currentText.substring(0, loc.start) + currentText.substring(loc.start + loc.len);
            applied++;
          } else {
            failed++;
          }
          break;
        }
        case 'insert_after': {
          const loc = this.locateAnchor(currentText, anchor, occurrence);
          if (loc.start !== -1) {
            const pos = loc.start + loc.len;
            currentText = currentText.substring(0, pos) + content + currentText.substring(pos);
            applied++;
          } else {
            failed++;
          }
          break;
        }
        case 'insert_before': {
          const loc = this.locateAnchor(currentText, anchor, occurrence);
          if (loc.start !== -1) {
            currentText = currentText.substring(0, loc.start) + content + currentText.substring(loc.start);
            applied++;
          } else {
            failed++;
          }
          break;
        }
        case 'append':
        case 'append_content':
        case 'insert_content': {
          currentText = currentText.length > 0 ? currentText + '\n' + content : content;
          applied++;
          break;
        }
        case 'prepend': {
          currentText = content + '\n' + currentText;
          applied++;
          break;
        }
        default:
          failed++;
          break;
      }
    }

    this.markdownText = currentText;
    this.recordHistory(currentText);
    this.updateCounts(currentText);

    const total = plan.steps.length;
    const msg = failed === 0
      ? `已应用 ${applied}/${total} 项操作`
      : `已应用 ${applied}/${total} 项，${failed} 项未找到锚点`;
    promptAction.showToast({ message: msg, duration: 2000 });
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      // 底层：真正的编辑器主体，全屏显示，由内部控制文字的初始下沉
      Column() {
        // 编辑器和预览区域 + AI 面板（三分屏布局，带拖拽分隔线）
        Row() {
          // 第一列：左侧编辑区域
          if (this.viewMode === 0 || this.viewMode === 1) {
            Column() {
              TextArea({
                  text: this.markdownText,
                  controller: this.controller
                })
              .onChange((value: string) => {
                // 如果当前内容因为 Undo/Redo 而改变，忽略这次记录
                if (this.markdownText !== value) {
                  this.markdownText = value
                  this.updateCounts(value)
                  this.hasUnsavedChanges = true // #1 dirty flag

                  if (this.typingTimer !== -1) {
                    clearTimeout(this.typingTimer)
                  }
                  this.typingTimer = setTimeout(() => {
                    this.recordHistory(value)
                    // #9 自动保存防抖兜底：800ms 无输入后触发静默保存
                    if (this.autoSave) {
                      this.performAutoSave();
                    }
                  }, 800)

                  // 自动补全逻辑已禁用
                }
              })
              .onTextSelectionChange((selectionStart: number, selectionEnd: number) => {
                this.selectionStart = selectionStart
                this.selectionEnd = selectionEnd
                // 自动补全逻辑已禁用
              })
              .onKeyEvent((_event) => {
                // 自动补全快捷键和导航已禁用
                return false;
              })
              .width('100%')
              .height('100%')
              .padding({ left: 16, right: 16, top: 100, bottom: 16 }) // 让出悬浮胶囊的高度
              .backgroundColor('transparent')
              .fontColor(this.isDark ? '#E5FFFFFF' : '#E5000000')
              .borderRadius(16)
          }
          .layoutWeight((this.viewMode === 0 || this.viewMode === 1) ? this.editorWeight : 0)
          .height('100%')
          .backgroundColor(this.isDark ? '#242424' : '#FFFFFF')
          .margin({ left: (this.viewMode === 0 || this.viewMode === 1) && !this.aiEnabled && this.viewMode !== 0 ? 16 : (this.viewMode === 1 && this.aiEnabled ? 16 : (this.viewMode === 0 ? 16 : 0)), top: 16, bottom: 0 })
          .borderRadius({ topLeft: 16, topRight: this.viewMode === 0 ? 0 : 16 })
          .clip(true)
        }

        // 第一道 分隔线（仅在分屏时显示）
        if (this.viewMode === 0) {
          this.DividerBar(() => {
            // #7 记录拖拽起始快照
            this.dragStartEditorWeight = this.editorWeight;
            this.dragStartPreviewWeight = this.previewWeight;
          }, (offset) => {
            // 根据拖拽调整权重（基于起始值）
            const totalWeight = this.dragStartEditorWeight + this.dragStartPreviewWeight;
            const delta = offset / 1000;
            this.editorWeight = Math.max(0.2, this.dragStartEditorWeight + delta * totalWeight);
            this.previewWeight = Math.max(0.2, totalWeight - this.editorWeight);
          })
        }

        // 第二列：中间/右侧预览区域
        if (this.viewMode === 0 || this.viewMode === 2) {
          Column() {
            Scroll() {
              Markdown({
                content: this.markdownText,
                options: {
                  darkMode: this.isDark,
                  options: {
                    gfm: true
                  },
                  darkTheme: {
                    themeColor: Color.Orange
                  }
                },
                onLoading: () => {
                  this.isLoading = true
                },
                onError: () => {
                  this.isLoading = false
                },
                onSuccess: () => {
                  this.isLoading = false
                }
              })
              .padding({ left: 16, right: 16, top: 100, bottom: 16 }) // 预览区让出胶囊高度
            }
            .layoutWeight(1)
          }
          .layoutWeight((this.viewMode === 0 || this.viewMode === 2) ? this.previewWeight : 0)
          .height('100%')
          .backgroundColor(this.isDark ? '#242424' : '#FFFFFF')
          .margin({ top: 16, left: this.viewMode === 2 ? 16 : 0, right: this.aiEnabled ? 0 : 16 })
          .borderRadius({ topLeft: this.viewMode === 2 ? 16 : 0, topRight: this.aiEnabled ? 0 : 16, bottomLeft: this.viewMode === 2 ? 16 : 0 })
          .clip(true)
        }

        // 第二道 分隔线（仅在启用了 AI 时显示）
        if (this.aiEnabled) {
          this.DividerBar(() => {
            // #7 记录拖拽起始快照
            this.dragStartEditorWeight = this.editorWeight;
            this.dragStartPreviewWeight = this.previewWeight;
            this.dragStartAiWeight = this.aiWeight;
          }, (offset) => {
            // 根据拖拽调整权重（基于起始值）
            const totalWeight = (this.viewMode === 1 ? this.dragStartEditorWeight : (this.viewMode === 2 ? this.dragStartPreviewWeight : this.dragStartEditorWeight + this.dragStartPreviewWeight)) + this.dragStartAiWeight;
            const delta = offset / 1000;

            // 如果是在分屏状态下拖动，我们保持左侧两栏的相对比例，缩小它们并放大 AI 面板
             if (this.viewMode === 0) {
               const leftPanelTotal = this.dragStartEditorWeight + this.dragStartPreviewWeight;
               const newLeftTotal = Math.max(0.2, leftPanelTotal + delta * totalWeight);
               this.aiWeight = Math.max(0.2, totalWeight - newLeftTotal);

               // 按原比例分配剩下的空间
               const ratio = this.dragStartEditorWeight / leftPanelTotal;
               this.editorWeight = newLeftTotal * ratio;
               this.previewWeight = newLeftTotal * (1 - ratio);
             } else if (this.viewMode === 1) {
                this.editorWeight = Math.max(0.2, this.dragStartEditorWeight + delta * totalWeight);
                this.aiWeight = Math.max(0.2, totalWeight - this.editorWeight);
             } else {
                this.previewWeight = Math.max(0.2, this.dragStartPreviewWeight + delta * totalWeight);
                this.aiWeight = Math.max(0.2, totalWeight - this.previewWeight);
             }
          })
        }

        // 第三列：最右侧 AI 面板
        if (this.aiEnabled) {
          Column() {
            AIChatPanel({
              isDark: this.isDark,
              aiEnabled: this.aiEnabled,
              aiConfig: this.aiConfig,
              aiConfigVersion: this.aiConfigVersion,
              context: this.context,
              currentContent: this.markdownText,
              onApplyPlan: (plan: AgentPlan) => {
                this.handleApplyPlan(plan);
              }
            })
          }
          .layoutWeight(this.aiWeight)
          .height('100%')
          .padding({ top: 100 }) // 顶部留出悬浮胶囊空间
          .margin({ top: 16, right: 16 })
          .borderRadius(16)
          .clip(true)
          .backgroundColor(this.isDark ? '#242424' : '#FFFFFF')
        }
      }
      .width('100%')
      .layoutWeight(1)
      .padding({ bottom: 16 })

      // 状态栏
      Row() {
        Text(`Words: ${this.wordCount}  Chars: ${this.charCount}`)
          .fontSize(12)
          .fontColor(this.isDark ? '#99FFFFFF' : '#99000000')
      }
      .width('100%')
      .height(32)
      .padding({ left: 24, right: 24 })
      .backgroundColor('transparent')
      .justifyContent(FlexAlign.End)

      // Hidden Web component for PDF export
      Web({ src: '', controller: this.webController })
        .height(0)
        .width(0)
        .visibility(Visibility.Hidden)
        .onPageEnd(() => {
          if (this.isExporting) {
            this.isExporting = false;
            try {
              // Use window.print() to trigger print dialog
              this.webController.runJavaScript('window.print()');
              this.isLoading = false;
            } catch (e) {
              console.error('Print failed:', e);
              this.isLoading = false;
            }
          }
        })
      }
      .width('100%')
      .height('100%')

      // 补全弹窗组件已注释禁用

      // 顶层：合并导航栏 + 工具栏为单行胶囊
      Column() {
        Row() {
          // 左侧：返回按钮 + Editor 标签
          Row({ space: 8 }) {
            this.GlassIconButton('‹', () => {
              router.back({
                url: 'pages/Index',
                params: {
                  content: this.markdownText,
                  uri: this.fileUri
                }
              })
            }, 30)

            Text('Editor')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontFamily('HarmonyOS Sans')
              .fontColor(this.isDark ? '#E5FFFFFF' : '#E5000000')
          }

          // 中间：横向滚动工具栏
          Scroll() {
            Row({ space: 10 }) {
              Divider().vertical(true).height(20).color(this.isDark ? '#33FFFFFF' : '#1A000000')
              this.UndoButton()
              this.RedoButton()
              Divider().vertical(true).height(20).color(this.isDark ? '#33FFFFFF' : '#1A000000')
              this.ToolButton('H1', () => { this.insertText('# ') })
              this.ToolButton('H2', () => { this.insertText('## ') })
              this.ToolButton('Bold', () => { this.applyFormat('**', '**') })
              this.ToolButton('Italic', () => { this.applyFormat('*', '*') })
              this.ToolButton('Code', () => { this.applyFormat('```\n', '\n```') })
              this.ToolButton('Link', () => { this.applyFormat('[', '](url)') })
              this.ToolButton('Image', () => { this.insertText('![alt](image-url)') })
              this.ToolButton('UL', () => { this.insertText('- ') })
              this.ToolButton('OL', () => { this.insertText('1. ') })
            }
            .padding({ left: 8, right: 8 })
          }
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
          .layoutWeight(1)

          // 右侧：功能按钮组
          Row({ space: 8 }) {
            this.GlassIconButton('🤖', () => {
              this.aiEnabled = !this.aiEnabled;
              if (this.aiEnabled) {
                this.context = getContext(this) as common.UIAbilityContext;
                AIConfig.load(this.context).then(config => {
                  this.aiConfig = config;
                  this.aiConfigVersion += 1;
                });
              }
            })
            // #14 视图模式分段控件 — 玻璃胶囊风格，融入工具栏
            Row({ space: 0 }) {
              Button('编辑')
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .height(32)
                .padding({ left: 14, right: 14 })
                .fontColor(this.viewMode === 1 ? Color.White : (this.isDark ? '#99FFFFFF' : '#99000000'))
                .backgroundColor(this.viewMode === 1 ? '#0A59F7' : 'transparent')
                .borderRadius(20)
                .onClick(() => { this.viewMode = 1; })
                .animation({ duration: 200, curve: Curve.EaseInOut })
              Button('分屏')
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .height(32)
                .padding({ left: 14, right: 14 })
                .fontColor(this.viewMode === 0 ? Color.White : (this.isDark ? '#99FFFFFF' : '#99000000'))
                .backgroundColor(this.viewMode === 0 ? '#0A59F7' : 'transparent')
                .borderRadius(20)
                .onClick(() => { this.viewMode = 0; })
                .animation({ duration: 200, curve: Curve.EaseInOut })
              Button('预览')
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .height(32)
                .padding({ left: 14, right: 14 })
                .fontColor(this.viewMode === 2 ? Color.White : (this.isDark ? '#99FFFFFF' : '#99000000'))
                .backgroundColor(this.viewMode === 2 ? '#0A59F7' : 'transparent')
                .borderRadius(20)
                .onClick(() => { this.viewMode = 2; })
                .animation({ duration: 200, curve: Curve.EaseInOut })
            }
            .padding(2)
            .borderRadius(22)
            .backgroundColor(this.isDark ? 'rgba(255, 255, 255, 0.1)' : 'rgba(0, 0, 0, 0.05)')
            .backdropBlur(50)
            this.GlassIconButton('💾', () => {
              this.saveFile()
            })
            this.GlassIconButton(this.isCloudSyncing ? '⏳' : '☁️', () => {
              if (!this.isCloudSyncing) this.cloudSave()
            })
            this.GlassIconButton('🔗', () => {
              this.openShareDialog()
            })
            this.GlassIconButton(this.isDark ? '☀️' : '🌙', () => {
              const context = getContext(this) as common.UIAbilityContext;
              if (this.followSystem) {
                this.followSystem = false;
                PreferencesUtil.saveFollowSystem(context, false);
              }
              this.isDark = !this.isDark
              PreferencesUtil.saveIsDark(context, this.isDark);
            })
          }
        }
        .width('95%')
        .padding({ left: 16, right: 16, top: 12, bottom: 12 })
        .margin({ top: 24 })
        .backgroundColor(this.isDark ? 'rgba(0, 0, 0, 0.4)' : 'rgba(241, 243, 245, 0.5)')
        .backdropBlur(80)
        .borderRadius(32)
        .shadow(ShadowStyle.OUTER_DEFAULT_XS)
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
      .zIndex(10)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.isDark ? '#000000' : '#F1F3F5')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}