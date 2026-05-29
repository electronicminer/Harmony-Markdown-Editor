import { common, ConfigurationConstant } from '@kit.AbilityKit';
import { promptAction, router } from '@kit.ArkUI';
import { AuthActionResult, AuthService, CurrentUserInfo } from '../utils/AuthService';
import { PreferencesUtil } from '../utils/PreferencesUtil';

@Entry
@Component
struct RegisterPage {
  @State email: string = '';
  @State password: string = '';
  @State verifyCode: string = '';
  @State isSendingCode: boolean = false;
  @State isSubmitting: boolean = false;
  @State countdown: number = 0;
  @State statusText: string = '使用邮箱验证码完成注册并自动登录';
  @State currentUser: CurrentUserInfo | null = null;
  @State showRegistrationForm: boolean = false;
  @State isLoginMode: boolean = false;
  @State passwordStrength: number = 0;
  @State profileNickname: string = '';
  @State profileBio: string = '';
  @State profileAvatarColor: string = '#0A59F7';

  private context = getContext(this) as common.UIAbilityContext;

  private countdownTimer: number = -1;

  aboutToAppear(): void {
    this.loadCurrentUser();
  }

  onPageShow(): void {
    if (this.currentUser) {
      this.loadProfile();
    }
  }

  aboutToDisappear(): void {
    this.stopCountdown();
  }

  updatePasswordStrength(pwd: string): void {
    let s = 0;
    if (pwd.length >= 8) s++;
    if (/[a-z]/.test(pwd) && /[A-Z]/.test(pwd)) s++;
    if (/[0-9]/.test(pwd)) s++;
    if (/[^a-zA-Z0-9]/.test(pwd)) s++;
    this.passwordStrength = s;
  }

  async loadCurrentUser(): Promise<void> {
    this.currentUser = await AuthService.getCurrentUser();
    if (this.currentUser) {
      this.showRegistrationForm = false;
      await this.loadProfile();
    }
  }

  async loadProfile(): Promise<void> {
    this.profileNickname = await PreferencesUtil.getProfileNickname(this.context);
    this.profileBio = await PreferencesUtil.getProfileBio(this.context);
    this.profileAvatarColor = await PreferencesUtil.getProfileAvatarColor(this.context);
  }

  async handlePasswordSettings(): Promise<void> {
    if (!this.currentUser) {
      promptAction.showToast({ message: '请先登录', duration: 2000 });
      return;
    }
    router.pushUrl({ url: 'pages/PasswordResetPage' });
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
      if (this.countdown <= 1) {
        this.countdown = 0;
        this.stopCountdown();
        return;
      }
      this.countdown -= 1;
    }, 1000);
  }

  async handleSendCode(): Promise<void> {
    if (this.isSendingCode || this.countdown > 0) return;
    this.isSendingCode = true;
    const result: AuthActionResult = await AuthService.sendCode(this.email);
    this.statusText = result.message;
    this.isSendingCode = false;
    if (result.success) this.startCountdown();
    promptAction.showToast({ message: result.message, duration: result.success ? 1500 : 2000 });
  }

  async handleRegister(): Promise<void> {
    if (this.isSubmitting) return;
    if (!this.email || !this.email.trim()) {
      promptAction.showToast({ message: '请输入邮箱地址', duration: 2000 });
      return;
    }

    if (this.isLoginMode) {
      if (!this.password || !this.password.trim()) {
        promptAction.showToast({ message: '请输入密码', duration: 2000 });
        return;
      }
      this.isSubmitting = true;
      const r: AuthActionResult = await AuthService.loginWithPassword(this.email, this.password);
      this.statusText = r.message;
      this.isSubmitting = false;
      if (r.success) {
        this.currentUser = r.user || await AuthService.getCurrentUser();
        this.email = ''; this.password = ''; this.verifyCode = '';
      }
      promptAction.showToast({ message: r.message, duration: r.success ? 1500 : 2000 });
      return;
    }

    if (!this.verifyCode || !this.verifyCode.trim()) {
      promptAction.showToast({ message: '请输入验证码', duration: 2000 });
      return;
    }
    if (this.password && this.password.length < 8) {
      promptAction.showToast({ message: '密码长度至少为8位', duration: 2000 });
      return;
    }
    this.isSubmitting = true;
    const r: AuthActionResult = await AuthService.registerAndLogin(this.email, this.verifyCode, this.password);
    this.statusText = r.message;
    this.isSubmitting = false;
    if (r.success) {
      this.currentUser = r.user || await AuthService.getCurrentUser();
      this.email = ''; this.password = ''; this.verifyCode = '';
    }
    promptAction.showToast({ message: r.message, duration: r.success ? 1500 : 2000 });
  }

  async handleLogout(): Promise<void> {
    const result: AuthActionResult = await AuthService.logout();
    if (result.success) {
      this.currentUser = null;
      promptAction.showToast({ message: '已退出登录', duration: 1500 });
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

  @Builder
  GlassMenuItem(icon: string, title: string, subtitle: string, onClick: () => void) {
    Row({ space: 14 }) {
      Text(icon)
        .fontSize(20)
        .width(40)
        .height(40)
        .textAlign(TextAlign.Center)
        .backgroundColor('rgba(10,89,247,0.05)')
        .borderRadius(12)

      Column({ space: 2 }) {
        Text(title)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor('#E5000000')
        if (subtitle) {
          Text(subtitle)
            .fontSize(12)
            .fontColor('#99000000')
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text('›')
        .fontSize(22)
        .fontColor('#4D000000')
    }
    .width('100%')
    .height(subtitle ? 60 : 52)
    .padding({ left: 8, right: 8 })
    .onClick(onClick)
  }

  @Builder
  PasswordStrengthBar() {
    if (this.password.length > 0 && !this.isLoginMode) {
      Row({ space: 6 }) {
        ForEach([0, 1, 2, 3], (idx: number) => {
          Column()
            .width(28)
            .height(4)
            .borderRadius(2)
            .backgroundColor(
              idx < this.passwordStrength
                ? (this.passwordStrength <= 1 ? '#F4222D' :
                  this.passwordStrength <= 2 ? '#FA8C16' : '#00A854')
                : 'rgba(10,89,247,0.08)'
            )
        })
        Blank()
        Text(this.passwordStrength <= 1 ? '弱' : this.passwordStrength <= 2 ? '中' : '强')
          .fontSize(12)
          .fontColor(this.passwordStrength <= 1 ? '#F4222D' :
            this.passwordStrength <= 2 ? '#FA8C16' : '#00A854')
      }
      .width('100%')
    }
  }

  @Builder
  LoginForm() {
    Column({ space: 0 }) {
      Column({ space: 8 }) {
        Text(this.isLoginMode ? '欢迎回来' : '创建账号')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor('#E5000000')

        Text(this.isLoginMode ? '使用邮箱和密码登录你的账号' : '使用邮箱验证码完成注册')
          .fontSize(14)
          .fontColor('#99000000')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .margin({ bottom: 24 })

      Column({ space: 16 }) {
        this.GlassInput('邮箱地址', '请输入邮箱地址', this.email, false, (v: string) => {
          this.email = v;
        })

        this.GlassInput('密码', this.isLoginMode ? '请输入密码' : '请设置密码（至少8位）',
          this.password, true, (v: string) => {
            this.password = v;
            this.updatePasswordStrength(v);
          })

        this.PasswordStrengthBar()

        if (!this.isLoginMode) {
          this.GlassInput('验证码', '请输入验证码', this.verifyCode, false, (v: string) => {
            this.verifyCode = v;
          })
        }
      }
      .width('100%')

      Column({ space: 16 }) {
        Row({ space: 12 }) {
          if (!this.isLoginMode) {
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
          }

          Button(this.isSubmitting ? '处理中...' : this.isLoginMode ? '登 录' : '注册并登录')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .backgroundColor('#0A59F7')
            .type(ButtonType.Capsule)
            .height(48)
            .layoutWeight(this.isLoginMode ? 1 : 1.2)
            .shadow({ radius: 16, color: 'rgba(10,89,247,0.4)', offsetY: 4 })
            .onClick(() => this.handleRegister())
        }
        .width('100%')

        Row({ space: 6 }) {
          Text(this.isLoginMode ? '没有账号？' : '已有账号？')
            .fontSize(13)
            .fontColor('#99000000')

          Text(this.isLoginMode ? '立即注册' : '直接登录')
            .fontSize(13)
            .fontColor('#0A59F7')
            .fontWeight(FontWeight.Medium)
            .onClick(() => {
              this.isLoginMode = !this.isLoginMode;
              this.passwordStrength = 0;
              this.statusText = this.isLoginMode ? '使用邮箱和密码登录' : '使用邮箱验证码完成注册并自动登录';
            })
        }
        .justifyContent(FlexAlign.Center)

        if (this.statusText) {
          Text(this.statusText)
            .fontSize(12)
            .lineHeight(18)
            .fontColor('#66000000')
            .textAlign(TextAlign.Center)
        }
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
  }

  @Builder
  UserProfile() {
    Column({ space: 0 }) {
      Row({ space: 14 }) {
        Column() {
          Text(this.profileNickname ? this.profileNickname.charAt(0).toUpperCase() :
            this.currentUser?.email?.charAt(0)?.toUpperCase() || 'U')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
        }
        .width(56)
        .height(56)
        .borderRadius(16)
        .backgroundColor(this.profileAvatarColor)
        .justifyContent(FlexAlign.Center)
        .shadow({ radius: 12, color: `${this.profileAvatarColor}66`, offsetY: 4 })

        Column({ space: 4 }) {
          Text(this.profileNickname || this.currentUser?.email || '未知用户')
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor('#E5000000')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          if (this.profileBio) {
            Text(this.profileBio)
              .fontSize(12)
              .fontColor('#99000000')
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          } else {
            Text('已登录')
              .fontSize(11)
              .fontColor('#00A854')
              .fontWeight(FontWeight.Medium)
              .padding({ left: 8, right: 8, top: 2, bottom: 2 })
              .borderRadius(6)
              .backgroundColor('rgba(0,168,84,0.1)')
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')

      Row() {
        Text('UID')
          .fontSize(12)
          .fontColor('#4D000000')
          .margin({ right: 8 })
        Text(this.currentUser?.uid || '')
          .fontSize(12)
          .fontColor('#99000000')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 10, bottom: 10 })
      .margin({ top: 14 })
      .borderRadius(14)
      .backgroundColor('rgba(10,89,247,0.04)')

      Divider()
        .color('rgba(10,89,247,0.06)')
        .margin({ top: 16, bottom: 4 })

      this.GlassMenuItem('🔐', '密码和账号设置', '修改密码、安全管理', () => {
        this.handlePasswordSettings();
      })

      Divider().color('rgba(10,89,247,0.06)').margin({ left: 54 })

      this.GlassMenuItem('✏️', '自定义个人资料', '头像、昵称设置', () => {
        router.pushUrl({ url: 'pages/ProfilePage' });
      })

      Divider().color('rgba(10,89,247,0.06)').margin({ left: 54 })

      this.GlassMenuItem('☁️', '云文档管理', '云端存储、分享文档', () => {
        router.pushUrl({ url: 'pages/CloudDocsPage' });
      })

      Divider().color('rgba(10,89,247,0.06)').margin({ left: 54 })

      this.GlassMenuItem('➕', '添加另一个账号', '切换或绑定新账号', () => {
        this.showRegistrationForm = true;
      })

      Divider().color('rgba(10,89,247,0.06)').margin({ left: 54 })

      this.GlassMenuItem('🚪', '退出登录', '', () => {
        this.handleLogout();
      })
    }
    .width('92%')
    .padding({ left: 24, right: 24, top: 24, bottom: 16 })
    .borderRadius(32)
    .backgroundColor('rgba(240, 244, 255, 0.85)')
    .backdropBlur(80)
    .shadow({ radius: 32, color: 'rgba(10,89,247,0.06)', offsetY: 8 })
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      Scroll() {
        Column() {
          Row().height(100).width('100%')

          if (!this.currentUser || this.showRegistrationForm) {
            this.LoginForm()
          }

          if (this.currentUser && !this.showRegistrationForm) {
            this.UserProfile()
          }

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