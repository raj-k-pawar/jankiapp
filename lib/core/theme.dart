import 'package:flutter/material.dart';

/// Brand colours — the same forest green and gold as the website.
class AppColors {
  static const Color forest = Color(0xFF1A4D2E);
  static const Color forestDark = Color(0xFF0D2B17);
  static const Color leaf = Color(0xFF2D7A4F);
  static const Color gold = Color(0xFFF5C451);
  static const Color goldDark = Color(0xFFE0A52E);
  static const Color cream = Color(0xFFF6F4EC);
  static const Color ink = Color(0xFF1F2B1F);
  static const Color muted = Color(0xFF6B756B);
  static const Color line = Color(0xFFE2E8E2);
  static const Color danger = Color(0xFFC0392B);
  static const Color dangerSoft = Color(0xFFFDECEA);
  static const Color success = Color(0xFF276536);
  static const Color successSoft = Color(0xFFEAF9EB);
  static const Color warn = Color(0xFF9A6700);
  static const Color warnSoft = Color(0xFFFFF4D6);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.leaf,
    primary: AppColors.forest,
    secondary: AppColors.goldDark,
    surface: Colors.white,
    error: AppColors.danger,
  );

  OutlineInputBorder border(Color c, [double w = 1.2]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: c, width: w),
      );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.cream,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.forest,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: border(AppColors.line),
      enabledBorder: border(AppColors.line),
      focusedBorder: border(AppColors.leaf, 2),
      errorBorder: border(AppColors.danger),
      focusedErrorBorder: border(AppColors.danger, 2),
      labelStyle: const TextStyle(color: AppColors.muted),
      floatingLabelStyle: const TextStyle(color: AppColors.leaf, fontWeight: FontWeight.w600),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.forest,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.forest,
        minimumSize: const Size.fromHeight(54),
        side: const BorderSide(color: AppColors.leaf, width: 1.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.line, thickness: 1, space: 1),
  );
}
