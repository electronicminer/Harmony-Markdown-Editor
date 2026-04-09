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
    if (this.isSendingCode || this.countdown > 0) {
      return;
    }

    this.isSendingCode = true;
    const result: AuthActionResult = await AuthService.sendPasswordUpdateCode();
    this.isSendingCode = false;

    if (result.success) {
      this.startCountdown();
      promptAction.showToast({
        message: result.message,
        duration: 1500
      });
    } else {
      promptAction.showToast({
        message: result.message,
        duration: 2000
      });
    }
  }

  async handleResetPassword(): Promise<void> {
    if (this.isSubmitting) {
      return;
    }

    if (!this.newPassword) {
      promptAction.showToast({
        message: '请输入新密码',
        duration: 2000
      });
      return;
    }

    if (this.newPassword.length < 8) {
      promptAction.showToast({
        message: '密码长度至少为8位',
        duration: 2000
      });
      return;
    }

    // 检查密码强度
    let strength = 0;
    if (/[a-z]/.test(this.newPassword)) strength++;
    if (/[A-Z]/.test(this.newPassword)) strength++;
    if (/[0-9]/.test(this.newPassword)) strength++;
    if (/[^a-zA-Z0-9]/.test(this.newPassword)) strength++;

    if (strength < 3) {
      promptAction.showToast({
        message: '密码必须包含大小写字母、数字、特殊字符中的至少3种',
        duration: 2000
      });
      return;
    }

    if (this.newPassword !== this.confirmPassword) {
      promptAction.showToast({
        message: '两次输入的密码不一致',
        duration: 2000
      });
      return;
    }

    if (!this.verifyCode) {
      promptAction.showToast({
        message: '请输入验证码',
        duration: 2000
      });
      return;
    }

    this.isSubmitting = true;
    const result: AuthActionResult = await AuthService.updatePassword(this.newPassword, this.verifyCode);
    this.isSubmitting = false;

    if (result.success) {
      promptAction.showToast({
        message: result.message,
        duration: 1500
      });
      setTimeout(() => {
        router.back();
      }, 1500);
    } else {
      promptAction.showToast({
        message: result.message,
        duration: 2000
      });
    }
  }

  build() {
    Scroll() {
      Column({ space: 20 }) {
        Row() {
          Button('返回')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.isDark ? '#E5FFFFFF' : '#0A59F7')
            .backgroundColor(this.isDark ? '#1F2A37' : '#EAF2FF')
            .type(ButtonType.Capsule)
            .height(36)
            .onClick(() => {
              router.back();
            })
        }
        .width('100%')
        .padding({ left: 24, right: 24, top: 28 })
        .justifyContent(FlexAlign.End)

        Column({ space: 16 }) {
          Text('修改密码')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.isDark ? '#E5FFFFFF' : '#172033')

          Text('邮箱地址')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.isDark ? '#A6FFFFFF' : '#99000000')

          TextInput({ text: this.email })
            .fontSize(16)
            .height(52)
            .enabled(false)
            .fontColor(this.isDark ? '#99FFFFFF' : '#667085')
            .backgroundColor(this.isDark ? '#1E293B' : '#F6F8FC')
            .borderRadius(16)
            .padding({ left: 16, right: 16 })

          Text('新密码')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.isDark ? '#A6FFFFFF' : '#99000000')

          TextInput({ text: this.newPassword, placeholder: '请输入新密码（至少6位）' })
            .fontSize(16)
            .height(52)
            .type(InputType.Password)
            .fontColor(this.isDark ? '#F3F7FF' : '#172033')
            .backgroundColor(this.isDark ? '#1E293B' : '#F6F8FC')
            .borderRadius(16)
            .padding({ left: 16, right: 16 })
            .onChange((value: string) => {
              this.newPassword = value;
            })

          Text('确认密码')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.isDark ? '#A6FFFFFF' : '#99000000')

          TextInput({ text: this.confirmPassword, placeholder: '请再次输入新密码' })
            .fontSize(16)
            .height(52)
            .type(InputType.Password)
            .fontColor(this.isDark ? '#F3F7FF' : '#172033')
            .backgroundColor(this.isDark ? '#1E293B' : '#F6F8FC')
            .borderRadius(16)
            .padding({ left: 16, right: 16 })
            .onChange((value: string) => {
              this.confirmPassword = value;
            })

          Text('验证码')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.isDark ? '#A6FFFFFF' : '#99000000')

          TextInput({ text: this.verifyCode, placeholder: '请输入验证码' })
            .fontSize(16)
            .height(52)
            .fontColor(this.isDark ? '#F3F7FF' : '#172033')
            .backgroundColor(this.isDark ? '#1E293B' : '#F6F8FC')
            .borderRadius(16)
            .padding({ left: 16, right: 16 })
            .onChange((value: string) => {
              this.verifyCode = value;
            })

          Row({ space: 12 }) {
            Button(this.isSendingCode ? '发送中...' : this.countdown > 0 ? `${this.countdown}s 后重试` : '发送验证码')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.countdown > 0 || this.isSendingCode ? (this.isDark ? '#A6FFFFFF' : '#8090A6') : Color.White)
              .backgroundColor(this.countdown > 0 || this.isSendingCode ? (this.isDark ? '#2B3647' : '#DCE6F7') : '#0A59F7')
              .type(ButtonType.Capsule)
              .height(48)
              .layoutWeight(1)
              .onClick(() => {
                this.handleSendCode();
              })

            Button(this.isSubmitting ? '提交中...' : '确认修改')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(Color.White)
              .backgroundColor('#0A59F7')
              .type(ButtonType.Capsule)
              .height(48)
              .layoutWeight(1)
              .onClick(() => {
                this.handleResetPassword();
              })
          }
          .width('100%')
        }
        .width('100%')
        .padding(20)
        .margin({ left: 24, right: 24 })
        .borderRadius(28)
        .backgroundColor(this.isDark ? '#162233' : '#FFFFFF')
        .shadow(ShadowStyle.OUTER_DEFAULT_MD)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.isDark ? '#0B1020' : '#F4F7FB')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
