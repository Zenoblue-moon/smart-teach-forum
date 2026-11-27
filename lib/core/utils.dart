import 'package:flutter/material.dart';

import 'config.dart';

/// 去掉 HTML 标签，得到纯文本摘要。
String stripHtml(String html) {
  if (html.isEmpty) return '';
  var text = html
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll(RegExp(r'&nbsp;'), ' ')
      .replaceAll(RegExp(r'&amp;'), '&')
      .replaceAll(RegExp(r'&lt;'), '<')
      .replaceAll(RegExp(r'&gt;'), '>')
      .replaceAll(RegExp(r'&quot;'), '"')
      .replaceAll(RegExp(r'&#39;'), "'");
  // 折叠连续换行
  text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  return text;
}

/// 截取摘要（用于列表卡片）。
String summarize(String html, {int maxLen = 120}) {
  final text = stripHtml(html);
  if (text.length <= maxLen) return text;
  return '${text.substring(0, maxLen)}…';
}

/// 相对时间（如「3 分钟前」）。
String timeAgo(String? iso, {DateTime? now}) {
  if (iso == null || iso.isEmpty) return '';
  final t = DateTime.tryParse(iso)?.toLocal();
  if (t == null) return '';
  final n = now ?? DateTime.now();
  final diff = n.difference(t);
  if (diff.inSeconds < 60) return '刚刚';
  if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
  if (diff.inHours < 24) return '${diff.inHours} 小时前';
  if (diff.inDays < 30) return '${diff.inDays} 天前';
  if (diff.inDays < 365) return '${(diff.inDays / 30).floor()} 个月前';
  return '${(diff.inDays / 365).floor()} 年前';
}

/// 完整时间（如「2026-11-26 17:30」）。
String formatDateTime(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final t = DateTime.tryParse(iso)?.toLocal();
  if (t == null) return '';
  String two(int v) => v.toString().padLeft(2, '0');
  return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
}

/// 十六进制颜色字符串转 Color（带透明度）。
Color colorFromHex(String? hex, {Color fallback = const Color(0xFF26A03D)}) {
  if (hex == null || hex.isEmpty) return fallback;
  var h = hex.replaceAll('#', '').trim();
  if (h.length == 3) h = h.split('').map((c) => '$c$c').join();
  if (h.length == 6) h = 'FF$h';
  if (h.length == 8) {
    final v = int.tryParse(h, radix: 16);
    if (v != null) return Color(v);
  }
  return fallback;
}

/// 处理头像相对路径。
String resolveAssetUrl(String? url) {
  if (url == null || url.isEmpty) return '';
  if (url.startsWith('http://') || url.startsWith('https://')) return url;
  if (url.startsWith('//')) return 'https:$url';
  return '${AppConfig.baseUrl}$url';
}

/// 处理正文 HTML 中的图片相对路径，转绝对路径。
String resolveHtmlAssets(String html) {
  return html
      .replaceAllMapped(
        RegExp(r'src="(/[^"]+)"', caseSensitive: false),
        (m) => 'src="${AppConfig.baseUrl}${m.group(1)}"',
      )
      .replaceAllMapped(
        RegExp(r'href="(/[^"]+)"', caseSensitive: false),
        (m) => 'href="${AppConfig.baseUrl}${m.group(1)}"',
      );
}

/// 提取正文中的图片地址列表（用于全屏预览）。
List<String> extractImageUrls(String html) {
  final urls = <String>[];
  final re = RegExp(r'<img[^>]+src="([^"]+)"', caseSensitive: false);
  for (final m in re.allMatches(html)) {
    urls.add(resolveAssetUrl(m.group(1)));
  }
  return urls;
}
