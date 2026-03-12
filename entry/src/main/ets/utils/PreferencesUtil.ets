import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

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
  private static readonly KEY_AI_API_KEY = 'aiApiKey';
  private static readonly KEY_AI_MODEL = 'aiModel';
  private static readonly KEY_AI_SYSTEM_PROMPT = 'aiSystemPrompt';
  private static readonly KEY_AI_ENABLED = 'aiEnabled';

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
  
  static async saveAIConfigApiKey(context: common.UIAbilityContext, key: string) {
    const prefs = await PreferencesUtil.getPreferences(context);
    await prefs.put(PreferencesUtil.KEY_AI_API_KEY, key);
    await prefs.flush();
  }
  
  static async getAIConfigApiKey(context: common.UIAbilityContext): Promise<string> {
    const prefs = await PreferencesUtil.getPreferences(context);
    return await prefs.get(PreferencesUtil.KEY_AI_API_KEY, '') as string;
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
}
