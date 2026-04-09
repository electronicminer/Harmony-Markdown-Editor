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
import { AgentPlan } from '../utils/AIService';
// 自动补全功能导入（已注释）
// import { CompletionItem, filterCompletions, checkTrigger, TriggerInfo, CompletionItemType } from '../utils/MarkdownCompletions';

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
  @State followSystem: boolean = false
  @StorageProp('currentColorMode') @Watch('onSystemModeChange') currentSystemMode: number = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT
  private autoSaveTimer: number = -1;
  
  // 拖拽分栏权重
  @State editorWeight: number = 1
  @State previewWeight: number = 1
  @State aiWeight: number = 1

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
      }
      if (params['isDark'] !== undefined) {
        this.isDark = params['isDark'] as boolean;
      }
      if (params['viewMode'] !== undefined) {
        this.viewMode = params['viewMode'] as number;
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
    if (this.autoSaveTimer !== -1) {
      clearInterval(this.autoSaveTimer);
      this.autoSaveTimer = -1;
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

  performAutoSave() {
    if (this.fileUri) {
      try {
        const file = fs.openSync(this.fileUri, fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
        fs.writeSync(file.fd, this.markdownText);
        fs.closeSync(file);
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
    this.saveDocument();
    return false;
  }

  saveDocument(silent: boolean = false) {
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const filesDir = context.filesDir;
      const filePath = filesDir + '/' + this.fileName;
      
      const file = fs.openSync(filePath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      fs.writeSync(file.fd, this.markdownText);
      fs.closeSync(file);
      
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

      const file = fs.openSync(uri, fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
      fs.writeSync(file.fd, this.markdownText);
      fs.closeSync(file);

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
  DividerBar(onDrag: (offset: number) => void) {
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
        .onActionUpdate((event) => {
          onDrag(event.offsetX)
        })
    )
  }

  handleApplyPlan(plan: AgentPlan) {
    let currentText = this.markdownText;
    
    switch (plan.action) {
      case 'replace_content':
        if (plan.targetContent && plan.replacementContent !== undefined) {
           // 确保处理可能的转义字符
           const sanitizedTarget = plan.targetContent.replace(/\\n/g, '\n');
           const sanitizedReplacement = plan.replacementContent.replace(/\\n/g, '\n');
           
           if (currentText.includes(sanitizedTarget)) {
             currentText = currentText.replace(sanitizedTarget, sanitizedReplacement);
             promptAction.showToast({ message: '已应用替换', duration: 1500 });
           } else {
             promptAction.showToast({ message: '未找到目标文本，可能已被修改', duration: 2000 });
           }
        }
        break;
      case 'delete_content':
        if (plan.targetContent) {
           const sanitizedTarget = plan.targetContent.replace(/\\n/g, '\n');
           if (currentText.includes(sanitizedTarget)) {
             currentText = currentText.replace(sanitizedTarget, '');
             promptAction.showToast({ message: '已删除内容', duration: 1500 });
           } else {
             promptAction.showToast({ message: '未找到要删除的内容', duration: 2000 });
           }
        }
        break;
      case 'append_content':
        if (plan.replacementContent) {
           const sanitizedReplacement = plan.replacementContent.replace(/\\n/g, '\n');
           currentText = currentText + '\n' + sanitizedReplacement;
           promptAction.showToast({ message: '已追加内容', duration: 1500 });
        }
        break;
      case 'insert_content':
        if (plan.replacementContent) {
           const sanitizedReplacement = plan.replacementContent.replace(/\\n/g, '\n');
           // 默认在光标处插入
           const start = this.selectionStart;
           const before = currentText.substring(0, start);
           const after = currentText.substring(start);
           currentText = before + sanitizedReplacement + after;
           promptAction.showToast({ message: '已插入内容', duration: 1500 });
        }
        break;
    }
    
    this.markdownText = currentText;
    this.recordHistory(currentText);
    this.updateCounts(currentText);
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

                  if (this.typingTimer !== -1) {
                    clearTimeout(this.typingTimer)
                  }
                  this.typingTimer = setTimeout(() => {
                    this.recordHistory(value)
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

        // 第一道 分隔线（仅在分屏或分屏预览时显示）
        if (this.viewMode === 0) {
          this.DividerBar( (offset) => {
            // 根据拖拽调整权重
            const totalWeight = this.editorWeight + this.previewWeight;
            // 简单处理：向右拖拽 -> editor 增加，preview 减小
            const delta = offset / 1000;
            this.editorWeight = Math.max(0.2, this.editorWeight + delta * totalWeight);
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
          this.DividerBar( (offset) => {
            // 根据拖拽调整权重
            const totalWeight = (this.viewMode === 1 ? this.editorWeight : (this.viewMode === 2 ? this.previewWeight : this.editorWeight + this.previewWeight)) + this.aiWeight;
            const delta = offset / 1000;
            
            // 如果是在分屏状态下拖动，我们保持左侧两栏的相对比例，缩小它们并放大 AI 面板
             if (this.viewMode === 0) {
               const leftPanelTotal = this.editorWeight + this.previewWeight;
               const newLeftTotal = Math.max(0.2, leftPanelTotal + delta * totalWeight);
               this.aiWeight = Math.max(0.2, totalWeight - newLeftTotal);
               
               // 按原比例分配剩下的空间
               const ratio = this.editorWeight / leftPanelTotal;
               this.editorWeight = newLeftTotal * ratio;
               this.previewWeight = newLeftTotal * (1 - ratio);
             } else if (this.viewMode === 1) {
                this.editorWeight = Math.max(0.2, this.editorWeight + delta * totalWeight);
                this.aiWeight = Math.max(0.2, totalWeight - this.editorWeight);
             } else {
                this.previewWeight = Math.max(0.2, this.previewWeight + delta * totalWeight);
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
            this.GlassIconButton(this.viewMode === 0 ? '🌗' : (this.viewMode === 1 ? '✏️' : '👁️'), () => {
              this.viewMode = (this.viewMode + 1) % 3
            })
            this.GlassIconButton('💾', () => {
              this.saveFile()
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