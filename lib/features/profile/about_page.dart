import 'package:flutter/material.dart';

import '../../core/config.dart';

/// 「关于」二级界面。
class AboutPage extends StatelessWidget {
  const AboutPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('关于')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: scheme.primary.withOpacity(0.12),
                  child: Icon(Icons.forum_outlined,
                      size: 44, color: scheme.primary),
                ),
                const SizedBox(height: 16),
                const Text(
                  AppConfig.siteName,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  '版本 ${AppConfig.appVersion}',
                  style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Column(
              children: [
                _infoRow(context, Icons.public, '官方网站', AppConfig.baseUrl),
                const Divider(height: 1),
                _infoRow(context, Icons.code, '开源框架', 'Flutter'),
                const Divider(height: 1),
                _infoRow(context, Icons.settings_suggest_outlined, '数据接口',
                    'Flarum JSON:API'),
                const Divider(height: 1),
                _infoRow(context, Icons.login, '登录方式', 'FoF Passport SSO'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '本应用为「${AppConfig.siteName}」的非官方第三方客户端，'
              '使用 Flutter 开源框架构建，覆盖论坛浏览、发帖、回复、搜索、'
              '通知与个人中心等核心功能。',
              style: TextStyle(
                fontSize: 13,
                height: 1.6,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(BuildContext context, IconData icon, String label, String value) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, size: 20),
      title: Text(label,
          style: const TextStyle(fontSize: 14, color: Colors.grey)),
      subtitle: Text(
        value,
        style: TextStyle(fontSize: 15, color: scheme.onSurface),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
