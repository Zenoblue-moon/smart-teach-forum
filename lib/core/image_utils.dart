import 'package:image/image.dart' as img;

/// 图片压缩工具：确保上传的图片不超过论坛大小限制。
class ImageUtils {
  ImageUtils._();

  /// 上传大小安全阈值（1.2MB）。论坛对超大文件会在 PHP 层直接丢弃并提示
  /// 「请上传小于 xx KB 的文件」，因此这里强制压缩到阈值以内。
  static const int maxUploadBytes = 1200 * 1024;

  /// 压缩图片。
  ///
  /// 若 [bytes] 未超过 [maxBytes]，原样返回；否则解码后按最长边缩放到
  /// 1440px 并重新编码为 JPEG，逐步降质直到满足阈值。
  static List<int> compress(List<int> bytes, {int maxBytes = maxUploadBytes}) {
    if (bytes.length <= maxBytes) return bytes;

    try {
      img.Image? decoded = img.decodeImage(bytes);
      if (decoded == null) return bytes;

      if (decoded.width > 1440 || decoded.height > 1440) {
        decoded = img.copyResize(
          decoded,
          width: decoded.width >= decoded.height ? 1440 : null,
          height: decoded.height > decoded.width ? 1440 : null,
        );
      }

      for (final quality in const [85, 75, 65, 55, 45]) {
        final jpg = img.encodeJpg(decoded, quality: quality);
        if (jpg.length <= maxBytes) return jpg;
      }
      return img.encodeJpg(decoded, quality: 35);
    } catch (_) {
      return bytes;
    }
  }

  /// 把文件名后缀改为 .jpg（压缩后内容已是 JPEG 时使用，避免 MIME 不一致）。
  static String toJpgName(String filename) {
    final dot = filename.lastIndexOf('.');
    final base = dot > 0 ? filename.substring(0, dot) : filename;
    return '$base.jpg';
  }
}
