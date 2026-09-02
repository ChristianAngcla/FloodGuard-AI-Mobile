import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile_model.dart';
import '../data/translations.dart';
import 'wave_background.dart';
import '../screens/profile_screen.dart';
import '../screens/login_screen.dart';

class AppDrawer extends StatefulWidget {
  final bool isDarkMode;
  final bool isTaglish;
  final Function(bool) onToggleDarkMode;
  final Function(bool) onToggleLanguage;

  const AppDrawer({
    super.key,
    required this.isDarkMode,
    required this.isTaglish,
    required this.onToggleDarkMode,
    required this.onToggleLanguage,
  });

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  UserProfile? _userProfile;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  String _t(String key) {
    return Translations.texts[key]?[widget.isTaglish ? "tl" : "en"] ?? key;
  }

  Future<void> _loadProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool('is_logged_in') ?? false;
      final userDataString = prefs.getString('user_data');

      if (isLoggedIn && userDataString != null) {
        final Map<String, dynamic> userData = jsonDecode(userDataString);
        final profile = UserProfile.fromJson(userData);

        if (mounted) {
          setState(() {
            _userProfile = profile;
            _isLoggedIn = true;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoggedIn = false;
            _userProfile = null;
          });
        }
      }
    } catch (e) {
      debugPrint("Error loading profile in Drawer: $e");
    }
  }

  void _openProfile() {
    Navigator.pop(context);
    if (_isLoggedIn && _userProfile != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProfileScreen(
            isTaglish: widget.isTaglish,
            isDarkMode: widget.isDarkMode,
            onLogout: () {
              if (mounted) {
                setState(() {
                  _isLoggedIn = false;
                  _userProfile = null;
                });
              }
            },
            showBackButton: true,
          ),
        ),
      ).then((_) => _loadProfile());
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LoginScreen(
            isTaglish: widget.isTaglish,
            isDarkMode: widget.isDarkMode,
          ),
        ),
      ).then((_) => _loadProfile());
    }
  }

  @override
  Widget build(BuildContext context) {
    // Modern color palette adjustments
    final bgColor =
        widget.isDarkMode ? const Color(0xFF1A2B3C) : const Color(0xFFF5F7FA);
    final surfaceColor =
        widget.isDarkMode ? const Color(0xFF253B50) : const Color(0xFFF5F7FA);
    final textColor =
        widget.isDarkMode ? Colors.white : const Color(0xFF1A2B3C);
    final accentColor = const Color(0xFF3784DF);

    return Drawer(
      backgroundColor: bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Stack(
        children: [
          WaveBackground(isDarkMode: widget.isDarkMode),
          SafeArea(
            child: Column(
              children: [
                // Header Section
                _buildHeader(context, textColor, accentColor),

                const SizedBox(height: 16),

                // Scrollable Content
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      if (_isLoggedIn && _userProfile != null) ...[
                        _buildProfileCard(
                            context, _userProfile!, surfaceColor, textColor),
                        const SizedBox(height: 12),
                      ],
                      Material(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(16),
                        child: ListTile(
                          leading:
                              Icon(Icons.person_rounded, color: accentColor),
                          title: Text(
                            'Profile',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                          trailing: Icon(Icons.chevron_right_rounded,
                              color: textColor.withValues(alpha: 0.4)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          onTap: _openProfile,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildSectionTitle(_t("settings"), textColor),
                      const SizedBox(height: 8),

                      // Dark Mode Toggle
                      Material(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(16),
                        child: SwitchListTile(
                          title: Text(
                            _t("darkMode"),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                          secondary: Icon(
                            widget.isDarkMode
                                ? Icons.dark_mode_rounded
                                : Icons.light_mode_rounded,
                            color: accentColor,
                          ),
                          activeThumbColor: accentColor,
                          value: widget.isDarkMode,
                          onChanged: widget.onToggleDarkMode,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Language Selector
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.language_rounded,
                                    color: accentColor, size: 24),
                                const SizedBox(width: 16),
                                Text(
                                  _t("language"),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: textColor,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildLanguageOption(
                                    label: "English",
                                    isSelected: !widget.isTaglish,
                                    onTap: () => widget.onToggleLanguage(false),
                                    activeColor: accentColor,
                                    textColor: textColor,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildLanguageOption(
                                    label: "Tagalog",
                                    isSelected: widget.isTaglish,
                                    onTap: () => widget.onToggleLanguage(true),
                                    activeColor: accentColor,
                                    textColor: textColor,
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

                // Footer
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Text(
                        "FloodGuard v1.0.0",
                        style: TextStyle(
                          color: textColor.withValues(alpha: 0.5),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
      BuildContext context, Color textColor, Color accentColor) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: accentColor, width: 2),
            ),
            child: ClipOval(
              child: Image.asset(
                "assets/new_logo_nobg.png",
                width: 48,
                height: 48,
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "FloodGuard",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  layoutBuilder: (currentChild, previousChildren) {
                    return Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        ...previousChildren,
                        if (currentChild != null) currentChild,
                      ],
                    );
                  },
                  child: Text(
                    _t("staySafe"),
                    key: ValueKey<String>(_t("staySafe")),
                    style: TextStyle(
                      fontSize: 12,
                      color: textColor.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(
    BuildContext context,
    UserProfile? profile,
    Color surfaceColor,
    Color textColor,
  ) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF3784DF).withValues(alpha: 0.15),
            const Color(0xFF3784DF).withValues(alpha: 0.05)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border:
            Border.all(color: const Color(0xFF3784DF).withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Avatar
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF3784DF), width: 2),
              ),
              child: const CircleAvatar(
                radius: 24,
                backgroundColor: Color(0xFF3784DF),
                child: Icon(Icons.person, color: Colors.white, size: 28),
              ),
            ),
            const SizedBox(width: 16),

            // Info Column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${widget.isTaglish ? 'Kamusta' : 'Welcome'}, ${(profile?.firstName.isNotEmpty == true) ? profile!.firstName : 'User'}",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: textColor,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    // Safely handle nullable email
                    profile?.email ?? '',
                    style: TextStyle(
                      color: textColor.withValues(alpha: 0.6),
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3784DF).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.location_on,
                            size: 12, color: Color(0xFF3784DF)),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            _userProfile?.barangay ?? "Loading...",
                            style: TextStyle(
                              color: Color(0xFF3784DF),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: textColor.withValues(alpha: 0.5),
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildLanguageOption({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required Color activeColor,
    required Color textColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? activeColor : textColor.withValues(alpha: 0.1),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : textColor.withValues(alpha: 0.7),
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
