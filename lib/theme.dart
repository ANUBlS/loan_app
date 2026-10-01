import 'package:flutter/material.dart';

import 'models/loan.dart';

class AppColors {
  static const primary = Color(0xFF1F5EF0);
  static const primaryLight = Color(0xFF3F78F6);
  static const primarySoft = Color(0xFFE6EEFF);
  static const cardBlue = Color(0xFFD3E2FD);
  static const ink = Color(0xFF111827);
  static const surface = Color(0xFFF2F4F8);
  static const muted = Color(0xFF6B7280);
  static const line = Color(0xFFE5E7EB);
  static const tableHeader = Color(0xFFF3F4F6);

  static const paid = Color(0xFF16A34A);
  static const paidBg = Color(0xFFE8F7EE);
  static const overdue = Color(0xFFDC2626);
  static const overdueBg = Color(0xFFFDECEC);
  static const next = Color(0xFF1F5EF0);
  static const nextBg = Color(0xFFE6EEFF);
  static const upcoming = Color(0xFF9CA3AF);

  static const headerGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [primaryLight, primary],
  );
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
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: AppColors.ink,
          fontSize: 18,
          fontWeight: FontWeight.w600,
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
          backgroundColor: AppColors.primary,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle:
              const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: AppColors.primarySoft,
        side: const BorderSide(color: AppColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        labelStyle: const TextStyle(color: AppColors.ink),
      ),
      dividerColor: AppColors.line,
    );
  }
}

/// Colors for each schedule row.
/// Paid = green, Overdue = red, Next = blue, Upcoming = white.
class StatusStyle {
  final Color color;
  final Color background;

  /// Translation key.
  final String label;

  const StatusStyle(this.color, this.background, this.label);

  static StatusStyle of(InstallmentStatus s) => switch (s) {
        InstallmentStatus.paid =>
          const StatusStyle(AppColors.paid, AppColors.paidBg, 'status.paid'),
        InstallmentStatus.overdue => const StatusStyle(
            AppColors.overdue, AppColors.overdueBg, 'status.overdue'),
        InstallmentStatus.next =>
          const StatusStyle(AppColors.next, AppColors.nextBg, 'status.next'),
        InstallmentStatus.upcoming =>
          const StatusStyle(AppColors.upcoming, Colors.white, 'status.upcoming'),
      };
}
