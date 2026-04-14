import 'package:flutter/material.dart';

class AppTheme {
  // Brand colors
  static const primary = Color(0xFF185FA5);
  static const primaryLight = Color(0xFF378ADD);
  static const primarySurface = Color(0xFFE6F1FB);

  static const success = Color(0xFF1D9E75);
  static const successSurface = Color(0xFFE1F5EE);

  static const error = Color(0xFFE24B4A);
  static const errorSurface = Color(0xFFFCEBEB);

  static const warning = Color(0xFFEF9F27);
  static const warningSurface = Color(0xFFFAEEDA);

  // Neutral
  static const bg = Color(0xFFFFFFFF);
  static const bgSecondary = Color(0xFFF8F7F4);
  static const bgTertiary = Color(0xFFF1EFE8);

  static const textPrimary = Color(0xFF1A1A18);
  static const textSecondary = Color(0xFF5F5E5A);
  static const textTertiary = Color(0xFF888780);

  static const border = Color(0xFFD3D1C7);
  static const borderLight = Color(0xFFE8E6DF);

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: bgSecondary,
    appBarTheme: const AppBarTheme(
      backgroundColor: bg,
      foregroundColor: textPrimary,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        color: textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
    ),
    cardTheme: CardThemeData(
      color: bg,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: borderLight),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: bg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: error),
      ),
      hintStyle: const TextStyle(color: textTertiary, fontSize: 14),
      labelStyle: const TextStyle(color: textSecondary, fontSize: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primary,
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: borderLight,
      thickness: 0.5,
      space: 0,
    ),
  );
}
