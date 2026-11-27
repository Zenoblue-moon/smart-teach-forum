import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/utils.dart';

/// 帖子正文 HTML 渲染。
class HtmlContent extends StatelessWidget {
  const HtmlContent({
    Key? key,
    required this.html,
    this.onImageTap,
    this.onFloorLink,
    this.onUserLink,
  }) : super(key: key);

  final String html;
  final void Function(List<String> urls, int index)? onImageTap;
  final void Function(String discussionId, int postNumber)? onFloorLink;
  final void Function(String username)? onUserLink;

  static final RegExp _floorRe = RegExp(r'/d/(\d+)(?:/(\d+))?');
  static final RegExp _userRe = RegExp(r'/u/([^/?#]+)');

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Html(
      data: resolveHtmlAssets(html),
      onLinkTap: (url, ctx, attributes, element) {
        _handleLink(url);
      },
      onImageTap: (src, ctx, attributes, element) {
        final urls = extractImageUrls(html);
        var idx = urls.indexOf(resolveAssetUrl(src));
        if (idx < 0) idx = 0;
        onImageTap?.call(urls, idx);
      },
      style: {
        'body': Style(
          margin: EdgeInsets.zero,
          padding: EdgeInsets.zero,
          fontSize: FontSize(15),
          lineHeight: const LineHeight(1.6),
          color: scheme.onSurface,
        ),
        'p': Style(margin: const EdgeInsets.symmetric(vertical: 4)),
        'a': Style(color: scheme.primary, textDecoration: TextDecoration.none),
        'blockquote': Style(
          backgroundColor: scheme.primary.withOpacity(0.06),
          border: Border(
            left: BorderSide(color: scheme.primary.withOpacity(0.5), width: 3),
          ),
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        'code': Style(
          backgroundColor: scheme.onSurface.withOpacity(0.08),
          fontFamily: 'monospace',
        ),
        'pre': Style(
          backgroundColor: scheme.onSurface.withOpacity(0.08),
          padding: const EdgeInsets.all(10),
          margin: const EdgeInsets.symmetric(vertical: 8),
        ),
        'img': Style(margin: const EdgeInsets.symmetric(vertical: 6)),
        'ul': Style(margin: const EdgeInsets.only(left: 18, top: 4, bottom: 8)),
        'ol': Style(margin: const EdgeInsets.only(left: 18, top: 4, bottom: 8)),
        'h1': Style(fontSize: FontSize(22), fontWeight: FontWeight.bold),
        'h2': Style(fontSize: FontSize(20), fontWeight: FontWeight.bold),
        'h3': Style(fontSize: FontSize(18), fontWeight: FontWeight.bold),
      },
    );
  }

  void _handleLink(String? url) async {
    if (url == null || url.isEmpty) return;

    // 楼层引用跳转
    final floor = _floorRe.firstMatch(url);
    if (floor != null) {
      final dId = floor.group(1) ?? '';
      final num = int.tryParse(floor.group(2) ?? '') ?? 0;
      if (dId.isNotEmpty) {
        onFloorLink?.call(dId, num);
        return;
      }
    }

    // 用户主页跳转
    final user = _userRe.firstMatch(url);
    if (user != null) {
      final uname = user.group(1) ?? '';
      if (uname.isNotEmpty) {
        onUserLink?.call(uname);
        return;
      }
    }

    // 外部链接
    final uri = Uri.tryParse(url);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
  }
}
