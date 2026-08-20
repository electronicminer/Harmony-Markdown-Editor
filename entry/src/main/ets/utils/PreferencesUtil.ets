import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { asset } from '@kit.AssetStoreKit';
import { util } from '@kit.ArkTS';

export class PreferencesUtil {
  private static readonly PREFERENCES_NAME = 'HMarkdownPrefs';
  private static readonly KEY_IS_DARK = 'isDark';
  private static readonly KEY_OPEN_LAST_FILE = 'openLastFile';
  private static readonly KEY_LAST_FILE_URI = 'lastFileUri';
  private static readonly KEY_AUTO_SAVE = 'autoSave';
  private static readonly KEY_AUTO_SAVE_INTERVAL = 'autoSaveInterval';
  private static readonly KEY_DEFAULT_VIEW_MODE = 'defaultViewMode';
  private static readonly KEY_FOLLOW_SYSTEM = 'followSystem';

  // AI Config Keys
  private static readonly KEY_AI_API_URL = 'aiApiUrl';
  private static readonly KEY_AI_API_KEY = 'aiApiKey'; // 旧版明文存储的遗留键，仅在迁移时读取后删除
  private static readonly KEY_AI_MODEL = 'aiModel';
  private static readonly KEY_AI_SYSTEM_PROMPT = 'aiSystemPrompt';
  private static readonly KEY_AI_ENABLED = 'aiEnabled';

  // Asset Store 中 API Key 的别名（Asset 数据不随系统备份导出）
  private static readonly ASSET_ALIAS_AI_API_KEY: string = 'HMarkdown_ai_api_key';

  // Cloud Doc Map Key（本地文件URI → 云端文档ID 映射）
  private static readonly KEY_CLOUD_DOC_MAP = 'cloudDocMap';

  // Profile Keys
  private static readonly KEY_PROFILE_NICKNAME = 'profileNickname';
  private static readonly KEY_PROFILE_BIO = 'profileBio';
  private static readonly KEY_PROFILE_AVATAR_COLOR = 'profileAvatarColor';

  static async getPreferences(context: common.UIAbilityContext): Promise<preferences.Preferences> {
    return await preferences.getPreferences(context, PreferencesUtil.PREFERENCES_NAME);
  }

  static async saveIsDark(context: common.UIAbilityContext, isDark: boolean) {
    const prefs = await PreferencesUtil.getPreferences(context);
    await prefs.put(PreferencesUtil.KEY_IS_DARK, isDark);
    await prefs.flush();
  }

  static async getIsDark(context: common.UIAbilityContext): Promise<boolean> {
    const prefs = await PreferencesUtil.getPreferences(context);
    return await prefs.get(PreferencesUtil.KEY_IS_DARK, false) as boolean;
  }

  static async saveOpenLastFile(context: common.UIAbilityContext, openLastFile: boolean) {
    const prefs = await PreferencesUtil.getPreferences(context);
    await prefs.put(PreferencesUtil.KEY_OPEN_LAST_FILE, openLastFile);
    await prefs.flush();
  }

  static async getOpenLastFile(context: common.UIAbilityContext): Promise<boolean> {
    const prefs = await PreferencesUtil.getPreferences(context);
    return await prefs.get(PreferencesUtil.KEY_OPEN_LAST_FILE, false) as boolean;
  }

  static async saveLastFileUri(context: common.UIAbilityContext, uri: string) {
    const prefs = await PreferencesUtil.getPreferences(context);
    await prefs.put(PreferencesUtil.KEY_LAST_FILE_URI, uri);
    await prefs.flush();
  }

  static async getLastFileUri(context: common.UIAbilityContext): Promise<string> {
    const prefs = await PreferencesUtil.getPreferences(context);
    return await prefs.get(PreferencesUtil.KEY_LAST_FILE_URI, '') as string;
  }

  static async saveAutoSave(context: common.UIAbilityContext, autoSave: boolean) {
    const prefs = await PreferencesUtil.getPreferences(context);
    await prefs.put(PreferencesUtil.KEY_AUTO_SAVE, autoSave);
    await prefs.flush();
  }

  static async getAutoSave(context: common.UIAbilityContext): Promise<boolean> {
    const prefs = await PreferencesUtil.getPreferences(context);
    return await prefs.get(PreferencesUtil.KEY_AUTO_SAVE, false) as boolean;
  }

  static async saveAutoSaveInterval(context: common.UIAbilityContext, interval: number) {
    const prefs = await PreferencesUtil.getPreferences(context);
    await prefs.put(PreferencesUtil.KEY_AUTO_SAVE_INTERVAL, interval);
    await prefs.flush();
  }

  static async getAutoSaveInterval(context: common.UIAbilityContext): Promise<number> {
    const prefs = await PreferencesUtil.getPreferences(context);
    return await prefs.get(PreferencesUtil.KEY_AUTO_SAVE_INTERVAL, 60) as number; // Default 60s
  }

  static async saveDefaultViewMode(context: common.UIAbilityContext, viewMode: number) {
    const prefs = await PreferencesUtil.getPreferences(context);
    await prefs.put(PreferencesUtil.KEY_DEFAULT_VIEW_MODE, viewMode);
    await prefs.flush();
  }

  static async getDefaultViewMode(context: common.UIAbilityContext): Promise<number> {
    const prefs = await PreferencesUtil.getPreferences(context);
    return await prefs.get(PreferencesUtil.KEY_DEFAULT_VIEW_MODE, 0) as number; // Default 0 (Split)
  }

  static async saveFollowSystem(context: common.UIAbilityContext, followSystem: boolean) {
    const prefs = await PreferencesUtil.getPreferences(context);
    await prefs.put(PreferencesUtil.KEY_FOLLOW_SYSTEM, followSystem);
    await prefs.flush();
  }

  static async getFollowSystem(context: common.UIAbilityContext): Promise<boolean> {
    const prefs = await PreferencesUtil.getPreferences(context);
    return await prefs.get(PreferencesUtil.KEY_FOLLOW_SYSTEM, false) as boolean;
  }

  // Cloud Doc Map Methods — 本地文件 URI → 云端文档 ID
  static async saveCloudDocId(context: common.UIAbilityContext, fileUri: string, cloudDocId: string) {
    if (!fileUri || !cloudDocId) return;
    const prefs = await PreferencesUtil.getPreferences(context);
    const raw = await prefs.get(PreferencesUtil.KEY_CLOUD_DOC_MAP, '{}') as string;
    const map: Record<string, string> = JSON.parse(raw) as Record<string, string>;
    map[fileUri] = cloudDocId;
    await prefs.put(PreferencesUtil.KEY_CLOUD_DOC_MAP, JSON.stringify(map));
    await prefs.flush();
  }

  static async getCloudDocId(context: common.UIAbilityContext, fileUri: string): Promise<string> {
    if (!fileUri) return '';
    const prefs = await PreferencesUtil.getPreferences(context);
    const raw = await prefs.get(PreferencesUtil.KEY_CLOUD_DOC_MAP, '{}') as string;
    const map: Record<string, string> = JSON.parse(raw) as Record<string, string>;
    return map[fileUri] || '';
  }

  static async removeCloudDocId(context: common.UIAbilityContext, fileUri: string) {
    if (!fileUri) return;
    const prefs = await PreferencesUtil.getPreferences(context);
    const raw = await prefs.get(PreferencesUtil.KEY_CLOUD_DOC_MAP, '{}') as string;
    const map: Record<string, string> = JSON.parse(raw) as Record<string, string>;
    const newMap: Record<string, string> = {};
    for (const key of Object.keys(map)) {
      if (key !== fileUri) {
        newMap[key] = map[key];
      }
    }
    await prefs.put(PreferencesUtil.KEY_CLOUD_DOC_MAP, JSON.stringify(newMap));
    await prefs.flush();
  }

  // AI Config Methods
  static async saveAIConfigApiUrl(context: common.UIAbilityContext, url: string) {
    const prefs = await PreferencesUtil.getPreferences(context);
    await prefs.put(PreferencesUtil.KEY_AI_API_URL, url);
    await prefs.flush();
  }
  
  static async getAIConfigApiUrl(context: common.UIAbilityContext): Promise<string> {
    const prefs = await PreferencesUtil.getPreferences(context);
    return await prefs.get(PreferencesUtil.KEY_AI_API_URL, '') as string;
  }
  
  // API Key 属敏感凭据：改用 Asset Store Kit 存储（系统加密且不随备份导出），
  // 不再写入明文 Preferences（旧值在首次读取时自动迁移并删除）。
  // 注意：Asset 的 ALIAS 标签值类型为字节数组（Uint8Array），需将字符串别名编码后使用。
  private static aliasBytes(): Uint8Array {
    return util.TextEncoder.create('utf-8').encodeInto(PreferencesUtil.ASSET_ALIAS_AI_API_KEY);
  }

  static async saveAIConfigApiKey(context: common.UIAbilityContext, key: string) {
    const encoder = util.TextEncoder.create('utf-8');
    const query: asset.AssetMap = new Map();
    query.set(asset.Tag.ALIAS, PreferencesUtil.aliasBytes());
    try {
      if (!key) {
        // 清空则移除资产
        try {
          await asset.remove(query);
        } catch (e) {
          // 资产本就不存在，忽略
        }
        return;
      }
      const secret: Uint8Array = encoder.encodeInto(key);
      const attrs: asset.AssetMap = new Map();
      attrs.set(asset.Tag.ALIAS, PreferencesUtil.aliasBytes());
      attrs.set(asset.Tag.SECRET, secret);
      try {
        await asset.add(attrs);
      } catch (e) {
        // 已存在同名资产则改为更新
        const updateAttrs: asset.AssetMap = new Map();
        updateAttrs.set(asset.Tag.SECRET, secret);
        await asset.update(query, updateAttrs);
      }
    } catch (e) {
      console.error('[Preferences] saveAIConfigApiKey to asset store failed: ' + JSON.stringify(e));
    }
  }

  static async getAIConfigApiKey(context: common.UIAbilityContext): Promise<string> {
    const query: asset.AssetMap = new Map();
    query.set(asset.Tag.ALIAS, PreferencesUtil.aliasBytes());
    try {
      const res: asset.AssetMap[] = await asset.query(query);
      if (res && res.length > 0) {
        const secret = res[0].get(asset.Tag.SECRET) as Uint8Array;
        return util.TextDecoder.create('utf-8').decodeWithStream(secret);
      }
    } catch (e) {
      // 资产不存在等，走旧数据迁移
    }
    // 迁移：旧版本将 API Key 明文存于 Preferences，读到后写入 Asset 并删除明文
    try {
      const prefs = await PreferencesUtil.getPreferences(context);
      const legacy = await prefs.get(PreferencesUtil.KEY_AI_API_KEY, '') as string;
      if (legacy) {
        await PreferencesUtil.saveAIConfigApiKey(context, legacy);
        await prefs.delete(PreferencesUtil.KEY_AI_API_KEY);
        await prefs.flush();
      }
      return legacy;
    } catch (e) {
      return '';
    }
  }
  
  static async saveAIConfigModel(context: common.UIAbilityContext, model: string) {
    const prefs = await PreferencesUtil.getPreferences(context);
    await prefs.put(PreferencesUtil.KEY_AI_MODEL, model);
    await prefs.flush();
  }
  
  static async getAIConfigModel(context: common.UIAbilityContext): Promise<string> {
    const prefs = await PreferencesUtil.getPreferences(context);
    return await prefs.get(PreferencesUtil.KEY_AI_MODEL, 'gpt-3.5-turbo') as string;
  }
  
  static async saveAIConfigSystemPrompt(context: common.UIAbilityContext, prompt: string) {
    const prefs = await PreferencesUtil.getPreferences(context);
    await prefs.put(PreferencesUtil.KEY_AI_SYSTEM_PROMPT, prompt);
    await prefs.flush();
  }
  
  static async getAIConfigSystemPrompt(context: common.UIAbilityContext): Promise<string> {
    const prefs = await PreferencesUtil.getPreferences(context);
    return await prefs.get(PreferencesUtil.KEY_AI_SYSTEM_PROMPT, '你是一个专业的 Markdown 写作助手，擅长解答 Markdown 语法问题、提供写作建议和生成各种 Markdown 模板。请用简洁清晰的中文回答用户问题。') as string;
  }
  
  static async saveAIConfigEnabled(context: common.UIAbilityContext, enabled: boolean) {
    const prefs = await PreferencesUtil.getPreferences(context);
    await prefs.put(PreferencesUtil.KEY_AI_ENABLED, enabled);
    await prefs.flush();
  }
  
  static async getAIConfigEnabled(context: common.UIAbilityContext): Promise<boolean> {
    const prefs = await PreferencesUtil.getPreferences(context);
    return await prefs.get(PreferencesUtil.KEY_AI_ENABLED, false) as boolean;
  }

  // Profile Methods
  static async saveProfileNickname(context: common.UIAbilityContext, nickname: string) {
    const prefs = await PreferencesUtil.getPreferences(context);
    await prefs.put(PreferencesUtil.KEY_PROFILE_NICKNAME, nickname);
    await prefs.flush();
  }

  static async getProfileNickname(context: common.UIAbilityContext): Promise<string> {
    const prefs = await PreferencesUtil.getPreferences(context);
    return await prefs.get(PreferencesUtil.KEY_PROFILE_NICKNAME, '') as string;
  }

  static async saveProfileBio(context: common.UIAbilityContext, bio: string) {
    const prefs = await PreferencesUtil.getPreferences(context);
    await prefs.put(PreferencesUtil.KEY_PROFILE_BIO, bio);
    await prefs.flush();
  }

  static async getProfileBio(context: common.UIAbilityContext): Promise<string> {
    const prefs = await PreferencesUtil.getPreferences(context);
    return await prefs.get(PreferencesUtil.KEY_PROFILE_BIO, '') as string;
  }

  static async saveProfileAvatarColor(context: common.UIAbilityContext, color: string) {
    const prefs = await PreferencesUtil.getPreferences(context);
    await prefs.put(PreferencesUtil.KEY_PROFILE_AVATAR_COLOR, color);
    await prefs.flush();
  }

  static async getProfileAvatarColor(context: common.UIAbilityContext): Promise<string> {
    const prefs = await PreferencesUtil.getPreferences(context);
    return await prefs.get(PreferencesUtil.KEY_PROFILE_AVATAR_COLOR, '#0A59F7') as string;
  }
}
