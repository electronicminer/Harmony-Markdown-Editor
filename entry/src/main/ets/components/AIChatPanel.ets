import { ChatMessage, AIService, AIResponse, AgentPlan, AgentStep } from '../utils/AIService';
import { AIConfigClass, AIConfig } from '../utils/AIConfig';
import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';

/**
 * 快捷操作类型
 */
interface QuickAction {
  label: string;
  prompt: string;
}

/**
 * AI 聊天面板组件
 */
@Component
export struct AIChatPanel {
  // 使用 @Prop 和 @State 代替 @Param 和 @Link
  @Prop isDark: boolean = false;
  @Prop aiEnabled: boolean = false;
  
  // 配置数据通过普通属性传递
  aiConfig: AIConfigClass = new AIConfigClass();
  @Prop @Watch('onConfigChange') aiConfigVersion: number = 0;
  context: common.UIAbilityContext = {} as common.UIAbilityContext;
  onInsertMarkdown: (markdown: string) => void = () => {};
  onApplyPlan?: (plan: AgentPlan) => void;
  currentContent: string = '';
  
  @State messages: ChatMessage[] = [];
  @State pendingPlan: AgentPlan | null = null;
  @State inputText: string = '';
  @State isLoading: boolean = false;
  @State showSettings: boolean = false;

  // 快捷操作按钮
  private quickActions: QuickAction[] = [
    { label: '📝 语法帮助', prompt: '请解释一下 Markdown 中' },
    { label: '✨ 优化写作', prompt: '请帮我优化以下内容的表达：' },
    { label: '📋 表格模板', prompt: '请给我一个 Markdown 表格模板示例' },
    { label: '💻 代码块', prompt: '请给我一个 Markdown 代码块示例，包含语法高亮' }
  ];

  onConfigChange() {
    // 强制触发组件更新的空跑方法，ArkUI 的机制中，只要有被 Watch 监听到就会触发渲染树更新
    this.aiConfig = AIConfig.getConfig();
  }

  aboutToAppear() {
    // 加载历史消息（可选：未来可以实现持久化）
    if (this.aiConfig && this.messages.length === 0) {
      this.messages = [{
        role: 'assistant',
        content: '你好！我是你的 Markdown 写作助手，有什么可以帮你的吗？\n\n你可以问我：\n• Markdown 语法问题\n• 写作优化建议\n• 模板示例（表格、代码块等）'
      }];
    }
  }

  /**
   * 发送消息
   */
  async sendMessage(): Promise<void> {
    if (!this.inputText.trim() || this.isLoading) {
      return;
    }

    this.aiConfig = AIConfig.getConfig();

    if (!this.aiConfig || !AIConfigClass.isConfigValid(this.aiConfig)) {
      promptAction.showToast({
        message: '请先配置 AI API（设置 > AI 配置）',
        duration: 2000
      });
      this.showSettings = true;
      return;
    }

    const userMessage: ChatMessage = {
      role: 'user',
      content: this.inputText
    };

    this.messages.push(userMessage);
    const currentInput: string = this.inputText;
    this.inputText = '';
    this.isLoading = true;

    try {
      // #4 移除 AIChatPanel 侧的内容注入，统一由 AIService.chat() 在系统提示中注入（已限长）
      const messagesWithContext: ChatMessage[] = [
        ...this.messages.filter(m => m.role !== 'system'),
        {
          role: 'user',
          content: currentInput
        }
      ];

      // 清除之前的未执行计划
      this.pendingPlan = null;

      const response: AIResponse = await AIService.chat(this.aiConfig, messagesWithContext, this.currentContent);

      if (response.success && response.content) {
        this.messages.push({
          role: 'assistant',
          content: response.content
        });
        
        if (response.plan) {
          this.pendingPlan = response.plan;
        }
      } else {
        this.messages.push({
          role: 'assistant',
          content: '❌ 错误：' + (response.error || '未知错误')
        });
      }
    } catch (e) {
      this.messages.push({
        role: 'assistant',
        content: '❌ 请求失败：' + (e instanceof Error ? e.message : '未知错误')
      });
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * 使用快捷操作
   */
  useQuickAction(prompt: string) {
    this.inputText = prompt;
  }

  /**
   * 清空对话
   */
  clearChat() {
    this.messages = [{
      role: 'assistant',
      content: '对话已清空。有什么新的问题可以问我吗？'
    }];
  }

  /**
   * 操作类型对应的图标
   */
  stepIcon(action: string): string {
    switch (action) {
      case 'replace':
      case 'replace_content':
        return '✏️';
      case 'insert_after':
      case 'insert_before':
      case 'insert_content':
        return '➕';
      case 'append':
      case 'append_content':
        return '⬇️';
      case 'prepend':
        return '⬆️';
      case 'delete':
      case 'delete_content':
        return '🗑️';
      default:
        return '•';
    }
  }

  /**
   * 截断文本用于预览展示
   */
  truncate(text: string | undefined, max: number): string {
    if (!text) {
      return '';
    }
    const clean = text.replace(/\\n/g, ' ').replace(/\n/g, ' ');
    return clean.length > max ? clean.substring(0, max) + '…' : clean;
  }

  /**
   * 生成单步的可读摘要
   */
  stepSummary(step: AgentStep): string {
    if (step.note && step.note.length > 0) {
      return step.note;
    }
    // 行号范围描述
    const range: string = (typeof step.startLine === 'number' && step.startLine > 0)
      ? (step.endLine && step.endLine > step.startLine ? `第 ${step.startLine}-${step.endLine} 行` : `第 ${step.startLine} 行`)
      : (step.anchor ? `「${this.truncate(step.anchor, 14)}」` : '');
    switch (step.action) {
      case 'replace':
      case 'replace_content':
        return `替换${range} → 「${this.truncate(step.content, 16)}」`;
      case 'insert_after':
        return `在${range}之后插入「${this.truncate(step.content, 14)}」`;
      case 'insert_before':
        return `在${range}之前插入「${this.truncate(step.content, 14)}」`;
      case 'append':
      case 'append_content':
      case 'insert_content':
        return `在文末追加「${this.truncate(step.content, 20)}」`;
      case 'prepend':
        return `在文首插入「${this.truncate(step.content, 20)}」`;
      case 'delete':
      case 'delete_content':
        return `删除${range}`;
      default:
        return '未知操作';
    }
  }

  build() {
    Column() {
      // 头部
      Row() {
        Text('🤖 AI 助手')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.isDark ? '#E5FFFFFF' : '#E5000000')
          .layoutWeight(1)

        Row({ space: 8 }) {
          // 清空按钮
          Button({ type: ButtonType.Circle }) {
            Text('🗑️')
              .fontSize(14)
          }
          .width(36)
          .height(36)
          .backgroundColor(this.isDark ? '#33FFFFFF' : '#0D000000')
          .onClick(() => {
            this.clearChat();
          })

          // 收起按钮
          Button({ type: ButtonType.Circle }) {
            Text('›')
              .fontSize(20)
              .offset({ y: -2 })
              .fontColor(this.isDark ? '#E5FFFFFF' : '#E5000000')
          }
          .width(36)
          .height(36)
          .backgroundColor(this.isDark ? '#33FFFFFF' : '#0D000000')
          .onClick(() => {
            // 通过父组件关闭
          })
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .border({ width: { bottom: 0.5 }, color: this.isDark ? '#1AFFFFFF' : '#0D000000' })

      // 消息列表
      Scroll() {
        Column() {
          ForEach(this.messages, (item: ChatMessage) => {
            Column() {
              if (item.role === 'user') {
                // 用户消息 - 右侧
                Row() {
                  Blank()
                  Column() {
                    Text(item.content)
                      .fontSize(15)
                      .fontColor(Color.White)
                      .width('100%')
                  }
                  .padding({ left: 16, right: 16, top: 12, bottom: 12 })
                  .backgroundColor('#0A59F7')
                  .borderRadius({ topLeft: 20, topRight: 20, bottomLeft: 20, bottomRight: 4 })
                  .margin({ right: 16 })
                  .shadow(ShadowStyle.OUTER_DEFAULT_MD)
                }
                .width('100%')
              } else {
                // AI 消息 - 左侧
                Row() {
                  Column() {
                    Text(item.content)
                      .fontSize(15)
                      .lineHeight(22)
                      .fontColor(this.isDark ? '#E5FFFFFF' : '#E5000000')
                      .width('100%')
                  }
                  .padding({ left: 16, right: 16, top: 12, bottom: 12 })
                  .backgroundColor(this.isDark ? '#33FFFFFF' : '#F5F5F5')
                  .borderRadius({ topLeft: 20, topRight: 20, bottomLeft: 4, bottomRight: 20 })
                  .margin({ left: 16 })
                  Blank()
                }
                .width('100%')
              }
            }
            .width('100%')
            .margin({ bottom: 16 })
          })

          // 渲染待执行的操作计划卡片
          if (this.pendingPlan) {
            Column() {
              Row() {
                Text('✨ 提议修改')
                  .fontSize(15)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.isDark ? '#E5FFFFFF' : '#E5000000')
              }
              .margin({ bottom: 12 })
              .width('100%')

              Text(this.pendingPlan.description)
                .fontSize(14)
                .lineHeight(20)
                .fontColor(this.isDark ? '#99FFFFFF' : '#99000000')
                .margin({ bottom: 12 })
                .width('100%')

              // 逐项操作预览
              ForEach(this.pendingPlan.steps, (step: AgentStep, index: number) => {
                Row({ space: 8 }) {
                  Text(this.stepIcon(step.action))
                    .fontSize(14)
                  Text(`${index + 1}. ${this.stepSummary(step)}`)
                    .fontSize(13)
                    .lineHeight(18)
                    .layoutWeight(1)
                    .fontColor(this.isDark ? '#CCFFFFFF' : '#CC000000')
                }
                .width('100%')
                .alignItems(VerticalAlign.Top)
                .padding({ top: 6, bottom: 6, left: 10, right: 10 })
                .margin({ bottom: 6 })
                .backgroundColor(this.isDark ? '#1AFFFFFF' : '#08000000')
                .borderRadius(10)
              })

              Row({ space: 12 }) {
                Button('拒绝')
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .height(36)
                  .backgroundColor(this.isDark ? '#33FFFFFF' : '#0D000000')
                  .fontColor(this.isDark ? '#99FFFFFF' : '#99000000')
                  .type(ButtonType.Capsule)
                  .onClick(() => {
                    this.pendingPlan = null;
                  })
                Button('允许执行 (Act)')
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .height(36)
                  .backgroundColor('#0A59F7')
                  .fontColor(Color.White)
                  .type(ButtonType.Capsule)
                  .onClick(() => {
                    if (this.onApplyPlan && this.pendingPlan) {
                      this.onApplyPlan(this.pendingPlan);
                      this.pendingPlan = null; // 执行后清除
                    }
                  })
              }
              .width('100%')
              .justifyContent(FlexAlign.End)
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 16, bottom: 16 })
            .margin({ left: 16, bottom: 16, right: 16 })
            .backgroundColor(this.isDark ? 'rgba(255, 255, 255, 0.05)' : '#FFFFFF')
            .borderRadius(20)
            .border({ width: 0.5, color: this.isDark ? '#1AFFFFFF' : '#0D000000' })
            .shadow(ShadowStyle.OUTER_DEFAULT_SM)
          }

          // 加载中指示器
          if (this.isLoading) {
            Row() {
              LoadingProgress()
                .width(24)
                .height(24)
              Text('思考中...')
                .fontSize(12)
                .fontColor(this.isDark ? '#888' : '#666')
                .margin({ left: 8 })
            }
            .padding(12)
            .margin({ left: 8 })
          }
        }
        .width('100%')
        .padding(12)
      }
      .layoutWeight(1)
      .width('100%')

      // 快捷操作栏
      Scroll() {
        Row({ space: 8 }) {
          ForEach(this.quickActions, (action: QuickAction) => {
            Button(action.label)
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .height(32)
              .padding({ left: 14, right: 14 })
              .backgroundColor(this.isDark ? '#33FFFFFF' : '#0D000000')
              .fontColor(this.isDark ? '#E5FFFFFF' : '#E5000000')
              .borderRadius(16)
              .onClick(() => {
                this.useQuickAction(action.prompt);
              })
          })
        }
        .padding({ left: 16, right: 16 })
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
      .padding({ top: 12, bottom: 12 })

      // 输入区域
      Row({ space: 12 }) {
        TextInput({ text: this.inputText, placeholder: '输入问题...' })
          .fontSize(15)
          .layoutWeight(1)
          .padding({ left: 16, right: 16 })
          .height(44)
          .fontColor(this.isDark ? '#E5FFFFFF' : '#E5000000')
          .placeholderColor(this.isDark ? '#99FFFFFF' : '#99000000')
          .backgroundColor(this.isDark ? '#33FFFFFF' : '#0D000000')
          .borderRadius(22)
          .onChange((value: string) => {
            this.inputText = value;
          })
          .onSubmit(() => {
            this.sendMessage();
          })

        Button({ type: ButtonType.Circle }) {
          if (this.isLoading) {
            LoadingProgress()
              .width(24)
              .height(24)
              .color('#FFFFFF')
          } else {
            Text('↑')
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
              .offset({ y: -1 })
          }
        }
        .width(44)
        .height(44)
        .backgroundColor(this.inputText.trim() && !this.isLoading ? '#0A59F7' : (this.isDark ? '#33FFFFFF' : '#E5E5E5'))
        .enabled(!!this.inputText.trim() && !this.isLoading)
        .onClick(() => {
          this.sendMessage();
        })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 16 })
      .backgroundColor('transparent')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.isDark ? '#242424' : '#FFFFFF')
  }
}