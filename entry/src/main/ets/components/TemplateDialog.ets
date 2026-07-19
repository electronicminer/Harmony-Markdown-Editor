import { NoteTemplate, NOTE_TEMPLATES } from '../utils/NoteTemplates';

/**
 * 笔记模板选择对话框
 * Grid 2 列展示校园专用模板,选中触发 onSelect 回调
 */
@CustomDialog
export struct TemplateDialog {
  controller: CustomDialogController;
  @Prop isDark: boolean = false;
  onSelect: (t: NoteTemplate) => void = () => {};

  build() {
    Column({ space: 16 }) {
      Text('选择笔记模板')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.isDark ? '#E5FFFFFF' : '#E5000000')

      Text('一键生成标准化课堂笔记结构')
        .fontSize(13)
        .fontColor(this.isDark ? '#99FFFFFF' : '#99000000')

      Grid() {
        ForEach(NOTE_TEMPLATES, (t: NoteTemplate) => {
          GridItem() {
            this.TemplateCard(t)
          }
        }, (t: NoteTemplate) => t.id)
      }
      .columnsTemplate('1fr 1fr')
      .columnsGap(12)
      .rowsGap(12)
      .padding({ top: 8 })
      .height(380)
      .width('100%')

      Button('取消')
        .fontSize(15)
        .fontColor(this.isDark ? '#E5FFFFFF' : '#E5000000')
        .backgroundColor(this.isDark ? '#33FFFFFF' : '#0D000000')
        .type(ButtonType.Capsule)
        .height(44)
        .width('100%')
        .onClick(() => this.controller.close())
    }
    .width('90%')
    .padding(24)
    .borderRadius(32)
    .backgroundColor(this.isDark ? 'rgba(36,36,36,0.95)' : 'rgba(240, 244, 255, 0.95)')
    .backdropBlur(80)
  }

  @Builder
  TemplateCard(t: NoteTemplate) {
    Column({ space: 8 }) {
      Text(t.icon)
        .fontSize(28)

      Text(t.name)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.isDark ? '#E5FFFFFF' : '#E5000000')

      Text(t.description)
        .fontSize(11)
        .fontColor(this.isDark ? '#99FFFFFF' : '#99000000')
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .padding(16)
    .borderRadius(16)
    .backgroundColor(this.isDark ? 'rgba(255,255,255,0.06)' : 'rgba(10,89,247,0.04)')
    .alignItems(HorizontalAlign.Center)
    .onClick(() => {
      this.onSelect(t);
      this.controller.close();
    })
  }
}
