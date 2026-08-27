/**
 * @Author : lcc
 * @CreateData : 2024/7/7
 * @Description:
 */
import { LatexMathColorFormat, latexStringToImage } from '@cangjie-tpc/formula_hybrid';
import { promptAction } from '@kit.ArkUI';
import { BusinessError, pasteboard } from '@kit.BasicServicesKit';
import { Marked, MarkedOptions, Token, TokenizerExtension } from './core';
import { image } from '@kit.ImageKit';
import { latexBlock, latexInline } from './core/plugins/latex';
import { superscriptExtension, subscriptExtension } from './extensions';


/**
 * 清理实体字符
 * @param content
 * @returns
 */
export function clearMarkdown(content: string) {
  return content.replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', '""')
}

/**
 * 判断字符串的第一个字符是否为数字
 * @param str 要检查的字符串
 * @returns 如果第一个字符是数字，则返回 true；否则返回 false
 */
export function isFirstCharDigit(str: string): boolean {
  if (str.length === 0) {
    return false;
  }
  return /^\d/.test(str.charAt(0));
}

function buildMarkedInstance(markedOptions?: MarkedOptions, markedExtensions?: TokenizerExtension[]): Marked {
  const marked = new Marked()
  let extensions = markedExtensions ?? []
  extensions.push(latexBlock(), latexInline(), superscriptExtension, subscriptExtension)
  marked.setOptions(markedOptions)
  marked.use({ extensions: extensions })
  return marked
}

/**
 * 主线程同步解析入口：供含函数成员的 options/extensions 使用
 * （taskpool 参数必须可序列化，函数无法跨线程传递，此时只能回退主线程解析）。
 */
export function parseMarkdownSync(content: string, markedOptions?: MarkedOptions,
  markedExtensions?: TokenizerExtension[]): Token[] {
  if (!content) {
    return []
  }
  return buildMarkedInstance(markedOptions, markedExtensions).lexer(content)
}

/**
 * taskpool 子线程解析入口。
 * 注意：@Concurrent 函数只能引用导入变量和局部变量，不能调用同文件的
 * parseMarkdownSync/buildMarkedInstance，因此此处必须内联解析逻辑
 * （与 parseMarkdownSync 保持一致，改动时需同步两处）。
 */
@Concurrent
export function parseMarkdown(content: string, markedOptions?: MarkedOptions, markedExtensions?: TokenizerExtension[]): Token[] {
  const marked = new Marked()
  let extensions = markedExtensions ?? []
  extensions.push(latexBlock(), latexInline(), superscriptExtension, subscriptExtension)
  marked.setOptions(markedOptions)
  marked.use({ extensions: extensions })

  if (content) {
    return marked.lexer(content)
  }
  return []
}

/**
 * 深度检测配置对象中是否含函数成员（限制层数防循环引用）。
 * 用于决定 Markdown 解析能否走 taskpool 子线程。
 */
export function hasFunctionMember(value: Object | undefined | null, depth: number = 0): boolean {
  if (value === undefined || value === null || depth > 5) {
    return false
  }
  const valueType = typeof value
  if (valueType === 'function') {
    return true
  }
  if (valueType !== 'object') {
    return false
  }
  if (value instanceof Array) {
    const arr = value as Array<Object>
    for (let i = 0; i < arr.length; i++) {
      if (hasFunctionMember(arr[i], depth + 1)) {
        return true
      }
    }
    return false
  }
  const record = value as Record<string, Object>
  const keys = Object.keys(record)
  for (let i = 0; i < keys.length; i++) {
    if (hasFunctionMember(record[keys[i]], depth + 1)) {
      return true
    }
  }
  return false
}

export function textAlign(align?: 'center' | 'left' | 'right' | null) {
  if (align === 'left') {
    return TextAlign.Start
  }
  if (align === 'right') {
    return TextAlign.End
  }
  return TextAlign.Center
}


export async function copyToPasteboard(text?: string) {
  if (!text) {
    return
  }
  let pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
  let systemPasteboard = pasteboard.getSystemPasteboard();
  await systemPasteboard.setData(pasteData).then((data) => {
    // 使用新的Toast API
    promptAction.showToast({
      message: '复制成功',
      duration: 2000
    });
  }).catch((err: BusinessError) => {
    // 使用新的Toast API
    promptAction.showToast({
      message: '复制异常' + err.message,
      duration: 2000
    });
  });
}

// LaTeX 公式渲染结果缓存：编辑器实时预览每键全量重渲染，
// 相同公式反复生成 PixelMap 既慢又持续累积 native 内存，这里按
// (公式文本, 字号, 前景, 背景) 缓存。超上限时淘汰最旧条目并释放其 PixelMap。
const latexPixelMapCache: Map<string, LatexToPixelMap> = new Map()
const LATEX_PIXEL_MAP_CACHE_MAX = 200

export function clearLatexPixelMapCache() {
  latexPixelMapCache.forEach((v: LatexToPixelMap) => {
    try {
      v.pixelMap.release()
    } catch (_) {
    }
  })
  latexPixelMapCache.clear()
}

export async function latexToPixelMap(latexText: string, latexMathTextSize: number, latexMathTextColor: number,
  latexMathBackGroupColor: number): Promise<LatexToPixelMap> {

  const cacheKey = `${latexText}|${latexMathTextSize}|${latexMathTextColor}|${latexMathBackGroupColor}`
  const cached = latexPixelMapCache.get(cacheKey)
  if (cached) {
    return cached
  }

  // 通过接口解析数学公式获取数学公式图片数组数据
  let buf: ArrayBuffer =
    await latexStringToImage(latexText, latexMathTextSize, latexMathTextColor, latexMathBackGroupColor,
      LatexMathColorFormat.COLOR_FORMAT_BGRA_8888)
  let imageSource = image.createImageSource(buf)
  // 图片pixelMap
  let pixelMap = imageSource.createPixelMapSync()
  // PixelMap 创建完成后即可释放 imageSource，否则 native 资源随源泄漏
  try {
    imageSource.release()
  } catch (_) {
  }
  let size: Size = pixelMap.getImageInfoSync().size
  let result: LatexToPixelMap = {
    pixelMap: pixelMap,
    width: size.width,
    height: size.height
  }
  if (latexPixelMapCache.size >= LATEX_PIXEL_MAP_CACHE_MAX) {
    // Map 保持插入序，取最早插入的键淘汰
    let oldestKey: string | undefined = undefined;
    for (const k of latexPixelMapCache.keys()) {
      oldestKey = k;
      break;
    }
    if (oldestKey !== undefined) {
      const evicted = latexPixelMapCache.get(oldestKey)
      try {
        evicted?.pixelMap.release()
      } catch (_) {
      }
      latexPixelMapCache.delete(oldestKey)
    }
  }
  latexPixelMapCache.set(cacheKey, result)
  return result
}

export interface LatexToPixelMap {
  pixelMap: image.PixelMap,
  width: number
  height: number
}

