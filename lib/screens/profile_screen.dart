import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';
import '../data/translations.dart';
import '../services/auth_service.dart';
import '../services/flood_api_service.dart';
import '../models/user_profile_model.dart';
import 'login_screen.dart';
import 'signup_screen.dart';
import '../widgets/wave_background.dart';

class ProfileScreen extends StatefulWidget {
  final bool isTaglish;
  final bool isDarkMode;
  final VoidCallback onLogout;

  const ProfileScreen({
    super.key,
    required this.isTaglish,
    required this.isDarkMode,
    required this.onLogout,
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
            _phoneCtrl.text = profile.phone;

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

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);
    final uid = await AuthService().getEffectiveUid() ?? _userProfile?.uid ?? 'anon_user';

    String capitalize(String s) {
      if (s.isEmpty) return s;
      return s.split(' ').map((word) {
        if (word.isEmpty) return word;
        return word[0].toUpperCase() + word.substring(1).toLowerCase();
      }).join(' ');
    }

    final formattedFirstName = capitalize(_firstNameCtrl.text.trim());
    final formattedLastName = capitalize(_lastNameCtrl.text.trim());
    final barangay = _selectedBarangay ?? "Nangka";
    final phone = _phoneCtrl.text.trim();
    final houseNo = _houseNoCtrl.text.trim();
    final streetName = _streetNameCtrl.text.trim();
    final city = _cityCtrl.text.trim().isEmpty ? "Marikina City" : _cityCtrl.text.trim();
    final province = _provinceCtrl.text.trim().isEmpty ? "Metro Manila" : _provinceCtrl.text.trim();
    final zipCode = _zipCodeCtrl.text.trim().isEmpty ? "1800" : _zipCodeCtrl.text.trim();
    final country = _countryCtrl.text.trim().isEmpty ? "Philippines" : _countryCtrl.text.trim();
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
          userData = Map<String, dynamic>.from(jsonDecode(userDataString) as Map);
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

      // Re-subscribe FCM to the new barangay for live emergency alerts!
      NotificationService.subscribeToBarangay(barangay);

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
    if (_userProfile != null) {
      await NotificationService.unsubscribeFromBarangay(_userProfile!.barangay);
    }

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
    final bgColor = isDark ? const Color(0xFF1A2B3C) : const Color(0xFFF5F7FA);
    final textColor = isDark ? Colors.white : const Color(0xFF1A2B3C);
    final subTextColor = isDark ? Colors.white70 : Colors.black54;

    return Container(
      color: bgColor,
      child: Stack(
        children: [
          WaveBackground(isDarkMode: isDark),
          _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF3784DF)))
              : _userProfile == null
                  ? Center(
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
                            padding: const EdgeInsets.symmetric(horizontal: 48),
                            child: Column(
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF3784DF),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => LoginScreen(
                                            isTaglish: widget.isTaglish,
                                            isDarkMode: widget.isDarkMode,
                                          ),
                                        ),
                                      ).then((_) => _loadProfile());
                                    },
                                    child: Text(
                                      widget.isTaglish ? "Mag-login" : "Log In",
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
                                      foregroundColor: const Color(0xFF3784DF),
                                      side: const BorderSide(
                                          color: Color(0xFF3784DF), width: 2),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => SignupScreen(
                                            isTaglish: widget.isTaglish,
                                            isDarkMode: widget.isDarkMode,
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
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.only(
                          top: 40, bottom: 140, left: 24, right: 24),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 520),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Custom Header
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const SizedBox(
                                      width: 48), // Balance for centering
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
                                        backgroundColor: const Color(0xFF3784DF)
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
                                style: TextStyle(fontSize: 14, color: subTextColor),
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
                                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
                                        borderRadius: BorderRadius.circular(16),
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

                              // Logout Button
                              Container(
                                width: double.infinity,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: _isEditing
                                      ? (isDark ? Colors.white10 : Colors.grey[200])
                                      : Colors.redAccent,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: _isEditing
                                      ? []
                                      : [
                                          BoxShadow(
                                            color:
                                                Colors.redAccent.withValues(alpha: 0.4),
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
                                  onPressed: _isEditing ? null : _handleLogout,
                                  icon: Icon(
                                    Icons.logout_rounded,
                                    color: _isEditing
                                        ? (isDark ? Colors.white54 : Colors.grey)
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
  }) {
    final fillColor =
        isDark ? const Color(0xFF253B50) : const Color(0xFFF4F9FF);
    final activeFillColor =
        readOnly ? (isDark ? Colors.black12 : Colors.grey[200]) : fillColor;
    final iconColor =
        isDark ? Colors.white54 : const Color(0xFF3784DF).withValues(alpha: 0.7);
    final defaultBorderColor = isDark ? Colors.white10 : Colors.transparent;

    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: TextStyle(
        color: isDark ? Colors.white : Colors.black87,
        fontSize: 15,
        fontWeight: FontWeight.w400,
        overflow: TextOverflow.ellipsis,
      ),
      validator: (val) => (val == null || val.isEmpty) ? "Required" : null,
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
        prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
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
    final activeFillColor =
        readOnly ? (isDark ? Colors.black12 : Colors.grey[200]) : fillColor;
    final iconColor =
        isDark ? Colors.white54 : const Color(0xFF3784DF).withValues(alpha: 0.7);
    final defaultBorderColor = isDark ? Colors.white10 : Colors.transparent;

    return DropdownButtonFormField<String>(
      initialValue: value,
      isDense: true,
      icon: readOnly
          ? const SizedBox()
          : null, // Hide dropdown arrow if read-only
      dropdownColor: isDark ? const Color(0xFF1A2B3C) : Colors.white,
      style: TextStyle(
          color: isDark ? Colors.white : Colors.black87, fontSize: 15),
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
        prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
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
