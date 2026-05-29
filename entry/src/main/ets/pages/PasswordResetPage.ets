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

  private countdownTimer: number = -1;

  aboutToAppear(): void {
    this.loadUserEmail();
  }

  aboutToDisappear(): void {
    this.stopCountdown();
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
        .fontColor('#99000000')

      TextInput({ text: value, placeholder: placeholder })
        .fontSize(15)
        .height(48)
        .type(isPassword ? InputType.Password : InputType.Normal)
        .fontColor('#E5000000')
        .placeholderColor('#66000000')
        .backgroundColor('rgba(10,89,247,0.04)')
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

          Column({ space: 0 }) {
            Column({ space: 8 }) {
              Text('修改密码')
                .fontSize(28)
                .fontWeight(FontWeight.Bold)
                .fontColor('#E5000000')

              Text('通过验证码验证身份后设置新密码')
                .fontSize(14)
                .fontColor('#99000000')
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
                  .fontColor(this.countdown > 0 || this.isSendingCode ? '#8090A6' : '#0A59F7')
                  .backgroundColor(this.countdown > 0 || this.isSendingCode
                    ? 'rgba(0,0,0,0.04)' : 'rgba(10,89,247,0.1)')
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