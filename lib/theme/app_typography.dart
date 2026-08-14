import 'package:flutter/material.dart';

/// High-contrast, Accessible Typography Scale for FloodGuard Mobile App.
class AppTypography {
  AppTypography._();

  // Display Styles (Main Screen Headers - 22-24px)
  static const TextStyle displayLarge = TextStyle(
    fontSize: 24.0,
    fontWeight: FontWeight.bold,
    height: 1.25,
    letterSpacing: -0.5,
  );

  static const TextStyle displayMedium = TextStyle(
    fontSize: 21.0,
    fontWeight: FontWeight.bold,
    height: 1.3,
  );

  // Headline Styles (Card & Modal Headers - 18-20px)
  static const TextStyle headlineLarge = TextStyle(
    fontSize: 19.0,
    fontWeight: FontWeight.bold,
    height: 1.3,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontSize: 17.0,
    fontWeight: FontWeight.w600,
    height: 1.35,
  );

  // Title Styles (Section Titles, List Items - 15-16px)
  static const TextStyle titleLarge = TextStyle(
    fontSize: 16.0,
    fontWeight: FontWeight.w600,
    height: 1.35,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 15.0,
    fontWeight: FontWeight.w600,
    height: 1.35,
  );

  static const TextStyle titleSmall = TextStyle(
    fontSize: 14.0,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  // Body Styles (Standard Form Inputs & Paragraphs - 15-16px)
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16.0,
    fontWeight: FontWeight.normal,
    height: 1.45,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 15.0,
    fontWeight: FontWeight.normal,
    height: 1.45,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 13.0,
    fontWeight: FontWeight.normal,
    height: 1.4,
  );

  // Label Styles (Buttons & Field Labels - 13-16px)
  static const TextStyle labelLarge = TextStyle(
    fontSize: 16.0, // Standard button text
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
  );

  static const TextStyle labelMedium = TextStyle(
    fontSize: 13.0, // Field labels
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
  );

  static const TextStyle labelSmall = TextStyle(
    fontSize: 12.0,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
  );

  /// Material TextTheme mapping with high-contrast baseline
  static TextTheme createTextTheme(Color primaryTextColor, Color secondaryTextColor) {
    return TextTheme(
      displayLarge: displayLarge.copyWith(color: primaryTextColor),
      displayMedium: displayMedium.copyWith(color: primaryTextColor),
      headlineLarge: headlineLarge.copyWith(color: primaryTextColor),
      headlineMedium: headlineMedium.copyWith(color: primaryTextColor),
      titleLarge: titleLarge.copyWith(color: primaryTextColor),
      titleMedium: titleMedium.copyWith(color: primaryTextColor),
      titleSmall: titleSmall.copyWith(color: primaryTextColor),
      bodyLarge: bodyLarge.copyWith(color: primaryTextColor),
      bodyMedium: bodyMedium.copyWith(color: primaryTextColor),
      bodySmall: bodySmall.copyWith(color: secondaryTextColor),
      labelLarge: labelLarge.copyWith(color: primaryTextColor),
      labelMedium: labelMedium.copyWith(color: secondaryTextColor),
      labelSmall: labelSmall.copyWith(color: secondaryTextColor),
    );
  }
}
