import 'package:flutter/material.dart';

/// Extension enabling `rem` units across Flutter UI matching design-system-foundation.mdc (1rem = 10px).
/// Example:
/// - 1.15.rem => 11.5px
/// - 1.2.rem  => 12px
/// - 0.8.rem  => 8px
/// - 0.6.rem  => 6px
extension RemExtension on num {
  double get rem => (this * 10.0).toDouble();
}

/// Typed design system tokens using `rem` scale (1rem = 10px).
class AppRem {
  AppRem._();

  // Typography scale (1rem = 10px)
  static double get fontCaption => 1.05.rem;   // 10.5px
  static double get fontBodySm => 1.15.rem;   // 11.5px
  static double get fontBody => 1.3.rem;      // 13px
  static double get fontSubtitle => 1.4.rem;  // 14px
  static double get fontTitle => 1.6.rem;     // 16px
  static double get fontHeader => 2.0.rem;    // 20px

  // Spacing scale
  static double get s1 => 0.2.rem;  // 2px
  static double get s2 => 0.4.rem;  // 4px
  static double get s3 => 0.6.rem;  // 6px
  static double get s4 => 0.8.rem;  // 8px
  static double get s5 => 1.0.rem;  // 10px
  static double get s6 => 1.2.rem;  // 12px
  static double get s8 => 1.6.rem;  // 16px
  static double get s10 => 2.0.rem; // 20px
  static double get s12 => 2.4.rem; // 24px

  // Input Constraints
  static const BoxConstraints prefixIconConstraints = BoxConstraints(
    minWidth: 26,
    minHeight: 26,
  );
}
