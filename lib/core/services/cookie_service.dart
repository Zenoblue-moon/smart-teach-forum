import 'package:flutter/services.dart';

/// 通过 Android 原生 CookieManager 读取 WebView Cookie。
///
/// 论坛的登录会话 Cookie（flarum_session）是 HttpOnly 的，
/// `document.cookie` 无法读取，因此走原生 Channel。
class CookieService {
  CookieService._();

  static const MethodChannel _channel = MethodChannel('smart_teach/cookies');

  /// 获取指定域名下所有 Cookie（含 HttpOnly）。
  static Future<String> getCookies(String url) async {
    try {
      final result = await _channel.invokeMethod<String>('getCookies', {'url': url});
      return result ?? '';
    } catch (_) {
      return '';
    }
  }

  /// 清空 WebView Cookie（退出登录时使用）。
  static Future<void> clearCookies() async {
    try {
      await _channel.invokeMethod('clearCookies');
    } catch (_) {
      // 忽略
    }
  }

  /// 从 Cookie 字符串中提取指定键的值。
  static String? extract(String cookieStr, String key) {
    final parts = cookieStr.split(';');
    for (final p in parts) {
      final kv = p.trim().split('=');
      if (kv.length >= 2 && kv[0] == key) {
        return kv.sublist(1).join('=');
      }
    }
    return null;
  }
}
