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
    const ColorScheme colorScheme = ColorScheme.light(
      primary: primaryBlue,
      secondary: Color(0xFF2BA7A0),
      surface: lightBg,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: Color(0xFF0F172A),
      surfaceContainer: lightBg,
      surfaceContainerHigh: Color(0xFFF1F5F9),
      surfaceContainerHighest: Color(0xFFE2E8F0),
      surfaceTint: Colors.transparent,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      primaryColor: primaryBlue,
      scaffoldBackgroundColor: lightBg,
      canvasColor: lightBg,
      cardColor: Colors.white,
      textTheme: AppTypography.createTextTheme(
        const Color(0xFF0F172A),
        const Color(0xFF475569),
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
    const ColorScheme colorScheme = ColorScheme.dark(
      primary: primaryBlue,
      secondary: Color(0xFF2BA7A0),
      surface: darkBg,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: Colors.white,
      surfaceContainer: darkBg,
      surfaceContainerHigh: darkCard,
      surfaceContainerHighest: Color(0xFF2E4660),
      surfaceTint: Colors.transparent,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      primaryColor: primaryBlue,
      scaffoldBackgroundColor: darkBg,
      canvasColor: darkBg,
      cardColor: darkCard,
      textTheme: AppTypography.createTextTheme(
        Colors.white,
        const Color(0xFFCBD5E1),
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
