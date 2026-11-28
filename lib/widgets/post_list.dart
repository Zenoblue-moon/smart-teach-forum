import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/services/forum_service.dart';
import '../core/utils.dart';
import '../features/discussion/discussion_page.dart';
import 'user_avatar.dart';

/// 可复用的帖子分页列表，用于个人主页的「回复 / 投票 / 被提及」。
class PostList extends StatefulWidget {
  const PostList({
    Key? key,
    this.author,
    this.mentionedUserId,
    this.votedUserId,
    this.commentsOnly = false,
  }) : super(key: key);

  /// 按作者用户名筛选。
  final String? author;

  /// 按被提及用户 id 筛选。
  final String? mentionedUserId;

  /// 按投票用户 id 筛选。
  final String? votedUserId;

  /// 仅楼层回复（排除首帖）。
  final bool commentsOnly;

  @override
  State<PostList> createState() => _PostListState();
}

class _PostListState extends State<PostList>
    with AutomaticKeepAliveClientMixin {
  final List<Post> _items = [];
  final ScrollController _scroll = ScrollController();
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _refresh();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(PostList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.author != widget.author ||
        oldWidget.mentionedUserId != widget.mentionedUserId ||
        oldWidget.votedUserId != widget.votedUserId ||
        oldWidget.commentsOnly != widget.commentsOnly) {
      _refresh();
    }
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ForumService.instance.getUserPosts(
        author: widget.author,
        mentionedUserId: widget.mentionedUserId,
        votedUserId: widget.votedUserId,
        commentsOnly: widget.commentsOnly,
        offset: 0,
      );
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(result.items);
        _hasMore = result.hasMore;
        _loading = false;
      });
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
      final result = await ForumService.instance.getUserPosts(
        author: widget.author,
        mentionedUserId: widget.mentionedUserId,
        votedUserId: widget.votedUserId,
        commentsOnly: widget.commentsOnly,
        offset: _items.length,
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(result.items);
        _hasMore = result.hasMore;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  void _open(Post post) {
    final d = post.discussion;
    if (d == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DiscussionPage(
          discussionId: d.id,
          initialTitle: d.title,
          initialPostNumber: post.number,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _items.isEmpty) {
      return _ErrorView(message: _error!, onRetry: _refresh);
    }
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 120),
            Icon(Icons.inbox_outlined, size: 56, color: Colors.grey),
            SizedBox(height: 12),
            Center(child: Text('暂无内容')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _items.length + (_hasMore ? 1 : 0),
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          if (i >= _items.length) {
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
          final post = _items[i];
          return _PostTile(post: post, onTap: () => _open(post));
        },
      ),
    );
  }
}

class _PostTile extends StatelessWidget {
  const _PostTile({required this.post, required this.onTap});

  final Post post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final summary = stripHtml(post.contentHtml).trim();
    final discussion = post.discussion;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (post.author != null) ...[
                  UserAvatar(user: post.author!, radius: 14),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.author?.displayName ?? '未知用户',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        timeAgo(post.createdAt),
                        style: TextStyle(
                            fontSize: 12, color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (summary.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                summary,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, height: 1.5),
              ),
            ],
            if (discussion != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.forum_outlined,
                      size: 14, color: scheme.primary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      discussion.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: scheme.primary),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off,
              size: 48, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          const Text('加载失败，请检查网络'),
          const SizedBox(height: 4),
          Text(message, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }
}
