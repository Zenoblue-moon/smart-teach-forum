import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/config.dart';
import '../../core/models.dart';
import '../../core/services/forum_service.dart';
import '../../core/utils.dart';
import '../../widgets/discussion_list.dart';
import '../../widgets/post_list.dart';
import '../../widgets/user_avatar.dart';

/// 用户主页：背景图 + 信息 + 分类标签（回复/主题/徽章/投票/被提及 + Feed）。
class UserPage extends StatefulWidget {
  const UserPage({Key? key, required this.user, this.initialTab = 0})
      : super(key: key);

  final ForumUser user;

  /// 初始选中的标签：0 回复 / 1 主题 / 2 徽章 / 3 投票 / 4 被提及。
  final int initialTab;

  @override
  State<UserPage> createState() => _UserPageState();
}

class _UserPageState extends State<UserPage>
    with SingleTickerProviderStateMixin {
  late ForumUser _user;
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    _tab = TabController(
      length: 5,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 4),
    );
    _loadFullUser();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  /// 列表页带入的用户对象通常只有昵称/头像，这里补拉完整统计字段。
  Future<void> _loadFullUser() async {
    if (widget.user.id.isEmpty) return;
    final full = await ForumService.instance.getUser(widget.user.id);
    if (full != null && mounted) {
      setState(() => _user = full);
    }
  }

  String get _rssFeed =>
      '${AppConfig.baseUrl}/rss/u/${_user.username}/posts';
  String get _atomFeed =>
      '${AppConfig.baseUrl}/atom/u/${_user.username}/posts';

  void _showFeedSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('Feed 订阅链接',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.rss_feed),
              title: const Text('RSS'),
              subtitle: Text(_rssFeed, maxLines: 2, overflow: TextOverflow.ellipsis),
              trailing: IconButton(
                icon: const Icon(Icons.copy),
                onPressed: () => _copy(ctx, _rssFeed),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.rss_feed),
              title: const Text('Atom'),
              subtitle: Text(_atomFeed, maxLines: 2, overflow: TextOverflow.ellipsis),
              trailing: IconButton(
                icon: const Icon(Icons.copy),
                onPressed: () => _copy(ctx, _atomFeed),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _copy(BuildContext ctx, String text) {
    Clipboard.setData(ClipboardData(text: text));
    Navigator.pop(ctx);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('链接已复制'), duration: Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final u = _user;
    final username = u.username.isNotEmpty ? u.username : u.slug;

    return Scaffold(
      appBar: AppBar(
        title: Text(u.displayName.isNotEmpty ? u.displayName : (username.isEmpty ? '用户' : username)),
        actions: [
          IconButton(
            icon: const Icon(Icons.rss_feed),
            tooltip: 'Feed 订阅链接',
            onPressed: _showFeedSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildHeader(),
          const Divider(height: 1),
          TabBar(
            controller: _tab,
            isScrollable: true,
            tabs: const [
              Tab(text: '回复'),
              Tab(text: '主题'),
              Tab(text: '徽章'),
              Tab(text: '投票'),
              Tab(text: '被提及'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                PostList(author: username, commentsOnly: true),
                DiscussionList(author: username, sort: '-createdAt'),
                _BadgesTab(userId: u.id),
                PostList(votedUserId: u.id),
                PostList(mentionedUserId: u.id),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final u = _user;
    final scheme = Theme.of(context).colorScheme;
    final cover = resolveAssetUrl(u.cover);

    return Column(
      children: [
        Container(
          height: 150,
          width: double.infinity,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: cover.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: cover,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => _coverPlaceholder(scheme),
                        errorWidget: (_, __, ___) => _coverPlaceholder(scheme),
                      )
                    : _coverPlaceholder(scheme),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.35),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 16,
                bottom: -34,
                child: UserAvatar(user: u, radius: 34),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 44, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          u.displayName.isNotEmpty ? u.displayName : (u.username.isNotEmpty ? u.username : '用户'),
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        if (u.username.isNotEmpty &&
                            u.username != u.displayName) ...[
                          const SizedBox(height: 2),
                          Text('@${u.username}',
                              style: const TextStyle(
                                  fontSize: 13, color: Colors.grey)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (u.statusText != null && u.statusText!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (u.statusEmoji != null && u.statusEmoji!.isNotEmpty) ...[
                      Text(u.statusEmoji!),
                      const SizedBox(width: 4),
                    ],
                    Expanded(
                      child: Text(
                        u.statusText!,
                        style: TextStyle(
                            fontSize: 13, color: scheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ],
              if (u.bio != null && u.bio!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(u.bio!,
                    style: const TextStyle(fontSize: 13, height: 1.5)),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  _stat(u.discussionCount, '主题'),
                  _stat(u.commentCount, '回复'),
                  _stat(u.points ?? 0, '积分'),
                  _stat(u.money, '金钱'),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _meta('关注 ${u.followingCount}'),
                  const SizedBox(width: 16),
                  _meta('粉丝 ${u.followerCount}'),
                  const SizedBox(width: 16),
                  if (u.joinTime != null)
                    Expanded(child: _meta('加入于 ${formatDateTime(u.joinTime)}')),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _coverPlaceholder(ColorScheme scheme) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primary, scheme.secondary],
        ),
      ),
    );
  }

  Widget _stat(int value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text('$value',
              style:
                  const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _meta(String text) {
    return Text(text, style: const TextStyle(fontSize: 12, color: Colors.grey));
  }
}

/// 徽章标签页。
class _BadgesTab extends StatefulWidget {
  const _BadgesTab({required this.userId});

  final String userId;

  @override
  State<_BadgesTab> createState() => _BadgesTabState();
}

class _BadgesTabState extends State<_BadgesTab>
    with AutomaticKeepAliveClientMixin {
  List<UserBadge> _badges = const [];
  bool _loading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await ForumService.instance.getUserBadges(widget.userId);
    if (!mounted) return;
    setState(() {
      _badges = list;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_badges.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 120),
            Icon(Icons.military_tech_outlined, size: 56, color: Colors.grey),
            SizedBox(height: 12),
            Center(child: Text('暂无徽章')),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemCount: _badges.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) => _BadgeTile(badge: _badges[i]),
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.badge});

  final UserBadge badge;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bgColor = Tag.parseColor(badge.backgroundColor);
    final iconColor = Tag.parseColor(badge.iconColor);
    final labelColor = Tag.parseColor(badge.labelColor);
    final img = badge.image;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor != null
              ? Color(bgColor).withOpacity(0.12)
              : scheme.primary.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: bgColor != null ? Color(bgColor).withOpacity(0.5) : Colors.black12,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: bgColor != null
                    ? Color(bgColor).withOpacity(0.2)
                    : scheme.primary.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: img != null && img.isNotEmpty
                  ? ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: resolveAssetUrl(img),
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                      ),
                    )
                  : Icon(
                      Icons.military_tech,
                      color: iconColor != null
                          ? Color(iconColor)
                          : scheme.primary,
                      size: 24,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    badge.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: labelColor != null ? Color(labelColor) : null,
                    ),
                  ),
                  if (badge.description.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      badge.description,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
