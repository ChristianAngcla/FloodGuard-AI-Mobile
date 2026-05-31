import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';
import '../data/translations.dart';
import '../services/auth_service.dart';
import 'signup_screen.dart';
import 'home_map_screen.dart';
import '../widgets/wave_background.dart';

class LoginScreen extends StatefulWidget {
  final bool isTaglish;
  final bool isDarkMode;

  const LoginScreen({
    super.key,
    required this.isTaglish,
    required this.isDarkMode,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  String _t(String key) {
    return Translations.texts[key]?[widget.isTaglish ? "tl" : "en"] ?? key;
  }

  void _handleLogin() async {
    if (_emailCtrl.text.isEmpty || _passwordCtrl.text.isEmpty) return;

    final authService = AuthService();
    final success =
        await authService.login(_emailCtrl.text.trim(), _passwordCtrl.text);

    if (success) {
      if (mounted) {
        // Success feedback
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                widget.isTaglish ? "Matagumpay na naka-login!" : "Welcome!"),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Route to Map
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
              builder: (_) => HomeMapScreen(
                    initialDarkMode: widget.isDarkMode,
                    initialTaglish: widget.isTaglish,
                  )),
          (route) => false,
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.isTaglish
                ? "Maling email o password"
                : "Invalid email or password"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final bgColor = isDark ? const Color(0xFF1A2B3C) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1A2B3C);
    final subTextColor = isDark ? Colors.white70 : Colors.black54;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (_) => HomeMapScreen(
                          initialDarkMode: widget.isDarkMode,
                          initialTaglish: widget.isTaglish,
                        )),
              );
            }
          },
        ),
      ),
      body: Stack(
        children: [
          WaveBackground(isDarkMode: isDark),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 20),
                        // Hero Logo
                        Hero(
                          tag: 'app_logo',
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3784DF).withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Image.asset(
                              'assets/new_logo_nobg.png',
                              width: 84,
                              height: 84,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          "FloodGuard AI",
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF3784DF),
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _t("loginTitle"),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: subTextColor,
                          ),
                        ),
                        const SizedBox(height: 48),

                        // Form
                        TextField(
                          controller: _emailCtrl,
                          style: TextStyle(color: textColor),
                          keyboardType: TextInputType.emailAddress,
                          decoration: _inputDecoration(
                            label: _t("email"),
                            icon: Icons.email_outlined,
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _passwordCtrl,
                          style: TextStyle(color: textColor),
                          obscureText: _obscurePassword,
                          decoration: _inputDecoration(
                            label: _t("password"),
                            icon: Icons.lock_outline_rounded,
                            isDark: isDark,
                            isPassword: true,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {},
                            child: Text(
                              _t("forgotPassword"),
                              style: const TextStyle(
                                color: Color(0xFF3784DF),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Login Button
                        Container(
                          width: double.infinity,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF3784DF), Color(0xFF2BA7A0)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF3784DF).withOpacity(0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _handleLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                            ),
                            child: Text(
                              _t("loginBtn"),
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                  color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Sign Up Link
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              widget.isTaglish
                                  ? "Wala pang account?"
                                  : "Don't have an account?",
                              style: TextStyle(color: subTextColor),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => SignupScreen(
                                      isTaglish: widget.isTaglish,
                                      isDarkMode: widget.isDarkMode,
                                    ),
                                  ),
                                );
                              },
                              child: Text(
                                _t("signupBtn"),
                                style: const TextStyle(
                                  color: Color(0xFF3784DF),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    required bool isDark,
    bool isPassword = false,
  }) {
    final borderColor = isDark ? Colors.white24 : Colors.grey[300]!;
    final fillColor = isDark ? const Color(0xFF253B50) : Colors.grey[50];
    final iconColor = isDark ? Colors.white54 : Colors.grey[500];

    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: iconColor),
      prefixIcon: Icon(icon, color: iconColor),
      suffixIcon: isPassword
          ? IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: iconColor,
              ),
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
            )
          : null,
      filled: true,
      fillColor: fillColor,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF3784DF), width: 2),
      ),
    );
  }
}
