import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/services/app_state.dart';
import 'core/theme_presets.dart';
import 'features/shell/main_shell.dart';

class SmartTeachApp extends StatelessWidget {
  const SmartTeachApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsState>();

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        return MaterialApp(
          title: '智教联盟论坛',
          debugShowCheckedModeBanner: false,
          themeMode: settings.themeMode,
          theme: _buildTheme(Brightness.light, settings, lightDynamic),
          darkTheme: _buildTheme(Brightness.dark, settings, darkDynamic),
          home: const MainShell(),
        );
      },
    );
  }

  ThemeData _buildTheme(
    Brightness brightness,
    SettingsState settings,
    ColorScheme? dynamicScheme,
  ) {
    final isDark = brightness == Brightness.dark;
    final preset = settings.themePreset;

    final ColorScheme scheme;
    if (settings.dynamicColor && dynamicScheme != null) {
      scheme = dynamicScheme;
    } else {
      scheme = ColorScheme.fromSeed(
        seedColor: preset.primary,
        brightness: brightness,
      ).copyWith(
        primary: preset.primary,
        onPrimary: _onColor(preset.primary),
        secondary: preset.secondary,
        onSecondary: _onColor(preset.secondary),
        tertiary: preset.tertiary,
        onTertiary: _onColor(preset.tertiary),
      );
    }

    final tabLabel = _tabLabelColor(scheme, isDark);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor:
          isDark ? const Color(0xFF121212) : const Color(0xFFF7F8FA),
      pageTransitionsTheme: _transitions(settings.pageTransition),
      tabBarTheme: TabBarTheme(
        labelColor: tabLabel,
        unselectedLabelColor: scheme.onSurfaceVariant,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light.copyWith(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.light,
                systemNavigationBarColor: Colors.transparent,
                systemNavigationBarIconBrightness: Brightness.light,
              )
            : SystemUiOverlayStyle.dark.copyWith(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.dark,
                systemNavigationBarColor: Colors.transparent,
                systemNavigationBarIconBrightness: Brightness.dark,
              ),
      ),
      cardTheme: CardTheme(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: DividerThemeData(
        color: isDark ? Colors.white12 : Colors.black12,
        thickness: 0.6,
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      textTheme: Typography.material2021(platform: TargetPlatform.android)
          .black
          .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface),
    );
  }

  /// 根据颜色亮度返回对比度足够的文字色（深色配白字，浅色配黑字）。
  Color _onColor(Color color) {
    return ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : Colors.black;
  }

  /// Tab 选中标签色：保留主题色相，但保证在浅色/深色背景下都清晰可读。
  ///
  /// Flutter 3.0 的 TabBar 默认取 `primaryTextTheme` 的颜色（等于 onPrimary），
  /// 浅色模式下会变成白色，因此在主题层显式指定可读的颜色。
  Color _tabLabelColor(ColorScheme scheme, bool isDark) {
    final base = scheme.primary;
    final hsl = HSLColor.fromColor(base);
    final lightness = hsl.lightness;
    if (isDark) {
      // 深色背景需要足够亮的文字。
      if (lightness < 0.55) {
        return hsl.withLightness(0.62).toColor();
      }
      return base;
    }
    // 浅色背景需要足够深的文字。
    if (lightness > 0.45) {
      return hsl.withLightness(0.40).toColor();
    }
    return base;
  }

  PageTransitionsTheme _transitions(PageTransitionType type) {
    PageTransitionsBuilder builder;
    switch (type) {
      case PageTransitionType.fadeUpwards:
        builder = const FadeUpwardsPageTransitionsBuilder();
        break;
      case PageTransitionType.openUpwards:
        builder = const OpenUpwardsPageTransitionsBuilder();
        break;
      case PageTransitionType.zoom:
        builder = const ZoomPageTransitionsBuilder();
        break;
      case PageTransitionType.slide:
        builder = const CupertinoPageTransitionsBuilder();
        break;
      case PageTransitionType.fade:
        builder = const _FadePageTransitionsBuilder();
        break;
    }
    return PageTransitionsTheme(builders: {
      for (final platform in TargetPlatform.values) platform: builder,
    });
  }
}

/// 纯淡入淡出过渡。
class _FadePageTransitionsBuilder extends PageTransitionsBuilder {
  const _FadePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(opacity: animation, child: child);
  }
}
