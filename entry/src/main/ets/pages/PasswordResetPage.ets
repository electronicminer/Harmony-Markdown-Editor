import { ConfigurationConstant } from '@kit.AbilityKit';
import { promptAction, router } from '@kit.ArkUI';
import { AuthActionResult, AuthService } from '../utils/AuthService';

@Entry
@Component
struct PasswordResetPage {
  @State email: string = '';
  @State newPassword: string = '';
  @State confirmPassword: string = '';
  @State verifyCode: string = '';
  @State isSendingCode: boolean = false;
  @State isSubmitting: boolean = false;
  @State countdown: number = 0;
  @State isDark: boolean = false;
  @StorageProp('currentColorMode') @Watch('syncTheme') currentSystemMode: number = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;

  private countdownTimer: number = -1;

  aboutToAppear(): void {
    this.syncTheme();
    this.loadUserEmail();
  }

  aboutToDisappear(): void {
    this.stopCountdown();
  }

  syncTheme(): void {
    this.isDark = this.currentSystemMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
  }

  async loadUserEmail(): Promise<void> {
    const user = await AuthService.getCurrentUser();
    if (user) {
      this.email = user.email;
    }
  }

  stopCountdown(): void {
    if (this.countdownTimer !== -1) {
      clearInterval(this.countdownTimer);
      this.countdownTimer = -1;
    }
  }

  startCountdown(): void {
    this.stopCountdown();
    this.countdown = 60;
    this.countdownTimer = setInterval(() => {
      this.countdown--;
      if (this.countdown <= 0) {
        this.stopCountdown();
      }
    }, 1000);
  }

  async handleSendCode(): Promise<void> {
    if (this.isSendingCode || this.countdown > 0) return;
    this.isSendingCode = true;
    const result: AuthActionResult = await AuthService.sendPasswordUpdateCode();
    this.isSendingCode = false;
    if (result.success) this.startCountdown();
    promptAction.showToast({ message: result.message, duration: result.success ? 1500 : 2000 });
  }

  async handleResetPassword(): Promise<void> {
    if (this.isSubmitting) return;

    if (!this.newPassword) {
      promptAction.showToast({ message: '请输入新密码', duration: 2000 });
      return;
    }
    if (this.newPassword.length < 8) {
      promptAction.showToast({ message: '密码长度至少为8位', duration: 2000 });
      return;
    }

    let strength = 0;
    if (/[a-z]/.test(this.newPassword)) strength++;
    if (/[A-Z]/.test(this.newPassword)) strength++;
    if (/[0-9]/.test(this.newPassword)) strength++;
    if (/[^a-zA-Z0-9]/.test(this.newPassword)) strength++;
    if (strength < 3) {
      promptAction.showToast({ message: '密码必须包含大小写字母、数字、特殊字符中的至少3种', duration: 2000 });
      return;
    }
    if (this.newPassword !== this.confirmPassword) {
      promptAction.showToast({ message: '两次输入的密码不一致', duration: 2000 });
      return;
    }
    if (!this.verifyCode) {
      promptAction.showToast({ message: '请输入验证码', duration: 2000 });
      return;
    }

    this.isSubmitting = true;
    const result: AuthActionResult = await AuthService.updatePassword(this.newPassword, this.verifyCode);
    this.isSubmitting = false;

    if (result.success) {
      promptAction.showToast({ message: result.message, duration: 1500 });
      setTimeout(() => router.back(), 1500);
    } else {
      promptAction.showToast({ message: result.message, duration: 2000 });
    }
  }

  @Builder
  GlassInput(label: string, placeholder: string, value: string, isPassword: boolean,
    onChange: (v: string) => void, enabled: boolean = true) {
    Column({ space: 8 }) {
      Text(label)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.isDark ? '#99FFFFFF' : '#99000000')

      TextInput({ text: value, placeholder: placeholder })
        .fontSize(15)
        .height(48)
        .type(isPassword ? InputType.Password : InputType.Normal)
        .fontColor(this.isDark ? '#E5FFFFFF' : '#E5000000')
        .placeholderColor(this.isDark ? '#66FFFFFF' : '#66000000')
        .backgroundColor(this.isDark ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.04)')
        .borderRadius(16)
        .padding({ left: 16, right: 16 })
        .enabled(enabled)
        .opacity(enabled ? 1 : 0.5)
        .onChange(onChange)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      Scroll() {
        Column() {
          Row().height(100).width('100%')

          // 修改密码卡片
          Column({ space: 0 }) {
            Column({ space: 8 }) {
              Text('修改密码')
                .fontSize(28)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.isDark ? '#E5FFFFFF' : '#E5000000')

              Text('通过验证码验证身份后设置新密码')
                .fontSize(14)
                .fontColor(this.isDark ? '#99FFFFFF' : '#99000000')
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .margin({ bottom: 24 })

            Column({ space: 16 }) {
              this.GlassInput('邮箱地址', '', this.email, false, (v: string) => {
                this.email = v;
              }, false)

              this.GlassInput('新密码', '请输入新密码（至少8位）', this.newPassword, true, (v: string) => {
                this.newPassword = v;
              })

              this.GlassInput('确认密码', '请再次输入新密码', this.confirmPassword, true, (v: string) => {
                this.confirmPassword = v;
              })

              this.GlassInput('验证码', '请输入验证码', this.verifyCode, false, (v: string) => {
                this.verifyCode = v;
              })
            }
            .width('100%')

            Column({ space: 16 }) {
              Row({ space: 12 }) {
                Button(this.isSendingCode ? '发送中...' : this.countdown > 0 ? `${this.countdown}s` : '发送验证码')
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.countdown > 0 || this.isSendingCode
                    ? (this.isDark ? '#66FFFFFF' : '#8090A6')
                    : (this.isDark ? '#E5FFFFFF' : '#0A59F7'))
                  .backgroundColor(this.countdown > 0 || this.isSendingCode
                    ? (this.isDark ? 'rgba(255,255,255,0.06)' : 'rgba(0,0,0,0.04)')
                    : (this.isDark ? 'rgba(10,89,247,0.2)' : 'rgba(10,89,247,0.1)'))
                  .type(ButtonType.Capsule)
                  .height(48)
                  .layoutWeight(1)
                  .backdropBlur(20)
                  .onClick(() => this.handleSendCode())

                Button(this.isSubmitting ? '处理中...' : '确认修改')
                  .fontSize(16)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(Color.White)
                  .backgroundColor('#0A59F7')
                  .type(ButtonType.Capsule)
                  .height(48)
                  .layoutWeight(1.2)
                  .shadow({ radius: 16, color: 'rgba(10,89,247,0.4)', offsetY: 4 })
                  .onClick(() => this.handleResetPassword())
              }
              .width('100%')
            }
            .width('100%')
            .margin({ top: 24 })
          }
          .width('92%')
          .padding({ left: 24, right: 24, top: 24, bottom: 24 })
          .borderRadius(32)
          .backgroundColor(this.isDark ? 'rgba(255, 255, 255, 0.06)' : 'rgba(255, 255, 255, 0.65)')
          .backdropBlur(80)
          .shadow(this.isDark
            ? { radius: 32, color: 'rgba(0,0,0,0.4)', offsetY: 8 }
            : { radius: 32, color: 'rgba(0,0,0,0.08)', offsetY: 8 })

          Column({ space: 6 }) {
            Text('鸿蒙 Markdown')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.isDark ? '#33FFFFFF' : '#33000000')
            Text('Powered by HarmonyOS NEXT')
              .fontSize(11)
              .fontColor(this.isDark ? '#1AFFFFFF' : '#1A000000')
          }
          .width('100%')
          .margin({ top: 32, bottom: 40 })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.isDark ? '#000000' : '#F1F3F5')
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      .scrollBar(BarState.Off)

      // 液态玻璃导航栏
      Row() {
        Text('鸿蒙 Markdown')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontFamily('HarmonyOS Sans')
          .fontColor(this.isDark ? '#E5FFFFFF' : '#E5000000')
          .layoutWeight(1)

        Row({ space: 12 }) {
          Button({ type: ButtonType.Circle, stateEffect: true }) {
            Text('←')
              .fontSize(20)
              .fontColor(this.isDark ? '#E5FFFFFF' : '#E5000000')
              .fontWeight(FontWeight.Medium)
          }
          .width(44)
          .height(44)
          .backgroundColor(this.isDark ? 'rgba(255, 255, 255, 0.1)' : 'rgba(0, 0, 0, 0.05)')
          .backdropBlur(50)
          .shadow(ShadowStyle.OUTER_DEFAULT_XS)
          .onClick(() => router.back())
        }
      }
      .width('92%')
      .padding({ left: 24, right: 24, top: 16, bottom: 16 })
      .margin({ top: 24 })
      .borderRadius(32)
      .backgroundColor(this.isDark ? 'rgba(0, 0, 0, 0.4)' : 'rgba(241, 243, 245, 0.5)')
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