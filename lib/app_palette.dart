import 'package:flutter/material.dart';

/// アプリ全体のカラーパレット
class AppPalette extends ThemeExtension<AppPalette> {
  final String id;
  final String jaName;
  final Color leftPanel;   // ホーム左パネル背景
  final Color background;  // 全画面の背景
  final Color primary;     // メインボタン色
  final Color secondary;   // サブボタン・アクセント色

  const AppPalette({
    required this.id,
    required this.jaName,
    required this.leftPanel,
    required this.background,
    required this.primary,
    required this.secondary,
  });

  @override
  AppPalette copyWith({
    String? id, String? jaName,
    Color? leftPanel, Color? background,
    Color? primary, Color? secondary,
  }) => AppPalette(
    id: id ?? this.id,
    jaName: jaName ?? this.jaName,
    leftPanel: leftPanel ?? this.leftPanel,
    background: background ?? this.background,
    primary: primary ?? this.primary,
    secondary: secondary ?? this.secondary,
  );

  @override
  AppPalette lerp(AppPalette? other, double t) {
    if (other == null) return this;
    return AppPalette(
      id: other.id,
      jaName: other.jaName,
      leftPanel: Color.lerp(leftPanel, other.leftPanel, t)!,
      background: Color.lerp(background, other.background, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
    );
  }
}

/// ビルトインパレット一覧
class AppPalettes {
  /// げんき（デフォルト・明るい）
  static const vivid = AppPalette(
    id: 'vivid',
    jaName: 'げんき',
    leftPanel:  Color(0xFFF0E040),
    background: Color(0xFFF5EDD8),
    primary:    Color(0xFF4A9FE8),
    secondary:  Color(0xFFEE6B9E),
  );

  /// やさしい（パステル）
  static const gentle = AppPalette(
    id: 'gentle',
    jaName: 'やさしい',
    leftPanel:  Color(0xFFB0D4C0),
    background: Color(0xFFF0F5F0),
    primary:    Color(0xFF5090B8),
    secondary:  Color(0xFFB87090),
  );

  /// そら（ブルー系）
  static const sky = AppPalette(
    id: 'sky',
    jaName: 'そら',
    leftPanel:  Color(0xFF8EC8E8),
    background: Color(0xFFEEF5FA),
    primary:    Color(0xFF2878C0),
    secondary:  Color(0xFFD06070),
  );

  /// ゆうやけ（オレンジ系）
  static const sunset = AppPalette(
    id: 'sunset',
    jaName: 'ゆうやけ',
    leftPanel:  Color(0xFFF0A050),
    background: Color(0xFFFBF0E8),
    primary:    Color(0xFFC06040),
    secondary:  Color(0xFF8060B8),
  );

  static const all = [vivid, gentle, sky, sunset];

  static AppPalette findById(String id) =>
      all.firstWhere((p) => p.id == id, orElse: () => vivid);
}

/// アプリグローバルのパレット状態（main.dart で初期化）
final paletteNotifier = ValueNotifier<AppPalette>(AppPalettes.vivid);

/// ThemeData にパレットを適用したものを返す
ThemeData buildTheme(AppPalette p) {
  return ThemeData(
    scaffoldBackgroundColor: p.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: p.primary,
      surface: p.background,
    ),
    fontFamily: 'sans-serif',
    extensions: [p],
  );
}

/// context からパレットを取得するヘルパー
AppPalette paletteOf(BuildContext context) =>
    Theme.of(context).extension<AppPalette>() ?? AppPalettes.vivid;
