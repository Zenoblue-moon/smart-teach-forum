import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../core/services/forum_service.dart';
import '../../core/utils.dart';

/// 应用内账号与安全（账号信息 + 修改密码），不跳转论坛网页。
class AccountSecurityPage extends StatefulWidget {
  const AccountSecurityPage({Key? key, required this.user}) : super(key: key);

  final ForumUser user;

  @override
  State<AccountSecurityPage> createState() => _AccountSecurityPageState();
}

class _AccountSecurityPageState extends State<AccountSecurityPage> {
  final _pwdCtrl = TextEditingController();
  final _pwd2Ctrl = TextEditingController();
  bool _showPwd = false;
  bool _saving = false;

  @override
  void dispose() {
    _pwdCtrl.dispose();
    _pwd2Ctrl.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (_saving) return;
    final pwd = _pwdCtrl.text;
    final pwd2 = _pwd2Ctrl.text;
    if (pwd.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('新密码至少 6 位')),
      );
      return;
    }
    if (pwd != pwd2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('两次输入的密码不一致')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await ForumService.instance.changePassword(widget.user.id, pwd);
      if (!mounted) return;
      _pwdCtrl.clear();
      _pwd2Ctrl.clear();
      setState(() => _showPwd = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('密码已修改')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('修改失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    return Scaffold(
      appBar: AppBar(title: const Text('账号与安全')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              children: [
                _infoTile('用户名', u.username),
                _infoTile('UID', u.id),
                _infoTile('注册时间', formatDateTime(u.joinTime)),
                _infoTile('最后在线', timeAgo(u.lastSeenAt)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('修改密码',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          TextField(
            controller: _pwdCtrl,
            obscureText: !_showPwd,
            decoration: const InputDecoration(
              labelText: '新密码',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pwd2Ctrl,
            obscureText: !_showPwd,
            decoration: const InputDecoration(
              labelText: '确认新密码',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _saving ? null : _changePassword,
            icon: const Icon(Icons.lock_reset),
            label: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('修改密码'),
          ),
        ],
      ),
    );
  }

  Widget _infoTile(String label, String value) {
    return ListTile(
      dense: true,
      title: Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
      trailing: Text(
        value.isEmpty ? '—' : value,
        style: const TextStyle(fontSize: 14),
      ),
    );
  }
}
