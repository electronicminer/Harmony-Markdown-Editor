import { ExportFormat } from '../utils/ExportService';

/**
 * 导出格式选择对话框
 */
@CustomDialog
export struct ExportDialog {
  controller: CustomDialogController;
  @Prop isDark: boolean = false;
  onExport: (format: ExportFormat) => void = () => {};

  build() {
    Column({ space: 16 }) {
      Text('📤 导出笔记')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.isDark ? '#E5FFFFFF' : '#E5000000')

      Text('选择导出格式,保存到设备')
        .fontSize(13)
        .fontColor(this.isDark ? '#99FFFFFF' : '#99000000')
        .margin({ bottom: 4 })

      this.FormatOption('📝', 'Markdown', '.md', '保留全部 md 语法,可再编辑', 'md')
      this.FormatOption('🌐', 'HTML', '.html', '带样式网页,内嵌公式渲染', 'html')
      this.FormatOption('📄', '纯文本', '.txt', '去掉格式,只留文字', 'txt')
      this.FormatOption('🖨️', 'PDF', '.html', '导出 HTML,浏览器 Ctrl+P 转 PDF', 'pdf')

      Button('取消')
        .fontSize(15)
        .fontColor(this.isDark ? '#E5FFFFFF' : '#E5000000')
        .backgroundColor(this.isDark ? '#33FFFFFF' : '#0D000000')
        .type(ButtonType.Capsule)
        .height(44)
        .width('100%')
        .onClick(() => this.controller.close())
    }
    .width('85%')
    .padding(24)
    .borderRadius(28)
    .backgroundColor(this.isDark ? 'rgba(36,36,36,0.95)' : 'rgba(240, 244, 255, 0.95)')
    .backdropBlur(80)
  }

  @Builder
  FormatOption(icon: string, name: string, ext: string, desc: string, format: ExportFormat) {
    Row({ space: 14 }) {
      Text(icon)
        .fontSize(24)
        .width(44)
        .height(44)
        .textAlign(TextAlign.Center)
        .backgroundColor(this.isDark ? 'rgba(255,255,255,0.06)' : 'rgba(10,89,247,0.06)')
        .borderRadius(12)

      Column({ space: 3 }) {
        Row({ space: 6 }) {
          Text(name)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.isDark ? '#E5FFFFFF' : '#E5000000')
          Text(ext)
            .fontSize(11)
            .fontColor('#0A59F7')
            .backgroundColor('rgba(10,89,247,0.08)')
            .padding({ left: 5, right: 5, top: 1, bottom: 1 })
            .borderRadius(4)
        }
        Text(desc)
          .fontSize(12)
          .fontColor(this.isDark ? '#99FFFFFF' : '#99000000')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text('›')
        .fontSize(22)
        .fontColor(this.isDark ? '#4DFFFFFF' : '#4D000000')
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 12, bottom: 12 })
    .borderRadius(16)
    .backgroundColor(this.isDark ? 'rgba(255,255,255,0.04)' : 'rgba(10,89,247,0.03)')
    .margin({ bottom: 8 })
    .onClick(() => {
      this.onExport(format);
      this.controller.close();
    })
  }
}
