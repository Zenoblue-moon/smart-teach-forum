import 'package:flutter/material.dart';

/// 应用主题预设。
///
/// 每种预设包含三种颜色：主色（primary）、副色（secondary）、点缀色（tertiary），
/// 三者共同构成一套完整的 Material 3 色彩方案。
class ThemePreset {
  const ThemePreset({
    required this.name,
    required this.primary,
    required this.secondary,
    required this.tertiary,
  });

  final String name;
  final Color primary;
  final Color secondary;
  final Color tertiary;

  int get primaryValue => primary.value;
}

/// 内置主题预设（至少 5 种）。
const List<ThemePreset> kThemePresets = [
  ThemePreset(
    name: '智教绿',
    primary: Color(0xFF26A03D),
    secondary: Color(0xFF1068AF),
    tertiary: Color(0xFFFB8C00),
  ),
  ThemePreset(
    name: '海洋蓝',
    primary: Color(0xFF1068AF),
    secondary: Color(0xFF26A03D),
    tertiary: Color(0xFF00ACC1),
  ),
  ThemePreset(
    name: '热情红',
    primary: Color(0xFFE53935),
    secondary: Color(0xFFFB8C00),
    tertiary: Color(0xFF8E24AA),
  ),
  ThemePreset(
    name: '优雅紫',
    primary: Color(0xFF8E24AA),
    secondary: Color(0xFFE53935),
    tertiary: Color(0xFF26A03D),
  ),
  ThemePreset(
    name: '活力橙',
    primary: Color(0xFFFB8C00),
    secondary: Color(0xFFE53935),
    tertiary: Color(0xFF1068AF),
  ),
  ThemePreset(
    name: '静谧青',
    primary: Color(0xFF00ACC1),
    secondary: Color(0xFF1068AF),
    tertiary: Color(0xFF26A03D),
  ),
];

/// 页面过渡动画类型。
enum PageTransitionType {
  fadeUpwards,
  openUpwards,
  zoom,
  slide,
  fade,
}

extension PageTransitionTypeExt on PageTransitionType {
  String get label {
    switch (this) {
      case PageTransitionType.fadeUpwards:
        return '淡入上移';
      case PageTransitionType.openUpwards:
        return '向上展开';
      case PageTransitionType.zoom:
        return '缩放';
      case PageTransitionType.slide:
        return '左右滑动';
      case PageTransitionType.fade:
        return '淡入淡出';
    }
  }
}
