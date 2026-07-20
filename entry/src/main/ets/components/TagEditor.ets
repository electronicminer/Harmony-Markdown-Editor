import { parseTags, joinTags, addTag, removeTag } from '../utils/TagsUtil';

/**
 * 标签编辑对话框
 * 显示当前标签 + 历史标签建议 + 输入新增
 */
@CustomDialog
export struct TagEditor {
  controller: CustomDialogController;
  @Prop isDark: boolean = false;
  @Prop title: string = '';
  @Prop initialTags: string = '';
  historyTags: string[] = [];
  @State inputTag: string = '';
  @State currentTags: string[] = [];
  onSave: (tags: string) => void = () => {};

  aboutToAppear(): void {
    this.currentTags = parseTags(this.initialTags);
  }

  private commitInput(): void {
    const t = this.inputTag.trim();
    if (!t) return;
    this.currentTags = addTag(this.currentTags, t);
    this.inputTag = '';
  }

  build() {
    Column({ space: 16 }) {
      Text('🏷️ 标签管理')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.isDark ? '#E5FFFFFF' : '#E5000000')

      Text(this.title)
        .fontSize(13)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .fontColor(this.isDark ? '#99FFFFFF' : '#99000000')
        .width('100%')

      Divider().color(this.isDark ? '#33FFFFFF' : '#1A000000')

      // 当前标签 chips
      Column({ space: 8 }) {
        if (this.currentTags.length === 0) {
          Text('暂无标签,从下方添加')
            .fontSize(12)
            .fontColor(this.isDark ? '#66FFFFFF' : '#66000000')
        }
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.currentTags, (tag: string) => {
            Row({ space: 4 }) {
              Text('#' + tag)
                .fontSize(12)
                .fontColor('#0A59F7')
              Text('✕')
                .fontSize(11)
                .fontColor(this.isDark ? '#99FFFFFF' : '#99000000')
                .onClick(() => {
                  this.currentTags = removeTag(this.currentTags, tag);
                })
            }
            .padding({ left: 10, right: 10, top: 5, bottom: 5 })
            .borderRadius(14)
            .backgroundColor('rgba(10,89,247,0.08)')
            .margin({ right: 6, bottom: 6 })
          }, (tag: string) => tag)
        }
        .width('100%')
      }
      .width('100%')

      // 输入新标签
      Row({ space: 8 }) {
        TextInput({ text: this.inputTag, placeholder: '输入标签后回车添加' })
          .fontSize(14)
          .height(40)
          .layoutWeight(1)
          .fontColor(this.isDark ? '#E5FFFFFF' : '#E5000000')
          .placeholderColor(this.isDark ? '#66FFFFFF' : '#66000000')
          .backgroundColor(this.isDark ? '#33FFFFFF' : '#0D000000')
          .borderRadius(10)
          .padding({ left: 12, right: 12 })
          .onChange((v: string) => { this.inputTag = v; })
          .onSubmit(() => { this.commitInput(); })

        Button('添加')
          .fontSize(13)
          .height(40)
          .fontColor(Color.White)
          .backgroundColor('#0A59F7')
          .type(ButtonType.Capsule)
          .onClick(() => { this.commitInput(); })
      }
      .width('100%')

      // 历史标签建议
      if (this.historyTags.length > 0) {
        Column({ space: 8 }) {
          Text('历史标签')
            .fontSize(12)
            .fontColor(this.isDark ? '#99FFFFFF' : '#99000000')
            .width('100%')
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(this.historyTags, (tag: string) => {
              Text('#' + tag)
                .fontSize(12)
                .fontColor(this.isDark ? '#CCFFFFFF' : '#33000000')
                .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                .borderRadius(14)
                .backgroundColor(this.isDark ? '#1AFFFFFF' : '#0D000000')
                .margin({ right: 6, bottom: 6 })
                .onClick(() => {
                  this.currentTags = addTag(this.currentTags, tag);
                })
            }, (tag: string) => tag)
          }
          .width('100%')
        }
        .width('100%')
      }

      Row({ space: 12 }) {
        Button('取消')
          .fontSize(15)
          .fontColor(this.isDark ? '#E5FFFFFF' : '#E5000000')
          .backgroundColor(this.isDark ? '#33FFFFFF' : '#0D000000')
          .type(ButtonType.Capsule)
          .height(44)
          .layoutWeight(1)
          .onClick(() => this.controller.close())
        Button('保存')
          .fontSize(15)
          .fontColor(Color.White)
          .backgroundColor('#0A59F7')
          .type(ButtonType.Capsule)
          .height(44)
          .layoutWeight(1)
          .onClick(() => {
            this.onSave(joinTags(this.currentTags));
            this.controller.close();
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
