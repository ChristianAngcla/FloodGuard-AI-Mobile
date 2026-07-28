import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onFinished;

  const SplashScreen({super.key, required this.onFinished});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late Animation<double> _logoScale;
  late Animation<double> _logoFade;

  late AnimationController _loaderController;

  @override
  void initState() {
    super.initState();

    // 1. Logo Entrance Animation (Scale Up + Fade In)
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _logoScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _logoController,
          curve: const Interval(0.0, 0.6, curve: Curves.easeIn)),
    );

    _logoController.forward();

    // 2. Custom Loader Animation (Infinite Ripple)
    _loaderController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    // 3. Timer to finish splash and navigate
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        widget.onFinished();
      }
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _loaderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white, Color(0xFFE3F2FD)],
              ),
            ),
          ),

          // Center Content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated Logo
                FadeTransition(
                  opacity: _logoFade,
                  child: ScaleTransition(
                    scale: _logoScale,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF3784DF).withValues(alpha: 0.2),
                            blurRadius: 40,
                            offset: const Offset(0, 15),
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/logo.png',
                        width: 100,
                        height: 100,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                // App Title
                FadeTransition(
                  opacity: _logoFade,
                  child: const Text(
                    "FloodGuard AI",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF3784DF),
                      letterSpacing: -1.0,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Custom Loading Animation at Bottom
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Center(
              child: CustomPaint(
                painter: _RippleLoaderPainter(_loaderController),
                size: const Size(60, 60),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom Painter for the Ripple/Wave Loading Effect
class _RippleLoaderPainter extends CustomPainter {
  final Animation<double> animation;

  _RippleLoaderPainter(this.animation) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // Draw 3 expanding ripples
    for (int i = 0; i < 3; i++) {
      // Stagger the animations (0.0, 0.33, 0.66)
      final progress = (animation.value + (i * 0.33)) % 1.0;

      // Radius expands from 0 to max
      final radius = maxRadius * progress;

      // Opacity fades out as it expands (1.0 -> 0.0)
      final opacity = 1.0 - progress;

      paint.color = const Color(0xFF3784DF).withValues(alpha: opacity);

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
