import 'package:flutter/material.dart';

class AppColors {
  static const background = Color(0xFF0A0E1A);
  static const surface = Color(0xFF161B22);
  static const surfaceLight = Color(0xFF1C2333);
  static const border = Color(0xFF30363D);
  static const primary = Color(0xFFE63946);
  static const primaryDark = Color(0xFFC1121F);
  static const textPrimary = Color(0xFFE6EDF3);
  static const textSecondary = Color(0xFF8B949E);
  static const textMuted = Color(0xFF6E7681);
  static const success = Color(0xFF3FB950);
  static const warning = Color(0xFFD29922);
  static const info = Color(0xFF58A6FF);
  static const danger = Color(0xFFF85149);
}

ThemeData buildAppTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primary,
      surface: AppColors.surface,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surface,
      elevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: AppColors.textPrimary),
      titleTextStyle: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.surface,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textMuted,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF0D1117),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
      hintStyle: const TextStyle(color: AppColors.textMuted),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(vertical: 14),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        elevation: 0,
      ),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1),
  );
}

// Status badge colors
Color statusColor(String status) {
  switch (status) {
    case 'available': return AppColors.success;
    case 'on_duty': return AppColors.warning;
    case 'on_route': return AppColors.info;
    case 'maintenance': return AppColors.textMuted;
    default: return AppColors.textMuted;
  }
}

Color intensityColor(String intensity) {
  switch (intensity) {
    case 'high': return AppColors.danger;
    case 'medium': return AppColors.warning;
    case 'low': return AppColors.success;
    default: return AppColors.textMuted;
  }
}

Color notifTypeColor(String type) {
  switch (type) {
    case 'danger': return AppColors.danger;
    case 'warning': return AppColors.warning;
    case 'success': return AppColors.success;
    default: return AppColors.info;
  }
}
