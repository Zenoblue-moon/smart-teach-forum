import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/services/forum_service.dart';
import '../core/utils.dart';

String _escapeHtml(String s) {
  return s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}

/// 楼层引用（PostMention）的解析结果。
class _PostMention {
  _PostMention(this.original, this.id, this.href, this.name);

  final String original;
  final String id;
  final String href;
  final String name;

  /// 仅带箭头 + 昵称（尚未拿到引用内容时的占位）。
  String get arrowOnly =>
      '<a href="$href">↩ $name</a>';

  /// 带引用内容灰框的最终形态。
  String withQuote(String quote) {
    if (quote.isEmpty) return arrowOnly;
    final q = _escapeHtml(quote);
    return '<div class="post-mention">'
        '<a href="$href">↩ $name</a>'
        '<blockquote>$q</blockquote>'
        '</div>';
  }
}

/// 帖子正文 HTML 渲染。
class HtmlContent extends StatefulWidget {
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

  @override
  State<HtmlContent> createState() => _HtmlContentState();
}

class _HtmlContentState extends State<HtmlContent> {
  static final RegExp _floorRe = RegExp(r'/d/(\d+)(?:/(\d+))?');
  static final RegExp _userRe = RegExp(r'/u/([^/?#]+)');

  /// 匹配形如 <a ... class="PostMention" ...>text</a> 的楼层引用。
  static final RegExp _postMentionTagRe = RegExp(
    r'<a\b[^>]*class="[^"]*PostMention[^"]*"[^>]*>.*?</a>',
    caseSensitive: false,
    dotAll: true,
  );

  String _processed = '';

  @override
  void initState() {
    super.initState();
    _processed = widget.html;
    _process();
  }

  @override
  void didUpdateWidget(covariant HtmlContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.html != widget.html) {
      _processed = widget.html;
      _process();
    }
  }

  Future<void> _process() async {
    final mentions = _extractPostMentions(widget.html);
    if (mentions.isEmpty) {
      if (_processed != widget.html && mounted) {
        setState(() => _processed = widget.html);
      }
      return;
    }

    // 先用箭头 + 昵称替换（同步可见）。
    var html = widget.html;
    for (final m in mentions) {
      html = html.replaceFirst(m.original, m.arrowOnly);
    }
    if (mounted) setState(() => _processed = html);

    // 异步拉取被引用楼层的正文摘要，填充灰框。
    final quotes = await Future.wait(
      mentions.map((m) => _fetchQuote(m.id)),
    );
    if (!mounted) return;
    for (var i = 0; i < mentions.length; i++) {
      html = html.replaceFirst(mentions[i].arrowOnly, mentions[i].withQuote(quotes[i]));
    }
    setState(() => _processed = html);
  }

  List<_PostMention> _extractPostMentions(String html) {
    final result = <_PostMention>[];
    for (final tag in _postMentionTagRe.allMatches(html)) {
      final full = tag.group(0)!;
      final id = _attr(full, 'data-id');
      final href = _attr(full, 'href');
      final name = _innerText(full);
      if (id.isEmpty) continue;
      result.add(_PostMention(
        full,
        id,
        href,
        name.isNotEmpty ? name : '原回复',
      ));
    }
    return result;
  }

  static String _attr(String tag, String name) {
    final m = RegExp('$name="([^"]*)"', caseSensitive: false).firstMatch(tag);
    return m?.group(1) ?? '';
  }

  static String _innerText(String tag) {
    final end = tag.lastIndexOf('</a>');
    final start = tag.indexOf('>') + 1;
    if (end < 0 || start <= 0 || start >= end) return '';
    var text = tag.substring(start, end);
    // 去掉可能存在的 @ 前缀和嵌套标签。
    text = text.replaceAll(RegExp(r'<[^>]+>'), '');
    return text.trim();
  }

  Future<String> _fetchQuote(String postId) async {
    try {
      final post = await ForumService.instance.getPost(postId);
      if (post == null) return '';
      final text = stripHtml(post.contentHtml);
      if (text.isEmpty) return '';
      return text.length > 180 ? '${text.substring(0, 180)}…' : text;
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Html(
      data: resolveHtmlAssets(_processed),
      onLinkTap: (url, ctx, attributes, element) {
        _handleLink(url);
      },
      onImageTap: (src, ctx, attributes, element) {
        final urls = extractImageUrls(_processed);
        var idx = urls.indexOf(resolveAssetUrl(src));
        if (idx < 0) idx = 0;
        widget.onImageTap?.call(urls, idx);
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
        '.post-mention': Style(
          margin: const EdgeInsets.symmetric(vertical: 4),
        ),
        '.post-mention blockquote': Style(
          backgroundColor: scheme.onSurface.withOpacity(0.05),
          border: Border(
            left: BorderSide(color: scheme.onSurface.withOpacity(0.25), width: 3),
          ),
          margin: const EdgeInsets.only(top: 4, bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          color: scheme.onSurface.withOpacity(0.75),
          fontSize: const FontSize(13.5),
        ),
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
        widget.onFloorLink?.call(dId, num);
        return;
      }
    }

    // 用户主页跳转
    final user = _userRe.firstMatch(url);
    if (user != null) {
      final uname = user.group(1) ?? '';
      if (uname.isNotEmpty) {
        widget.onUserLink?.call(uname);
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
