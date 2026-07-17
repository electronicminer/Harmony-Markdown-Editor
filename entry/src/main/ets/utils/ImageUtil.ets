import { picker, fileIo as fs } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { util } from '@kit.ArkTS';

/**
 * 图片处理工具
 * 用于 AI 多模态输入:选图 -> 等比压缩 -> JPEG -> base64 data URL,发送给 vision 大模型
 */

/**
 * 通过系统文件选择器选择一张图片,等比压缩后转为 JPEG base64 data URL。
 *
 * 说明:用 DocumentViewPicker(非 deprecated)选图。其返回的 file://docs/... URI
 * 不能直接交给 image.createImageSource(uri),需先 fs.openSync 拿 fd 再传入,
 * 这与项目 Index.ets 的 loadUri 读取方式一致。
 * 用户取消(返回空)返回 null;其他异常向上抛出,由调用方提示。
 *
 * @param maxLongEdge 长边最大像素,默认 1600(兼顾清晰度与 token 成本)
 * @param quality JPEG 质量 0-100,默认 80
 * @returns data URL(data:image/jpeg;base64,...);用户取消返回 null;失败抛异常
 */
export async function pickImageAsDataUrl(maxLongEdge: number = 1600, quality: number = 80): Promise<string | null> {
  const documentViewPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker();
  const options: picker.DocumentSelectOptions = new picker.DocumentSelectOptions();
  options.maxSelectNumber = 1;
  options.fileSuffixFilters = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp'];

  const uris: string[] = await documentViewPicker.select(options);
  if (!uris || uris.length === 0) {
    return null; // 用户取消
  }
  const uri: string = uris[0];

  let file: fs.File | undefined;
  let imageSource: image.ImageSource | undefined;
  let pixelMap: image.PixelMap | undefined;
  let packer: image.ImagePacker | undefined;
  try {
    // DocumentViewPicker 返回的 URI 需先打开为 fd,再交给 createImageSource
    file = fs.openSync(uri, fs.OpenMode.READ_ONLY);
    imageSource = image.createImageSource(file.fd);

    const imageInfo: image.ImageInfo = await imageSource.getImageInfo();
    const originW: number = imageInfo.size.width;
    const originH: number = imageInfo.size.height;

    // 等比缩放:长边不超过 maxLongEdge,小图不放大
    const longEdge: number = Math.max(originW, originH);
    let targetW: number = originW;
    let targetH: number = originH;
    if (longEdge > maxLongEdge) {
      const scale: number = maxLongEdge / longEdge;
      targetW = Math.round(originW * scale);
      targetH = Math.round(originH * scale);
    }

    const desiredSize: image.Size = { width: targetW, height: targetH };
    pixelMap = await imageSource.createPixelMap({ desiredSize: desiredSize });

    packer = image.createImagePacker();
    const packingOption: image.PackingOption = { format: 'image/jpeg', quality: quality };
    const buffer: ArrayBuffer = await packer.packing(pixelMap, packingOption);

    const base64Helper: util.Base64Helper = new util.Base64Helper();
    const base64Str: string = base64Helper.encodeToStringSync(new Uint8Array(buffer));

    return `data:image/jpeg;base64,${base64Str}`;
  } finally {
    // 任何路径都释放资源,避免句柄泄漏
    if (packer) {
      try { packer.release(); } catch {}
    }
    if (pixelMap) {
      try { pixelMap.release(); } catch {}
    }
    if (imageSource) {
      try { imageSource.release(); } catch {}
    }
    if (file) {
      try { fs.closeSync(file); } catch {}
    }
  }
}
