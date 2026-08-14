import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/translations.dart';
import '../services/auth_service.dart';
import 'signup_screen.dart';
import 'home_map_screen.dart';
import '../widgets/wave_background.dart';
import '../theme/app_typography.dart';
import '../theme/app_spacing.dart';

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
    final otpCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();

    String? foundPhone;
    String? maskedPhone;
    String? verificationId;
    String? infoMessage;
    int currentStep = 0; // 0 = Enter Email, 1 = Send OTP & Verify SMS
    bool busy = false;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final isDark = widget.isDarkMode;
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1A2B3C) : Colors.white,
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
                    if (currentStep == 0) ...[
                      Text(
                        widget.isTaglish
                            ? 'Ilagay ang iyong rehistradong email address upang mahanap ang iyong account.'
                            : 'Enter your registered email address to locate your account.',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          fontSize: 15,
                        ),
                        decoration: InputDecoration(
                          labelText: widget.isTaglish ? 'Rehistradong Email' : 'Registered Email',
                          labelStyle: TextStyle(
                            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          hintText: 'e.g. user@gmail.com',
                          hintStyle: TextStyle(
                            color: isDark ? Colors.white38 : Colors.black38,
                            fontSize: 14,
                          ),
                          prefixIcon: const Icon(Icons.email_rounded, color: Color(0xFF3784DF)),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF253B50) : const Color(0xFFF1F5F9),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark ? Colors.white24 : Colors.grey.shade300,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF3784DF), width: 2),
                          ),
                        ),
                      ),
                    ] else if (currentStep == 1) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3784DF).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF3784DF).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.phonelink_ring_rounded, color: Color(0xFF3784DF), size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                widget.isTaglish
                                    ? 'Magpapadala kami ng OTP code sa iyong rehistradong numero: $maskedPhone'
                                    : 'We will send a 6-digit OTP code to your registered mobile number: $maskedPhone',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: otpCtrl,
                        keyboardType: TextInputType.number,
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.0,
                        ),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          labelText: widget.isTaglish ? '6-Digit SMS OTP' : '6-Digit SMS OTP',
                          labelStyle: TextStyle(
                            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0,
                          ),
                          hintText: '123456',
                          hintStyle: TextStyle(
                            color: isDark ? Colors.white38 : Colors.black38,
                            fontSize: 14,
                            letterSpacing: 0,
                          ),
                          prefixIcon: const Icon(Icons.pin_rounded, color: Color(0xFF3784DF)),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF253B50) : const Color(0xFFF1F5F9),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark ? Colors.white24 : Colors.grey.shade300,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF3784DF), width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: newPassCtrl,
                        obscureText: true,
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          fontSize: 15,
                        ),
                        decoration: InputDecoration(
                          labelText: widget.isTaglish ? 'Bagong Password' : 'New Password',
                          labelStyle: TextStyle(
                            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          prefixIcon: const Icon(Icons.lock_reset_rounded, color: Color(0xFF3784DF)),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF253B50) : const Color(0xFFF1F5F9),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark ? Colors.white24 : Colors.grey.shade300,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF3784DF), width: 2),
                          ),
                        ),
                      ),
                    ],
                    if (infoMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        infoMessage!,
                        style: const TextStyle(
                          fontSize: 13,
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
                if (currentStep == 0)
                  ElevatedButton(
                    onPressed: busy
                        ? null
                        : () async {
                            final targetEmail = emailCtrl.text.trim();
                            if (targetEmail.isEmpty) return;
                            setDialogState(() => busy = true);

                            final res = await AuthService().lookupPhoneByEmail(targetEmail);
                            setDialogState(() => busy = false);

                            if (res['success'] == true && res['phone'] != null) {
                              setDialogState(() {
                                foundPhone = res['phone'].toString();
                                maskedPhone = res['maskedPhone']?.toString() ?? foundPhone;
                                currentStep = 1;
                                infoMessage = widget.isTaglish
                                    ? 'Pindutin ang "Ipadala ang OTP" upang matanggap ang SMS.'
                                    : 'Press "Send OTP" to receive the SMS code.';
                              });
                            } else {
                              setDialogState(() {
                                infoMessage = res['message']?.toString() ??
                                    (widget.isTaglish
                                        ? 'Walang nakitang account sa email na ito.'
                                        : 'No registered account found with that email.');
                              });
                            }
                          },
                    child: Text(widget.isTaglish ? 'Hanapin ang Account' : 'Find Account'),
                  )
                else if (currentStep == 1 && verificationId == null)
                  ElevatedButton(
                    onPressed: busy
                        ? null
                        : () async {
                            if (foundPhone == null) return;
                            setDialogState(() => busy = true);

                            try {
                              await FirebaseAuth.instance.verifyPhoneNumber(
                                phoneNumber: foundPhone!,
                                timeout: const Duration(seconds: 60),
                                verificationCompleted: (PhoneAuthCredential cred) async {
                                  if (cred.smsCode != null) {
                                    otpCtrl.text = cred.smsCode!;
                                  }
                                },
                                verificationFailed: (FirebaseAuthException e) async {
                                  // Auto-fallback for emulators / unconfigured SHA-1 during testing
                                  final fallbackRes = await AuthService().requestPasswordReset(foundPhone!);
                                  setDialogState(() {
                                    busy = false;
                                    verificationId = 'emulator_fallback_id';
                                    if (fallbackRes['dev_code'] != null) {
                                      otpCtrl.text = fallbackRes['dev_code'].toString();
                                    }
                                    infoMessage = widget.isTaglish
                                        ? 'Ginamit ang Test OTP code para sa emulator/testing.'
                                        : 'Using Test OTP code for emulator testing.';
                                  });
                                },
                                codeSent: (String vId, int? resendToken) {
                                  setDialogState(() {
                                    busy = false;
                                    verificationId = vId;
                                    infoMessage = widget.isTaglish
                                        ? 'Naipadala na ang SMS OTP sa iyong telepono.'
                                        : 'SMS OTP sent to your registered phone.';
                                  });
                                },
                                codeAutoRetrievalTimeout: (String vId) {
                                  verificationId = vId;
                                },
                              );
                            } catch (e) {
                              final fallbackRes = await AuthService().requestPasswordReset(foundPhone!);
                              setDialogState(() {
                                busy = false;
                                verificationId = 'emulator_fallback_id';
                                if (fallbackRes['dev_code'] != null) {
                                  otpCtrl.text = fallbackRes['dev_code'].toString();
                                }
                                infoMessage = widget.isTaglish
                                    ? 'Ginamit ang Test OTP code para sa testing.'
                                    : 'Using Test OTP code for testing.';
                              });
                            }
                          },
                    child: Text(widget.isTaglish ? 'Ipadala ang OTP' : 'Send OTP'),
                  )
                else if (currentStep == 1 && verificationId != null)
                  ElevatedButton(
                    onPressed: busy
                        ? null
                        : () async {
                            final code = otpCtrl.text.trim();
                            final newPass = newPassCtrl.text;
                            if (code.length < 6 || newPass.length < 6) {
                              setDialogState(() {
                                infoMessage = widget.isTaglish
                                    ? 'Kailangan ng 6-digit OTP at bagong password (min 6 chars).'
                                    : 'Requires 6-digit OTP and new password (min 6 chars).';
                              });
                              return;
                            }
                            setDialogState(() => busy = true);

                            try {
                              Map<String, dynamic> res;
                              if (verificationId == 'emulator_fallback_id') {
                                // Fallback: Reset via AuthService for emulator testing
                                res = await AuthService().resetPassword(
                                  identifier: emailCtrl.text.trim(),
                                  code: code,
                                  newPassword: newPass,
                                );
                              } else {
                                // 1. Verify SMS Credential via Firebase Phone Auth
                                final credential = PhoneAuthProvider.credential(
                                  verificationId: verificationId!,
                                  smsCode: code,
                                );
                                await FirebaseAuth.instance.signInWithCredential(credential);

                                // 2. Update password in MongoDB account
                                res = await AuthService().updatePasswordByEmail(
                                  email: emailCtrl.text.trim(),
                                  newPassword: newPass,
                                );
                              }

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
                                  infoMessage = res['message']?.toString() ?? 'Failed to update password.';
                                });
                              }
                            } catch (e) {
                              setDialogState(() {
                                busy = false;
                                infoMessage = widget.isTaglish
                                    ? 'Maling OTP code o nag-expire na.'
                                    : 'Invalid or expired OTP code.';
                              });
                            }
                          },
                    child: Text(widget.isTaglish ? 'I-save ang Password' : 'Save New Password'),
                  ),
              ],
            );
          },
        );
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      emailCtrl.dispose();
      otpCtrl.dispose();
      newPassCtrl.dispose();
    });
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    required bool isDark,
    bool isPassword = false,
  }) {
    return InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      labelText: label,
      labelStyle: TextStyle(
        color: isDark ? Colors.white70 : const Color(0xFF64748B),
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      prefixIcon: Padding(
        padding: const EdgeInsets.only(left: 12, right: 8),
        child: Icon(icon, color: const Color(0xFF3784DF), size: 22),
      ),
      suffixIcon: isPassword
          ? IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: isDark ? Colors.white54 : Colors.black45,
                size: 22,
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
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF3784DF).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Image.asset(
                          'assets/new_logo_nobg.png',
                          height: 56,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.water_drop,
                            size: 56,
                            color: Color(0xFF3784DF),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        widget.isTaglish ? 'Mag-login' : 'Login',
                        style: AppTypography.displayMedium.copyWith(
                          color: textColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 22,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        widget.isTaglish
                            ? 'Mag-sign in para sa mga alerto'
                            : 'Sign in for flood alerts',
                        style: AppTypography.bodySmall.copyWith(
                          color: subTextColor,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Form(
                        child: Column(
                          children: [
                            TextField(
                              controller: _emailCtrl,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                              ),
                              keyboardType: TextInputType.emailAddress,
                              decoration: _inputDecoration(
                                label: _t("email"),
                                icon: Icons.email_outlined,
                                isDark: isDark,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            TextField(
                              controller: _passwordCtrl,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                              ),
                              obscureText: _obscurePassword,
                              decoration: _inputDecoration(
                                label: _t("password"),
                                icon: Icons.lock_outline_rounded,
                                isDark: isDark,
                                isPassword: true,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _showForgotPasswordDialog,
                                child: Text(
                                  _t("forgotPassword"),
                                  style: AppTypography.labelMedium.copyWith(
                                    color: const Color(0xFF3784DF),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xl),
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _handleLogin,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF3784DF),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: AppSpacing.borderRadiusLg,
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
                                        style: AppTypography.labelLarge.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xl),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  widget.isTaglish
                                      ? "Wala pang account? "
                                      : "No account yet? ",
                                  style: AppTypography.bodySmall.copyWith(
                                    color: subTextColor,
                                    fontSize: 13,
                                  ),
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
                                    style: AppTypography.labelMedium.copyWith(
                                      color: const Color(0xFF3784DF),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
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
          ),
        ],
      ),
    );
  }
}
