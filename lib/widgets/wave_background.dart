import 'package:flutter/material.dart';

class WaveBackground extends StatelessWidget {
  final bool isDarkMode;

  const WaveBackground({super.key, this.isDarkMode = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDarkMode
              ? const [
                  Color(0xFF0F172A),
                  Color(0xFF1E293B),
                  Color(0xFF0F172A),
                ]
              : const [
                  Color(0xFFF8FAFC),
                  Color(0xFFE2E8F0),
                  Color(0xFFF1F5F9),
                ],
        ),
      ),
    );
  }
}