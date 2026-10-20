// ============================================================
//  lib/core/theme/app_theme.dart
// ============================================================
import 'package:flutter/material.dart';

class AppTheme {
  static const Color terra = Color(0xFFC8714A);
  static const Color sand = Color(0xFFE8C9A0);
  static const Color blush = Color(0xFFF2A58B);
  static const Color deepBg = Color(0xFF0F0F0F);
  static const Color cardBg = Color(0xFF1C1712);
  static const Color muted = Color(0xFF8A7A6E);
  static const Color success = Color(0xFF6AB187);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: deepBg,
      colorScheme: const ColorScheme.dark(
        primary: terra,
        secondary: sand,
        surface: cardBg,
        onPrimary: Colors.white,
        onSurface: Color(0xFFF5F0EC),
      ),
      fontFamily: 'Inter',
      appBarTheme: const AppBarTheme(
        backgroundColor: deepBg,
        elevation: 0,
        iconTheme: IconThemeData(color: terra),
        titleTextStyle: TextStyle(
          color: Color(0xFFF5F0EC),
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: Color(0xFFF5F0EC),
          fontWeight: FontWeight.w900,
          fontSize: 28,
        ),
        headlineMedium: TextStyle(
          color: Color(0xFFF5F0EC),
          fontWeight: FontWeight.w700,
          fontSize: 22,
        ),
        bodyLarge: TextStyle(color: Color(0xFFF5F0EC), fontSize: 16),
        bodyMedium: TextStyle(color: Color(0xFF8A7A6E), fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: terra,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          minimumSize: const Size(double.infinity, 54),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
