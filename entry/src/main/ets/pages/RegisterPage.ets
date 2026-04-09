import { ConfigurationConstant } from '@kit.AbilityKit';
import { promptAction, router } from '@kit.ArkUI';
import { AuthActionResult, AuthService, CurrentUserInfo } from '../utils/AuthService';

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
  @State isDark: boolean = false;
  @State showRegistrationForm: boolean = false;
  @State isLoginMode: boolean = false;
  @StorageProp('currentColorMode') @Watch('syncTheme') currentSystemMode: number = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;

  private countdownTimer: number = -1;

  aboutToAppear(): void {
    this.syncTheme();
    this.loadCurrentUser();
  }

  aboutToDisappear(): void {
    this.stopCountdown();
  }

  syncTheme(): void {
    this.isDark = this.currentSystemMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
  }

  async loadCurrentUser(): Promise<void> {
    this.currentUser = await AuthService.getCurrentUser();
    // 如果已登录，隐藏注册表单
    if (this.currentUser) {
      this.showRegistrationForm = false;
    }
  }

  async handlePasswordSettings(): Promise<void> {
    if (!this.currentUser) {
      promptAction.showToast({
        message: '请先登录',
        duration: 2000
      });
      return;
    }

    promptAction.showDialog({
      title: '密码和账号设置',
      message: '请选择操作',
      buttons: [
        { text: '修改密码', color: '#0A59F7' },
        { text: '取消', color: '#666666' }
      ]
    }).then((result) => {
      if (result.index === 0) {
        this.showPasswordResetDialog();
      }
    });
  }

  async showPasswordResetDialog(): Promise<void> {
    router.pushUrl({
      url: 'pages/PasswordResetPage'
    });
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
    if (this.isSendingCode || this.countdown > 0) {
      return;
    }

    this.isSendingCode = true;
    const result: AuthActionResult = await AuthService.sendCode(this.email);
    this.statusText = result.message;
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

  async handleRegister(): Promise<void> {
    if (this.isSubmitting) {
      return;
    }

    if (!this.email || !this.email.trim()) {
      promptAction.showToast({
        message: '请输入邮箱地址',
        duration: 2000
      });
      return;
    }

    // 登录模式：使用邮箱密码登录
    if (this.isLoginMode) {
      if (!this.password || !this.password.trim()) {
        promptAction.showToast({
          message: '请输入密码',
          duration: 2000
        });
        return;
      }

      this.isSubmitting = true;
      const result: AuthActionResult = await AuthService.loginWithPassword(this.email, this.password);
      this.statusText = result.message;
      this.isSubmitting = false;

      if (result.success) {
        this.currentUser = result.user || await AuthService.getCurrentUser();
        this.email = '';
        this.password = '';
        this.verifyCode = '';
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
      return;
    }

    // 注册模式：使用验证码注册
    if (!this.verifyCode || !this.verifyCode.trim()) {
      promptAction.showToast({
        message: '请输入验证码',
        duration: 2000
      });
      return;
    }

    if (this.password && this.password.length < 8) {
      promptAction.showToast({
        message: '密码长度至少为8位',
        duration: 2000
      });
      return;
    }

    this.isSubmitting = true;
    const result: AuthActionResult = await AuthService.registerAndLogin(this.email, this.verifyCode, this.password);
    this.statusText = result.message;
    this.isSubmitting = false;

    if (result.success) {
      this.currentUser = result.user || await AuthService.getCurrentUser();
      this.email = '';
      this.password = '';
      this.verifyCode = '';
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

  async handleLogout(): Promise<void> {
    const result: AuthActionResult = await AuthService.logout();
    if (result.success) {
      this.currentUser = null;
      promptAction.showToast({
        message: '已退出登录',
        duration: 1500
      });
    }
  }

  @Builder
  MenuItemBuilder(icon: string, text: string, onClick: () => void) {
    Row({ space: 12 }) {
      Text(icon)
        .fontSize(20)
        .width(40)

      Text(text)
        .fontSize(15)
        .fontColor(this.isDark ? '#F3F7FF' : '#172033')
        .layoutWeight(1)

      Text('›')
        .fontSize(20)
        .fontColor(this.isDark ? '#667085' : '#A6A6A6')
    }
    .width('100%')
    .height(52)
    .padding({ left: 16, right: 16 })
    .onClick(onClick)
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

        if (!this.currentUser || this.showRegistrationForm) {
          Column({ space: 16 }) {
          Text(this.isLoginMode ? '邮箱登录' : '邮箱注册')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.isDark ? '#E5FFFFFF' : '#172033')

          Text('邮箱地址')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.isDark ? '#A6FFFFFF' : '#99000000')

          TextInput({ text: this.email, placeholder: '请输入邮箱地址' })
            .fontSize(16)
            .height(52)
            .fontColor(this.isDark ? '#F3F7FF' : '#172033')
            .backgroundColor(this.isDark ? '#1E293B' : '#F6F8FC')
            .borderRadius(16)
            .padding({ left: 16, right: 16 })
            .onChange((value: string) => {
              this.email = value;
            })

          Text('设置密码')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.isDark ? '#A6FFFFFF' : '#99000000')

          TextInput({ text: this.password, placeholder: this.isLoginMode ? '请输入密码' : '请设置密码（至少8位）' })
            .fontSize(16)
            .height(52)
            .type(InputType.Password)
            .fontColor(this.isDark ? '#F3F7FF' : '#172033')
            .backgroundColor(this.isDark ? '#1E293B' : '#F6F8FC')
            .borderRadius(16)
            .padding({ left: 16, right: 16 })
            .onChange((value: string) => {
              this.password = value;
            })

          if (!this.isLoginMode) {
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
          }

          Row({ space: 12 }) {
            if (!this.isLoginMode) {
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
            }

            Button(this.isSubmitting ? '提交中...' : this.isLoginMode ? '登录' : '立即注册/登录')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(Color.White)
              .backgroundColor('#0A59F7')
              .type(ButtonType.Capsule)
              .height(48)
              .layoutWeight(this.isLoginMode ? 1 : 1.2)
              .onClick(() => {
                this.handleRegister();
              })
          }

          Row({ space: 8 }) {
            Text(this.isLoginMode ? '没有账号？' : '已有账号？')
              .fontSize(13)
              .fontColor(this.isDark ? '#A6FFFFFF' : '#667085')

            Text(this.isLoginMode ? '立即注册' : '直接登录')
              .fontSize(13)
              .fontColor('#0A59F7')
              .fontWeight(FontWeight.Medium)
              .onClick(() => {
                this.isLoginMode = !this.isLoginMode;
                this.statusText = this.isLoginMode ? '使用邮箱和密码登录' : '使用邮箱验证码完成注册并自动登录';
              })
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)

          Text(this.statusText)
            .fontSize(13)
            .lineHeight(20)
            .fontColor(this.isDark ? '#A6FFFFFF' : '#667085')
            .width('100%')
        }
        .width('100%')
        .padding(20)
        .margin({ left: 24, right: 24, bottom: 24 })
        .borderRadius(28)
        .backgroundColor(this.isDark ? '#162233' : '#FFFFFF')
        .shadow(ShadowStyle.OUTER_DEFAULT_MD)
      }

        if (this.currentUser) {
          Column({ space: 20 }) {
            Column({ space: 0 }) {
              // 用户头像和信息
              Row({ space: 12 }) {
                // 用户头像
                Column() {
                  Text('👤')
                    .fontSize(32)
                }
                .width(64)
                .height(64)
                .borderRadius(32)
                .backgroundColor(this.isDark ? '#2A3441' : '#E8F0FE')
                .justifyContent(FlexAlign.Center)

                // 用户信息
                Column({ space: 4 }) {
                  Text(this.currentUser.email || '未知用户')
                    .fontSize(16)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.isDark ? '#F3F7FF' : '#172033')
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })

                  Text(`UID: ${this.currentUser.uid}`)
                    .fontSize(12)
                    .fontColor(this.isDark ? '#A6FFFFFF' : '#667085')
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
              }
              .width('100%')
              .padding(16)

              // 分割线
              Divider()
                .color(this.isDark ? '#2A3441' : '#E8EDF2')

              // 账号管理选项
              Column({ space: 0 }) {
                // 密码和账号设置
                this.MenuItemBuilder('🔐', '密码和账号设置', () => {
                  this.handlePasswordSettings()
                })

                Divider()
                  .color(this.isDark ? '#2A3441' : '#E8EDF2')
                  .margin({ left: 52 })

                // 自定义个人资料
                this.MenuItemBuilder('✏️', '自定义个人资料', () => {
                  promptAction.showToast({ message: '功能开发中' })
                })

                Divider()
                  .color(this.isDark ? '#2A3441' : '#E8EDF2')
                  .margin({ left: 52 })

                // 添加另一个账号
                this.MenuItemBuilder('➕', '添加另一个账号', () => {
                  this.showRegistrationForm = true;
                })

                Divider()
                  .color(this.isDark ? '#2A3441' : '#E8EDF2')
                  .margin({ left: 52 })

                // 退出登录
                this.MenuItemBuilder('🚪', '退出登录', () => {
                  this.handleLogout()
                })
              }
            }
            .borderRadius(16)
            .backgroundColor(this.isDark ? '#132033' : '#EEF4FF')
          }
          .width('100%')
          .padding(20)
          .margin({ left: 24, right: 24, bottom: 24 })
          .borderRadius(28)
          .backgroundColor(this.isDark ? '#162233' : '#FFFFFF')
          .shadow(ShadowStyle.OUTER_DEFAULT_MD)
        }
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