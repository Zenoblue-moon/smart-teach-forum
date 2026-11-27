import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/utils.dart';

/// 用户头像，支持缓存、加载占位、管理员金框。
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    Key? key,
    required this.user,
    this.radius = 18,
  }) : super(key: key);

  final ForumUser user;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final url = resolveAssetUrl(user.avatarUrl);
    final colorScheme = Theme.of(context).colorScheme;
    final borderColor = user.isAdmin
        ? const Color(0xFFF5A623)
        : colorScheme.primary.withOpacity(0.35);
    final borderWidth = user.isAdmin ? 2.0 : 1.0;

    Widget child;
    if (url.isNotEmpty) {
      child = CachedNetworkImage(
        imageUrl: url,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        placeholder: (_, __) => _fallback(colorScheme, radius),
        errorWidget: (_, __, ___) => _fallback(colorScheme, radius),
      );
    } else {
      child = _fallback(colorScheme, radius);
    }

    return Container(
      width: radius * 2 + borderWidth * 2,
      height: radius * 2 + borderWidth * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      child: ClipOval(child: child),
    );
  }

  Widget _fallback(ColorScheme scheme, double radius) {
    final initial = user.displayName.isNotEmpty
        ? user.displayName.characters.first.toUpperCase()
        : '?';
    return Container(
      width: radius * 2,
      height: radius * 2,
      color: scheme.primary.withOpacity(0.15),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: scheme.primary,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.9,
        ),
      ),
    );
  }
}
