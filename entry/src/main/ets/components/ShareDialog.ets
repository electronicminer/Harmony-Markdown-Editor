import { promptAction } from '@kit.ArkUI';
import { UserDocument } from '../models/UserDocument';
import { CloudDBService } from '../utils/CloudDBService';

@CustomDialog
export struct ShareDialog {
  controller: CustomDialogController;
  @Link doc: UserDocument;
  @Link isDark: boolean;
  @State shareEmail: string = '';
  @State isSaving: boolean = false;
  onRefresh: () => void = () => {};

  build() {
    Column({ space: 16 }) {
      Text('分享设置')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.isDark ? '#E5FFFFFF' : '#E5000000')

      Text(this.doc.getDisplayTitle())
        .fontSize(14)
        .fontColor(this.isDark ? '#99FFFFFF' : '#99000000')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')

      Divider().color(this.isDark ? '#33FFFFFF' : '#1A000000')

      Row() {
        Column({ space: 4 }) {
          Text('公开访问')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.isDark ? '#E5FFFFFF' : '#E5000000')
          Text('任何人输入文档ID即可查看')
            .fontSize(12)
            .fontColor(this.isDark ? '#99FFFFFF' : '#99000000')
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Toggle({ type: ToggleType.Switch, isOn: this.doc.isPublic })
          .onChange((isOn: boolean) => {
            this.doc.isPublic = isOn;
          })
      }
      .width('100%')

      Divider().color(this.isDark ? '#33FFFFFF' : '#1A000000')

      Column({ space: 8 }) {
        Text('文档ID（分享给其他人）')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.isDark ? '#99FFFFFF' : '#99000000')
          .width('100%')

        Row({ space: 8 }) {
          Text(this.doc.id)
            .fontSize(13)
            .fontColor(this.isDark ? '#B3FFFFFF' : '#B3000000')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
            .padding({ left: 12, right: 12, top: 10, bottom: 10 })
            .borderRadius(10)
            .backgroundColor(this.isDark ? '#33FFFFFF' : '#0D000000')

          Button('复制')
            .fontSize(13)
            .fontColor('#0A59F7')
            .backgroundColor('rgba(10,89,247,0.1)')
            .type(ButtonType.Capsule)
            .height(36)
            .onClick(() => {
              // @ts-ignore
              const pasteboard = globalThis.requireModule('system.pasteboard');
              if (pasteboard) {
                pasteboard.setData({ data: this.doc.id, type: 'text/plain' });
              }
              promptAction.showToast({ message: '已复制文档ID', duration: 1500 });
            })
        }
        .width('100%')
      }
      .width('100%')

      Column({ space: 8 }) {
        Text('通过邮箱添加协作者')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.isDark ? '#99FFFFFF' : '#99000000')
          .width('100%')

        Row({ space: 8 }) {
          TextInput({ text: this.shareEmail, placeholder: '输入对方邮箱地址' })
            .fontSize(14)
            .height(40)
            .fontColor(this.isDark ? '#E5FFFFFF' : '#E5000000')
            .placeholderColor(this.isDark ? '#66FFFFFF' : '#66000000')
            .backgroundColor(this.isDark ? '#33FFFFFF' : '#0D000000')
            .borderRadius(10)
            .padding({ left: 12, right: 12 })
            .layoutWeight(1)
            .onChange((v: string) => { this.shareEmail = v; })

          Button('添加')
            .fontSize(13)
            .fontColor(Color.White)
            .backgroundColor('#0A59F7')
            .type(ButtonType.Capsule)
            .height(40)
            .onClick(() => {
              if (this.shareEmail.trim()) {
                this.doc.addSharedUser(this.shareEmail.trim());
                this.shareEmail = '';
                promptAction.showToast({ message: '已添加', duration: 1500 });
              }
            })
        }
        .width('100%')

        if (this.doc.sharedWith) {
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(this.doc.sharedWith.split(',').filter(s => s.trim()), (uid: string) => {
              Row({ space: 4 }) {
                Text(uid.trim())
                  .fontSize(11)
                  .fontColor('#0A59F7')
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })

                Text('✕')
                  .fontSize(11)
                  .fontColor(this.isDark ? '#99FFFFFF' : '#99000000')
                  .onClick(() => {
                    this.doc.removeSharedUser(uid.trim());
                  })
              }
              .padding({ left: 8, right: 8, top: 4, bottom: 4 })
              .borderRadius(8)
              .backgroundColor('rgba(10,89,247,0.08)')
              .margin({ right: 6, bottom: 6 })
            })
          }
          .width('100%')
        }
      }
      .width('100%')

      Row({ space: 12 }) {
        Button('取消')
          .fontSize(15)
          .fontColor(this.isDark ? '#E5FFFFFF' : '#E5000000')
          .backgroundColor(this.isDark ? '#33FFFFFF' : '#0D000000')
          .type(ButtonType.Capsule)
          .height(44)
          .layoutWeight(1)
          .onClick(() => this.controller.close())

        Button(this.isSaving ? '保存中...' : '保存设置')
          .fontSize(15)
          .fontColor(Color.White)
          .backgroundColor('#0A59F7')
          .type(ButtonType.Capsule)
          .height(44)
          .layoutWeight(1)
          .shadow({ radius: 12, color: 'rgba(10,89,247,0.3)', offsetY: 4 })
          .onClick(async () => {
            this.isSaving = true;
            const result = await CloudDBService.updateSharing(this.doc);
            this.isSaving = false;
            if (result.success) {
              promptAction.showToast({ message: '分享设置已保存', duration: 1500 });
              this.onRefresh();
              this.controller.close();
            } else {
              promptAction.showToast({ message: result.message, duration: 2000 });
            }
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
