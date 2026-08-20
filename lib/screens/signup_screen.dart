import 'dart:async';
import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/translations.dart';
import '../services/auth_service.dart';
import '../widgets/wave_background.dart';
import 'home_map_screen.dart';
import 'login_screen.dart';

class SignupScreen extends StatefulWidget {
  final bool isTaglish;
  final bool isDarkMode;

  const SignupScreen({
    super.key,
    required this.isTaglish,
    required this.isDarkMode,
  });

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  static const Color _accessibleBlue = Color(0xFF1769AA);

  final _step0Key = GlobalKey<FormState>();
  final _step1Key = GlobalKey<FormState>();
  final _step2Key = GlobalKey<FormState>();

  int _currentStep = 0;
  final int _totalSteps = 3;

  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _firstNameCtrl = TextEditingController();
  final TextEditingController _lastNameCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();

  final TextEditingController _passwordCtrl = TextEditingController();
  final TextEditingController _confirmPasswordCtrl = TextEditingController();

  // Verification & Location Controllers
  final TextEditingController _otpCtrl = TextEditingController();
  final TextEditingController _houseNoCtrl = TextEditingController();
  final TextEditingController _streetNameCtrl = TextEditingController();
  final TextEditingController _cityCtrl =
      TextEditingController(text: "Marikina City");
  final TextEditingController _provinceCtrl =
      TextEditingController(text: "Metro Manila");
  final TextEditingController _zipCodeCtrl =
      TextEditingController(text: "1800");
  final TextEditingController _countryCtrl =
      TextEditingController(text: "Philippines");

  String? _selectedBarangay;

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreedToTerms = false;
  bool _isSuccess = false;
  bool _isOtpVerified = false;

  String? _verificationId;
  String? _sentPhoneNumber;
  int? _forceResendingToken;
  bool _isSendingOtp = false;
  bool _isVerifyingOtp = false;
  bool _isSigningUp = false;
  Timer? _resendTimer;
  int _resendCooldownSec = 0;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _otpCtrl.dispose();
    _houseNoCtrl.dispose();
    _streetNameCtrl.dispose();
    _cityCtrl.dispose();
    _provinceCtrl.dispose();
    _zipCodeCtrl.dispose();
    _countryCtrl.dispose();
    super.dispose();
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    setState(() => _resendCooldownSec = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendCooldownSec <= 1) {
        timer.cancel();
        setState(() => _resendCooldownSec = 0);
      } else {
        setState(() => _resendCooldownSec -= 1);
      }
    });
  }

  String _otpFailureMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-phone-number':
        return widget.isTaglish
            ? 'Hindi valid ang numero ng telepono.'
            : 'Invalid phone number.';
      case 'too-many-requests':
        return widget.isTaglish
            ? 'Masyadong maraming OTP request. Subukan ulit mamaya.'
            : 'Too many OTP requests. Please try again later.';
      case 'network-request-failed':
        return widget.isTaglish
            ? 'Walang network. Suriin ang koneksyon.'
            : 'Network error. Check your connection.';
      case 'session-expired':
        return widget.isTaglish
            ? 'Nag-expire ang OTP. Mag-resend ng code.'
            : 'OTP expired. Please resend the code.';
      default:
        return e.message?.isNotEmpty == true
            ? e.message!
            : (widget.isTaglish ? 'Nabigo ang OTP.' : 'OTP failed.');
    }
  }

  String _t(String key) {
    return Translations.texts[key]?[widget.isTaglish ? "tl" : "en"] ?? key;
  }

  bool _isStrongPassword(String password) {
    final regex = RegExp(
      r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&]).{8,}$',
    );
    return regex.hasMatch(password);
  }

  void _sendOtp() async {
    if (_isSendingOtp || _isOtpVerified || _resendCooldownSec > 0) return;

    String phone = _phoneCtrl.text.trim();

    // Ensure proper +63 format regardless of whether they typed a leading 0
    if (phone.startsWith('0')) phone = phone.substring(1);
    phone = '+63$phone';
    _sentPhoneNumber = phone;

    setState(() {
      _isSendingOtp = true;
    });

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        timeout: const Duration(seconds: 60),
        forceResendingToken: _forceResendingToken,
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            await FirebaseAuth.instance.signInWithCredential(credential);
            if (mounted) {
              setState(() {
                _isOtpVerified = true;
                _otpCtrl.text = credential.smsCode ?? '';
                _isSendingOtp = false;
                if (_currentStep < 2) _currentStep = 2;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    widget.isTaglish
                        ? "Awtomatikong na-verify ang phone!"
                        : "Phone auto-verified!",
                  ),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } catch (e) {
            if (mounted) setState(() => _isSendingOtp = false);
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          // Temporary diagnostics for real-device OTP (no secrets / no SMS codes).
          debugPrint(
            'Firebase Phone Auth failed: code=${e.code}, message=${e.message}',
          );
          if (mounted) {
            setState(() => _isSendingOtp = false);
            final friendly = _otpFailureMessage(e);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  kDebugMode
                      ? '$friendly\n[${e.code}]'
                      : friendly,
                ),
                backgroundColor: Colors.redAccent,
                duration: const Duration(seconds: 6),
              ),
            );
          }
        },
        codeSent: (String verId, int? resendToken) {
          if (mounted) {
            setState(() {
              _verificationId = verId;
              _forceResendingToken = resendToken;
              _isSendingOtp = false;
              if (_currentStep == 1) {
                _currentStep++; // Move to Step 2 only after OTP is successfully sent
              }
            });
            // Start/reset 60s cooldown only after Firebase accepts the send.
            _startResendCooldown();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  widget.isTaglish ? "Naipadala na ang OTP!" : "OTP sent!",
                ),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
        codeAutoRetrievalTimeout: (String verId) {
          if (mounted) {
            _verificationId = verId;
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isSendingOtp = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isTaglish
                  ? "Hindi maipadala ang OTP. Subukan ulit."
                  : "Could not send OTP. Please try again.",
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _verifyOtp() async {
    if (_isVerifyingOtp || _isOtpVerified) return;
    if (_verificationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isTaglish
                ? "Walang OTP session. Mag-resend ng code."
                : "No OTP session. Please resend the code.",
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    if (!_step2Key.currentState!.validate()) return;

    setState(() {
      _isVerifyingOtp = true;
    });
    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _otpCtrl.text.trim(),
      );

      await FirebaseAuth.instance.signInWithCredential(credential);

      if (mounted) {
        setState(() {
          _isOtpVerified = true;
          _isVerifyingOtp = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isTaglish
                  ? "Matagumpay na na-verify!"
                  : "Verified successfully!",
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _isVerifyingOtp = false;
        });
        final msg = e.code == 'session-expired' || e.code == 'invalid-verification-code'
            ? (e.code == 'session-expired'
                ? (widget.isTaglish
                    ? "Nag-expire ang OTP. Mag-resend ng code."
                    : "OTP expired. Please resend the code.")
                : (widget.isTaglish ? "Maling OTP code." : "Invalid OTP code."))
            : _otpFailureMessage(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isVerifyingOtp = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isTaglish ? "Maling OTP code." : "Invalid OTP code.",
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _nextStep() {
    FocusScope.of(context).unfocus();
    if (_currentStep == 0) {
      if (_step0Key.currentState!.validate()) {
        if (_agreedToTerms) {
          setState(() => _currentStep++);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.isTaglish
                  ? "Kailangan mong sumang-ayon sa mga kasunduan."
                  : "You must agree to the Terms and Privacy Policy."),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } else if (_currentStep == 1) {
      if (_step1Key.currentState!.validate()) {
        String phone = _phoneCtrl.text.trim();
        if (phone.startsWith('0')) phone = phone.substring(1);
        phone = '+63$phone';

        if (_verificationId != null && _sentPhoneNumber == phone) {
          // Returning to OTP step with existing valid session and unchanged phone:
          // Proceed to Step 2 without duplicate SMS send or cooldown stall.
          setState(() => _currentStep = 2);
        } else {
          // If phone number changed, invalidate old session
          if (_sentPhoneNumber != null && _sentPhoneNumber != phone) {
            _verificationId = null;
            _isOtpVerified = false;
            _forceResendingToken = null;
            _otpCtrl.clear();
          }
          _sendOtp(); // Initiates OTP Firebase Auth Flow & handles moving forward!
        }
      }
    } else if (_currentStep == 2) {
      if (_step2Key.currentState!.validate()) _handleSignup();
    }
  }

  void _prevStep() {
    FocusScope.of(context).unfocus();
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    } else {
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
    }
  }

  void _handleSignup() async {
    if (_isSigningUp || _isSuccess) return;
    if (!_isOtpVerified) return;

    String finalBarangay = _selectedBarangay ?? "Unknown";

    String email = _emailCtrl.text.trim();
    String phone = _phoneCtrl.text.trim();
    String firstName = _firstNameCtrl.text.trim();
    String lastName = _lastNameCtrl.text.trim();

    setState(() {
      _isSigningUp = true;
      _isSuccess = false;
    });

    try {
      final authService = AuthService();
      final result = await authService.signUp(
        email: email,
        password: _passwordCtrl.text,
        firstName: firstName,
        lastName: lastName,
        barangay: finalBarangay,
        phone: phone,
        houseNo: _houseNoCtrl.text.trim(),
        streetName: _streetNameCtrl.text.trim(),
        city: _cityCtrl.text.trim(),
        province: _provinceCtrl.text.trim(),
        zipCode: _zipCodeCtrl.text.trim(),
        country: _countryCtrl.text.trim(),
      );

      if (!mounted) return;

      if (result['success'] == true) {
        setState(() {
          _isSuccess = true;
          _isSigningUp = false;
        });

        Future.delayed(const Duration(seconds: 3), () async {
          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (_) => LoginScreen(
                  isTaglish: widget.isTaglish,
                  isDarkMode: widget.isDarkMode,
                ),
              ),
              (route) => false,
            );
          }
        });
      } else {
        setState(() => _isSigningUp = false);
        final serverMsg = result['message']?.toString() ?? '';
        final isDuplicate =
            serverMsg.toLowerCase().contains('already registered');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isDuplicate
                  ? (widget.isTaglish
                      ? "Naka-register na ang email. Mag-login na lang."
                      : "Email already registered. Please log in.")
                  : (serverMsg.isNotEmpty
                      ? serverMsg
                      : (widget.isTaglish
                          ? "Nabigo ang paggawa ng account."
                          : "Account creation failed.")),
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSigningUp = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst("Exception: ", "")),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final bgColor = isDark ? const Color(0xFF1A2B3C) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1A2B3C);

    if (_isSuccess) {
      return Scaffold(
        backgroundColor: bgColor,
        body: Stack(children: [
          WaveBackground(isDarkMode: isDark),
          Center(child: _buildSuccessContent(isDark)),
        ]),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        // Keep the app inside the phone's status-bar boundary instead of
        // drawing the sign-up background behind the device indicators.
        backgroundColor: bgColor,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: bgColor,
          statusBarIconBrightness:
              isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
          systemNavigationBarColor: bgColor,
          systemNavigationBarIconBrightness:
              isDark ? Brightness.light : Brightness.dark,
        ),
        elevation: 0,
        leading: IconButton(
          tooltip: widget.isTaglish ? 'Bumalik' : 'Go back',
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor),
          onPressed: _prevStep,
        ),
      ),
      body: Stack(
        children: [
          WaveBackground(isDarkMode: isDark),
          // The AppBar already owns the top safe area.  Avoid adding the
          // status-bar height a second time to every sign-up step.
          SafeArea(
            top: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                  child: _buildProgressIndicator(),
                ),
                _buildStepHeader(_currentStep),
                Expanded(
                  child: IndexedStack(
                    index: _currentStep,
                    children: [
                      _buildStep0(),
                      _buildStep1(),
                      _buildStep2(),
                    ],
                  ),
                ),
                _buildBottomControls(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_totalSteps, (index) {
        final isActive = _currentStep >= index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 8,
          width: isActive ? 32 : 12,
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFF3784DF)
                : (widget.isDarkMode ? Colors.white24 : Colors.grey[300]),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  Widget _buildStepHeader(int stepIndex) {
    final isDark = widget.isDarkMode;
    final textColor = isDark ? Colors.white : const Color(0xFF1A2B3C);
    final subTextColor = isDark ? Colors.white70 : Colors.black54;

    String title = "";
    String subtitle = "";
    IconData stepIcon = Icons.person_add_rounded;

    if (stepIndex == 0) {
      title = widget.isTaglish ? "Gumawa ng Account" : "Account Setup";
      subtitle = widget.isTaglish ? "Simulan natin" : "Let's get started";
      stepIcon = Icons.person_add_alt_1_rounded;
    } else if (stepIndex == 1) {
      title = widget.isTaglish ? "Lokasyon" : "Your Location";
      subtitle = widget.isTaglish ? "Saan ka nakatira?" : "Where do you live?";
      stepIcon = Icons.location_on_rounded;
    } else if (stepIndex == 2) {
      title = widget.isTaglish ? "Beripikasyon" : "Verification";
      subtitle =
          widget.isTaglish ? "Kumpirmahin ang detalye" : "Prove you're human";
      stepIcon = Icons.verified_user_rounded;
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Column(
        key: ValueKey<int>(stepIndex),
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white
                  : const Color(0xFF3784DF).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: stepIndex == 0
                ? Image.asset(
                    'assets/new_logo_nobg.png',
                    height: 32,
                    errorBuilder: (_, __, ___) => Icon(
                      stepIcon,
                      size: 28,
                      color: const Color(0xFF3784DF),
                    ),
                  )
                : Icon(stepIcon, size: 28, color: const Color(0xFF3784DF)),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.w900, color: textColor),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: subTextColor),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // Scrollable step form — top-aligned & constrained for tablets/wide screens
  Widget _buildCenteredStepForm(
      {required Key key, required List<Widget> children}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Form(
                key: key,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStep0() {
    final isDark = widget.isDarkMode;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 360;
        return _buildCenteredStepForm(
          key: _step0Key,
          children: [
            if (isNarrow) ...[
              _buildTextField(
                controller: _firstNameCtrl,
                label: _t("firstName"),
                icon: Icons.person_outline,
                isDark: isDark,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _lastNameCtrl,
                label: _t("lastName"),
                icon: Icons.person_outline,
                isDark: isDark,
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _firstNameCtrl,
                      label: _t("firstName"),
                      icon: Icons.person_outline,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      controller: _lastNameCtrl,
                      label: _t("lastName"),
                      icon: Icons.person_outline,
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            _buildTextField(
              controller: _emailCtrl,
              label: "Email",
              icon: Icons.email_outlined,
              isDark: isDark,
              inputType: TextInputType.emailAddress,
              validator: (val) {
                if (val == null || val.isEmpty) return "Required";
                if (!val.contains('@')) return "Enter a valid email";
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _phoneCtrl,
              label: widget.isTaglish ? "Numero ng Telepono" : "Phone Number",
              hintText: "9123456789",
              prefixText: "+63 ",
              icon: Icons.phone_outlined,
              isDark: isDark,
              inputType: TextInputType.phone,
              maxLength: 10,
              validator: (val) {
                if (val == null || val.isEmpty) return "Required";
                String checkVal = val.startsWith('0') ? val.substring(1) : val;
                if (checkVal.length != 10) {
                  return widget.isTaglish
                      ? "Dapat 10 numero (hal. 9123456789)"
                      : "Must be 10 digits (e.g. 9123456789)";
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _passwordCtrl,
              label: _t("password"),
              icon: Icons.lock_outline_rounded,
              isDark: isDark,
              isPassword: true,
              obscureText: _obscurePassword,
              onTogglePassword: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              validator: (val) {
                if (val == null || val.isEmpty) return "Required";
                if (!_isStrongPassword(val)) {
                  return "Use 8+ chars with upper, lower, number & symbol";
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _confirmPasswordCtrl,
              label: _t("confirmPassword"),
              icon: Icons.lock_outline_rounded,
              isDark: isDark,
              isPassword: true,
              obscureText: _obscureConfirmPassword,
              onTogglePassword: () => setState(
                  () => _obscureConfirmPassword = !_obscureConfirmPassword),
              validator: (val) {
                if (val != _passwordCtrl.text) return "Passwords do not match";
                return null;
              },
            ),
            const SizedBox(height: 24),
            // Compact Agreement Checkbox
            _buildCompactAgreement(),
          ],
        );
      },
    );
  }

  Widget _buildStep1() {
    final isDark = widget.isDarkMode;
    return _buildCenteredStepForm(
      key: _step1Key,
      children: [
        _buildTextField(
          controller: _houseNoCtrl,
          label: "House No.",
          hintText: "e.g., 123 or Blk 1 Lot 2",
          icon: Icons.numbers_rounded,
          isDark: isDark,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _streetNameCtrl,
          label: "Street Name",
          hintText: "e.g., Rizal St.",
          icon: Icons.add_road_rounded,
          isDark: isDark,
        ),
        const SizedBox(height: 16),
        _buildDropdownField(
          label: "Barangay",
          icon: Icons.map_rounded,
          value: _selectedBarangay,
          items: [
            "Barangka",
            "Calumpang",
            "Concepcion Dos",
            "Concepcion Uno",
            "Fortune",
            "Industrial Valley",
            "Jesus Dela Peña",
            "Malanday",
            "Marikina Heights",
            "Nangka",
            "Parang",
            "San Roque",
            "Santa Elena",
            "Santo Niño",
            "Tañong",
            "Tumana"
          ],
          isDark: isDark,
          onChanged: (val) => setState(() => _selectedBarangay = val),
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _cityCtrl,
          label: "City",
          icon: Icons.location_city_rounded,
          isDark: isDark,
          readOnly: true,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _provinceCtrl,
          label: "Province",
          icon: Icons.map_outlined,
          isDark: isDark,
          readOnly: true,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                controller: _zipCodeCtrl,
                label: "ZIP Code",
                icon: Icons.markunread_mailbox_outlined,
                isDark: isDark,
                readOnly: true,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildTextField(
                controller: _countryCtrl,
                label: "Country",
                icon: Icons.public_rounded,
                isDark: isDark,
                readOnly: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStep2() {
    final isDark = widget.isDarkMode;
    return _buildCenteredStepForm(
      key: _step2Key,
      children: [
        Text(
          widget.isTaglish
              ? "Nagpadala kami ng 6-digit code sa iyong numero."
              : "We've sent a 6-digit code to your phone number.",
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 15, color: isDark ? Colors.white70 : Colors.black87),
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _otpCtrl,
          label: "6-Digit OTP",
          hintText: "Enter 6-digit code",
          icon: Icons.security_rounded,
          isDark: isDark,
          inputType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          validator: (val) {
            if (val == null || val.length < 6) {
              return "Enter complete 6-digit OTP";
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: (_isOtpVerified || _isVerifyingOtp) ? null : _verifyOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: _accessibleBlue,
              foregroundColor: Colors.white,
              disabledBackgroundColor:
                  isDark ? Colors.white10 : Colors.grey[300],
              disabledForegroundColor:
                  isDark ? Colors.white54 : Colors.grey[500],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: _isVerifyingOtp
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Text(
                    _isOtpVerified
                        ? (widget.isTaglish ? "Na-verify na" : "Verified")
                        : (widget.isTaglish ? "I-verify" : "Verify"),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: (_isSendingOtp ||
                  _isOtpVerified ||
                  _resendCooldownSec > 0)
              ? null
              : _sendOtp,
          child: _isSendingOtp
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(
                  _resendCooldownSec > 0
                      ? (widget.isTaglish
                          ? "I-resend ang code sa $_resendCooldownSec s"
                          : "Resend code in $_resendCooldownSec s")
                      : (widget.isTaglish
                          ? "I-resend ang Code"
                          : "Resend code"),
                  style: TextStyle(
                      color: (_resendCooldownSec > 0 || _isOtpVerified)
                          ? (isDark ? Colors.white54 : Colors.black45)
                          : _accessibleBlue,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
        )
      ],
    );
  }

  Widget _buildBottomControls() {
    final isDark = widget.isDarkMode;
    return SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A2B3C) : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    offset: const Offset(0, -4),
                    blurRadius: 16,
                  )
                ]),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          color: _accessibleBlue,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: _accessibleBlue.withValues(alpha: 0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: (_currentStep == 2 && !_isOtpVerified) ||
                                  _isSendingOtp ||
                                  _isSigningUp
                              ? null
                              : _nextStep,
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            disabledForegroundColor: Colors.white70,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: (_isSendingOtp && _currentStep == 1) || _isSigningUp
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  _currentStep == _totalSteps - 1
                                      ? _t("signupBtn")
                                      : (widget.isTaglish ? "Susunod" : "Next"),
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.0,
                                      color: Colors.white),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_currentStep == 0)
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _t("alreadyAccount"),
                          style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black54,
                              fontSize: 13),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => LoginScreen(
                                  isTaglish: widget.isTaglish,
                                  isDarkMode: widget.isDarkMode,
                                ),
                              ),
                            );
                          },
                          child: const Text(
                            "Login",
                            style: TextStyle(
                                color: _accessibleBlue,
                                fontWeight: FontWeight.bold,
                                fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    bool isPassword = false,
    bool obscureText = false,
    bool readOnly = false,
    String? hintText,
    VoidCallback? onTogglePassword,
    Function(String)? onChanged,
    TextInputType? inputType,
    int maxLines = 1,
    int? maxLength,
    String? prefixText,
    TextAlign textAlign = TextAlign.start,
    String? Function(String?)? validator,
  }) {
    final fillColor = isDark
        ? const Color(0xFF253B50)
        : const Color(0xFFF4F9FF);
    // City, province, ZIP code, and country are read-only values, not
    // disabled fields. Keep their surface consistent with the rest of the
    // form instead of giving them the grey disabled appearance.
    final activeFillColor = fillColor;

    final iconColor =
        isDark ? Colors.white70 : _accessibleBlue;
    final defaultBorderColor =
        isDark ? Colors.white.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.2);

    return TextFormField(
        controller: controller,
        obscureText: obscureText,
        readOnly: readOnly,
        keyboardType: inputType,
        maxLines: maxLines,
        maxLength: maxLength,
        onChanged: onChanged,
        textAlign: textAlign,
        style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 15,
            fontWeight: FontWeight.w400,
            overflow: TextOverflow.ellipsis),
        validator: validator ??
            (val) => (val == null || val.isEmpty) ? "Required" : null,
        decoration: InputDecoration(
        isDense: true,
        counterText: "",
        prefixText: prefixText,
        hintText: hintText,
        hintStyle: TextStyle(
            color: isDark ? Colors.white70 : const Color(0xFF475569), fontSize: 14),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        labelText: label,
        labelStyle: TextStyle(
          color: isDark ? Colors.white70 : const Color(0xFF64748B),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 12, right: 8),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        suffixIcon: isPassword
            ? IconButton(
                tooltip: obscureText ? 'Show $label' : 'Hide $label',
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                icon: Icon(
                  obscureText
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: iconColor,
                  size: 22,
                ),
                onPressed: onTogglePassword,
              )
            : null,
        filled: true,
        fillColor: activeFillColor,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: defaultBorderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF3784DF), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
        ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required IconData icon,
    required String? value,
    required List<String> items,
    required bool isDark,
    required Function(String?) onChanged,
  }) {
    final fillColor = isDark
        ? const Color(0xFF253B50)
        : const Color(0xFFF4F9FF);
    final iconColor =
        isDark ? Colors.white70 : _accessibleBlue;
    final defaultBorderColor =
        isDark ? Colors.white.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.2);

    return DropdownButtonFormField<String>(
      initialValue: value,
      isDense: true,
      dropdownColor: isDark ? const Color(0xFF1A2B3C) : Colors.white,
      style: TextStyle(
          color: isDark ? Colors.white : Colors.black87, fontSize: 15),
      validator: (val) => (val == null || val.isEmpty)
          ? (widget.isTaglish
              ? "Pakipili ang isang opsyon upang magpatuloy."
              : "Please select an option to continue.")
          : null,
      decoration: InputDecoration(
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        labelText: label,
        labelStyle: TextStyle(
          color: isDark ? Colors.white70 : const Color(0xFF64748B),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 12, right: 8),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        filled: true,
        fillColor: fillColor,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: defaultBorderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF3784DF), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
      ),
      items:
          items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: onChanged,
    );
  }

  /// ---------- COMPACT AGREEMENT WITH POPUPS ----------
  Widget _buildCompactAgreement() {
    final isDark = widget.isDarkMode;
    final textColor = isDark ? Colors.white70 : Colors.black87;
    final linkColor = _accessibleBlue;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Semantics(
          label: 'Agree to Terms and Privacy Policy',
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: Checkbox(
                value: _agreedToTerms,
                onChanged: (val) {
                  if (val == true && !_agreedToTerms) {
                    _showUnifiedLegalPopup();
                  } else {
                    setState(() => _agreedToTerms = false);
                  }
                },
                activeColor: linkColor,
                side: BorderSide(
                    color: isDark ? Colors.white70 : Colors.grey, width: 2),
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Semantics(
            label: 'Open Terms and Privacy Policy',
            button: true,
            child: GestureDetector(
              onTap: () {
                if (!_agreedToTerms) _showUnifiedLegalPopup();
              },
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                          fontSize: 13, color: textColor, height: 1.5),
                      children: [
                        TextSpan(
                            text: widget.isTaglish
                                ? "Para makapagpatuloy, basahin at sumang-ayon sa "
                                : "To continue, please read and agree to the "),
                        TextSpan(
                          text: widget.isTaglish
                              ? "Mga Tuntunin at Patakaran"
                              : "Terms & Privacy Policy",
                          style: TextStyle(
                              color: linkColor,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline),
                        ),
                        const TextSpan(text: "."),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showUnifiedLegalPopup() {
    final scrollController = ScrollController();
    var hasScrolledToBottom = false;
    var listenerAttached = false;
    VoidCallback? scrollListener;

    showDialog(
      context: context,
      barrierColor:
          widget.isDarkMode ? Colors.black87 : Colors.black54, // Dim background
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        final isDark = widget.isDarkMode;
        final bgColor = isDark ? const Color(0xFF1A2B3C) : Colors.white;
        final textColor = isDark ? Colors.white : Colors.black87;

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            if (!listenerAttached) {
              listenerAttached = true;
              scrollListener = () {
                if (!hasScrolledToBottom &&
                    scrollController.hasClients &&
                    scrollController.offset >=
                        scrollController.position.maxScrollExtent - 20) {
                  setStateDialog(() {
                    hasScrolledToBottom = true;
                  });
                }
              };
              scrollController.addListener(scrollListener!);
            }

            // Check automatically in case screen is large enough it doesn't need to scroll
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (scrollController.hasClients) {
                if (scrollController.position.maxScrollExtent <= 0 &&
                    !hasScrolledToBottom) {
                  setStateDialog(() => hasScrolledToBottom = true);
                }
              }
            });

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: bgColor.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.white.withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isDark
                              ? Colors.black54
                              : Colors.black.withValues(alpha: 0.15),
                          blurRadius: 30,
                          offset: const Offset(0, 15),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header icon
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF3784DF).withValues(alpha: 0.15)
                                : Colors.blue.shade50,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF3784DF).withValues(alpha: 0.3),
                                blurRadius: 24,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.gavel_rounded,
                            size: 32,
                            color: Color(0xFF3784DF),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                            widget.isTaglish
                                ? "Mga Tuntunin at Patakaran"
                                : "Terms & Privacy Policy",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.w900,
                                fontSize: 20)),
                        const SizedBox(height: 20),

                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.orange.withValues(alpha: 0.15)
                                  : const Color(0xFFFFF3E0),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: isDark
                                      ? Colors.orange.withValues(alpha: 0.5)
                                      : const Color(0xFFFFCC80),
                                  width: 1.5)),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline_rounded,
                                  color: Colors.orange, size: 24),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  widget.isTaglish
                                      ? "Mag-scroll hanggang sa ibaba para makasagot."
                                      : "Please scroll to the bottom to agree.",
                                  style: TextStyle(
                                      color: isDark
                                          ? Colors.orangeAccent
                                          : Colors.orange.shade900,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800),
                                ),
                              ),
                            ],
                          ),
                        ),

                        Flexible(
                          child: Container(
                            height: MediaQuery.of(context).size.height * 0.4,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : Colors.black.withValues(alpha: 0.03),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.1)
                                    : Colors.black.withValues(alpha: 0.05),
                              ),
                            ),
                            child: SingleChildScrollView(
                              controller: scrollController,
                              physics: const BouncingScrollPhysics(),
                              child: Text(
                                "${_getTermsOfServiceContent()}\n\n${_getPrivacyPolicyContent()}",
                                style: TextStyle(
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black87,
                                    fontSize: 13,
                                    height: 1.6),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () => Navigator.pop(dialogContext),
                                style: TextButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: Text(
                                    widget.isTaglish ? "Kanselahin" : "Cancel",
                                    style: TextStyle(
                                        color: isDark
                                            ? Colors.white54
                                            : Colors.black54,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: hasScrolledToBottom
                                      ? const LinearGradient(
                                          colors: [
                                            Color(0xFF3784DF),
                                            Color(0xFF2BA7A0)
                                          ],
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                        )
                                      : null,
                                  color: hasScrolledToBottom
                                      ? null
                                      : (isDark
                                          ? Colors.white10
                                          : Colors.grey[300]),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: hasScrolledToBottom
                                      ? [
                                          BoxShadow(
                                            color: const Color(0xFF3784DF)
                                                .withValues(alpha: 0.4),
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                          ),
                                        ]
                                      : [],
                                ),
                                child: ElevatedButton(
                                  onPressed: hasScrolledToBottom
                                      ? () {
                                          FocusScope.of(context).unfocus();
                                          setState(() {
                                            _agreedToTerms = true;
                                          });
                                          Navigator.pop(dialogContext);
                                        }
                                      : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: Text(
                                      widget.isTaglish
                                          ? "Sumasang-ayon Ako"
                                          : "I Agree",
                                      style: TextStyle(
                                          color: hasScrolledToBottom
                                              ? Colors.white
                                              : (isDark
                                                  ? Colors.white54
                                                  : Colors.black38),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16)),
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
            );
          },
        );
      },
    ).whenComplete(() {
      if (scrollListener != null) {
        scrollController.removeListener(scrollListener!);
      }
      scrollController.dispose();
    });
  }

  /// ---------- CONTENT STRINGS ----------
  String _getTermsOfServiceContent() {
    if (widget.isTaglish) {
      return """FloodGuard — Mga Tuntunin ng Serbisyo

1. Pagtanggap
Sa paggamit ng FloodGuard, sumasang-ayon ka sa mga tuntuning ito.

2. Layunin ng App
Ang FloodGuard ay para sa paghahanda sa baha sa Marikina. Hindi ito kapalit ng opisyal na babala ng PAMAHALAAN.

3. Disclaimer ng Prediksyon
Ang prediksyon ng water level ay HINDI 100% tumpak. Ito ay batay sa OLS / time-series analytics at maaaring mali dahil sa biglaang ulan, sira/kulang na sensor, o lokal na drainage. Sundin palagi ang PAGASA at Marikina CDRRMO/MDRRMO.

4. Ulat at Lokasyon
Ang mga ulat, numero, at lokasyon ay ginagamit para sa emergency response at hindi ibinebenta.

5. Responsibilidad ng User
Ikaw ang responsable sa katotohanan ng iyong account at mga ulat.""";
    }
    return """FloodGuard — Terms of Service

1. Acceptance
By using FloodGuard, you agree to these terms.

2. App Purpose
FloodGuard supports flood preparedness in Marikina. It does not replace official government warnings.

3. Prediction Disclaimer
Water-level predictions are NOT 100% accurate. They use OLS / time-series analytics and may miss sudden rainfall, sensor gaps, or local drainage effects. Always follow PAGASA and Marikina CDRRMO/MDRRMO advisories.

4. Reports and Location
Reports, phone numbers, and location data are used for emergency response and are not sold.

5. User Responsibility
You are responsible for the accuracy of your account details and submitted reports.""";
  }

  String _getPrivacyPolicyContent() {
    if (widget.isTaglish) {
      return """FloodGuard — Patakaran sa Privacy

1. Panimula
Ipinapaliwanag ng patakarang ito kung anong personal na datos ang kinokolekta at paano ginagamit.

2. Datos na Kinokolekta
Maaaring kabilang ang: email, pangalan, numero ng telepono, barangay/address, lokasyon (GPS), at mga flood report.

3. Paggamit ng Datos
Ginagamit ang datos para sa account, flood alerts, pagpapakita ng mga ulat sa admin/responders, at pagpapabuti ng serbisyo.

4. Seguridad
Nagsusumikap kaming protektahan ang datos, ngunit walang sistemang 100% secure sa internet.

5. Mga Pagbabago
Maaaring i-update ang patakarang ito; ang pinakabagong bersyon ang mananaig sa app.""";
    }
    return """FloodGuard — Privacy Policy

1. Introduction
This policy explains what personal data we collect and how we use it.

2. Data Collected
May include: email, name, phone number, barangay/address, GPS location, and flood reports.

3. Use of Data
Data is used for accounts, flood alerts, showing reports to admins/responders, and improving the service.

4. Security
We work to protect data, but no internet system is 100% secure.

5. Changes
This policy may be updated; the latest in-app version applies.""";
  }

  Widget _buildSuccessContent(bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 800),
          curve: Curves.elasticOut,
          builder: (context, value, child) {
            return Transform.scale(
              scale: value,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.greenAccent,
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    )
                  ],
                ),
                child: const Icon(Icons.check_rounded,
                    color: Colors.white, size: 48),
              ),
            );
          },
        ),
        const SizedBox(height: 32),
        Text(
          widget.isTaglish ? "Tagumpay!" : "Success!",
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF1A2B3C),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          widget.isTaglish
              ? "Handa na ang iyong account."
              : "Your account has been created.",
          style: TextStyle(
            color: isDark ? Colors.white70 : Colors.grey[600],
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}
