import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/utils.dart';

/// 帖子正文 HTML 渲染。
///
/// 特殊处理：
/// - 楼层引用（PostMention）渲染为「回复图标 + 昵称」，点击跳转到对应楼层；
/// - 普通链接、图片等按默认行为处理。
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
      customRender: {
        // 楼层引用：回复图标 + 昵称，点击跳转到对应楼层。
        'a': (RenderContext context, Widget parsedChild) {
          final tree = context.tree;
          if (!tree.elementClasses.contains('PostMention')) return null;

          final href = tree.attributes['href'] ?? '';
          final name = (tree.element?.text ?? '').trim();

          return WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: _PostMentionInline(
              name: name.isNotEmpty ? name : '原回复',
              color: scheme.primary,
              onTap: () {
                final m = _floorRe.firstMatch(href);
                if (m == null) return;
                final dId = m.group(1) ?? '';
                final num = int.tryParse(m.group(2) ?? '') ?? 0;
                if (dId.isNotEmpty) onFloorLink?.call(dId, num);
              },
            ),
          );
        },
      },
      style: {
        'body': Style(
          margin: EdgeInsets.zero,
          padding: EdgeInsets.zero,
          fontSize: const FontSize(15),
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
        'h1': Style(fontSize: const FontSize(22), fontWeight: FontWeight.bold),
        'h2': Style(fontSize: const FontSize(20), fontWeight: FontWeight.bold),
        'h3': Style(fontSize: const FontSize(18), fontWeight: FontWeight.bold),
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

/// 楼层引用的内联样式：回复图标 + 昵称。
class _PostMentionInline extends StatelessWidget {
  const _PostMentionInline({
    Key? key,
    required this.name,
    required this.color,
    required this.onTap,
  }) : super(key: key);

  final String name;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.reply, size: 15, color: color),
          const SizedBox(width: 4),
          Text(
            name,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
