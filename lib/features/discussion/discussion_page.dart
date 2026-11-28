import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

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
  int _currentFloor = 0;
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
    _updateCurrentFloor();
  }

  /// 追踪当前视口顶部的楼层号（用于快速跳转面板显示 x / y 条）。
  void _updateCurrentFloor() {
    if (!_scroll.hasClients || !mounted) return;
    final position = _scroll.position;
    final viewportDim = position.viewportDimension;
    final viewportCtx = position.context.storageContext;
    final viewportBox = viewportCtx.findRenderObject() as RenderBox?;
    if (viewportBox == null || !viewportBox.attached) return;
    final viewportBottom = viewportBox.localToGlobal(Offset.zero).dy + viewportDim;

    int? current;
    final numbers = _keys.keys.toList()..sort();
    for (final n in numbers) {
      final ctx = _keys[n]?.currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.attached || !box.hasSize) continue;
      final top = box.localToGlobal(Offset.zero).dy;
      if (top < viewportBottom) {
        current = n;
        break;
      }
    }
    if (current != null && current != _currentFloor) {
      final floor = current;
      setState(() => _currentFloor = floor);
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
      // 跳转到其它帖子的楼层：打开新帖子并定位到该楼层。
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DiscussionPage(
            discussionId: discussionId,
            initialPostNumber: number > 0 ? number : null,
          ),
        ),
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

  /// 滚动定位到指定楼层。
  ///
  /// [instant] 为 true 时直接跳转（快速跳转时间轴拖动时使用），
  /// 否则使用平滑动画。
  void _scrollToPost(int number, {bool instant = false}) {
    final key = _keys[number];
    if (key != null && key.currentContext != null) {
      Scrollable.ensureVisible(
        key.currentContext!,
        duration: instant ? Duration.zero : const Duration(milliseconds: 350),
        curve: instant ? Curves.easeOut : Curves.easeInOut,
        alignment: 0.05,
      );
      return;
    }

    // 目标楼层尚未渲染：估算位置。
    final target = ((number - 1) * 220.0).clamp(0.0, double.infinity);
    if (instant) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(target.clamp(0.0, _scroll.position.maxScrollExtent));
      }
    } else {
      _scroll.animateTo(
        target,
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

    // 若目标楼层尚未加载，后台补载后再精确定位。
    if (!_hasFloor(number) && _hasMore && !_loadingMore) {
      _ensureFloorLoaded(number).then((_) {
        if (!mounted) return;
        final k = _keys[number];
        if (k != null && k.currentContext != null) {
          Scrollable.ensureVisible(
            k.currentContext!,
            duration: instant ? Duration.zero : const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            alignment: 0.05,
          );
        }
      });
    }
  }

  /// 顺序补载，直到目标楼层加载完成。
  Future<void> _ensureFloorLoaded(int number) async {
    var guard = 0;
    while (!_hasFloor(number) && _hasMore && guard < 100) {
      await _loadMore();
      guard++;
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

  int get _totalFloors {
    final d = _discussion;
    if (d != null && d.lastPostNumber > 0) return d.lastPostNumber;
    if (_posts.isEmpty) return 0;
    return _posts.last.number ?? _posts.length;
  }

  Post? _postForFloor(int floor) {
    for (final p in _posts) {
      if (p.number == floor) return p;
    }
    return null;
  }

  String _yearMonth(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final t = DateTime.tryParse(iso)?.toLocal();
    if (t == null) return '';
    return '${t.year}年${t.month}月';
  }

  Future<void> _jumpToEarliest() async {
    if (_scroll.hasClients) {
      await _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _jumpToLatest() async {
    // 补齐剩余楼层后再定位到底部。
    var guard = 0;
    while (_hasMore && !_loadingMore && guard < 100) {
      await _loadMore();
      guard++;
    }
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  /// 快速跳转面板：最早内容 / 可拖动时间轴（x/y 条 + 日期）/ 最新回复。
  ///
  /// 时间轴是一个可拖动的竖向滑块，拖动到哪一条，正文列表就定位到哪一条。
  void _showQuickJump() {
    final total = _totalFloors;
    if (total <= 0) return;
    final scheme = Theme.of(context).colorScheme;

    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final current = _currentFloor > 0 ? _currentFloor.clamp(1, total) : 1;
            final post = _postForFloor(current);

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 顶部：最早内容
                    _jumpOption(
                      ctx,
                      Icons.keyboard_double_arrow_up,
                      '最早内容',
                      _jumpToEarliest,
                    ),
                    const SizedBox(height: 4),
                    // 中间：可拖动时间轴 + x/y 条 + 日期
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (total > 1)
                            SizedBox(
                              height: 150,
                              child: RotatedBox(
                                quarterTurns: 1,
                                child: Slider(
                                  value: current.toDouble(),
                                  min: 1,
                                  max: total.toDouble(),
                                  activeColor: scheme.primary,
                                  inactiveColor: Colors.grey.shade300,
                                  onChanged: (v) {
                                    final floor = v.round().clamp(1, total);
                                    if (floor == _currentFloor) return;
                                    _currentFloor = floor;
                                    setSheetState(() {});
                                    _scrollToPost(floor, instant: true);
                                  },
                                ),
                              ),
                            )
                          else
                            const SizedBox(
                              height: 150,
                              width: 32,
                              child: Center(
                                child: Text('1', style: TextStyle(color: Colors.grey)),
                              ),
                            ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$current / $total 条',
                                  style: const TextStyle(
                                      fontSize: 17, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _yearMonth(post?.createdAt),
                                  style: const TextStyle(
                                      fontSize: 13, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    // 底部：最新回复
                    _jumpOption(
                      ctx,
                      Icons.keyboard_double_arrow_down,
                      '最新回复',
                      _jumpToLatest,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _jumpOption(
    BuildContext ctx,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: () {
        Navigator.pop(ctx);
        onTap();
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        child: Row(
          children: [
            Icon(icon, size: 22),
            const SizedBox(width: 10),
            Text(label, style: const TextStyle(fontSize: 15)),
          ],
        ),
      ),
    );
  }

  Future<void> _openUser(String username) async {
    // 优先解析为本地用户主页，失败则浏览器打开论坛主页。
    final user = await ForumService.instance.getUserByUsername(username);
    if (!mounted) return;
    if (user != null && user.id.isNotEmpty) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => UserPage(user: user)),
      );
      return;
    }
    final uri = Uri.tryParse('${AppConfig.baseUrl}/u/$username');
    if (uri != null) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('无法打开用户：$username')),
          );
        }
      }
    }
  }

  void _openReply({Post? quote}) {
    String? quoteContent;
    String? quoteAuthor;
    String? quotePostId;
    if (quote != null) {
      quoteContent = stripHtml(quote.contentHtml);
      quoteAuthor = quote.author?.username;
      quotePostId = quote.id;
    }
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => ReplyPage(
            discussionId: widget.discussionId,
            discussionTitle: _title,
            quoteContent: quoteContent,
            quoteAuthor: quoteAuthor,
            postId: quotePostId,
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
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: '更多',
            onSelected: (v) {
              if (v == 'copy') _copyLink();
              if (v == 'jump') _showQuickJump();
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'copy',
                child: Row(
                  children: const [
                    Icon(Icons.link, size: 20),
                    SizedBox(width: 10),
                    Text('复制链接'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'jump',
                child: Row(
                  children: const [
                    Icon(Icons.swap_vert, size: 20),
                    SizedBox(width: 10),
                    Text('快速跳转'),
                  ],
                ),
              ),
            ],
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
