import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api_client.dart';
import '../config.dart';
import '../theme_presets.dart';

/// 登录状态。
class AuthState extends ChangeNotifier {
  String? _token;
  String? _userId;
  String? _username;
  String? _displayName;
  String? _avatarUrl;
  String? _sessionCookie;

  String? get token => _token;
  String? get userId => _userId;
  String? get username => _username;
  String? get displayName => _displayName;
  String? get avatarUrl => _avatarUrl;
  String? get sessionCookie => _sessionCookie;
  bool get isLoggedIn =>
      (_token != null && _token!.isNotEmpty) ||
      (_sessionCookie != null && _sessionCookie!.isNotEmpty);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(AppConfig.kToken);
    _userId = prefs.getString(AppConfig.kUserId);
    _username = prefs.getString(AppConfig.kUsername);
    _displayName = prefs.getString(AppConfig.kDisplayName);
    _avatarUrl = prefs.getString(AppConfig.kAvatarUrl);
    _sessionCookie = prefs.getString(AppConfig.kSessionCookie);
    final csrf = prefs.getString(AppConfig.kCsrfToken);
    ApiClient.instance.setToken(_token);
    ApiClient.instance.setSession(_sessionCookie, csrf);
    notifyListeners();
  }

  Future<void> login(String identification, String password) async {
    final result = await ApiClient.instance.login(identification, password);
    _token = result.token;
    _userId = result.userId;
    _username = identification;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConfig.kToken, result.token);
    await prefs.setString(AppConfig.kUserId, result.userId);
    await prefs.setString(AppConfig.kUsername, identification);
    notifyListeners();
  }

  /// SSO 登录成功后的会话落地。
  Future<void> loginWithSession({
    required String cookie,
    required String? csrfToken,
    required String? userId,
    required String? username,
    required String? displayName,
    required String? avatarUrl,
  }) async {
    _sessionCookie = cookie;
    _userId = userId;
    _username = username;
    _displayName = displayName;
    _avatarUrl = avatarUrl;
    ApiClient.instance.setSession(cookie, csrfToken);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConfig.kSessionCookie, cookie);
    if (csrfToken != null) await prefs.setString(AppConfig.kCsrfToken, csrfToken);
    if (userId != null) await prefs.setString(AppConfig.kUserId, userId);
    if (username != null) await prefs.setString(AppConfig.kUsername, username);
    if (displayName != null) {
      await prefs.setString(AppConfig.kDisplayName, displayName);
    }
    if (avatarUrl != null) await prefs.setString(AppConfig.kAvatarUrl, avatarUrl);
    notifyListeners();
  }

  Future<void> logout() async {
    ApiClient.instance.logout();
    _token = null;
    _userId = null;
    _username = null;
    _displayName = null;
    _avatarUrl = null;
    _sessionCookie = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConfig.kToken);
    await prefs.remove(AppConfig.kUserId);
    await prefs.remove(AppConfig.kUsername);
    await prefs.remove(AppConfig.kDisplayName);
    await prefs.remove(AppConfig.kAvatarUrl);
    await prefs.remove(AppConfig.kSessionCookie);
    await prefs.remove(AppConfig.kCsrfToken);
    notifyListeners();
  }
}

/// 外观与偏好设置。
class SettingsState extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  int _themePresetIndex = 0;
  bool _dynamicColor = false;
  bool _predictiveBack = false;
  PageTransitionType _pageTransition = PageTransitionType.fadeUpwards;
  bool _haptics = true;
  List<String> _recentSearches = [];

  ThemeMode get themeMode => _themeMode;
  ThemePreset get themePreset =>
      kThemePresets[_themePresetIndex.clamp(0, kThemePresets.length - 1)];
  int get themePresetIndex =>
      _themePresetIndex.clamp(0, kThemePresets.length - 1);
  Color get accentColor => themePreset.primary;
  bool get dynamicColor => _dynamicColor;
  bool get predictiveBack => _predictiveBack;
  PageTransitionType get pageTransition => _pageTransition;
  bool get hapticsEnabled => _haptics;
  List<String> get recentSearches => List.unmodifiable(_recentSearches);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString(AppConfig.kThemeMode);
    if (mode == 'light') {
      _themeMode = ThemeMode.light;
    } else if (mode == 'dark') {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.system;
    }
    _themePresetIndex = prefs.getInt(AppConfig.kThemePreset) ?? 0;
    _dynamicColor = prefs.getBool(AppConfig.kDynamicColor) ?? false;
    _predictiveBack = prefs.getBool(AppConfig.kPredictiveBack) ?? false;
    final pt = prefs.getString(AppConfig.kPageTransition);
    _pageTransition = PageTransitionType.values.firstWhere(
      (e) => e.name == pt,
      orElse: () => PageTransitionType.fadeUpwards,
    );
    _haptics = prefs.getBool(AppConfig.kHaptics) ?? true;
    _recentSearches = prefs.getStringList(AppConfig.kRecentSearches) ?? [];
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      AppConfig.kThemeMode,
      mode == ThemeMode.light
          ? 'light'
          : mode == ThemeMode.dark
              ? 'dark'
              : 'system',
    );
  }

  Future<void> setThemePreset(int index) async {
    if (index < 0 || index >= kThemePresets.length) return;
    _themePresetIndex = index;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AppConfig.kThemePreset, index);
  }

  Future<void> setDynamicColor(bool value) async {
    _dynamicColor = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConfig.kDynamicColor, value);
  }

  Future<void> setPredictiveBack(bool value) async {
    _predictiveBack = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConfig.kPredictiveBack, value);
  }

  Future<void> setPageTransition(PageTransitionType type) async {
    _pageTransition = type;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConfig.kPageTransition, type.name);
  }

  Future<void> setHaptics(bool value) async {
    _haptics = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConfig.kHaptics, value);
  }

  Future<void> addRecentSearch(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    _recentSearches.remove(q);
    _recentSearches.insert(0, q);
    if (_recentSearches.length > 10) {
      _recentSearches = _recentSearches.sublist(0, 10);
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(AppConfig.kRecentSearches, _recentSearches);
  }

  Future<void> clearRecentSearches() async {
    _recentSearches = [];
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConfig.kRecentSearches);
  }
}
