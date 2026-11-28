import 'dart:convert';

import 'package:http/http.dart' as http;

import 'config.dart';
import 'models.dart';

/// API 异常，携带用户可读信息。
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.code});

  final String message;
  final int? statusCode;
  final String? code;

  @override
  String toString() => message;
}

/// 认证结果。
class AuthResult {
  AuthResult({required this.token, required this.userId});

  final String token;
  final String userId;
}

/// Flarum JSON:API 客户端。
///
/// 统一处理认证头、JSON:API 解析、错误与分页。
class ApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();

  final http.Client _client = http.Client();

  String? _token;

  /// SSO 登录后的会话 Cookie（flarum_session=xxx）。
  String? _sessionCookie;

  /// 会话对应的 CSRF Token（写操作需要）。
  String? _csrfToken;

  String? get token => _token;
  String? get sessionCookie => _sessionCookie;
  bool get isLoggedIn =>
      (_token != null && _token!.isNotEmpty) ||
      (_sessionCookie != null && _sessionCookie!.isNotEmpty);

  void setToken(String? token) => _token = token;

  /// 设置 SSO 会话（Cookie + CSRF Token）。
  void setSession(String? cookie, String? csrfToken) {
    _sessionCookie = cookie;
    _csrfToken = csrfToken;
  }

  Map<String, String> get _headers {
    final h = authHeaders;
    h['Content-Type'] = 'application/json';
    return h;
  }

  /// 认证头（不含 Content-Type）。
  ///
  /// 同时携带 API Token（若存在）与会话 Cookie + CSRF Token，
  /// 供 multipart 上传等需要认证的请求使用。
  Map<String, String> get authHeaders {
    final h = <String, String>{
      'Accept': 'application/json',
    };
    if (_token != null && _token!.isNotEmpty) {
      h['Authorization'] = 'Token $_token';
    }
    if (_sessionCookie != null && _sessionCookie!.isNotEmpty) {
      h['Cookie'] = _sessionCookie!;
      if (_csrfToken != null && _csrfToken!.isNotEmpty) {
        h['X-CSRF-Token'] = _csrfToken!;
      }
    }
    return h;
  }

  /// 拼接查询参数（Flarum 使用 page[offset] 这类带方括号的 key，需要保留）。
  static Uri _uri(String path, Map<String, String>? query) {
    var url = path.startsWith('http') ? path : '${AppConfig.apiUrl}$path';
    final uri = Uri.parse(url);
    if (query == null || query.isEmpty) return uri;
    return uri.replace(queryParameters: {
      ...uri.queryParameters,
      ...query,
    });
  }

  /// 解析响应为 [ApiDocument]。
  ApiDocument _parse(http.Response res) {
    Map<String, dynamic> json;
    try {
      json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException('服务器返回了无法解析的内容（HTTP ${res.statusCode}）',
          statusCode: res.statusCode);
    }

    final doc = ApiDocument(json);
    doc.indexIncluded();

    // Flarum 用非 2xx + errors 数组表达业务错误。
    if (res.statusCode >= 400) {
      String? code;
      final errs = json['errors'];
      if (errs is List && errs.isNotEmpty) {
        final first = errs.first;
        if (first is Map) {
          code = first['code']?.toString();
        }
      }
      throw ApiException(
        doc.error ?? '请求失败（HTTP ${res.statusCode}）',
        statusCode: res.statusCode,
        code: code,
      );
    }
    return doc;
  }

  Future<ApiDocument> get(String path, {Map<String, String>? query}) async {
    final res = await _client
        .get(_uri(path, query), headers: _headers)
        .timeout(const Duration(seconds: 20));
    return _parse(res);
  }

  Future<ApiDocument> post(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) async {
    final res = await _client
        .post(
          _uri(path, query),
          headers: _headers,
          body: body == null ? null : jsonEncode(body),
        )
        .timeout(const Duration(seconds: 30));
    return _parse(res);
  }

  Future<ApiDocument> delete(String path) async {
    final res = await _client
        .delete(_uri(path, null), headers: _headers)
        .timeout(const Duration(seconds: 20));
    return _parse(res);
  }

  Future<ApiDocument> patch(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) async {
    final res = await _client
        .patch(
          _uri(path, query),
          headers: _headers,
          body: body == null ? null : jsonEncode(body),
        )
        .timeout(const Duration(seconds: 30));
    return _parse(res);
  }

  /// 账号密码登录（Flarum /api/token）。
  Future<AuthResult> login(String identification, String password) async {
    final res = await _client
        .post(
          Uri.parse('${AppConfig.apiUrl}/token'),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'identification': identification,
            'password': password,
          }),
        )
        .timeout(const Duration(seconds: 30));

    Map<String, dynamic> json;
    try {
      json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException('登录响应解析失败（HTTP ${res.statusCode}）',
          statusCode: res.statusCode);
    }

    if (res.statusCode >= 400 || json['token'] == null) {
      final errs = json['errors'];
      String msg = '账号或密码错误';
      if (errs is List && errs.isNotEmpty && errs.first is Map) {
        msg = (errs.first as Map)['detail']?.toString() ?? msg;
      }
      throw ApiException(msg, statusCode: res.statusCode);
    }

    final token = json['token'].toString();
    final userId = (json['userId'] ?? '').toString();
    _token = token;
    return AuthResult(token: token, userId: userId);
  }

  void logout() {
    _token = null;
    _sessionCookie = null;
    _csrfToken = null;
  }

  /// 通过已登录的会话 Cookie 请求 `/api`，获取本次会话的 CSRF Token。
  /// 返回 null 表示获取失败。
  Future<String?> fetchCsrfToken(String cookie) async {
    try {
      final res = await _client
          .get(
            Uri.parse(AppConfig.apiUrl),
            headers: {
              'Accept': 'application/json',
              'Cookie': cookie,
            },
          )
          .timeout(const Duration(seconds: 20));
      return res.headers['x-csrf-token'];
    } catch (_) {
      return null;
    }
  }

  /// 用已登录的会话 Cookie 请求 `/api`，解析当前登录用户。
  ///
  /// FoF Passport 的 SSO 回调页是「关闭弹窗」脚本（白屏），
  /// 不含 `flarum-json-payload`，因此这里直接读 `/api` 的
  /// `data.relationships.actor` 与 `included` 来兜底获取用户信息。
  /// 返回 null 表示会话无效或请求失败。
  Future<Map<String, String>?> fetchSessionInfo(String cookie) async {
    try {
      final res = await _client
          .get(
            Uri.parse(AppConfig.apiUrl),
            headers: {
              'Accept': 'application/json',
              'Cookie': cookie,
            },
          )
          .timeout(const Duration(seconds: 20));

      final csrf = res.headers['x-csrf-token'] ?? '';
      final json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final data = json['data'] as Map<String, dynamic>?;
      final actor = data?['relationships']?['actor']?['data'];
      final userId = (actor is Map) ? actor['id']?.toString() : null;
      if (userId == null || userId.isEmpty) return null;

      var username = '';
      var displayName = '';
      var avatarUrl = '';
      final included = json['included'];
      if (included is List) {
        for (final inc in included) {
          if (inc is Map &&
              inc['type'] == 'users' &&
              inc['id'].toString() == userId) {
            final a = inc['attributes'] as Map<String, dynamic>?;
            username = a?['username']?.toString() ?? '';
            displayName = a?['displayName']?.toString() ?? '';
            avatarUrl = a?['avatarUrl']?.toString() ?? '';
            break;
          }
        }
      }

      return {
        'userId': userId,
        'csrfToken': csrf,
        'username': username,
        'displayName': displayName,
        'avatarUrl': avatarUrl,
      };
    } catch (_) {
      return null;
    }
  }
}
