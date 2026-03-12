import { common } from '@kit.AbilityKit';
import { PreferencesUtil } from './PreferencesUtil';

/**
 * AI 配置类
 * 存储和管理 AI API 相关配置
 */
@ObservedV2
export class AIConfigClass {
  @Trace
  apiUrl: string = '';
  
  @Trace
  apiKey: string = '';
  
  @Trace
  model: string = 'gpt-3.5-turbo';
  
  @Trace
  systemPrompt: string = '你是一个专业的 Markdown 写作助手，擅长解答 Markdown 语法问题、提供写作建议和生成各种 Markdown 模板。请用简洁清晰的中文回答用户问题。';
  
  @Trace
  enabled: boolean = false;

  constructor() {}

  /**
   * 检查配置是否完整
   */
  static isConfigValid(cfg: AIConfigClass): boolean {
    return cfg.apiUrl.length > 0 && cfg.apiKey.length > 0;
  }
}

/**
 * AI 配置工具类
 */
export class AIConfig {
  private static config: AIConfigClass | undefined;

  /**
   * 从本地存储加载配置
   */
  static async load(context: common.UIAbilityContext): Promise<AIConfigClass> {
    const cfg = new AIConfigClass();
    cfg.apiUrl = await PreferencesUtil.getAIConfigApiUrl(context);
    cfg.apiKey = await PreferencesUtil.getAIConfigApiKey(context);
    cfg.model = await PreferencesUtil.getAIConfigModel(context);
    cfg.systemPrompt = await PreferencesUtil.getAIConfigSystemPrompt(context);
    cfg.enabled = await PreferencesUtil.getAIConfigEnabled(context);
    AIConfig.config = cfg;
    return cfg;
  }

  /**
   * 保存配置到本地存储
   */
  static async save(context: common.UIAbilityContext, cfg: AIConfigClass): Promise<void> {
    AIConfig.config = cfg;
    await PreferencesUtil.saveAIConfigApiUrl(context, cfg.apiUrl);
    await PreferencesUtil.saveAIConfigApiKey(context, cfg.apiKey);
    await PreferencesUtil.saveAIConfigModel(context, cfg.model);
    await PreferencesUtil.saveAIConfigSystemPrompt(context, cfg.systemPrompt);
    await PreferencesUtil.saveAIConfigEnabled(context, cfg.enabled);
  }

  /**
   * 获取当前配置
   */
  static getConfig(): AIConfigClass {
    if (AIConfig.config === undefined) {
      AIConfig.config = new AIConfigClass();
    }
    return AIConfig.config;
  }

  /**
   * 检查配置是否完整
   */
  static isConfigValid(cfg: AIConfigClass): boolean {
    return cfg.apiUrl.length > 0 && cfg.apiKey.length > 0;
  }
}