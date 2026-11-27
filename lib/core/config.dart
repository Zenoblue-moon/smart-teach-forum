/// 站点配置
class AppConfig {
  AppConfig._();

  /// 论坛基础地址
  static const String baseUrl = 'https://forum.smart-teach.cn';

  /// Flarum JSON:API 地址
  static const String apiUrl = 'https://forum.smart-teach.cn/api';

  /// 论坛名称
  static const String siteName = '智教联盟论坛';

  /// 应用版本号
  static const String appVersion = 'v1.2';

  /// 站点主色（绿色）
  static const int primaryColorValue = 0xFF26A03D;

  /// 站点副色（蓝）
  static const int secondaryColorValue = 0xFF1068AF;

  /// 每页加载数量
  static const int pageSize = 20;

  /// 本地存储键
  static const String kToken = 'auth_token';
  static const String kUserId = 'auth_user_id';
  static const String kUsername = 'auth_username';
  static const String kDisplayName = 'auth_display_name';
  static const String kAvatarUrl = 'auth_avatar_url';
  static const String kSessionCookie = 'auth_session_cookie';
  static const String kCsrfToken = 'auth_csrf_token';
  static const String kThemeMode = 'theme_mode';
  static const String kAccentColor = 'accent_color';
  static const String kThemePreset = 'theme_preset';
  static const String kDynamicColor = 'dynamic_color';
  static const String kPredictiveBack = 'predictive_back';
  static const String kPageTransition = 'page_transition';
  static const String kHaptics = 'haptics_enabled';
  static const String kRecentSearches = 'recent_searches';

  /// 登录相关路径
  static const String loginPath = '$baseUrl/auth/passport';
}
