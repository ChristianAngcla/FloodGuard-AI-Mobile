import 'package:flutter/material.dart';

/// Standard, Best-Practice Material 3 Typography Scale for FloodGuard Mobile App.
class AppTypography {
  AppTypography._();

  // Display Styles (Main Screen Headers - 20px)
  static const TextStyle displayLarge = TextStyle(
    fontSize: 22.0,
    fontWeight: FontWeight.bold,
    height: 1.2,
  );

  static const TextStyle displayMedium = TextStyle(
    fontSize: 20.0,
    fontWeight: FontWeight.bold,
    height: 1.25,
  );

  // Headline Styles (Card & Modal Headers - 16-18px)
  static const TextStyle headlineLarge = TextStyle(
    fontSize: 18.0,
    fontWeight: FontWeight.bold,
    height: 1.3,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontSize: 16.0,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  // Title Styles (Section Titles, List Items - 14-16px)
  static const TextStyle titleLarge = TextStyle(
    fontSize: 16.0,
    fontWeight: FontWeight.w600,
    height: 1.35,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 14.0,
    fontWeight: FontWeight.w600,
    height: 1.35,
  );

  static const TextStyle titleSmall = TextStyle(
    fontSize: 13.0,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  // Body Styles (Standard Form Inputs & Paragraphs - 14px)
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 15.0,
    fontWeight: FontWeight.normal,
    height: 1.4,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14.0, // Standard, usual mobile body & input text (14px)
    fontWeight: FontWeight.normal,
    height: 1.4,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12.0, // Standard small body & subtitles (12px)
    fontWeight: FontWeight.normal,
    height: 1.35,
  );

  // Label Styles (Buttons & Field Labels - 12-14px)
  static const TextStyle labelLarge = TextStyle(
    fontSize: 14.0, // Standard button text (14px)
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
  );

  static const TextStyle labelMedium = TextStyle(
    fontSize: 12.0, // Standard field label (12px)
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
  );

  static const TextStyle labelSmall = TextStyle(
    fontSize: 11.0, // Standard small label (11px)
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
  );

  /// Material TextTheme mapping
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
