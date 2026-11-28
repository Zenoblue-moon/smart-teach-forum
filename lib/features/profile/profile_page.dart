import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/models.dart';
import '../../core/services/app_state.dart';
import '../../core/services/forum_service.dart';
import '../../core/theme_presets.dart';
import '../../widgets/user_avatar.dart';
import '../auth/web_login_page.dart';
import 'about_page.dart';
import 'account_security_page.dart';
import 'edit_profile_page.dart';
import 'user_page.dart';

/// 「我的」页：登录态、个人主页入口、账号与个性化设置。
class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  ForumUser? _me;

  @override
  void initState() {
    super.initState();
    _loadMe();
  }

  Future<void> _loadMe() async {
    final auth = context.read<AuthState>();
    if (!auth.isLoggedIn || auth.userId == null) return;
    final user = await ForumService.instance.getUser(auth.userId!);
    if (mounted) setState(() => _me = user);
  }

  /// 构建「我自己」的用户对象（_me 未加载完时用登录态兜底）。
  ForumUser _selfUser(AuthState auth) {
    if (_me != null) return _me!;
    final attrs = <String, dynamic>{
      'username': auth.username ?? '',
      'displayName': auth.displayName ?? auth.username ?? '',
      'avatarUrl': auth.avatarUrl ?? '',
    };
    return ForumUser.fromJson(<String, dynamic>{
      'id': auth.userId ?? '',
      'attributes': attrs,
    });
  }

  void _openSelf(int tab) {
    final auth = context.read<AuthState>();
    if (!auth.isLoggedIn) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => UserPage(user: _selfUser(auth), initialTab: tab)),
    );
  }

  void _openEditProfile(ForumUser me) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => EditProfilePage(user: me)))
        .then((_) => _loadMe());
  }

  void _openAccountSecurity(ForumUser me) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AccountSecurityPage(user: me)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();

    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (auth.isLoggedIn) ..._buildLoggedIn(auth) else ..._buildGuest(),
          const SizedBox(height: 8),
          _buildAppearanceCard(),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('关于'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const AboutPage())),
            ),
          ),
          if (auth.isLoggedIn) ...[
            const SizedBox(height: 8),
            _buildAccountCard(auth),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('退出登录', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  await auth.logout();
                  setState(() => _me = null);
                },
              ),
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  List<Widget> _buildLoggedIn(AuthState auth) {
    final me = _selfUser(auth);
    final name = me.displayName.isNotEmpty
        ? me.displayName
        : (me.username.isNotEmpty ? me.username : '用户');
    final uid = auth.userId ?? '';

    return [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  if (_me != null)
                    UserAvatar(user: _me!, radius: 28)
                  else
                    CircleAvatar(
                      radius: 28,
                      child: Icon(Icons.person, size: 32),
                    ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('UID: $uid',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _stat(_me?.discussionCount ?? 0, '主题'),
                  _divider(),
                  _stat(_me?.commentCount ?? 0, '回复'),
                  _divider(),
                  _stat(_me?.points ?? 0, '积分'),
                  _divider(),
                  _stat(_me?.money ?? 0, '金钱'),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _openSelf(0),
                  icon: const Icon(Icons.person_outline),
                  label: const Text('查看完整主页'),
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  Widget _buildAccountCard(AuthState auth) {
    final me = _selfUser(auth);
    return Card(
      child: Column(
        children: [
          const ListTile(
            leading: Icon(Icons.manage_accounts_outlined),
            title: Text('账号', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          _menuTile(Icons.edit_outlined, '编辑资料', () => _openEditProfile(me)),
          _menuTile(Icons.lock_outline, '账号与安全', () => _openAccountSecurity(me)),
        ],
      ),
    );
  }

  Widget _menuTile(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }

  Widget _divider() => Container(width: 1, height: 32, color: Colors.black12);

  Widget _stat(int value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text('$value',
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }

  List<Widget> _buildGuest() {
    return [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const CircleAvatar(
                radius: 32,
                child: Icon(Icons.person, size: 36),
              ),
              const SizedBox(height: 12),
              const Text('未登录',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context)
                    .push(MaterialPageRoute(
                        builder: (_) => const WebLoginPage()))
                    .then((_) => _loadMe()),
                icon: const Icon(Icons.login),
                label: const Text('登录'),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  Widget _buildAppearanceCard() {
    final settings = context.watch<SettingsState>();
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ListTile(
            leading: Icon(Icons.palette_outlined),
            title: Text('外观', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          if (!settings.dynamicColor) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('应用主题',
                      style: TextStyle(fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: [
                      for (var i = 0; i < kThemePresets.length; i++)
                        _presetItem(settings, scheme, i),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
          ],
          SwitchListTile(
            secondary: const Icon(Icons.auto_awesome),
            title: const Text('动态取色'),
            value: settings.dynamicColor,
            onChanged: (v) {
              settings.setDynamicColor(v);
              _haptic();
            },
          ),
          const Divider(height: 1),
          SwitchListTile(
            secondary: const Icon(Icons.gesture),
            title: const Text('预测式返回'),
            value: settings.predictiveBack,
            onChanged: (v) {
              settings.setPredictiveBack(v);
              _haptic();
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.animation),
            title: const Text('页面过渡动画'),
            trailing: DropdownButton<PageTransitionType>(
              value: settings.pageTransition,
              isDense: true,
              underline: const SizedBox.shrink(),
              onChanged: (t) {
                if (t != null) settings.setPageTransition(t);
              },
              items: [
                for (final t in PageTransitionType.values)
                  DropdownMenuItem(value: t, child: Text(t.label)),
              ],
            ),
          ),
          const Divider(height: 1),
          SwitchListTile(
            secondary: const Icon(Icons.vibration),
            title: const Text('震动反馈'),
            subtitle: const Text('点击与切换时轻微震动', maxLines: 2),
            value: settings.hapticsEnabled,
            onChanged: (v) {
              settings.setHaptics(v);
              if (v) HapticFeedback.selectionClick();
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.brightness_6_outlined),
            title: const Text('深色模式'),
            trailing: DropdownButton<ThemeMode>(
              value: settings.themeMode,
              isDense: true,
              underline: const SizedBox.shrink(),
              onChanged: (m) {
                if (m != null) settings.setThemeMode(m);
              },
              items: const [
                DropdownMenuItem(value: ThemeMode.system, child: Text('跟随系统')),
                DropdownMenuItem(value: ThemeMode.light, child: Text('浅色')),
                DropdownMenuItem(value: ThemeMode.dark, child: Text('深色')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _presetItem(SettingsState settings, ColorScheme scheme, int index) {
    final preset = kThemePresets[index];
    final selected = settings.themePresetIndex == index;
    return InkWell(
      onTap: () {
        settings.setThemePreset(index);
        _haptic();
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? scheme.primary : Colors.transparent,
            width: 2,
          ),
          color: selected
              ? scheme.primary.withOpacity(0.08)
              : Colors.transparent,
        ),
        child: Column(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dot(preset.primary),
                const SizedBox(width: 4),
                _dot(preset.secondary),
                const SizedBox(width: 4),
                _dot(preset.tertiary),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              preset.name,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                color: selected ? scheme.primary : scheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dot(Color color) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black12, width: 0.5),
      ),
    );
  }

  void _haptic() {
    final settings = context.read<SettingsState>();
    if (settings.hapticsEnabled) {
      HapticFeedback.selectionClick();
    }
  }
}
