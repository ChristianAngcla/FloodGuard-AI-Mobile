import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';
import '../data/translations.dart';
import '../services/auth_service.dart';
import '../services/flood_api_service.dart';
import '../models/user_profile_model.dart';
import '../theme/app_spacing.dart';
import '../utils/name_validator.dart';
import 'login_screen.dart';
import 'signup_screen.dart';
import '../widgets/wave_background.dart';
import 'help_requests_screen.dart';

class ProfileScreen extends StatefulWidget {
  final bool isTaglish;
  final bool isDarkMode;
  final VoidCallback onLogout;
  final bool showBackButton;

  const ProfileScreen({
    super.key,
    required this.isTaglish,
    required this.isDarkMode,
    required this.onLogout,
    this.showBackButton = false,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfile? _userProfile;
  bool _isLoading = true;
  bool _isEditing = false;

  final _formKey = GlobalKey<FormState>();

  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _houseNoCtrl = TextEditingController();
  final _streetNameCtrl = TextEditingController();
  final _cityCtrl = TextEditingController(text: "Marikina City");
  final _provinceCtrl = TextEditingController(text: "Metro Manila");
  final _zipCodeCtrl = TextEditingController(text: "1800");
  final _countryCtrl = TextEditingController(text: "Philippines");

  String? _selectedBarangay;
  String _avatarSeed = 'Felix'; // Default avatar seed
  String _originalPhone = '';

  final List<String> _marikinaBarangays = [
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
  ];

  /// Map legacy ASCII spellings from older accounts onto canonical names.
  String _canonicalBarangay(String raw) {
    const aliases = {
      'Jesus De La Pena': 'Jesus Dela Peña',
      'Jesus Dela Pena': 'Jesus Dela Peña',
      'Santo Nino': 'Santo Niño',
      'Tanong': 'Tañong',
    };
    return aliases[raw] ?? raw;
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
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

  Future<void> _loadProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString('user_data');

      if (userDataString != null) {
        final Map<String, dynamic> userData = jsonDecode(userDataString);

        // Map the stored JSON safely using our model
        final profile = UserProfile.fromJson(userData);

        if (mounted) {
          setState(() {
            _userProfile = profile;
            _firstNameCtrl.text = profile.firstName;
            _lastNameCtrl.text = profile.lastName;
            final formattedPhone = formatPhMobileNumber(profile.phone);
            _phoneCtrl.text = formattedPhone;
            _originalPhone = formattedPhone;

            final safeEmail = profile.email.trim().toLowerCase();
            _houseNoCtrl.text = profile.houseNo.isNotEmpty
                ? profile.houseNo
                : (prefs.getString('temp_house_no_$safeEmail') ?? '');
            _streetNameCtrl.text = profile.streetName.isNotEmpty
                ? profile.streetName
                : (prefs.getString('temp_street_name_$safeEmail') ?? '');
            _cityCtrl.text =
                profile.city.isNotEmpty ? profile.city : "Marikina City";
            _provinceCtrl.text =
                profile.province.isNotEmpty ? profile.province : "Metro Manila";
            _zipCodeCtrl.text =
                profile.zipCode.isNotEmpty ? profile.zipCode : "1800";
            _countryCtrl.text =
                profile.country.isNotEmpty ? profile.country : "Philippines";
            _avatarSeed = prefs.getString('avatar_seed_$safeEmail') ?? 'Felix';

            final barangay = _canonicalBarangay(profile.barangay);
            if (_marikinaBarangays.contains(barangay)) {
              _selectedBarangay = barangay;
            } else {
              _selectedBarangay = "Nangka";
            }
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error loading profile: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final phone = _phoneCtrl.text.trim();
    if (!RegExp(r'^09\d{9}$').hasMatch(phone)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isTaglish
                  ? "Maglagay ng wastong 11-digit mobile number na nagsisimula sa 09."
                  : "Enter a valid 11-digit mobile number starting with 09.",
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    // Require Firebase SMS OTP verification if changing the mobile number
    if (_originalPhone.isNotEmpty && phone != _originalPhone) {
      FocusScope.of(context).unfocus();
      final verified = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _PhoneChangeOtpDialog(
          newPhone: phone,
          isTaglish: widget.isTaglish,
          isDarkMode: widget.isDarkMode,
        ),
      );

      if (verified != true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.isTaglish
                    ? "Hindi na-verify ang bagong mobile number. Hindi nai-save ang profile."
                    : "New mobile number was not verified. Profile was not saved.",
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }
    }

    if (!mounted) return;
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);
    final uid = await AuthService().getEffectiveUid() ??
        _userProfile?.uid ??
        'anon_user';

    String capitalize(String s) {
      if (s.isEmpty) return s;
      return s.split(' ').map((word) {
        if (word.isEmpty) return word;
        return word[0].toUpperCase() + word.substring(1);
      }).join(' ');
    }

    final formattedFirstName =
        capitalize(NameValidator.normalize(_firstNameCtrl.text));
    final formattedLastName =
        capitalize(NameValidator.normalize(_lastNameCtrl.text));
    final barangay = _selectedBarangay ?? "Nangka";
    final houseNo = _houseNoCtrl.text.trim();
    final streetName = _streetNameCtrl.text.trim();
    final city =
        _cityCtrl.text.trim().isEmpty ? "Marikina City" : _cityCtrl.text.trim();
    final province = _provinceCtrl.text.trim().isEmpty
        ? "Metro Manila"
        : _provinceCtrl.text.trim();
    final zipCode =
        _zipCodeCtrl.text.trim().isEmpty ? "1800" : _zipCodeCtrl.text.trim();
    final country = _countryCtrl.text.trim().isEmpty
        ? "Philippines"
        : _countryCtrl.text.trim();
    final safeEmail = (_userProfile?.email ?? '').trim().toLowerCase();

    // Call API service to persist to backend
    await FloodApiService.saveUserProfile(
      uid: uid,
      email: safeEmail,
      firstName: formattedFirstName,
      lastName: formattedLastName,
      phone: phone,
      houseNo: houseNo,
      streetName: streetName,
      barangay: barangay,
      city: city,
      province: province,
      zipCode: zipCode,
      country: country,
    );

    if (mounted) {
      // Instantly update the local cache so changes reflect everywhere across the app!
      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString('user_data');
      Map<String, dynamic> userData = {};
      if (userDataString != null) {
        try {
          userData =
              Map<String, dynamic>.from(jsonDecode(userDataString) as Map);
        } catch (_) {}
      }

      userData['uid'] = uid;
      userData['email'] = safeEmail;
      userData['firstName'] = formattedFirstName;
      userData['lastName'] = formattedLastName;
      userData['first_name'] = formattedFirstName;
      userData['last_name'] = formattedLastName;
      userData['phone'] = phone;
      userData['houseNo'] = houseNo;
      userData['house_no'] = houseNo;
      userData['streetName'] = streetName;
      userData['street_name'] = streetName;
      userData['barangay'] = barangay;
      userData['city'] = city;
      userData['province'] = province;
      userData['zipCode'] = zipCode;
      userData['zip_code'] = zipCode;
      userData['country'] = country;

      await prefs.setString('user_data', jsonEncode(userData));

      if (safeEmail.isNotEmpty) {
        await prefs.setString('temp_house_no_$safeEmail', houseNo);
        await prefs.setString('temp_street_name_$safeEmail', streetName);
        await prefs.setString('avatar_seed_$safeEmail', _avatarSeed);
      }

      // Sync FCM notification routing with new registered barangay (preserves GPS if active, updates fallback)
      await NotificationService.syncFromCurrentEnvironment(
        registeredBarangay: barangay,
      );

      if (mounted) {
        setState(() {
          _isEditing = false;
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.isTaglish
                ? "Na-save ang profile!"
                : "Profile updated successfully!"),
            backgroundColor: Colors.green,
          ),
        );

        _loadProfile();
      }
    }
  }

  // Show a bottom sheet to let the user pick an avatar seed
  void _showAvatarPicker() {
    final List<String> seeds = [
      'Felix',
      'Aneka',
      'Ethan',
      'Leo',
      'Mia',
      'Nolan',
      'Zoe',
      'Oliver',
      'Lily',
      'Jack',
      'Chloe',
      'Noah',
      'Max',
      'Ruby',
      'Oscar',
      'Luna'
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor:
          widget.isDarkMode ? const Color(0xFF1A2B3C) : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.isTaglish ? "Pumili ng Avatar" : "Choose an Avatar",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: widget.isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 300,
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: seeds.length,
                  itemBuilder: (context, index) {
                    final seed = seeds[index];
                    final isSelected = seed == _avatarSeed;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _avatarSeed = seed);
                        Navigator.pop(context);
                      },
                      child: CircleAvatar(
                        backgroundColor: isSelected
                            ? const Color(0xFF3784DF)
                            : const Color(0xFF3784DF).withValues(alpha: 0.1),
                        backgroundImage: NetworkImage(
                            'https://api.dicebear.com/7.x/adventurer/png?seed=$seed'),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleLogout() async {
    await NotificationService.cleanupOnLogout();

    await AuthService().logout(); // Centralized logout logic

    widget.onLogout();
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
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final bgColor = isDark ? const Color(0xFF1A2B3C) : const Color(0xFFF8F9FA);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subTextColor =
        isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          WaveBackground(isDarkMode: isDark),
          SafeArea(
            bottom: false,
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF3784DF)))
                : _userProfile == null
                    ? Column(
                        children: [
                          if (widget.showBackButton)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: IconButton(
                                icon: Icon(Icons.arrow_back_rounded,
                                    color: textColor),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ),
                          Expanded(
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.person_off_rounded,
                                      size: 80, color: Colors.grey[400]),
                                  const SizedBox(height: 16),
                                  Text(
                                    widget.isTaglish
                                        ? "Mag-login upang makita ang iyong profile"
                                        : "Log in to view your profile",
                                    style: TextStyle(color: subTextColor),
                                  ),
                                  const SizedBox(height: 32),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 48),
                                    child: Column(
                                      children: [
                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  const Color(0xFF3784DF),
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 16),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                            ),
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => LoginScreen(
                                                    isTaglish: widget.isTaglish,
                                                    isDarkMode:
                                                        widget.isDarkMode,
                                                  ),
                                                ),
                                              ).then((_) => _loadProfile());
                                            },
                                            child: Text(
                                              widget.isTaglish
                                                  ? "Mag-login"
                                                  : "Log In",
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        SizedBox(
                                          width: double.infinity,
                                          child: OutlinedButton(
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor:
                                                  const Color(0xFF3784DF),
                                              side: const BorderSide(
                                                  color: Color(0xFF3784DF),
                                                  width: 2),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 16),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                            ),
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => SignupScreen(
                                                    isTaglish: widget.isTaglish,
                                                    isDarkMode:
                                                        widget.isDarkMode,
                                                  ),
                                                ),
                                              ).then((_) => _loadProfile());
                                            },
                                            child: Text(
                                              widget.isTaglish
                                                  ? "Gumawa ng Account"
                                                  : "Sign Up",
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.only(
                            top: 16, bottom: 140, left: 24, right: 24),
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 520),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Custom Header
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    widget.showBackButton
                                        ? IconButton(
                                            icon: Icon(Icons.arrow_back_rounded,
                                                color: textColor),
                                            onPressed: () =>
                                                Navigator.pop(context),
                                          )
                                        : const SizedBox(width: 48),
                                    Text(
                                      _t("profile"),
                                      style: TextStyle(
                                          color: textColor,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    if (_userProfile != null)
                                      IconButton(
                                        icon: Icon(
                                            _isEditing
                                                ? Icons.close_rounded
                                                : Icons.edit_rounded,
                                            color: const Color(0xFF3784DF)),
                                        onPressed: () {
                                          setState(() {
                                            if (_isEditing) {
                                              _loadProfile(); // Revert changes
                                            }
                                            _isEditing = !_isEditing;
                                          });
                                        },
                                      )
                                    else
                                      const SizedBox(width: 48),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                // Avatar
                                GestureDetector(
                                  onTap: _isEditing ? _showAvatarPicker : null,
                                  child: Stack(
                                    alignment: Alignment.bottomRight,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: const Color(0xFF3784DF),
                                              width: 2),
                                        ),
                                        child: CircleAvatar(
                                          radius: 50,
                                          backgroundColor:
                                              const Color(0xFF3784DF)
                                                  .withValues(alpha: 0.1),
                                          backgroundImage: NetworkImage(
                                              'https://api.dicebear.com/7.x/adventurer/png?seed=$_avatarSeed'),
                                        ),
                                      ),
                                      if (_isEditing)
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF3784DF),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.edit_rounded,
                                              size: 20, color: Colors.white),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _userProfile != null &&
                                          (_userProfile!.firstName.isNotEmpty ||
                                              _userProfile!.lastName.isNotEmpty)
                                      ? '${_userProfile!.firstName} ${_userProfile!.lastName}'
                                          .trim()
                                      : "User",
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _userProfile?.email ?? "",
                                  style: TextStyle(
                                      fontSize: 14, color: subTextColor),
                                ),
                                const SizedBox(height: 32),

                                // Form Fields
                                Form(
                                  key: _formKey,
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _buildTextField(
                                              controller: _firstNameCtrl,
                                              label: widget.isTaglish
                                                  ? "Pangalan"
                                                  : "First Name",
                                              icon: Icons.person_outline,
                                              isDark: isDark,
                                              readOnly: !_isEditing,
                                              validator: (val) =>
                                                  NameValidator.validate(
                                                val,
                                                isTaglish: widget.isTaglish,
                                                fieldName: widget.isTaglish
                                                    ? "Pangalan"
                                                    : "First Name",
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: _buildTextField(
                                              controller: _lastNameCtrl,
                                              label: widget.isTaglish
                                                  ? "Apelyido"
                                                  : "Last Name",
                                              icon: Icons.person_outline,
                                              isDark: isDark,
                                              readOnly: !_isEditing,
                                              validator: (val) =>
                                                  NameValidator.validate(
                                                val,
                                                isTaglish: widget.isTaglish,
                                                fieldName: widget.isTaglish
                                                    ? "Apelyido"
                                                    : "Last Name",
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      _buildTextField(
                                        controller: _phoneCtrl,
                                        label: "Mobile Number",
                                        icon: Icons.phone_outlined,
                                        isDark: isDark,
                                        readOnly: !_isEditing,
                                        keyboardType: TextInputType.phone,
                                        maxLength: 11,
                                        inputFormatters: [
                                          FilteringTextInputFormatter
                                              .digitsOnly,
                                          LengthLimitingTextInputFormatter(11),
                                        ],
                                        validator: (val) {
                                          if (val == null ||
                                              val.trim().isEmpty) {
                                            return "Required";
                                          }
                                          final clean = val.trim();
                                          if (!RegExp(r'^09\d{9}$')
                                              .hasMatch(clean)) {
                                            return widget.isTaglish
                                                ? "Maglagay ng wastong 11-digit mobile number na nagsisimula sa 09."
                                                : "Enter a valid 11-digit mobile number starting with 09.";
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 32),
                                      const Divider(),
                                      const SizedBox(height: 16),
                                      _buildTextField(
                                        controller: _houseNoCtrl,
                                        label: "House No.",
                                        icon: Icons.numbers_rounded,
                                        isDark: isDark,
                                        readOnly: !_isEditing,
                                      ),
                                      const SizedBox(height: 16),
                                      _buildTextField(
                                        controller: _streetNameCtrl,
                                        label: "Street Name",
                                        icon: Icons.add_road_rounded,
                                        isDark: isDark,
                                        readOnly: !_isEditing,
                                      ),
                                      const SizedBox(height: 16),
                                      _buildDropdownField(
                                        label: "Barangay",
                                        icon: Icons.map_rounded,
                                        value: _selectedBarangay,
                                        items: _marikinaBarangays,
                                        isDark: isDark,
                                        readOnly: !_isEditing,
                                        onChanged: _isEditing
                                            ? (val) => setState(
                                                () => _selectedBarangay = val)
                                            : null,
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
                                          const SizedBox(width: 10),
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
                                              icon: Icons
                                                  .markunread_mailbox_outlined,
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
                                  ),
                                ),

                                const SizedBox(height: 40),

                                if (_isEditing)
                                  Container(
                                    width: double.infinity,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF3784DF),
                                          Color(0xFF2BA7A0)
                                        ],
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF3784DF)
                                              .withValues(alpha: 0.4),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                        ),
                                      ),
                                      onPressed: _saveProfile,
                                      icon: const Icon(Icons.save_rounded,
                                          color: Colors.white),
                                      label: Text(
                                        widget.isTaglish
                                            ? "I-save ang Profile"
                                            : "Save Profile",
                                        style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white),
                                      ),
                                    ),
                                  ),

                                if (_isEditing) const SizedBox(height: 16),

                                Container(
                                  width: double.infinity,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF3784DF),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF3784DF)
                                            .withValues(alpha: 0.35),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      )
                                    ],
                                  ),
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      elevation: 0,
                                    ),
                                    onPressed: _isEditing
                                        ? null
                                        : () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    HelpRequestsScreen(
                                                  isTaglish: widget.isTaglish,
                                                  isDarkMode: widget.isDarkMode,
                                                ),
                                              ),
                                            );
                                          },
                                    icon: const Icon(
                                        Icons.support_agent_rounded,
                                        color: Colors.white),
                                    label: Text(
                                      widget.isTaglish
                                          ? "Mga Hiling Kong Tulong"
                                          : "My Help Requests",
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 16),

                                // Logout Button
                                Container(
                                  width: double.infinity,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: _isEditing
                                        ? (isDark
                                            ? Colors.white10
                                            : Colors.grey[200])
                                        : Colors.redAccent,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: _isEditing
                                        ? []
                                        : [
                                            BoxShadow(
                                              color: Colors.redAccent
                                                  .withValues(alpha: 0.4),
                                              blurRadius: 12,
                                              offset: const Offset(0, 4),
                                            )
                                          ],
                                  ),
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      elevation: 0,
                                    ),
                                    onPressed:
                                        _isEditing ? null : _handleLogout,
                                    icon: Icon(
                                      Icons.logout_rounded,
                                      color: _isEditing
                                          ? (isDark
                                              ? Colors.white54
                                              : Colors.grey)
                                          : Colors.white,
                                    ),
                                    label: Text(
                                      _t("logout"),
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: _isEditing
                                              ? (isDark
                                                  ? Colors.white54
                                                  : Colors.grey)
                                              : Colors.white),
                                    ),
                                  ),
                                ),
                                if (_isEditing)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 12.0),
                                    child: Text(
                                      widget.isTaglish
                                          ? "Kailangan i-save ang profile bago mag-logout."
                                          : "You must save your profile to logout.",
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: isDark
                                              ? Colors.white54
                                              : Colors.grey[600]),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    bool readOnly = false,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    int? maxLength,
  }) {
    final fillColor =
        isDark ? const Color(0xFF253B50) : const Color(0xFFF4F9FF);
    final activeFillColor = readOnly
        ? (isDark ? const Color(0xFF203449) : const Color(0xFFF8FAFC))
        : fillColor;
    final iconColor = isDark ? Colors.white70 : const Color(0xFF1769AA);
    final defaultBorderColor =
        isDark ? Colors.white24 : const Color(0xFFE2E8F0);

    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLength: maxLength,
      style: TextStyle(
        color: isDark ? Colors.white : const Color(0xFF0F172A),
        fontSize: 15,
        fontWeight: FontWeight.w400,
        overflow: TextOverflow.ellipsis,
      ),
      validator: validator ??
          ((val) => (val == null || val.isEmpty) ? "Required" : null),
      decoration: InputDecoration(
        isDense: true,
        counterText: "",
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        labelText: label,
        labelStyle: TextStyle(
          color: isDark ? Colors.white70 : const Color(0xFF64748B),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        prefixIconConstraints:
            const BoxConstraints(minWidth: 48, minHeight: 48),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 12, right: 8),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        filled: true,
        fillColor: activeFillColor,
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: defaultBorderColor)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF3784DF), width: 2)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.redAccent, width: 1.5)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.redAccent, width: 2)),
        errorStyle: const TextStyle(
          color: Colors.redAccent,
          fontSize: 12,
          fontWeight: FontWeight.w500,
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
    bool readOnly = false,
    Function(String?)? onChanged,
  }) {
    final fillColor =
        isDark ? const Color(0xFF253B50) : const Color(0xFFF4F9FF);
    final activeFillColor = readOnly
        ? (isDark ? const Color(0xFF203449) : const Color(0xFFF8FAFC))
        : fillColor;
    final iconColor = isDark ? Colors.white70 : const Color(0xFF1769AA);
    final defaultBorderColor =
        isDark ? Colors.white24 : const Color(0xFFE2E8F0);

    if (readOnly) {
      return InputDecorator(
        isEmpty: value == null || value.isEmpty,
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
          filled: true,
          fillColor: activeFillColor,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: defaultBorderColor),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                value ?? '',
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return DropdownButtonFormField<String>(
      initialValue: value,
      isDense: true,
      icon: readOnly
          ? const SizedBox()
          : null, // Hide dropdown arrow if read-only
      dropdownColor: isDark ? const Color(0xFF1A2B3C) : Colors.white,
      style: TextStyle(
          color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 15),
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
        prefixIconConstraints:
            const BoxConstraints(minWidth: 48, minHeight: 48),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 12, right: 8),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        filled: true,
        fillColor: activeFillColor,
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: defaultBorderColor)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: Color(0xFF3784DF), width: 2)),
      ),
      items:
          items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: onChanged,
    );
  }
}

class _PhoneChangeOtpDialog extends StatefulWidget {
  final String newPhone;
  final bool isTaglish;
  final bool isDarkMode;

  const _PhoneChangeOtpDialog({
    required this.newPhone,
    required this.isTaglish,
    required this.isDarkMode,
  });

  @override
  State<_PhoneChangeOtpDialog> createState() => _PhoneChangeOtpDialogState();
}

class _PhoneChangeOtpDialogState extends State<_PhoneChangeOtpDialog> {
  final TextEditingController _otpCtrl = TextEditingController();
  bool _isSendingOtp = false;
  bool _isVerifyingOtp = false;
  String? _verificationId;
  int? _forceResendingToken;
  String? _errorMessage;
  int _cooldownSec = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _sendOtp();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpCtrl.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    if (!mounted) return;
    setState(() => _cooldownSec = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_cooldownSec <= 1) {
        timer.cancel();
        setState(() => _cooldownSec = 0);
      } else {
        setState(() => _cooldownSec--);
      }
    });
  }

  String _formatToE164(String phone) {
    String clean = phone.trim();
    if (clean.startsWith('0')) {
      clean = clean.substring(1);
    }
    if (clean.startsWith('+63')) {
      return clean;
    }
    return '+63$clean';
  }

  void _sendOtp() async {
    if (_isSendingOtp || _cooldownSec > 0) return;
    setState(() {
      _isSendingOtp = true;
      _errorMessage = null;
    });

    final e164 = _formatToE164(widget.newPhone);

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: e164,
        timeout: const Duration(seconds: 60),
        forceResendingToken: _forceResendingToken,
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            await FirebaseAuth.instance.signInWithCredential(credential);
            if (mounted) {
              Navigator.of(context).pop(true);
            }
          } catch (e) {
            if (mounted) {
              setState(() => _errorMessage = e.toString());
            }
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          if (mounted) {
            setState(() {
              _isSendingOtp = false;
              _errorMessage = _otpFailureMessage(e);
            });
          }
        },
        codeSent: (String verId, int? resendToken) {
          if (mounted) {
            setState(() {
              _verificationId = verId;
              _forceResendingToken = resendToken;
              _isSendingOtp = false;
            });
            _startCooldown();
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
        setState(() {
          _isSendingOtp = false;
          _errorMessage = widget.isTaglish
              ? "Hindi maipadala ang OTP. Pakisubukang muli."
              : "Could not send OTP. Please try again.";
        });
      }
    }
  }

  void _verifyOtp() async {
    final code = _otpCtrl.text.trim();
    if (code.length != 6 || _isVerifyingOtp) return;
    if (_verificationId == null) {
      setState(() {
        _errorMessage = widget.isTaglish
            ? "Walang aktibong OTP session. Pindutin ang Ipadala Muli."
            : "No active OTP session. Tap Resend Code.";
      });
      return;
    }

    setState(() {
      _isVerifyingOtp = true;
      _errorMessage = null;
    });

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: code,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _isVerifyingOtp = false;
          if (e.code == 'session-expired') {
            _errorMessage = widget.isTaglish
                ? "Nag-expire ang OTP. Mag-resend ng code."
                : "OTP expired. Please resend code.";
          } else if (e.code == 'invalid-verification-code') {
            _errorMessage = widget.isTaglish
                ? "Maling OTP code. Pakitingnan muli."
                : "Invalid OTP code. Please check and try again.";
          } else {
            _errorMessage = _otpFailureMessage(e);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isVerifyingOtp = false;
          _errorMessage = widget.isTaglish
              ? "Maling OTP code."
              : "Invalid OTP code.";
        });
      }
    }
  }

  String _otpFailureMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-phone-number':
        return widget.isTaglish
            ? 'Hindi valid ang numero ng mobile.'
            : 'Invalid mobile number.';
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

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final bgColor = isDark ? const Color(0xFF1A2B3C) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtextColor =
        isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569);

    return AlertDialog(
      backgroundColor: bgColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF3784DF).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.phonelink_lock_rounded,
                color: Color(0xFF3784DF), size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.isTaglish
                  ? "I-verify ang Numero"
                  : "Verify Mobile Number",
              style: TextStyle(
                color: textColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.isTaglish
                  ? "Nagpadala kami ng 6-digit SMS OTP sa ${widget.newPhone} upang kumpirmahin ang pagbabago."
                  : "We sent a 6-digit SMS OTP to ${widget.newPhone} to confirm this phone number change.",
              style: TextStyle(color: subtextColor, fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _otpCtrl,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              autofocus: true,
              style: TextStyle(
                color: textColor,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 6,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              decoration: InputDecoration(
                counterText: "",
                hintText: "••••••",
                hintStyle: TextStyle(
                  color: isDark ? Colors.white24 : Colors.black26,
                  letterSpacing: 6,
                  fontSize: 22,
                ),
                filled: true,
                fillColor:
                    isDark ? const Color(0xFF253B50) : const Color(0xFFF1F5F9),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      const BorderSide(color: Color(0xFF3784DF), width: 2),
                ),
              ),
              onChanged: (val) {
                if (val.trim().length == 6) {
                  _verifyOtp();
                }
              },
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.redAccent.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_cooldownSec > 0)
                  Text(
                    widget.isTaglish
                        ? "Ipadala muli sa ${_cooldownSec}s"
                        : "Resend in ${_cooldownSec}s",
                    style: TextStyle(
                      fontSize: 13,
                      color: subtextColor,
                      fontWeight: FontWeight.w500,
                    ),
                  )
                else
                  TextButton.icon(
                    onPressed: _isSendingOtp ? null : _sendOtp,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(
                      widget.isTaglish ? "Ipadala Muli" : "Resend Code",
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            widget.isTaglish ? "Kanselahin" : "Cancel",
            style: TextStyle(color: subtextColor),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3784DF),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
          onPressed: _isVerifyingOtp ? null : _verifyOtp,
          child: _isVerifyingOtp
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  widget.isTaglish ? "Kumpirmahin" : "Confirm",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
        ),
      ],
    );
  }
}
