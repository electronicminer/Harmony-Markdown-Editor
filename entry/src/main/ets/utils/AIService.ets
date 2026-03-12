import { http } from '@kit.NetworkKit';
import { AIConfigClass } from './AIConfig';

/**
 * 聊天消息类型
 */
export interface ChatMessage {
  role: 'system' | 'user' | 'assistant';
  content: string;
}

/**
 * AI 支持的操作类型
 */
export type AgentActionType = 'replace_content' | 'append_content' | 'insert_content' | 'delete_content';

/**
 * AI 操作的具体指令
 */
export interface AgentPlan {
  action: AgentActionType;
  targetContent?: string;      // 要替换或删除的目标文本内容（精准匹配）
  replacementContent?: string; // 替换后的文本内容（用于 replace 或 insert）
  description: string;         // 给用户的简要解释，说明此操作的效果
}

/**
 * AI 响应结果
 */
export interface AIResponse {
  success: boolean;
  content?: string;
  plan?: AgentPlan;
  error?: string;
}

/**
 * 请求体类型
 */
interface ChatRequestBody {
  model: string;
  messages: ChatMessage[];
  temperature: number;
  max_tokens: number;
}

/**
 * API 响应数据结构
 */
interface APIResponseData {
  choices?: APIChoice[];
  error?: APIError;
}

interface APIChoice {
  message?: APIMessage;
}

interface APIMessage {
  content?: string;
}

interface APIError {
  message?: string;
}

/**
 * AI 服务类
 * 调用 OpenAI 兼容格式的 API
 */
export class AIService {
  private static readonly REQUEST_TIMEOUT: number = 60000;

  /**
   * 发送聊天请求到 AI API
   * @param config AI 配置
   * @param messages 消息历史
   * @param currentContent 当前编辑器里的文档内容（可选，附加在系统提示中）
   * @returns AI 响应结果
   */
  static async chat(config: AIConfigClass, messages: ChatMessage[], currentContent?: string): Promise<AIResponse> {
    try {
      if (!config.apiUrl || !config.apiKey) {
        return {
          success: false,
          error: 'API 配置不完整，请先设置 API URL 和 API Key'
        };
      }

      let injectedSystemPrompt = config.systemPrompt;
      // 动态注入增强的 Agent 提示词
      injectedSystemPrompt += `
      
[IMPORTANT INSTRUCTIONS FOR AI AGENT]
You have the ability to modify the user's document directly. 
When the user asks you to modify, delete, replace, or insert text, you MUST respond in JSON format ONLY, matching this schema:
\`\`\`json
{
  "reply": "A brief explanation of what you are doing. E.g., 'I will delete the specific text for you.'",
  "plan": {
    "action": "replace_content" | "append_content" | "insert_content" | "delete_content",
    "targetContent": "The exact original text to find and modify. (Required for replace_content and delete_content)",
    "replacementContent": "The new text. (Required for replace_content, append_content, and insert_content)",
    "description": "Short summary of the action."
  }
}
\`\`\`
CRITICAL ACTION RULES:
- 'replace_content': Use this to modify existing text OR to insert text at a specific semantic location (e.g., "after the title", "before the conclusion"). To insert at a specific location, set targetContent to the existing anchor text, and set replacementContent to (anchor text + new text) or (new text + anchor text). This ensures the text goes exactly where the user wants.
- 'insert_content': Use this ONLY when the user explicitly wants to insert text at their current cursor position.
- 'append_content': Use this ONLY when inserting at the very end of the entire document.
- 'delete_content': Use this to delete specific text.

If the user's request is just a normal question, you can reply normally in markdown text format. But if they instruct you to change the text, you must return JSON.`;

      if (currentContent) {
        injectedSystemPrompt += `\n\n[CURRENT DOCUMENT CONTENT]\n${currentContent}`;
      }

      const systemMsg: ChatMessage = { role: 'system', content: injectedSystemPrompt };
      const allMessages: ChatMessage[] = [systemMsg, ...messages];

      const requestBody: ChatRequestBody = {
        model: config.model,
        messages: allMessages,
        temperature: 0.7,
        max_tokens: 2000
      };

      const httpRequest = http.createHttp();
      
      const response = await httpRequest.request(
        config.apiUrl,
        {
          method: http.RequestMethod.POST,
          header: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${config.apiKey}`
          },
          extraData: JSON.stringify(requestBody),
          connectTimeout: AIService.REQUEST_TIMEOUT,
          readTimeout: AIService.REQUEST_TIMEOUT
        }
      );

      httpRequest.destroy();

      if (response.responseCode === 200) {
        const resultStr: string = response.result as string;
        const resultObj: APIResponseData = JSON.parse(resultStr);
        let content: string | undefined = resultObj.choices?.[0]?.message?.content;
        
        if (content) {
          let plan: AgentPlan | undefined = undefined;
          let replyContent = content;
          
          try {
            // 尝试解析是否是 JSON 格式的指令
            // 兼容可能带有 Markdown 代码块包裹的 JSON
            let jsonStr = content.trim();
            if (jsonStr.startsWith('\`\`\`json') && jsonStr.endsWith('\`\`\`')) {
              jsonStr = jsonStr.substring(7, jsonStr.length - 3).trim();
            } else if (jsonStr.startsWith('\`\`\`') && jsonStr.endsWith('\`\`\`')) {
              jsonStr = jsonStr.substring(3, jsonStr.length - 3).trim();
            }
            
            interface AgentResponseJSON {
              reply?: string;
              plan?: AgentPlan;
            }
            
            const parsed = JSON.parse(jsonStr) as AgentResponseJSON;
            if (parsed && parsed.reply) {
               replyContent = parsed.reply;
               if (parsed.plan && parsed.plan.action) {
                 plan = parsed.plan;
               }
            }
          } catch (e) {
            // 解析失败说明只是普通的文本回答，保持原有逻辑
            console.log("Response is not JSON, treating as raw string.");
          }

          return {
            success: true,
            content: replyContent,
            plan: plan
          };
        } else {
          return {
            success: false,
            error: 'AI 返回数据格式异常'
          };
        }
      } else {
        let errorMessage: string = `HTTP 错误：${response.responseCode}`;
        try {
          const errorStr: string = response.result as string;
          const errorData: APIResponseData = JSON.parse(errorStr);
          if (errorData.error?.message) {
            errorMessage = errorData.error.message;
          }
        } catch (e) {
          // 忽略解析错误
        }
        return {
          success: false,
          error: errorMessage
        };
      }
    } catch (e) {
      console.error('AIService chat error:', e);
      return {
        success: false,
        error: `请求失败：${e instanceof Error ? e.message : '未知错误'}`
      };
    }
  }

  /**
   * 测试 API 连接
   */
  static async testConnection(config: AIConfigClass): Promise<AIResponse> {
    const testMessages: ChatMessage[] = [
      { role: 'user', content: '你好，请用一句话介绍你自己。' }
    ];
    return await AIService.chat(config, testMessages);
  }
}