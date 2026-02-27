import 'package:flutter/material.dart';

class AppTheme {
  // Panel colors
  static const Color background = Color(0xFFF5EDD8);
  static const Color yellowPanel = Color(0xFFF0E040);
  static const Color blueAccent = Color(0xFF4A9FE8);
  static const Color pinkAccent = Color(0xFFEE6B9E);
  static const Color levelGold = Color(0xFFF0C030);
  static const Color white = Colors.white;
  static const Color lightGray = Color(0xFFEAEAEA);
  static const Color textGray = Color(0xFFAAAAAA);
  static const Color darkText = Color(0xFF333333);
  static const Color greenStroke = Color(0xFF88BB88);

  // Canvas
  static const Color canvasBg = Color(0xFFFBFBFB);
  static const Color canvasLine = Color(0xFFCED8EC);
  static const Color canvasDash = Color(0xFFB0BCDC);
  static const Color refChar = Color(0xFFDDDDDD);
  static const Color inkColor = Color(0xFF1A1A1A);

  static ThemeData build() {
    return ThemeData(
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: blueAccent,
        surface: background,
      ),
      fontFamily: 'sans-serif',
    );
  }
}
