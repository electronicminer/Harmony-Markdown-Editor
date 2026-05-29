import { common } from '@kit.AbilityKit';
import { promptAction, router } from '@kit.ArkUI';
import { AuthService } from '../utils/AuthService';
import { PreferencesUtil } from '../utils/PreferencesUtil';

const AVATAR_COLORS: string[] = [
  '#0A59F7', '#F4222D', '#FA8C16', '#00A854',
  '#722ED1', '#EB2F96', '#13C2C2', '#2F54EB',
  '#FA541C', '#A0D911', '#F5222D', '#1890FF'
];

@Entry
@Component
struct ProfilePage {
  @State nickname: string = '';
  @State bio: string = '';
  @State avatarColor: string = '#0A59F7';
  @State email: string = '';
  @State isSaving: boolean = false;
  @State maxLength: number = 20;
  @State bioMaxLength: number = 100;

  private context = getContext(this) as common.UIAbilityContext;

  aboutToAppear(): void {
    this.loadProfile();
  }

  async loadProfile(): Promise<void> {
    const user = await AuthService.getCurrentUser();
    if (user) {
      this.email = user.email;
    }
    this.nickname = await PreferencesUtil.getProfileNickname(this.context);
    this.bio = await PreferencesUtil.getProfileBio(this.context);
    this.avatarColor = await PreferencesUtil.getProfileAvatarColor(this.context);
  }

  async handleSave(): Promise<void> {
    if (this.isSaving) return;
    if (!this.nickname.trim()) {
      promptAction.showToast({ message: '请输入昵称', duration: 2000 });
      return;
    }
    this.isSaving = true;
    try {
      await PreferencesUtil.saveProfileNickname(this.context, this.nickname.trim());
      await PreferencesUtil.saveProfileBio(this.context, this.bio.trim());
      await PreferencesUtil.saveProfileAvatarColor(this.context, this.avatarColor);
      promptAction.showToast({ message: '个人资料已保存', duration: 1500 });
      setTimeout(() => router.back(), 1500);
    } catch (e) {
      promptAction.showToast({ message: '保存失败，请重试', duration: 2000 });
    }
    this.isSaving = false;
  }

  @Builder
  GlassInput(label: string, placeholder: string, value: string, onChange: (v: string) => void,
    maxLength: number = 50, multiline: boolean = false) {
    Column({ space: 8 }) {
      Row() {
        Text(label)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor('#99000000')
        Blank()
        Text(`${value.length}/${maxLength}`)
          .fontSize(11)
          .fontColor(value.length > maxLength ? '#F4222D' : '#4D000000')
      }
      .width('100%')

      TextInput({ text: value, placeholder: placeholder })
        .fontSize(15)
        .height(multiline ? 100 : 48)
        .type(InputType.Normal)
        .fontColor('#E5000000')
        .placeholderColor('#66000000')
        .backgroundColor('rgba(10,89,247,0.04)')
        .borderRadius(16)
        .padding({ left: 16, right: 16 })
        .maxLength(maxLength)
        .onChange(onChange)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  AvatarPreview() {
    Column({ space: 12 }) {
      Column() {
        Text(this.nickname ? this.nickname.charAt(0).toUpperCase() :
          this.email ? this.email.charAt(0).toUpperCase() : 'U')
          .fontSize(40)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
      }
      .width(96)
      .height(96)
      .borderRadius(28)
      .backgroundColor(this.avatarColor)
      .justifyContent(FlexAlign.Center)
      .shadow({ radius: 20, color: `${this.avatarColor}66`, offsetY: 6 })

      Text(this.nickname || this.email || '未设置昵称')
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor('#E5000000')

      if (this.bio) {
        Text(this.bio)
          .fontSize(13)
          .fontColor('#99000000')
          .textAlign(TextAlign.Center)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('80%')
      }
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  ColorPicker() {
    Column({ space: 12 }) {
      Text('头像颜色')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor('#99000000')
        .width('100%')

      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(AVATAR_COLORS, (color: string) => {
          Column()
            .width(36)
            .height(36)
            .borderRadius(18)
            .backgroundColor(color)
            .border({
              width: this.avatarColor === color ? 3 : 0,
              color: '#FFFFFF',
              style: BorderStyle.Solid
            })
            .shadow(this.avatarColor === color ?
              { radius: 8, color: `${color}80`, offsetY: 2 } :
              { radius: 0, color: 'transparent' })
            .margin({ right: 12, bottom: 12 })
            .onClick(() => {
              this.avatarColor = color;
            })
        })
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      Scroll() {
        Column() {
          Row().height(100).width('100%')

          Column({ space: 0 }) {
            Column({ space: 8 }) {
              Text('自定义个人资料')
                .fontSize(28)
                .fontWeight(FontWeight.Bold)
                .fontColor('#E5000000')

              Text('设置你的昵称和头像样式')
                .fontSize(14)
                .fontColor('#99000000')
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .margin({ bottom: 20 })

            this.AvatarPreview()

            Divider()
              .color('rgba(10,89,247,0.06)')
              .margin({ top: 16, bottom: 16 })

            Column({ space: 16 }) {
              this.GlassInput('昵称', '给自己起个名字吧', this.nickname,
                (v: string) => { this.nickname = v; }, this.maxLength)

              this.GlassInput('个性签名', '用一句话介绍自己', this.bio,
                (v: string) => { this.bio = v; }, this.bioMaxLength, true)
            }
            .width('100%')

            Divider()
              .color('rgba(10,89,247,0.06)')
              .margin({ top: 16, bottom: 16 })

            this.ColorPicker()

            Column({ space: 16 }) {
              Button(this.isSaving ? '保存中...' : '保存资料')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor(Color.White)
                .backgroundColor('#0A59F7')
                .type(ButtonType.Capsule)
                .height(48)
                .width('100%')
                .shadow({ radius: 16, color: 'rgba(10,89,247,0.4)', offsetY: 4 })
                .onClick(() => this.handleSave())
            }
            .width('100%')
            .margin({ top: 24 })
          }
          .width('92%')
          .padding({ left: 24, right: 24, top: 24, bottom: 24 })
          .borderRadius(32)
          .backgroundColor('rgba(240, 244, 255, 0.85)')
          .backdropBlur(80)
          .shadow({ radius: 32, color: 'rgba(10,89,247,0.06)', offsetY: 8 })

          Column({ space: 6 }) {
            Text('鸿蒙 Markdown')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor('#33000000')
            Text('Powered by HarmonyOS NEXT')
              .fontSize(11)
              .fontColor('#1A000000')
          }
          .width('100%')
          .margin({ top: 32, bottom: 40 })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#FFFFFF')
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      .scrollBar(BarState.Off)

      // 液态玻璃导航栏
      Row() {
        Text('鸿蒙 Markdown')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontFamily('HarmonyOS Sans')
          .fontColor('#E5000000')
          .layoutWeight(1)

        Row({ space: 12 }) {
          Button({ type: ButtonType.Circle, stateEffect: true }) {
            Text('←')
              .fontSize(20)
              .fontColor('#E5000000')
              .fontWeight(FontWeight.Medium)
          }
          .width(44)
          .height(44)
          .backgroundColor('rgba(0, 0, 0, 0.05)')
          .backdropBlur(50)
          .shadow(ShadowStyle.OUTER_DEFAULT_XS)
          .onClick(() => router.back())
        }
      }
      .width('92%')
      .padding({ left: 24, right: 24, top: 16, bottom: 16 })
      .margin({ top: 24 })
      .borderRadius(32)
      .backgroundColor('rgba(240, 244, 255, 0.7)')
      .backdropBlur(80)
      .justifyContent(FlexAlign.SpaceBetween)
      .alignItems(VerticalAlign.Center)
      .shadow(ShadowStyle.OUTER_DEFAULT_XS)
      .zIndex(10)
    }
    .width('100%')
    .height('100%')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
