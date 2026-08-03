import 'package:flutter/material.dart';

/// Centralized Spacing and Layout Tokens.
class AppSpacing {
  AppSpacing._();

  // Spacing Tokens
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;

  static const double s1 = 2.0;
  static const double s2 = 4.0;
  static const double s3 = 6.0;
  static const double s4 = 8.0;
  static const double s5 = 10.0;
  static const double s6 = 12.0;
  static const double s7 = 14.0;
  static const double s8 = 16.0;
  static const double s9 = 18.0;
  static const double s10 = 20.0;
  static const double s11 = 24.0;
  static const double s12 = 28.0;
  static const double s13 = 32.0;

  // EdgeInsets Helpers
  static const EdgeInsets paddingXs = EdgeInsets.all(xs);
  static const EdgeInsets paddingSm = EdgeInsets.all(sm);
  static const EdgeInsets paddingMd = EdgeInsets.all(md);
  static const EdgeInsets paddingLg = EdgeInsets.all(lg);
  static const EdgeInsets paddingXl = EdgeInsets.all(xl);

  static const EdgeInsets paddingHorizontalSm = EdgeInsets.symmetric(horizontal: sm);
  static const EdgeInsets paddingHorizontalMd = EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets paddingHorizontalLg = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets paddingHorizontalXl = EdgeInsets.symmetric(horizontal: xl);

  // Border Radius Tokens
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 20.0;
  static const double radiusFull = 9999.0;

  static final BorderRadius borderRadiusSm = BorderRadius.circular(radiusSm);
  static final BorderRadius borderRadiusMd = BorderRadius.circular(radiusMd);
  static final BorderRadius borderRadiusLg = BorderRadius.circular(radiusLg);
  static final BorderRadius borderRadiusXl = BorderRadius.circular(radiusXl);

  // Component Constraints
  static const BoxConstraints prefixIconConstraints = BoxConstraints(
    minWidth: 28.0,
    minHeight: 28.0,
  );

  static const EdgeInsets inputContentPadding = EdgeInsets.symmetric(
    horizontal: 8.0,
    vertical: 10.0,
  );

  static const EdgeInsets compactInputContentPadding = EdgeInsets.symmetric(
    horizontal: 6.0,
    vertical: 8.0,
  );
}

/// Formats PH mobile numbers as 09XXXXXXXXX when possible.
String formatPhMobileNumber(String? raw) {
  if (raw == null) return '';
  var digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('63') && digits.length >= 12) {
    digits = '0${digits.substring(2)}';
  } else if (digits.length == 10 && digits.startsWith('9')) {
    digits = '0$digits';
  }
  return digits.isEmpty ? raw.trim() : digits;
}
