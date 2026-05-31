import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:ui';
import '../data/translations.dart';
import '../services/flood_api_service.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'home_map_screen.dart';
import '../widgets/wave_background.dart';

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
  bool _isSendingOtp = false;
  bool _isVerifyingOtp = false;

  @override
  void dispose() {
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
    String phone = _phoneCtrl.text.trim();

    // Ensure proper +63 format regardless of whether they typed a leading 0
    if (phone.startsWith('0')) phone = phone.substring(1);
    phone = '+63$phone';

    setState(() {
      _isSendingOtp = true;
    });

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            await FirebaseAuth.instance.signInWithCredential(credential);
            if (mounted) {
              setState(() {
                _isOtpVerified = true;
                _otpCtrl.text = credential.smsCode ?? '';
                _isSendingOtp = false;
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
          if (mounted) {
            setState(() => _isSendingOtp = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("OTP Failed: ${e.message}"),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        },
        codeSent: (String verId, int? resendToken) {
          if (mounted) {
            setState(() {
              _verificationId = verId;
              _isSendingOtp = false;
              if (_currentStep == 1) {
                _currentStep++; // Move to Step 2 only after OTP is successfully sent
              }
            });
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
            content: Text("Error: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _verifyOtp() async {
    if (_step2Key.currentState!.validate() && _verificationId != null) {
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
        _sendOtp(); // Initiates OTP Firebase Auth Flow & handles moving forward!
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
    String finalBarangay = _selectedBarangay ?? "Unknown";

    String email = _emailCtrl.text.trim();
    String phone = _phoneCtrl.text.trim();
    String firstName = _firstNameCtrl.text.trim();
    String lastName = _lastNameCtrl.text.trim();

    try {
      // Show loading indicator
      setState(() => _isSuccess = false);

      final authService = AuthService();
      final success = await authService.signUp(
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

      if (success) {
        // If all successful, show the success animation
        setState(() {
          _isSuccess = true;
        });

        // Automatically navigate away after success animation.
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
        throw Exception(widget.isTaglish
            ? "Nabigo ang paggawa ng account."
            : "Account creation failed.");
      }
    } catch (e) {
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
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    final isDark = widget.isDarkMode;
    final bgColor = isDark ? const Color(0xFF1A2B3C) : const Color(0xFFF5F7FA);
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor),
          onPressed: _prevStep,
        ),
      ),
      body: Stack(
        children: [
          WaveBackground(isDarkMode: isDark),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 16),
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
                if (!isKeyboardOpen) _buildBottomControls(),
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
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF3784DF).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(stepIcon, size: 36, color: const Color(0xFF3784DF)),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 28, fontWeight: FontWeight.w900, color: textColor),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: subTextColor),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // Centralized wrapper to ensure all form steps are perfectly centered vertically
  Widget _buildCenteredStepForm(
      {required Key key, required List<Widget> children}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),
            child: IntrinsicHeight(
              child: Form(
                key: key,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
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
    return _buildCenteredStepForm(
      key: _step0Key,
      children: [
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
            if (!_isStrongPassword(val))
              return "Use 8+ chars with upper, lower, number & symbol";
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
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                controller: _cityCtrl,
                label: "City",
                icon: Icons.location_city_rounded,
                isDark: isDark,
                readOnly: true,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTextField(
                controller: _provinceCtrl,
                label: "Province",
                icon: Icons.map_outlined,
                isDark: isDark,
                readOnly: true,
              ),
            ),
          ],
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
            const SizedBox(width: 16),
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
              fontSize: 16, color: isDark ? Colors.white70 : Colors.black87),
        ),
        const SizedBox(height: 32),
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
            if (val == null || val.length < 6)
              return "Enter complete 6-digit OTP";
            return null;
          },
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: (_isOtpVerified || _isVerifyingOtp) ? null : _verifyOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3784DF),
              foregroundColor: Colors.white,
              disabledBackgroundColor:
                  isDark ? Colors.white10 : Colors.grey[300],
              disabledForegroundColor:
                  isDark ? Colors.white54 : Colors.grey[500],
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: _isVerifyingOtp
                ? const SizedBox(
                    height: 20,
                    width: 20,
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
        const SizedBox(height: 16),
        TextButton(
          onPressed: _isSendingOtp ? null : _sendOtp,
          child: _isSendingOtp
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(
                  widget.isTaglish ? "I-resend ang Code" : "Resend Code",
                  style: const TextStyle(
                      color: Color(0xFF3784DF),
                      fontWeight: FontWeight.bold,
                      fontSize: 17),
                ),
        )
      ],
    );
  }

  Widget _buildBottomControls() {
    final isDark = widget.isDarkMode;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A2B3C) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              offset: const Offset(0, -4),
              blurRadius: 16,
            )
          ]),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
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
                    onPressed:
                        (_currentStep == 2 && !_isOtpVerified) || _isSendingOtp
                            ? null
                            : _nextStep,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _isSendingOtp && _currentStep == 1
                        ? const SizedBox(
                            height: 20,
                            width: 20,
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
            Padding(
              padding: const EdgeInsets.only(top: 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _t("alreadyAccount"),
                    style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black54,
                        fontSize: 15),
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
                          color: Color(0xFF3784DF),
                          fontWeight: FontWeight.bold,
                          fontSize: 15),
                    ),
                  ),
                ],
              ),
            ),
        ],
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
        ? Colors.white.withOpacity(0.05)
        : Colors.black.withOpacity(0.03);
    final activeFillColor =
        readOnly ? (isDark ? Colors.black12 : Colors.grey[200]) : fillColor;

    final iconColor =
        isDark ? Colors.white54 : const Color(0xFF3784DF).withOpacity(0.7);
    final defaultBorderColor =
        isDark ? Colors.white.withOpacity(0.2) : Colors.grey.withOpacity(0.2);

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
          color: isDark ? Colors.white : Colors.black87, fontSize: 15),
      validator: validator ??
          (val) => (val == null || val.isEmpty) ? "Required" : null,
      decoration: InputDecoration(
        counterText: "",
        prefixText: prefixText,
        hintText: hintText,
        hintStyle: TextStyle(
            color: isDark ? Colors.white30 : Colors.black38, fontSize: 13),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        labelText: label,
        labelStyle: TextStyle(color: iconColor, fontSize: 14),
        prefixIcon: Icon(icon, color: iconColor),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  obscureText
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: iconColor,
                ),
                onPressed: onTogglePassword,
              )
            : null,
        filled: true,
        fillColor: activeFillColor,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: defaultBorderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Color(0xFF3784DF), width: 2.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
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
        ? Colors.white.withOpacity(0.05)
        : Colors.black.withOpacity(0.03);
    final iconColor =
        isDark ? Colors.white54 : const Color(0xFF3784DF).withOpacity(0.7);
    final defaultBorderColor =
        isDark ? Colors.white.withOpacity(0.2) : Colors.grey.withOpacity(0.2);

    return DropdownButtonFormField<String>(
      value: value,
      dropdownColor: isDark ? const Color(0xFF1A2B3C) : Colors.white,
      style: TextStyle(
          color: isDark ? Colors.white : Colors.black87, fontSize: 15),
      validator: (val) => (val == null || val.isEmpty) ? "Required" : null,
      decoration: InputDecoration(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        labelText: label,
        labelStyle: TextStyle(color: iconColor, fontSize: 14),
        prefixIcon: Icon(icon, color: iconColor),
        filled: true,
        fillColor: fillColor,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: defaultBorderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Color(0xFF3784DF), width: 2.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
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
    final linkColor = const Color(0xFF3784DF);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () {
            if (!_agreedToTerms) {
              _showUnifiedLegalPopup();
            } else {
              setState(() => _agreedToTerms = false);
            }
          },
          child: SizedBox(
            width: 24,
            height: 24,
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
                  color: isDark ? Colors.white54 : Colors.grey, width: 2),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () {
              if (!_agreedToTerms) _showUnifiedLegalPopup();
            },
            child: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 13, color: textColor, height: 1.5),
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
      ],
    );
  }

  void _showUnifiedLegalPopup() {
    showDialog(
      context: context,
      barrierColor:
          widget.isDarkMode ? Colors.black87 : Colors.black54, // Dim background
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        bool hasScrolledToBottom = false;
        final ScrollController scrollController = ScrollController();

        final isDark = widget.isDarkMode;
        final bgColor = isDark ? const Color(0xFF1A2B3C) : Colors.white;
        final textColor = isDark ? Colors.white : Colors.black87;

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            // Check automatically in case screen is large enough it doesn't need to scroll
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (scrollController.hasClients) {
                if (scrollController.position.maxScrollExtent <= 0 &&
                    !hasScrolledToBottom) {
                  setStateDialog(() => hasScrolledToBottom = true);
                }
              }
            });

            scrollController.addListener(() {
              if (!hasScrolledToBottom &&
                  scrollController.offset >=
                      scrollController.position.maxScrollExtent - 20) {
                setStateDialog(() {
                  hasScrolledToBottom = true;
                });
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
                      color: bgColor.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withOpacity(0.1)
                            : Colors.white.withOpacity(0.5),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isDark
                              ? Colors.black54
                              : Colors.black.withOpacity(0.15),
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
                                ? const Color(0xFF3784DF).withOpacity(0.15)
                                : Colors.blue.shade50,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF3784DF).withOpacity(0.3),
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
                                  ? Colors.orange.withOpacity(0.15)
                                  : const Color(0xFFFFF3E0),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: isDark
                                      ? Colors.orange.withOpacity(0.5)
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
                                  ? Colors.white.withOpacity(0.05)
                                  : Colors.black.withOpacity(0.03),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withOpacity(0.1)
                                    : Colors.black.withOpacity(0.05),
                              ),
                            ),
                            child: SingleChildScrollView(
                              controller: scrollController,
                              physics: const BouncingScrollPhysics(),
                              child: Text(
                                _getTermsOfServiceContent() +
                                    "\n\n" +
                                    _getPrivacyPolicyContent(),
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
                                                .withOpacity(0.4),
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                          ),
                                        ]
                                      : [],
                                ),
                                child: ElevatedButton(
                                  onPressed: hasScrolledToBottom
                                      ? () {
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
    );
  }

  /// ---------- CONTENT STRINGS ----------
  String _getTermsOfServiceContent() {
    return """FloodGuard AI Terms of Service

1. Acceptance of Terms
By accessing and using FloodGuard AI, you accept and agree to be bound by the terms and provision of this agreement.

2. Use License
Permission is granted to temporarily download one copy of the materials (information or software) on FloodGuard AI for personal, non-commercial transitory viewing only. This is the grant of a license, not a transfer of title, and under this license you may not:
- Modifying or copying the materials
- Using the materials for commercial purposes
- Attempting to decompile or reverse engineer any software contained on FloodGuard AI
- Removing any copyright or other proprietary notations from the materials
- Transferring the materials to another person or "mirroring" the materials on any other server

3. Disclaimer
The materials on FloodGuard AI are provided on an 'as is' basis. FloodGuard AI makes no warranties, expressed or implied, and hereby disclaims and negates all other warranties including, without limitation, implied warranties or conditions of merchantability, fitness for a particular purpose, or non-infringement of intellectual property or other violation of rights.

4. Limitations
In no event shall FloodGuard AI or its suppliers be liable for any damages (including, without limitation, damages for loss of data or profit, or due to business interruption) arising out of the use or inability to use the materials on FloodGuard AI.""";
  }

  String _getPrivacyPolicyContent() {
    return """FloodGuard AI Privacy Policy

1. Introduction
FloodGuard AI ("we" or "us" or "our") operates the FloodGuard AI application. This page informs you of our policies regarding the collection, use, and disclosure of personal data when you use our Service and the choices you have associated with that data.

2. Information Collection and Use
We collect several different types of information for various purposes to provide and improve our Service to you.

Types of Data Collected:
- Personal Data: While using our Service, we may ask you to provide us with certain personally identifiable information that can be used to contact or identify you ("Personal Data"). This may include, but is not limited to:
  * Email address
  * First name and last name
  * Username
  * Location data

3. Use of Data
FloodGuard AI uses the collected data for various purposes:
- To provide and maintain our Service
- To notify you about changes to our Service
- To provide customer care and support
- To gather analysis or valuable information so that we can improve our Service
- To monitor the usage of our Service
- To detect, prevent and address technical issues

4. Security of Data
The security of your data is important to us, but remember that no method of transmission over the Internet or method of electronic storage is 100% secure. While we strive to use commercially acceptable means to protect your Personal Data, we cannot guarantee its absolute security.

5. Changes to This Privacy Policy
We may update our Privacy Policy from time to time. We will notify you of any changes by posting the new Privacy Policy on this page.""";
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
