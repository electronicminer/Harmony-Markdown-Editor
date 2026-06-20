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
 * 新版语义化定位操作；保留旧值以兼容历史响应。
 */
export type AgentActionType =
  | 'replace' | 'insert_before' | 'insert_after' | 'append' | 'prepend' | 'delete'
  // —— 兼容旧版 ——
  | 'replace_content' | 'append_content' | 'insert_content' | 'delete_content';

/**
 * 单个操作步骤
 */
export interface AgentStep {
  action: AgentActionType;
  startLine?: number;     // 起始行号（1-based，含）；行号定位优先
  endLine?: number;       // 结束行号（1-based，含）；省略时等于 startLine
  anchor?: string;        // 兜底定位文本（行号失效时使用）
  endAnchor?: string;     // 兜底：区间结束锚点
  occurrence?: number;    // 锚点第几次出现，1-based，默认 1
  content?: string;       // 新文本
  note?: string;          // 该步的简短说明
}

/**
 * AI 操作计划：一次回复可包含多个顺序执行的步骤
 */
export interface AgentPlan {
  description: string;         // 整体说明
  steps: AgentStep[];          // 操作序列
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
 * 模型返回的原始 plan（可能是新版 steps 或旧版单 action）
 */
interface RawPlanJSON {
  action?: string;
  targetContent?: string;
  replacementContent?: string;
  description?: string;
  steps?: AgentStep[];
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
You can directly edit the user's document. When the user asks you to modify, add, delete, replace, or restructure text, you MUST respond in JSON format ONLY, matching this schema:
\`\`\`json
{
  "reply": "A brief explanation of what you will do.",
  "plan": {
    "description": "Overall summary of all changes.",
    "steps": [
      {
        "action": "replace" | "insert_before" | "insert_after" | "append" | "prepend" | "delete",
        "startLine": 5,
        "endLine": 8,
        "anchor": "Optional fallback text used to locate the edit if line numbers drift.",
        "content": "The new text to write.",
        "note": "Short description of this single step."
      }
    ]
  }
}
\`\`\`
ACTION SEMANTICS (steps run in order):
- "replace": replace lines startLine..endLine with 'content'. (startLine + content required; endLine defaults to startLine)
- "insert_after": insert 'content' as new line(s) right after line startLine. (startLine + content required)
- "insert_before": insert 'content' as new line(s) right before line startLine. (startLine + content required)
- "delete": delete lines startLine..endLine. (startLine required; endLine defaults to startLine)
- "append": add 'content' at the very end of the document. (content required, no line numbers)
- "prepend": add 'content' at the very beginning of the document. (content required, no line numbers)

LOCATING EDITS — READ CAREFULLY:
- The document below is shown with line numbers in the form "  12→ text". These numbers are NOT part of the document; use them ONLY to locate edits.
- ALWAYS prefer line numbers (startLine / endLine, 1-based, inclusive). To act on a single line, set startLine = endLine (or omit endLine).
- To delete or replace a WHOLE SECTION (a heading and everything under it), set startLine to the heading's line and endLine to the last line of that section (the line just before the next heading, or the document's last line).
- DO NOT copy long blocks of text. 'anchor' is only an optional safety fallback — a SHORT distinctive snippet from startLine; never paste whole paragraphs.
- You may return MULTIPLE steps. Use real newline characters inside 'content'.

If the user's request is just a normal question (not a document edit), reply normally in plain markdown text WITHOUT any JSON.`;

      if (currentContent) {
        // 文档按行加行号注入，供模型用行号精准定位
        const maxContentLen = 12000;
        const clipped = currentContent.length > maxContentLen
          ? currentContent.substring(0, maxContentLen)
          : currentContent;
        const lines = clipped.split('\n');
        const numbered = lines.map((line: string, i: number): string => {
          const ln = (i + 1).toString().padStart(4, ' ');
          return `${ln}→ ${line}`;
        }).join('\n');
        const note = currentContent.length > maxContentLen ? '\n...(内容已截断)' : '';
        injectedSystemPrompt += `\n\n[CURRENT DOCUMENT CONTENT — line numbers are for reference only, not part of the text]\n${numbered}${note}`;
      }

      const systemMsg: ChatMessage = { role: 'system', content: injectedSystemPrompt };

      // 在最后一条用户消息前再注入一条强提醒，防止多轮对话后模型「忘记」用 JSON 指令格式
      const reminder: ChatMessage = {
        role: 'system',
        content: 'REMINDER: If the latest user message asks to edit/add/delete/replace/restructure the document in ANY way, you MUST reply with ONLY the JSON {"reply":...,"plan":{...}} described above — never plain prose. This applies on every turn regardless of earlier replies. Only pure questions get plain text.'
      };

      // 找到最后一条 user 消息的位置，把 reminder 插在它前面
      let lastUserIdx = -1;
      for (let i = messages.length - 1; i >= 0; i--) {
        if (messages[i].role === 'user') {
          lastUserIdx = i;
          break;
        }
      }
      let allMessages: ChatMessage[];
      if (lastUserIdx >= 0) {
        allMessages = [
          systemMsg,
          ...messages.slice(0, lastUserIdx),
          reminder,
          ...messages.slice(lastUserIdx)
        ];
      } else {
        allMessages = [systemMsg, ...messages];
      }

      const requestBody: ChatRequestBody = {
        model: config.model,
        messages: allMessages,
        temperature: 0.3,
        max_tokens: 2000
      };

      const httpRequest = http.createHttp();

      let response: http.HttpResponse;
      try {
        response = await httpRequest.request(
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
      } finally {
        // #2 确保 HTTP 句柄在任何异常路径都被释放
        httpRequest.destroy();
      }

      if (response.responseCode === 200) {
        const resultStr: string = response.result as string;
        const resultObj: APIResponseData = JSON.parse(resultStr);
        let content: string | undefined = resultObj.choices?.[0]?.message?.content;
        
        if (content) {
          let plan: AgentPlan | undefined = undefined;
          let replyContent = content;
          
          try {
            // 稳健提取 JSON 指令：兼容前后带说明文字、代码块包裹等多种情况
            const jsonStr: string | undefined = AIService.extractJson(content);
            if (jsonStr) {
              interface AgentResponseJSON {
                reply?: string;
                plan?: RawPlanJSON;
              }

              const parsed = JSON.parse(jsonStr) as AgentResponseJSON;
              // 只要解析出 plan（或带 steps/action 的结构）就识别为指令
              const rawPlan: RawPlanJSON | undefined = parsed.plan;
              if (rawPlan) {
                const normalized: AgentPlan | undefined = AIService.normalizePlan(rawPlan);
                if (normalized && normalized.steps.length > 0) {
                  plan = normalized;
                  // reply 缺失时用 plan.description 兜底，避免对话框空白
                  replyContent = parsed.reply && parsed.reply.length > 0
                    ? parsed.reply
                    : (normalized.description || '已为你准备好修改，请确认执行。');
                }
              } else if (parsed.reply) {
                replyContent = parsed.reply;
              }
            }
          } catch (e) {
            // 解析失败说明只是普通的文本回答，保持原有逻辑
            console.log('Response is not JSON, treating as raw string.');
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
   * 从模型输出中稳健提取 JSON 字符串。
   * 优先取 ```json / ``` 代码块；否则取第一个能配平括号的 {...} 区间。
   * 找不到返回 undefined。
   */
  private static extractJson(content: string): string | undefined {
    const text = content.trim();

    // 1) 代码块：```json ... ``` 或 ``` ... ```
    const fenceMatch = text.match(/```(?:json)?\s*([\s\S]*?)```/);
    if (fenceMatch && fenceMatch[1]) {
      const inner = fenceMatch[1].trim();
      if (inner.startsWith('{')) {
        return inner;
      }
    }

    // 2) 第一个配平的 {...} 区间（忽略字符串内的括号）
    const start = text.indexOf('{');
    if (start === -1) {
      return undefined;
    }
    let depth = 0;
    let inStr = false;
    let escaped = false;
    for (let i = start; i < text.length; i++) {
      const ch = text.charAt(i);
      if (escaped) {
        escaped = false;
        continue;
      }
      if (ch === '\\') {
        escaped = true;
        continue;
      }
      if (ch === '"') {
        inStr = !inStr;
        continue;
      }
      if (inStr) {
        continue;
      }
      if (ch === '{') {
        depth++;
      } else if (ch === '}') {
        depth--;
        if (depth === 0) {
          return text.substring(start, i + 1);
        }
      }
    }
    return undefined;
  }

  /**
   * 把模型返回的原始 plan 规整成统一的多步结构。
   * - 新版：直接采用 steps，过滤掉缺必填字段的非法步骤。
   * - 旧版：把单 action 映射为单元素 steps（向后兼容）。
   */
  private static normalizePlan(raw: RawPlanJSON): AgentPlan | undefined {
    const description: string = raw.description ?? '';
    let steps: AgentStep[] = [];

    if (Array.isArray(raw.steps) && raw.steps.length > 0) {
      steps = raw.steps;
    } else if (raw.action) {
      // 旧版单 action 兼容映射
      const legacy: AgentStep = AIService.mapLegacyStep(raw);
      steps = [legacy];
    }

    // 过滤非法步骤
    const valid: AgentStep[] = steps.filter((s): boolean => AIService.isStepValid(s));
    if (valid.length === 0) {
      return undefined;
    }
    return { description: description, steps: valid };
  }

  /**
   * 旧版字段 -> 新版 step
   */
  private static mapLegacyStep(raw: RawPlanJSON): AgentStep {
    switch (raw.action) {
      case 'replace_content':
        return { action: 'replace', anchor: raw.targetContent, content: raw.replacementContent, note: raw.description };
      case 'delete_content':
        return { action: 'delete', anchor: raw.targetContent, note: raw.description };
      case 'append_content':
        return { action: 'append', content: raw.replacementContent, note: raw.description };
      case 'insert_content':
        // 旧版「光标处插入」无锚点，降级为追加，避免定位失败
        return { action: 'append', content: raw.replacementContent, note: raw.description };
      default:
        return { action: 'append', content: raw.replacementContent, note: raw.description };
    }
  }

  /**
   * 校验单个 step 的必填字段
   */
  private static isStepValid(s: AgentStep): boolean {
    if (!s || !s.action) {
      return false;
    }
    // 有行号即可定位
    const hasLine: boolean = typeof s.startLine === 'number' && s.startLine > 0;
    switch (s.action) {
      case 'replace':
      case 'replace_content':
        return (hasLine || !!s.anchor) && s.content !== undefined;
      case 'insert_before':
      case 'insert_after':
        return (hasLine || !!s.anchor) && s.content !== undefined;
      case 'delete':
      case 'delete_content':
        return hasLine || !!s.anchor;
      case 'append':
      case 'append_content':
      case 'prepend':
        return s.content !== undefined && s.content !== '';
      default:
        return false;
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