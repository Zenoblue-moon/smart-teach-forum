import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../core/services/forum_service.dart';
import '../../core/utils.dart';
import '../../widgets/discussion_list.dart';
import '../../widgets/user_avatar.dart';

/// 用户主页：信息 + 统计 + 其发布的主题。
class UserPage extends StatefulWidget {
  const UserPage({Key? key, required this.user}) : super(key: key);

  final ForumUser user;

  @override
  State<UserPage> createState() => _UserPageState();
}

class _UserPageState extends State<UserPage> {
  late ForumUser _user;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    _loadFullUser();
  }

  /// 列表页带入的用户对象通常只有昵称/头像，这里补拉完整统计字段。
  Future<void> _loadFullUser() async {
    final full = await ForumService.instance.getUser(widget.user.id);
    if (full != null && mounted) {
      setState(() => _user = full);
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = _user;
    final scheme = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 1,
      child: Scaffold(
        appBar: AppBar(title: Text(u.displayName)),
        body: Column(
          children: [
            Container(
              width: double.infinity,
              color: scheme.primary.withOpacity(0.06),
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
              child: Column(
                children: [
                  UserAvatar(user: u, radius: 32),
                  const SizedBox(height: 12),
                  Text(
                    u.displayName,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  if (u.username.isNotEmpty && u.username != u.displayName) ...[
                    const SizedBox(height: 2),
                    Text('@${u.username}', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                  ],
                  if (u.bio != null && u.bio!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(u.bio!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13)),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _stat(u.discussionCount, '主题'),
                      Container(width: 1, height: 28, color: Colors.black12),
                      _stat(u.commentCount, '回复'),
                      Container(width: 1, height: 28, color: Colors.black12),
                      _stat(u.points ?? 0, '积分'),
                    ],
                  ),
                  if (u.joinTime != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      '加入于 ${formatDateTime(u.joinTime)}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            const TabBar(tabs: [Tab(text: '发布的主题')]),
            Expanded(
              child: TabBarView(
                children: [
                  DiscussionList(author: u.username, sort: '-createdAt'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(int value, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Column(
        children: [
          Text('$value', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}
