import agconnect from '@hw-agconnect/api-ohos';
import '@hw-agconnect/core-ohos';
import '@hw-agconnect/auth-ohos';
import {
  EmailUserBuilder,
  VerifyCodeAction,
  VerifyCodeSettingBuilder,
  EmailAuthProvider
} from '@hw-agconnect/auth-ohos';

export interface CurrentUserInfo {
  uid: string;
  email: string;
}

export interface AuthActionResult {
  success: boolean;
  message: string;
  user?: CurrentUserInfo;
}

export class AuthService {
  private static readonly VERIFY_CODE_INTERVAL: number = 60;

  static async sendCode(email: string): Promise<AuthActionResult> {
    const trimmedEmail: string = email.trim();
    if (!trimmedEmail) {
      return {
        success: false,
        message: '请输入邮箱地址'
      };
    }

    try {
      const auth = agconnect.auth();
      const settings = new VerifyCodeSettingBuilder()
        .setAction(VerifyCodeAction.REGISTER_LOGIN)
        .setLang('zh_CN')
        .setSendInterval(AuthService.VERIFY_CODE_INTERVAL)
        .build();

      await auth.requestEmailVerifyCode(trimmedEmail, settings);

      return {
        success: true,
        message: '验证码已发送，请注意查收'
      };
    } catch (error) {
      return {
        success: false,
        message: AuthService.getErrorMessage(error)
      };
    }
  }

  static async registerAndLogin(email: string, code: string, password?: string): Promise<AuthActionResult> {
    const trimmedEmail: string = email.trim();
    const trimmedCode: string = code.trim();
    const trimmedPassword: string = password?.trim() || '';

    if (!trimmedEmail) {
      return {
        success: false,
        message: '请输入邮箱地址'
      };
    }

    if (!trimmedCode) {
      return {
        success: false,
        message: '请输入验证码'
      };
    }

    // 华为 AGConnect 密码强度要求
    if (trimmedPassword.length > 0) {
      if (trimmedPassword.length < 8) {
        return {
          success: false,
          message: '密码长度至少为8位'
        };
      }

      // 检查密码强度：必须包含大小写字母、数字、特殊字符中的至少3种
      let strength = 0;
      if (/[a-z]/.test(trimmedPassword)) strength++; // 小写字母
      if (/[A-Z]/.test(trimmedPassword)) strength++; // 大写字母
      if (/[0-9]/.test(trimmedPassword)) strength++; // 数字
      if (/[^a-zA-Z0-9]/.test(trimmedPassword)) strength++; // 特殊字符

      if (strength < 3) {
        return {
          success: false,
          message: '密码必须包含大小写字母、数字、特殊字符中的至少3种'
        };
      }
    }

    try {
      const auth = agconnect.auth();

      const emailUser = new EmailUserBuilder()
        .setEmail(trimmedEmail)
        .setVerifyCode(trimmedCode)
        .setPassword(trimmedPassword)
        .build();

      const signInResult = await auth.createEmailUser(emailUser);
      const user = signInResult.getUser();

      return {
        success: true,
        message: '注册并登录成功',
        user: {
          uid: String(user.getUid()),
          email: String(user.getEmail() || trimmedEmail)
        }
      };
    } catch (error) {
      console.error('注册失败:', error);
      return {
        success: false,
        message: AuthService.getErrorMessage(error)
      };
    }
  }

  static async getCurrentUser(): Promise<CurrentUserInfo | null> {
    try {
      const user = await agconnect.auth().getCurrentUser();
      if (!user) {
        return null;
      }

      return {
        uid: String(user.getUid()),
        email: String(user.getEmail() || '')
      };
    } catch (error) {
      return null;
    }
  }

  static async loginWithPassword(email: string, password: string): Promise<AuthActionResult> {
    const trimmedEmail: string = email.trim();
    const trimmedPassword: string = password.trim();

    if (!trimmedEmail) {
      return {
        success: false,
        message: '请输入邮箱地址'
      };
    }

    if (!trimmedPassword) {
      return {
        success: false,
        message: '请输入密码'
      };
    }

    try {
      const auth = agconnect.auth();
      const credential = EmailAuthProvider.credentialWithPassword(trimmedEmail, trimmedPassword);
      const signInResult = await auth.signIn(credential);
      const user = signInResult.getUser();

      return {
        success: true,
        message: '登录成功',
        user: {
          uid: String(user.getUid()),
          email: String(user.getEmail() || trimmedEmail)
        }
      };
    } catch (error) {
      return {
        success: false,
        message: AuthService.getErrorMessage(error)
      };
    }
  }

  static async logout(): Promise<AuthActionResult> {
    try {
      await agconnect.auth().signOut();
      return {
        success: true,
        message: '已退出登录'
      };
    } catch (error) {
      return {
        success: false,
        message: AuthService.getErrorMessage(error)
      };
    }
  }

  static async sendPasswordUpdateCode(): Promise<AuthActionResult> {
    try {
      const auth = agconnect.auth();
      const currentUser = await auth.getCurrentUser();

      if (!currentUser) {
        return {
          success: false,
          message: '请先登录'
        };
      }

      const email = currentUser.getEmail();
      if (!email) {
        return {
          success: false,
          message: '无法获取当前用户邮箱'
        };
      }

      const settings = new VerifyCodeSettingBuilder()
        .setAction(VerifyCodeAction.RESET_PASSWORD)
        .setLang('zh_CN')
        .setSendInterval(AuthService.VERIFY_CODE_INTERVAL)
        .build();

      await auth.requestEmailVerifyCode(email.toString(), settings);

      return {
        success: true,
        message: '验证码已发送，请注意查收'
      };
    } catch (error) {
      return {
        success: false,
        message: AuthService.getErrorMessage(error)
      };
    }
  }

  static async updatePassword(newPassword: string, verifyCode: string): Promise<AuthActionResult> {
    const trimmedPassword: string = newPassword.trim();
    const trimmedCode: string = verifyCode.trim();

    if (!trimmedPassword) {
      return {
        success: false,
        message: '请输入新密码'
      };
    }

    if (trimmedPassword.length < 6) {
      return {
        success: false,
        message: '密码长度至少为6位'
      };
    }

    if (!trimmedCode) {
      return {
        success: false,
        message: '请输入验证码'
      };
    }

    try {
      const auth = agconnect.auth();
      const currentUser = await auth.getCurrentUser();

      if (!currentUser) {
        return {
          success: false,
          message: '请先登录'
        };
      }

      // 12 表示邮箱提供者
      await currentUser.updatePassword(trimmedPassword, trimmedCode, 12);

      return {
        success: true,
        message: '密码修改成功'
      };
    } catch (error) {
      return {
        success: false,
        message: AuthService.getErrorMessage(error)
      };
    }
  }

  private static getErrorMessage(error: unknown): string {
    if (error instanceof Error && error.message) {
      return error.message;
    }

    if (typeof error === 'object' && error !== null && 'message' in error) {
      const message = (error as { message?: string }).message;
      if (message) {
        return message;
      }
    }

    return '操作失败，请稍后重试';
  }
}