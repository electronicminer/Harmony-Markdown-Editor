import { UserDocument } from '../models/UserDocument';
import { DocumentVersion } from '../models/DocumentVersion';

/**
 * 版本历史对话框
 * 显示某文档的历史快照列表,支持预览与恢复
 */
@CustomDialog
export struct VersionHistoryDialog {
  controller: CustomDialogController;
  @Prop isDark: boolean = false;
  versions: DocumentVersion[] = [];
  @State selectedVersion: DocumentVersion | null = null;

  build() {
    Column({ space: 16 }) {
      Text('⏱️ 版本历史')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.isDark ? '#E5FFFFFF' : '#E5000000')

      if (this.versions.length === 0) {
        Column({ space: 8 }) {
          Text('🕐')
            .fontSize(36)
          Text('暂无历史版本')
            .fontSize(14)
            .fontColor(this.isDark ? '#99FFFFFF' : '#99000000')
          Text('每次保存文档时会自动记录版本')
            .fontSize(12)
            .fontColor(this.isDark ? '#66FFFFFF' : '#66000000')
        }
        .width('100%')
        .padding({ top: 40, bottom: 40 })
        .alignItems(HorizontalAlign.Center)
      } else {
        Scroll() {
          Column({ space: 8 }) {
            ForEach(this.versions, (v: DocumentVersion, index: number) => {
              Column({ space: 4 }) {
                Row() {
                  Text(v.getFormattedTime())
                    .fontSize(13)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.isDark ? '#E5FFFFFF' : '#E5000000')
                    .layoutWeight(1)
                  if (index === 0) {
                    Text('最新')
                      .fontSize(10)
                      .fontColor('#00A854')
                      .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                      .borderRadius(4)
                      .backgroundColor('rgba(0,168,84,0.1)')
                  }
                }
                .width('100%')

                Text(v.getPreview(80))
                  .fontSize(12)
                  .lineHeight(18)
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .fontColor(this.isDark ? '#99FFFFFF' : '#99000000')
                  .width('100%')

                if (this.selectedVersion && this.selectedVersion.id === v.id) {
                  Row({ space: 8 }) {
                    Blank()
                    Button('取消选择')
                      .fontSize(11)
                      .height(28)
                      .fontColor(this.isDark ? '#E5FFFFFF' : '#99000000')
                      .backgroundColor(this.isDark ? '#33FFFFFF' : '#0D000000')
                      .borderRadius(14)
                      .onClick(() => { this.selectedVersion = null; })
                    Button('恢复此版本')
                      .fontSize(11)
                      .height(28)
                      .fontColor(Color.White)
                      .backgroundColor('#0A59F7')
                      .borderRadius(14)
                      .onClick(() => {
                        if (this.onRestore && this.selectedVersion) {
                          this.onRestore(this.selectedVersion);
                        }
                        this.controller.close();
                      })
                  }
                  .width('100%')
                  .margin({ top: 4 })
                }
              }
              .width('100%')
              .padding(12)
              .borderRadius(12)
              .backgroundColor(this.isDark
                ? (this.selectedVersion && this.selectedVersion.id === v.id ? 'rgba(10,89,247,0.15)' : '#1AFFFFFF')
                : (this.selectedVersion && this.selectedVersion.id === v.id ? 'rgba(10,89,247,0.08)' : '#F5F5F5'))
              .onClick(() => {
                this.selectedVersion = v;
              })
            }, (v: DocumentVersion) => v.id)
          }
          .width('100%')
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }

      Row({ space: 12 }) {
        Button('关闭')
          .fontSize(15)
          .fontColor(this.isDark ? '#E5FFFFFF' : '#E5000000')
          .backgroundColor(this.isDark ? '#33FFFFFF' : '#0D000000')
          .type(ButtonType.Capsule)
          .height(44)
          .layoutWeight(1)
          .onClick(() => this.controller.close())
      }
      .width('100%')
    }
    .width('76%')
    .constraintSize({ maxHeight: '70%' })
    .padding(20)
    .borderRadius(28)
    .backgroundColor(this.isDark ? 'rgba(36,36,36,0.95)' : 'rgba(240, 244, 255, 0.95)')
    .backdropBlur(80)
  }

  onRestore: (v: DocumentVersion) => void = () => {};
}
