import { Token } from './core'
import { MarkdownComponent } from './component/MarkdownComponent'
import { parseMarkdown } from './utils'
import { MarkdownOptions, MarkdownOptionsClass } from './Index'
import { defaultDarkTheme, defaultTheme } from './config/DefaultTheme'
import { LengthMetrics } from '@kit.ArkUI'
import deepMerge from './merge'
import { taskpool } from '@kit.ArkTS'
import { BusinessError } from '@kit.BasicServicesKit'


@ComponentV2
export struct Markdown {
  /**
   * 外层传入时仅需传递content或token
   */
  @Param token: Token[] = []
  @Param content: string = ''
  @Param options?: MarkdownOptions = undefined
  @Local tokenList: Token[] = []
  @Local optionsClass: MarkdownOptionsClass = new MarkdownOptionsClass()
  @Event onLoading?: () => void
  @Event onSuccess?: () => void
  @Event onError?: (e: BusinessError) => void
  // 解析序号守卫：content 快速连续变更时多个 taskpool 任务并发，
  // 先发起但后返回的旧结果不能覆盖新结果
  private parseSeq: number = 0

  aboutToAppear(): void {
    this.watchOptions()
    if (this.content && this.content.trim().length !== 0) {
      this.watchContent()
    } else if (this.token.length != 0) {
      this.watchToken()
    }
  }

  @Monitor('token')
  watchToken() {
    this.tokenList = this.token
  }

  @Monitor('content')
  watchContent() {
    if (this.content && this.content.trim().length !== 0) {
      this.onLoading?.()
      const seq = ++this.parseSeq
      taskpool.execute(parseMarkdown, this.content, this.options?.options, this.options?.extensions).then((data) => {
        if (seq !== this.parseSeq) {
          return // 已有更新的 content 发起解析，丢弃本次旧结果
        }
        this.tokenList = data as Token[]
        this.onSuccess?.()
      }).catch((e: BusinessError) => {
        if (seq === this.parseSeq) {
          this.onError?.(e)
        }
      })
    } else {
      // content 置空时清理渲染，避免预览区残留上一个文档
      this.parseSeq++
      this.tokenList = []
    }
  }

  @Monitor('options')
  watchOptions() {
    if (this.options) {
      this.optionsClass.theme = this.options.darkMode ? deepMerge(defaultDarkTheme, this.options.darkTheme) :
        deepMerge(defaultTheme, this.options.theme)
      this.optionsClass.lineSpacing = this.options.lineSpace ?? 12
      this.optionsClass.inlineLineSpacing = this.options.inlineLineSpace ?? LengthMetrics.vp(12)
      this.optionsClass.maxLines = this.options.maxLines
      // 回调挂在本实例的 optionsClass 上（随组件销毁而释放，不跨实例共享）
      this.optionsClass.linkClick = this.options.linkClick
      this.optionsClass.imageClick = this.options.imageClick
      this.optionsClass.customInlineBuilder = this.options.customInlineBuilder
      this.optionsClass.customBlockBuilder = this.options.customBlockBuilder
    }
  }

  build() {
    if (this.tokenList.length != 0) {
      MarkdownComponent({ tokenList: this.tokenList, options: this.optionsClass })
    }
  }
}
