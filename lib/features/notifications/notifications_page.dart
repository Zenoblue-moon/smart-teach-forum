import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models.dart';
import '../../core/services/app_state.dart';
import '../../core/services/forum_service.dart';
import '../../core/utils.dart';
import '../../widgets/user_avatar.dart';
import '../auth/web_login_page.dart';
import '../discussion/discussion_page.dart';

/// 通知页（需登录）。
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({Key? key}) : super(key: key);

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage>
    with AutomaticKeepAliveClientMixin {
  final List<NotificationItem> _items = [];
  final ScrollController _scroll = ScrollController();
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _wasLoggedIn = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    // 首次进入自动加载（未登录时 _refresh 内部会直接返回）。
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  Future<void> _refresh() async {
    if (!context.read<AuthState>().isLoggedIn) return;
    setState(() => _loading = true);
    try {
      final result = await ForumService.instance.getNotifications(offset: 0);
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(result.items);
        _hasMore = result.hasMore;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final result =
          await ForumService.instance.getNotifications(offset: _items.length);
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

  Future<void> _markAllRead() async {
    try {
      await ForumService.instance.markAllNotificationsRead();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已全部标记为已读')),
      );
      _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('操作失败：$e')),
      );
    }
  }

  void _openLink(String discussionId, int postNumber) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DiscussionPage(
          discussionId: discussionId,
          initialPostNumber: postNumber > 0 ? postNumber : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final auth = context.watch<AuthState>();

    // 登录状态从「未登录」变为「已登录」时自动刷新通知。
    if (auth.isLoggedIn != _wasLoggedIn) {
      _wasLoggedIn = auth.isLoggedIn;
      if (auth.isLoggedIn) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('通知'),
        actions: [
          if (auth.isLoggedIn)
            TextButton(onPressed: _markAllRead, child: const Text('全部已读')),
        ],
      ),
      body: !auth.isLoggedIn ? _buildLoginPrompt() : _buildList(),
    );
  }

  Widget _buildLoginPrompt() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_none, size: 56, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          const Text('登录后查看通知'),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const WebLoginPage()))
                .then((_) => _refresh()),
            icon: const Icon(Icons.login),
            label: const Text('去登录'),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 140),
            Icon(Icons.notifications_off_outlined, size: 56, color: Colors.grey),
            SizedBox(height: 12),
            Center(child: Text('暂无通知')),
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
          final n = _items[i];
          return _NotificationTile(item: n, onOpen: _openLink);
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item, required this.onOpen});

  final NotificationItem item;
  final void Function(String, int) onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final emoji = item.reactionEmoji;
    final summary = stripHtml(item.subjectText).trim();
    final from = item.fromUser;
    final did = item.discussionId;

    return InkWell(
      onTap: did == null
          ? null
          : () => onOpen(did, item.postNumber ?? 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: item.isRead ? null : scheme.primary.withOpacity(0.04),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (from != null)
              UserAvatar(user: from, radius: 16)
            else
              CircleAvatar(
                radius: 16,
                backgroundColor: scheme.primary.withOpacity(0.15),
                child: Icon(Icons.notifications_none,
                    size: 18, color: scheme.primary),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: DefaultTextStyle.of(context).style,
                      children: [
                        TextSpan(
                          text: item.fromUsername.isNotEmpty
                              ? item.fromUsername
                              : '有人',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        TextSpan(
                          text: ' ${item.actionText}',
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                        if (emoji != null) TextSpan(text: ' $emoji'),
                      ],
                    ),
                  ),
                  if (summary.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    timeAgo(item.createdAt),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
