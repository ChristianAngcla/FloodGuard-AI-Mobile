import 'package:flutter/material.dart';
import 'dart:math' as math;

class WaveBackground extends StatefulWidget {
  final bool isDarkMode;

  const WaveBackground({super.key, this.isDarkMode = false});

  @override
  State<WaveBackground> createState() => _WaveBackgroundState();
}

class _WaveBackgroundState extends State<WaveBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20), // Slower animation
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _WavePainter(
              isDarkMode: widget.isDarkMode,
              animationValue: _controller.value,
            ),
          );
        },
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  final bool isDarkMode;
  final double animationValue;

  _WavePainter({required this.isDarkMode, required this.animationValue});

  void _drawWave(Canvas canvas, Size size, Paint paint, double yOffset,
      double period, double amplitude, double animationOffset) {
    final path = Path();
    path.moveTo(size.width * -1, size.height * yOffset);
    for (double i = -1; i <= 2; i += 0.01) {
      final x = i * size.width;
      final y = size.height * yOffset +
          math.sin((i * period * math.pi) +
                  (animationValue * 2 * math.pi) +
                  animationOffset) *
              amplitude;
      path.lineTo(x, y);
    }
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()
      ..color = (isDarkMode ? const Color(0xFF253B50) : const Color(0xFFE3F2FD)).withOpacity(0.7)
      ..style = PaintingStyle.fill;
    _drawWave(canvas, size, paint1, 0.88, 2, 20, 0);

    final paint2 = Paint()
      ..color = (isDarkMode ? const Color(0xFF3784DF) : const Color(0xFFCAE1FC)).withOpacity(0.5)
      ..style = PaintingStyle.fill;
    _drawWave(canvas, size, paint2, 0.92, 1.5, 25, math.pi);
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) {
    return oldDelegate.isDarkMode != isDarkMode ||
        oldDelegate.animationValue != animationValue;
  }
}