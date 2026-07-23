import { fileIo as fs, picker } from '@kit.CoreFileKit';
import { marked } from '@lidary/markdown';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { util } from '@kit.ArkTS';

export type ExportFormat = 'md' | 'html' | 'txt' | 'pdf';

/**
 * 笔记导出服务
 * 支持 md(原文)/ html(带样式 + 内嵌 KaTeX 公式渲染)/ txt(去格式纯文本)
 */
export class ExportService {
  /**
   * 导出当前内容为指定格式,弹保存对话框让用户选路径
   * @returns true=成功 false=用户取消
   */
  static async export(context: common.UIAbilityContext, content: string, format: ExportFormat, defaultName: string): Promise<boolean> {
    let ext: string;
    let output: string;
    if (format === 'md') {
      ext = 'md';
      output = content;
    } else if (format === 'html' || format === 'pdf') {
      // PDF 在端上无法直接生成,降级导出 HTML(用户用浏览器 Ctrl+P 转 PDF)
      ext = 'html';
      output = await ExportService.toHtml(context, content);
    } else {
      ext = 'txt';
      output = ExportService.toText(content);
    }

    // 弹保存对话框
    const savePicker = new picker.DocumentViewPicker();
    const options = new picker.DocumentSaveOptions();
    const safeName: string = (defaultName || 'note').replace(/[/\\:*?"<>|]/g, '_').substring(0, 50) || 'note';
    options.newFileNames = [`${safeName}.${ext}`];
    const result: string[] = await savePicker.save(options);
    if (!result || result.length === 0) {
      return false;
    }

    const uri: string = result[0];
    const file = fs.openSync(uri, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
    fs.writeSync(file.fd, output);
    fs.closeSync(file);
    return true;
  }

  /**
   * md -> 完整 HTML 文档
   * KaTeX 的 CSS/JS 从 rawfile 读取后内联,公式渲染不依赖网络(JS+CSS 离线可用);
   * 字体文件走 CDN(体积大,离线时降级为系统字体,公式仍可渲染)
   */
  static async toHtml(context: common.UIAbilityContext, md: string): Promise<string> {
    let body: string;
    try {
      body = marked(md) as string;
    } catch (e) {
      body = `<pre>${md.replace(/</g, '&lt;')}</pre>`;
    }

    const katexCss: string = await ExportService.readRawFile(context, 'katex/katex.min.css');
    const katexJs: string = await ExportService.readRawFile(context, 'katex/katex.min.js');
    const autoRenderJs: string = await ExportService.readRawFile(context, 'katex/auto-render.min.js');

    // CSS 里字体相对路径 fonts/ 改成 CDN 绝对路径(字体不内联,避免 HTML 过大)
    const cssInlined: string = katexCss.replace(/url\((["']?)fonts\//g, 'url($1https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/fonts/');

    const styleBlock: string = cssInlined ? `<style>${cssInlined}</style>` : '';
    const scriptBlock: string = (katexJs && autoRenderJs)
      ? `<script>${katexJs}</script>\n<script>${autoRenderJs}</script>\n<script>renderMathInElement(document.body,{delimiters:[{left:'$$',right:'$$',display:true},{left:'$',right:'$',display:false}],throwOnError:false});</script>`
      : '';

    return `<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Exported Note</title>
${styleBlock}
<style>
body { font-family: "HarmonyOS Sans", -apple-system, sans-serif; max-width: 800px; margin: 40px auto; padding: 0 20px; line-height: 1.7; color: #333; }
h1, h2, h3, h4, h5, h6 { color: #0A59F7; margin-top: 1.4em; }
h1 { font-size: 1.8em; border-bottom: 2px solid #eef; padding-bottom: 0.3em; }
h2 { font-size: 1.5em; border-bottom: 1px solid #eef; padding-bottom: 0.3em; }
pre { background: #f5f7f9; padding: 14px; border-radius: 8px; overflow-x: auto; }
code { background: #f5f7f9; padding: 2px 6px; border-radius: 4px; font-family: "JetBrains Mono", "Cascadia Code", monospace; font-size: 0.9em; }
pre code { background: none; padding: 0; }
table { border-collapse: collapse; width: 100%; margin: 1em 0; }
th, td { border: 1px solid #ddd; padding: 8px 12px; }
th { background: #f5f7f9; }
blockquote { border-left: 4px solid #0A59F7; margin: 1em 0; padding: 4px 16px; color: #666; background: #f8faff; }
img { max-width: 100%; }
a { color: #0A59F7; }
hr { border: none; border-top: 1px solid #eee; margin: 2em 0; }
</style>
</head>
<body>
${body}
${scriptBlock}
</body>
</html>`;
  }

  /**
   * md -> 纯文本(去掉 md 语法符号)
   */
  static toText(md: string): string {
    return md
      // 图片:保留 alt 文本
      .replace(/!\[([^\]]*)\]\([^)]+\)/g, '$1')
      // 链接:保留文本
      .replace(/\[([^\]]+)\]\([^)]+\)/g, '$1')
      // 代码块:去掉 ``` 围栏,保留内容
      .replace(/```[a-zA-Z]*\n?/g, '')
      .replace(/```/g, '')
      // 行内代码:去掉反引号
      .replace(/`([^`]+)`/g, '$1')
      // 粗体斜体
      .replace(/\*\*([^*]+)\*\*/g, '$1')
      .replace(/__([^_]+)__/g, '$1')
      .replace(/\*([^*]+)\*/g, '$1')
      .replace(/_([^_]+)_/g, '$1')
      // 删除线
      .replace(/~~([^~]+)~~/g, '$1')
      // 标题井号
      .replace(/^#{1,6}\s*/gm, '')
      // 引用符
      .replace(/^>\s*/gm, '')
      // 无序列表符号
      .replace(/^[-*+]\s+/gm, '• ')
      // 有序列表保留数字
      .replace(/^(\d+)\.\s+/gm, '$1. ')
      // 分隔线
      .replace(/^---+$/gm, '-----------')
      // 多余空行压缩
      .replace(/\n{3,}/g, '\n\n')
      .trim();
  }

  /**
   * 读取 rawfile 文本内容
   */
  private static readRawFile(context: common.UIAbilityContext, path: string): Promise<string> {
    return new Promise<string>((resolve: (s: string) => void) => {
      try {
        context.resourceManager.getRawFileContent(path, (err: BusinessError, value: Uint8Array) => {
          if (err || !value || value.length === 0) {
            resolve('');
            return;
          }
          resolve(util.TextDecoder.create('utf-8').decodeWithStream(value));
        });
      } catch (e) {
        resolve('');
      }
    });
  }
}
