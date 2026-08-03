import 'package:flutter/material.dart';
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

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  String _t(String key) {
    return Translations.texts[key]?[widget.isTaglish ? "tl" : "en"] ?? key;
  }

  Future<void> _handleLogin() async {
    if (_emailCtrl.text.isEmpty || _passwordCtrl.text.isEmpty) return;
    setState(() => _isLoading = true);

    final authService = AuthService();
    final success =
        await authService.login(_emailCtrl.text.trim(), _passwordCtrl.text);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              widget.isTaglish ? "Matagumpay na naka-login!" : "Welcome!"),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
            builder: (_) => HomeMapScreen(
                  initialDarkMode: widget.isDarkMode,
                  initialTaglish: widget.isTaglish,
                )),
        (route) => false,
      );
    } else {
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

  Future<void> _showForgotPasswordDialog() async {
    final emailCtrl = TextEditingController(text: _emailCtrl.text.trim());
    final codeCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    String? infoMessage;
    bool codeSent = false;
    bool busy = false;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final isDark = widget.isDarkMode;
            return AlertDialog(
              backgroundColor:
                  isDark ? const Color(0xFF1A2B3C) : Colors.white,
              title: Text(
                widget.isTaglish ? 'I-reset ang Password' : 'Reset Password',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w800,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.isTaglish
                          ? 'Maglagay ng email, humiling ng code, tapos ilagay ang bagong password.'
                          : 'Enter your email, request a code, then set a new password.',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (codeSent) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: codeCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: widget.isTaglish ? 'Code' : 'Reset code',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: newPassCtrl,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: widget.isTaglish
                              ? 'Bagong password'
                              : 'New password',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ],
                    if (infoMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        infoMessage!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF3784DF),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: busy ? null : () => Navigator.pop(ctx),
                  child: Text(widget.isTaglish ? 'Isara' : 'Close'),
                ),
                if (!codeSent)
                  ElevatedButton(
                    onPressed: busy
                        ? null
                        : () async {
                            setDialogState(() => busy = true);
                            final res = await AuthService()
                                .requestPasswordReset(emailCtrl.text.trim());
                            setDialogState(() {
                              busy = false;
                              codeSent = res['success'] == true;
                              final demo = res['demo_code']?.toString();
                              infoMessage = demo != null
                                  ? (widget.isTaglish
                                      ? 'Testing code: $demo (15 min)'
                                      : 'Testing code: $demo (valid 15 min)')
                                  : (res['message']?.toString() ??
                                      'Check your email for the code.');
                            });
                          },
                    child: Text(widget.isTaglish ? 'Kunin ang Code' : 'Get Code'),
                  )
                else
                  ElevatedButton(
                    onPressed: busy
                        ? null
                        : () async {
                            setDialogState(() => busy = true);
                            final res = await AuthService().resetPassword(
                              email: emailCtrl.text.trim(),
                              code: codeCtrl.text.trim(),
                              newPassword: newPassCtrl.text,
                            );
                            setDialogState(() => busy = false);
                            if (res['success'] == true && ctx.mounted) {
                              Navigator.pop(ctx);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(widget.isTaglish
                                        ? 'Na-update ang password. Mag-login na.'
                                        : 'Password updated. You can log in now.'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } else {
                              setDialogState(() {
                                infoMessage = res['message']?.toString() ??
                                    'Reset failed.';
                              });
                            }
                          },
                    child: Text(
                        widget.isTaglish ? 'I-save' : 'Save New Password'),
                  ),
              ],
            );
          },
        );
      },
    );

    emailCtrl.dispose();
    codeCtrl.dispose();
    newPassCtrl.dispose();
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    required bool isDark,
    bool isPassword = false,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
      prefixIcon: Icon(icon, color: const Color(0xFF3784DF)),
      suffixIcon: isPassword
          ? IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            )
          : null,
      filled: true,
      fillColor: isDark ? const Color(0xFF253B50) : const Color(0xFFF4F9FF),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    );
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color:
                            const Color(0xFF3784DF).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Image.asset(
                        'assets/new_logo_nobg.png',
                        height: 72,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.water_drop,
                          size: 72,
                          color: Color(0xFF3784DF),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _t("login"),
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.isTaglish
                          ? 'Mag-sign in para sa mga alerto'
                          : 'Sign in for flood alerts',
                      style: TextStyle(color: subTextColor, fontSize: 14),
                    ),
                    const SizedBox(height: 28),
                    Form(
                      child: Column(
                        children: [
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
                          const SizedBox(height: 16),
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
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _showForgotPasswordDialog,
                              child: Text(
                                _t("forgotPassword"),
                                style: const TextStyle(
                                  color: Color(0xFF3784DF),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF3784DF),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      _t("loginBtn"),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                widget.isTaglish
                                    ? "Wala pang account? "
                                    : "No account yet? ",
                                style: TextStyle(color: subTextColor),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
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
                                  widget.isTaglish ? 'Mag-sign up' : 'Sign up',
                                  style: const TextStyle(
                                    color: Color(0xFF3784DF),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
