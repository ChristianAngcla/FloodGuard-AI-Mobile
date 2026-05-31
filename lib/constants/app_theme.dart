import 'package:flutter/material.dart';

class AppColors {
  static const Color white = Color(0xFFFFFFFF);
  static const Color lightBlue = Color(0xFFCAE1FC);
  static const Color grayBlue = Color(0xFF9FAEBE);
  static const Color mutedBlue = Color(0xFFA0AFBF);
  static const Color primaryBlue = Color(0xFF3784DF);
}

class AppTextStyles {
  // Titles / Headers
  static const TextStyle titleBold = TextStyle(
    fontFamily: 'CreatoDisplay',
    fontWeight: FontWeight.bold,
    fontSize: 24,
    color: AppColors.primaryBlue,
  );

  // Body text
  static const TextStyle bodyRegular = TextStyle(
    fontFamily: 'CreatoDisplay',
    fontWeight: FontWeight.normal,
    fontSize: 14,
    color: AppColors.grayBlue,
  );

  // Buttons
  static const TextStyle buttonBold = TextStyle(
    fontFamily: 'CreatoDisplay',
    fontWeight: FontWeight.bold,
    fontSize: 16,
    color: AppColors.white,
  );
}
