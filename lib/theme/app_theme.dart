import 'package:flutter/material.dart';
import 'app_typography.dart';
import 'app_spacing.dart';

/// FloodGuard Central ThemeData configuration.
class AppTheme {
  AppTheme._();

  static const Color primaryBlue = Color(0xFF3784DF);
  static const Color darkBg = Color(0xFF1A2B3C);
  static const Color darkCard = Color(0xFF253B50);
  static const Color lightBg = Color(0xFFF8F9FA);

  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryBlue,
      scaffoldBackgroundColor: lightBg,
      textTheme: AppTypography.createTextTheme(
        Colors.black87,
        Colors.grey[600]!,
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        contentPadding: AppSpacing.compactInputContentPadding,
        prefixIconConstraints: AppSpacing.prefixIconConstraints,
        border: OutlineInputBorder(
          borderRadius: AppSpacing.borderRadiusLg,
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  static ThemeData darkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryBlue,
      scaffoldBackgroundColor: darkBg,
      cardColor: darkCard,
      textTheme: AppTypography.createTextTheme(
        Colors.white,
        Colors.white70,
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        contentPadding: AppSpacing.compactInputContentPadding,
        prefixIconConstraints: AppSpacing.prefixIconConstraints,
        border: OutlineInputBorder(
          borderRadius: AppSpacing.borderRadiusLg,
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
