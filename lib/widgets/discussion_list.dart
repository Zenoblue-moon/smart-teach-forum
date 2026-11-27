import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/services/forum_service.dart';
import '../features/discussion/discussion_page.dart';
import '../features/profile/user_page.dart';
import 'discussion_card.dart';

/// 可复用的讨论分页列表。
///
/// 支持按排序、板块、关键词加载，下拉刷新与滚动分页。
class DiscussionList extends StatefulWidget {
  const DiscussionList({
    Key? key,
    this.sort = '-lastPostedAt',
    this.tagSlug,
    this.query,
    this.author,
  }) : super(key: key);

  final String sort;
  final String? tagSlug;
  final String? query;
  final String? author;

  @override
  State<DiscussionList> createState() => _DiscussionListState();
}

class _DiscussionListState extends State<DiscussionList>
    with AutomaticKeepAliveClientMixin {
  final List<Discussion> _items = [];
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
  void didUpdateWidget(DiscussionList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sort != widget.sort ||
        oldWidget.tagSlug != widget.tagSlug ||
        oldWidget.query != widget.query ||
        oldWidget.author != widget.author) {
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
      final result = await ForumService.instance.getDiscussions(
        sort: widget.sort,
        tagSlug: widget.tagSlug,
        query: widget.query,
        author: widget.author,
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
      final result = await ForumService.instance.getDiscussions(
        sort: widget.sort,
        tagSlug: widget.tagSlug,
        query: widget.query,
        author: widget.author,
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
      return _EmptyView(onRefresh: _refresh);
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _items.length + (_hasMore ? 1 : 0),
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
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
          final d = _items[i];
          return DiscussionCard(
            discussion: d,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => DiscussionPage(discussionId: d.id, initialTitle: d.title),
              ),
            ),
            onAuthorTap: d.author == null
                ? null
                : () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => UserPage(user: d.author!)),
                    ),
          );
        },
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
          Icon(Icons.cloud_off, size: 48, color: Theme.of(context).colorScheme.outline),
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

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
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
}
