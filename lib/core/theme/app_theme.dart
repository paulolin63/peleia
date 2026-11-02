// ============================================================
//  lib/core/theme/app_theme.dart
//  Identidade Visual PeleIA: Alinhada com o Ícone Oficial do App
//  (Verde Botânico / Sálvia, Branco Pérola e Nude Pêssego Radiante)
// ============================================================
import 'package:flutter/material.dart';

class AppTheme {
  // ── 🌿 Paleta Primária Botânica (Extraída do Círculo do Ícone) ─
  static const Color primary = Color(0xFF5E9C42); // Verde herba/sálvia vibrante e elegante
  static const Color primaryLight = Color(0xFF88BE63); // Verde matcha suave do anel do ícone
  static const Color primarySoft = Color(0xFFEDF5E8); // Lavagem botânica suave para pills e badges
  static const Color primaryDark = Color(0xFF3F6E2A); // Verde floresta profundo para ênfase

  // ── 🌸 Pêssego / Nude Radiante (Extraído do Tom de Pele do Ícone) ─
  static const Color peach = Color(0xFFEAA07A); // Pêssego dourado aquecido
  static const Color peachLight = Color(0xFFF9DFD2); // Pêssego claro
  static const Color peachSoft = Color(0xFFFDF4ED); // Lavagem pêssego suave
  static const Color gold = Color(0xFFD4973B); // Dourado âmbar para alerta UV / FPS

  // ── 🏛️ Superfícies e Fundos (Estética Skincare Clean & Luminosa) ─
  static const Color bg = Color(0xFFF8FAF6); // Branco pérola suave (idêntico ao fundo do launcher)
  static const Color surface = Color(0xFFFFFFFF); // Branco puro para cartões clínicos
  static const Color surfaceMuted = Color(0xFFF0F5EE); // Superfície atenuada para pills/seletores
  static const Color border = Color(0xFFE2EBE0); // Borda sutil de cartões
  static const Color borderSubtle = Color(0xFFEBF0E9); // Borda ultrafina

  // ── 🖋️ Tipografia e Alto Contraste ─
  static const Color textPrimary = Color(0xFF192418); // Carvão florestal escuro (leitura ultra nítida)
  static const Color textSecondary = Color(0xFF586B56); // Cinza esverdeado para subtítulos
  static const Color textMuted = Color(0xFF8B9C89); // Texto secundário atenuado

  // ── 🎯 Feedback e Status de Pele ─
  static const Color success = Color(0xFF48A03D); // Pele saudável / etapa concluída
  static const Color warning = Color(0xFFE59533); // Atenção / oleosidade moderada
  static const Color error = Color(0xFFD9534F); // Irritação alta / alerta

  // ── 🔄 Aliases de Compatibilidade Reversa ─
  static const Color terra = primary;
  static const Color sand = peachLight;
  static const Color blush = peach;
  static const Color deepBg = bg;
  static const Color cardBg = surface;
  static const Color muted = textSecondary;

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: bg,
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: peach,
        surface: surface,
        onPrimary: Colors.white,
        onSurface: textPrimary,
      ),
      fontFamily: 'Inter',
      appBarTheme: const AppBarTheme(
        backgroundColor: bg,
        elevation: 0,
        iconTheme: IconThemeData(color: primary),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.w900,
          fontSize: 28,
        ),
        headlineMedium: TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 22,
        ),
        bodyLarge: TextStyle(color: textPrimary, fontSize: 16),
        bodyMedium: TextStyle(color: textSecondary, fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
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

  // Compatibilidade com main.dart
  static ThemeData get darkTheme => lightTheme;
}
