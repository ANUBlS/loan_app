import 'package:flutter/material.dart';

import 'models/loan.dart';

class AppColors {
  static const ink = Color(0xFF14213D);
  static const primary = Color(0xFF0F5C58);
  static const primarySoft = Color(0xFFE3EFED);
  static const surface = Color(0xFFF3F5F4);
  static const muted = Color(0xFF6B7682);
  static const line = Color(0xFFE1E6E4);

  static const paid = Color(0xFF2E7D4F);
  static const paidBg = Color(0xFFE8F5EC);
  static const overdue = Color(0xFFC0392B);
  static const overdueBg = Color(0xFFFDECEA);
  static const next = Color(0xFF1F5FBF);
  static const nextBg = Color(0xFFEAF1FC);
  static const upcoming = Color(0xFF8A949E);
}

class AppTheme {
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
    );
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.line),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.surface,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.ink,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: fieldBorder,
        enabledBorder: fieldBorder,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle:
              const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: AppColors.primarySoft,
      ),
    );
  }
}

/// Colors for each schedule row.
/// Paid = green, Overdue = red, Next = blue, Upcoming = white.
class StatusStyle {
  final Color color;
  final Color background;
  final String label;

  const StatusStyle(this.color, this.background, this.label);

  static StatusStyle of(InstallmentStatus s) => switch (s) {
        InstallmentStatus.paid =>
          const StatusStyle(AppColors.paid, AppColors.paidBg, 'Paid'),
        InstallmentStatus.overdue =>
          const StatusStyle(AppColors.overdue, AppColors.overdueBg, 'Overdue'),
        InstallmentStatus.next =>
          const StatusStyle(AppColors.next, AppColors.nextBg, 'Next'),
        InstallmentStatus.upcoming =>
          const StatusStyle(AppColors.upcoming, Colors.white, 'Upcoming'),
      };
}
