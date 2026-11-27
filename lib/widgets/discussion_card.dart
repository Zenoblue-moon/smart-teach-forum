import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/utils.dart';
import 'tag_chip.dart';
import 'user_avatar.dart';

/// 讨论列表卡片。
class DiscussionCard extends StatelessWidget {
  const DiscussionCard({
    Key? key,
    required this.discussion,
    required this.onTap,
    this.onAuthorTap,
  }) : super(key: key);

  final Discussion discussion;
  final VoidCallback onTap;
  final VoidCallback? onAuthorTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tags = discussion.tags.where((t) => t.isChild).toList();
    if (tags.isEmpty) {
      tags.addAll(discussion.tags);
    }

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 状态标签 + 板块
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ..._statusBadges(context),
                for (final t in tags.take(3)) TagChip(tag: t),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              discussion.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                if (discussion.author != null) ...[
                  InkWell(
                    onTap: onAuthorTap,
                    borderRadius: BorderRadius.circular(999),
                    child: UserAvatar(user: discussion.author!, radius: 14),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        discussion.author?.displayName ?? '未知用户',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        timeAgo(discussion.lastPostedAt ?? discussion.createdAt),
                        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant.withOpacity(0.7)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _Metric(
                  icon: Icons.chat_bubble_outline,
                  value: discussion.commentCount,
                ),
                const SizedBox(width: 12),
                _Metric(icon: Icons.visibility_outlined, value: discussion.views),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _statusBadges(BuildContext context) {
    final badges = <Widget>[];
    if (discussion.isStickiest) {
      badges.add(const _Badge(text: '全站置顶', color: Color(0xFFE53935)));
    } else if (discussion.isSticky) {
      badges.add(const _Badge(text: '置顶', color: Color(0xFFE53935)));
    } else if (discussion.isTagSticky) {
      badges.add(const _Badge(text: '板块置顶', color: Color(0xFFFF9800)));
    }
    if (discussion.hasBestAnswer) {
      badges.add(const _Badge(text: '已解决', color: Color(0xFF26A03D)));
    }
    if (discussion.isLocked) {
      badges.add(const _Badge(text: '已锁定', color: Color(0xFF757575)));
    }
    return badges;
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.6)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.value});

  final IconData icon;
  final int value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 15, color: scheme.onSurfaceVariant.withOpacity(0.6)),
        const SizedBox(width: 3),
        Text(
          value > 999 ? '${(value / 1000).toStringAsFixed(1)}k' : '$value',
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant.withOpacity(0.7)),
        ),
      ],
    );
  }
}
