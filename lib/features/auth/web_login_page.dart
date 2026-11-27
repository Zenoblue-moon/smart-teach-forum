import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/api_client.dart';
import '../../core/config.dart';
import '../../core/services/app_state.dart';
import '../../core/services/cookie_service.dart';
import '../../core/services/forum_service.dart';

/// 内置浏览器 SSO 登录。
///
/// 打开论坛的 FoF Passport 授权入口（/auth/passport），
/// 经 auth.smart-teach.cn 完成 OAuth 登录后，从 WebView 提取：
/// 1. 登录会话 Cookie（flarum_session，HttpOnly，走原生 Channel 读取）
/// 2. 页面 payload 里的 session.userId 与 session.csrfToken
/// 3. payload resources 里的当前用户信息
class WebLoginPage extends StatefulWidget {
  const WebLoginPage({Key? key}) : super(key: key);

  @override
  State<WebLoginPage> createState() => _WebLoginPageState();
}

class _WebLoginPageState extends State<WebLoginPage> {
  WebViewController? _controller;
  bool _checking = false;
  bool _done = false;
  bool _loading = true;
  int _attempts = 0;

  void _onWebViewCreated(WebViewController controller) {
    _controller = controller;
  }

  /// 页面加载完成后，若已回到论坛域名，则尝试提取登录态。
  Future<void> _onPageFinished(String url) async {
    if (_done || _checking) return;
    if (!url.startsWith(AppConfig.baseUrl)) return;
    if (_attempts >= 10) return;

    _checking = true;
    try {
      // 等 Flarum 前端完成 OAuth 回调后的会话落地，再读取 payload。
      await Future.delayed(const Duration(milliseconds: 1200));
      final session = await _extractSession();
      if (session != null) {
        await _complete(session);
      }
    } finally {
      _checking = false;
    }
  }

  Future<Map<String, String>?> _extractSession() async {
    final ctrl = _controller;
    if (ctrl == null) return null;

    // 1. 通过原生 CookieManager 读取 HttpOnly 的 flarum_session。
    final cookieStr = await CookieService.getCookies(AppConfig.baseUrl);
    final session = CookieService.extract(cookieStr, 'flarum_session');
    if (session == null || session.isEmpty) {
      _attempts++;
      return null;
    }

    // 2. 优先从页面 payload 提取 session.userId / csrfToken 与当前用户。
    final payload = await _readPayload(ctrl);
    if (payload != null) {
      return {
        'cookie': cookieStr,
        'csrfToken': payload['csrfToken'] ?? '',
        'userId': payload['userId']!,
        'username': payload['username'] ?? '',
        'displayName': payload['displayName'] ?? '',
        'avatarUrl': payload['avatarUrl'] ?? '',
      };
    }

    // 3. 兜底：FoF Passport 的 SSO 回调页是「关闭弹窗」脚本（白屏），
    //    不含 payload，此时用已登录的 flarum_session 直接请求 /api 获取用户。
    final info = await ApiClient.instance.fetchSessionInfo(cookieStr);
    if (info != null && (info['userId']?.isNotEmpty ?? false)) {
      return {
        'cookie': cookieStr,
        'csrfToken': info['csrfToken'] ?? '',
        'userId': info['userId']!,
        'username': info['username'] ?? '',
        'displayName': info['displayName'] ?? '',
        'avatarUrl': info['avatarUrl'] ?? '',
      };
    }

    _attempts++;
    return null;
  }

  /// 读取页面 `flarum-json-payload`，成功返回用户信息 map，失败返回 null。
  Future<Map<String, String>?> _readPayload(WebViewController ctrl) async {
    String payloadJson = '';
    try {
      payloadJson = (await ctrl.evaluateJavascript(_payloadJs)).trim();
    } catch (_) {
      payloadJson = '';
    }

    if (payloadJson.isEmpty ||
        payloadJson == 'GUEST' ||
        payloadJson == 'ERR' ||
        payloadJson == 'null') {
      return null;
    }

    Map<String, dynamic>? payload;
    try {
      payload = jsonDecode(payloadJson) as Map<String, dynamic>;
    } catch (_) {
      payload = null;
    }
    final userId = payload?['userId']?.toString();
    if (userId == null || userId.isEmpty || userId == '0') {
      return null;
    }

    final csrf = payload?['csrfToken']?.toString() ?? '';
    var username = payload?['username']?.toString() ?? '';
    var displayName = payload?['displayName']?.toString() ?? '';
    var avatarUrl = payload?['avatarUrl']?.toString() ?? '';

    // 若 payload 里没有用户信息，用 API 补取。
    if (username.isEmpty && displayName.isEmpty) {
      final user = await ForumService.instance.getUser(userId);
      if (user != null) {
        username = user.username;
        displayName = user.displayName;
        avatarUrl = user.avatarUrl ?? '';
      }
    }

    return {
      'userId': userId,
      'csrfToken': csrf,
      'username': username,
      'displayName': displayName,
      'avatarUrl': avatarUrl,
    };
  }

  Future<void> _complete(Map<String, String> session) async {
    if (_done || !mounted) return;
    _done = true;

    // payload 里若没有 csrfToken，则用会话 Cookie 额外请求一次 /api 换取。
    var csrf = session['csrfToken'] ?? '';
    if (csrf.isEmpty) {
      csrf = await ApiClient.instance.fetchCsrfToken(session['cookie']!) ?? '';
    }

    if (!mounted) return;

    await context.read<AuthState>().loginWithSession(
          cookie: session['cookie']!,
          csrfToken: csrf.isEmpty ? null : csrf,
          userId: session['userId'],
          username: (session['username']?.isEmpty ?? true)
              ? session['userId']
              : session['username'],
          displayName: session['displayName'],
          avatarUrl: session['avatarUrl'],
        );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('登录成功')),
    );
    Navigator.of(context).pop(true);
  }

  /// 从 Flarum 前端 payload 中提取登录态。
  /// 未登录返回 GUEST，读取失败返回 ERR，成功返回 JSON 字符串。
  static const String _payloadJs = '''
(function(){
  try {
    var el = document.getElementById('flarum-json-payload');
    if (!el) return 'ERR';
    var p = JSON.parse(el.textContent);
    var s = p.session || {};
    var userId = s.userId || 0;
    if (!userId || userId <= 0) return 'GUEST';
    var r = { userId: String(userId), csrfToken: s.csrfToken || '' };
    var resources = p.resources || [];
    for (var i = 0; i < resources.length; i++) {
      var x = resources[i];
      if (x.type === 'users' && String(x.id) === String(userId)) {
        var a = x.attributes || {};
        r.username = a.username || '';
        r.displayName = a.displayName || a.username || '';
        r.avatarUrl = a.avatarUrl || '';
        break;
      }
    }
    return JSON.stringify(r);
  } catch (e) { return 'ERR'; }
})()
''';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('登录'),
        actions: [
          IconButton(
            tooltip: '刷新',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _done = false;
              _attempts = 0;
              _controller?.reload();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          WebView(
            initialUrl: AppConfig.loginPath,
            javascriptMode: JavascriptMode.unrestricted,
            onWebViewCreated: _onWebViewCreated,
            onPageFinished: _onPageFinished,
            onProgress: (progress) {
              if (mounted) setState(() => _loading = progress < 100);
            },
            onWebResourceError: (error) {
              if (mounted) setState(() => _loading = false);
            },
          ),
          if (_loading)
            const Align(
              alignment: Alignment.topCenter,
              child: LinearProgressIndicator(minHeight: 2),
            ),
        ],
      ),
    );
  }
}
