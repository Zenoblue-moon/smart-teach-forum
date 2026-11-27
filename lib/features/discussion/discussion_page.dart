import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../core/models.dart';
import '../../core/services/app_state.dart';
import '../../core/services/forum_service.dart';
import '../../core/utils.dart';
import '../../widgets/html_content.dart';
import '../../widgets/tag_chip.dart';
import '../../widgets/user_avatar.dart';
import '../compose/reply_page.dart';
import '../profile/user_page.dart';
import 'image_viewer_page.dart';

/// 帖子详情页：标题 + 楼层列表。
class DiscussionPage extends StatefulWidget {
  const DiscussionPage({
    Key? key,
    required this.discussionId,
    this.initialTitle = '',
    this.initialPostNumber,
  }) : super(key: key);

  final String discussionId;
  final String initialTitle;

  /// 进入后自动定位到的楼层号（如来自通知）。
  final int? initialPostNumber;

  @override
  State<DiscussionPage> createState() => _DiscussionPageState();
}

class _DiscussionPageState extends State<DiscussionPage> {
  final List<Post> _posts = [];
  final ScrollController _scroll = ScrollController();
  final Map<int, GlobalKey> _keys = {};

  Discussion? _discussion;
  String _title = '';
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;
  int? _highlightFloor;
  List<Reaction> _reactions = const [];
  final Set<String> _pendingVote = {};
  final Set<String> _pendingReact = {};

  @override
  void initState() {
    super.initState();
    _title = widget.initialTitle;
    _scroll.addListener(_onScroll);
    _load();
    _loadReactions();
  }

  Future<void> _loadReactions() async {
    try {
      final list = await ForumService.instance.getReactions();
      if (mounted) setState(() => _reactions = list);
    } catch (_) {
      // 表情列表加载失败不影响主体。
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // 并行加载详情与首屏楼层
      final results = await Future.wait([
        ForumService.instance.getDiscussion(widget.discussionId),
        ForumService.instance.getPosts(widget.discussionId, offset: 0),
      ]);
      final discussion = results[0] as Discussion;
      final posts = results[1] as PageResult<Post>;
      if (!mounted) return;
      setState(() {
        _discussion = discussion;
        _title = discussion.title.isNotEmpty ? discussion.title : _title;
        _posts
          ..clear()
          ..addAll(posts.items);
        _hasMore = posts.hasMore;
        _loading = false;
      });
      final target = widget.initialPostNumber;
      if (target != null && target > 0) {
        await _jumpToFloor(widget.discussionId, target);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final result =
          await ForumService.instance.getPosts(widget.discussionId, offset: _posts.length);
      if (!mounted) return;
      setState(() {
        _posts.addAll(result.items);
        _hasMore = result.hasMore;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  bool _hasFloor(int number) => _posts.any((p) => p.number == number);

  /// 楼层引用跳转。
  Future<void> _jumpToFloor(String discussionId, int number) async {
    if (discussionId != widget.discussionId) {
      // 跳转到其它帖子的楼层：打开新页面。
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('该引用指向其他帖子')),
      );
      return;
    }
    if (number <= 0) return;

    // 若目标楼层未加载，顺序补载。
    while (!_hasFloor(number) && _hasMore) {
      await _loadMore();
    }
    if (!_hasFloor(number)) return;

    setState(() => _highlightFloor = number);
    _scrollToPost(number);

    // 2.5 秒后取消高亮。
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted && _highlightFloor == number) {
        setState(() => _highlightFloor = null);
      }
    });
  }

  void _scrollToPost(int number) {
    final key = _keys[number];
    if (key != null && key.currentContext != null) {
      Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
        alignment: 0.05,
      );
    } else {
      // 估算滚动，待渲染后精确定位。
      _scroll.animateTo(
        (number - 1) * 220.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
      Future.delayed(const Duration(milliseconds: 250), () {
        final k = _keys[number];
        if (k != null && k.currentContext != null && mounted) {
          Scrollable.ensureVisible(
            k.currentContext!,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            alignment: 0.05,
          );
        }
      });
    }
  }

  void _copyLink({int? postNumber}) {
    final base = AppConfig.baseUrl;
    final url = postNumber == null
        ? '$base/d/${widget.discussionId}'
        : '$base/d/${widget.discussionId}/$postNumber';
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('链接已复制'), duration: Duration(seconds: 1)),
    );
  }

  void _openUser(String username) {
    // 预留：跳到用户主页（Flarum 用户搜索需登录，这里先提示）。
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('用户：$username')),
    );
  }

  void _openReply({Post? quote}) {
    String? quoteContent;
    String? quoteAuthor;
    if (quote != null) {
      quoteContent = stripHtml(quote.contentHtml);
      quoteAuthor = quote.author?.username;
    }
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => ReplyPage(
            discussionId: widget.discussionId,
            discussionTitle: _title,
            quoteContent: quoteContent,
            quoteAuthor: quoteAuthor,
          ),
        ))
        .then((_) => _load());
  }

  void _replacePost(Post updated) {
    final idx = _posts.indexWhere((p) => p.id == updated.id);
    if (idx >= 0 && mounted) {
      setState(() => _posts[idx] = updated);
    }
  }

  bool get _loggedIn => context.read<AuthState>().isLoggedIn;

  void _requireLogin() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('请先登录后再操作')),
    );
  }

  Future<void> _onVote(
    Post post, {
    required bool upvote,
    required bool downvote,
  }) async {
    if (_pendingVote.contains(post.id)) return;
    if (!_loggedIn) return _requireLogin();
    setState(() => _pendingVote.add(post.id));
    try {
      final updated = await ForumService.instance
          .vote(post.id, upvote: upvote, downvote: downvote);
      _replacePost(updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _pendingVote.remove(post.id));
    }
  }

  Future<void> _onReact(Post post, String? reactionId) async {
    if (_pendingReact.contains(post.id)) return;
    if (!_loggedIn) return _requireLogin();
    setState(() => _pendingReact.add(post.id));
    try {
      final updated =
          await ForumService.instance.react(post.id, reactionId);
      _replacePost(updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _pendingReact.remove(post.id));
    }
  }

  String? _reactionEmoji(String? id) {
    if (id == null) return null;
    for (final r in _reactions) {
      if (r.id == id) return r.emoji;
    }
    return null;
  }

  /// 弹出表情选择面板（排除会转换为赞/踩的 thumbsup/thumbsdown）。
  void _showReactions(Post post) {
    final options = _reactions
        .where((r) => r.identifier != 'thumbsup' && r.identifier != 'thumbsdown')
        .toList();
    final current = post.userReactionIdentifier;

    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Row(
                  children: [
                    const Text('选择表情',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    if (current != null)
                      TextButton(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          _onReact(post, null);
                        },
                        child: const Text('取消回应'),
                      ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      for (final r in options)
                        _reactionOption(sheetContext, post, r, current),
                      if (options.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('暂无可用表情'),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _reactionOption(
    BuildContext sheetContext,
    Post post,
    Reaction reaction,
    String? current,
  ) {
    final selected = current == reaction.id;
    return InkWell(
      onTap: () {
        Navigator.pop(sheetContext);
        _onReact(post, selected ? null : reaction.id);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected
              ? Theme.of(context).colorScheme.primary.withOpacity(0.12)
              : Colors.transparent,
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(reaction.emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 4),
            Text(
              '${post.reactionCounts[reaction.id] ?? 0}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _title.isEmpty ? '帖子' : _title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.link),
            tooltip: '复制链接',
            onPressed: () => _copyLink(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openReply(),
        icon: const Icon(Icons.reply),
        label: const Text('回复'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('帖子加载失败'),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      controller: _scroll,
      padding: const EdgeInsets.only(bottom: 88),
      itemCount: _posts.length + 1 + (_hasMore ? 1 : 0),
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        if (i == 0) return _buildHeader();
        final postIndex = i - 1;
        if (postIndex >= _posts.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final post = _posts[postIndex];
        final number = post.number ?? (postIndex + 1);
        if (!_keys.containsKey(number)) {
          _keys[number] = GlobalKey();
        }
        return PostTile(
          key: _keys[number],
          post: post,
          isHighlighted: _highlightFloor == number,
          onImageTap: (urls, index) => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ImageViewerPage(urls: urls, initialIndex: index),
            ),
          ),
          onFloorLink: _jumpToFloor,
          onUserLink: _openUser,
          onAuthorTap: post.author == null
              ? null
              : () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => UserPage(user: post.author!)),
                  ),
          onReply: () => _openReply(quote: post),
          onCopyLink: () => _copyLink(postNumber: number),
          onVote: (up, down) => _onVote(post, upvote: up, downvote: down),
          onReact: () => _showReactions(post),
          currentReactionEmoji: _reactionEmoji(post.userReactionIdentifier),
        );
      },
    );
  }

  Widget _buildHeader() {
    final d = _discussion;
    final tags = d?.tags ?? const <Tag>[];
    final firstPost = _posts.isNotEmpty ? _posts.first : null;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _title,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold, height: 1.35),
          ),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final t in tags) TagChip(tag: t)],
            ),
          ],
          if (firstPost != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (firstPost.author != null)
                  UserAvatar(user: firstPost.author!, radius: 15),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        firstPost.author?.displayName ?? '',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        formatDateTime(firstPost.createdAt),
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// 单个楼层。
class PostTile extends StatelessWidget {
  const PostTile({
    Key? key,
    required this.post,
    required this.isHighlighted,
    required this.onImageTap,
    required this.onFloorLink,
    required this.onUserLink,
    required this.onAuthorTap,
    required this.onReply,
    required this.onCopyLink,
    required this.onVote,
    required this.onReact,
    this.currentReactionEmoji,
  }) : super(key: key);

  final Post post;
  final bool isHighlighted;
  final void Function(List<String>, int) onImageTap;
  final void Function(String, int) onFloorLink;
  final void Function(String) onUserLink;
  final VoidCallback? onAuthorTap;
  final VoidCallback onReply;
  final VoidCallback onCopyLink;
  final void Function(bool upvote, bool downvote) onVote;
  final VoidCallback onReact;

  /// 当前用户所选表情的 Emoji（用于在按钮上显示）。
  final String? currentReactionEmoji;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final number = post.number ?? 0;

    return Container(
      color: isHighlighted ? scheme.primary.withOpacity(0.10) : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (post.author != null) ...[
                InkWell(
                  onTap: onAuthorTap,
                  borderRadius: BorderRadius.circular(999),
                  child: UserAvatar(user: post.author!, radius: 16),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: onAuthorTap,
                      child: Text(
                        post.author?.displayName ?? '未知用户',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      '${formatDateTime(post.createdAt)}${post.editedAt != null ? ' · 已编辑' : ''}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Text(
                '#$number',
                style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 12),
          HtmlContent(
            html: post.contentHtml,
            onImageTap: onImageTap,
            onFloorLink: onFloorLink,
            onUserLink: onUserLink,
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 2,
            runSpacing: 2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _voteButton(context, up: true),
              _voteButton(context, up: false),
              _reactButton(context),
              TextButton.icon(
                onPressed: onReply,
                icon: const Icon(Icons.reply, size: 16),
                label: const Text('回复'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
              TextButton.icon(
                onPressed: onCopyLink,
                icon: const Icon(Icons.link, size: 16),
                label: const Text('复制'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _voteButton(BuildContext context, {required bool up}) {
    final scheme = Theme.of(context).colorScheme;
    final selected = up ? post.hasUpvoted : post.hasDownvoted;
    final color = up ? scheme.primary : Colors.redAccent;
    final icon = up
        ? (selected ? Icons.thumb_up_alt : Icons.thumb_up_alt_outlined)
        : (selected ? Icons.thumb_down_alt : Icons.thumb_down_alt_outlined);
    final label = up ? (post.votes > 0 ? '${post.votes}' : '赞') : '踩';
    return TextButton.icon(
      onPressed: post.canVote
          ? () => up
              ? onVote(!post.hasUpvoted, false)
              : onVote(false, !post.hasDownvoted)
          : null,
      icon: Icon(icon, size: 16, color: selected ? color : null),
      label: Text(label),
      style: TextButton.styleFrom(
        primary: selected ? color : scheme.onSurfaceVariant,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }

  Widget _reactButton(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasReact = post.userReactionIdentifier != null;
    final total = post.reactionCounts.values.fold<int>(0, (a, b) => a + b);
    final label = hasReact
        ? (currentReactionEmoji ?? '已回应')
        : (total > 0 ? '$total' : '表情');
    return TextButton.icon(
      onPressed: post.canReact ? onReact : null,
      icon: Icon(
        hasReact ? Icons.emoji_emotions : Icons.emoji_emotions_outlined,
        size: 16,
        color: hasReact ? scheme.primary : null,
      ),
      label: Text(label),
      style: TextButton.styleFrom(
        primary: hasReact ? scheme.primary : scheme.onSurfaceVariant,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }
}
