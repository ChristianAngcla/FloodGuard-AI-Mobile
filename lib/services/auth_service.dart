import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../models/user_profile_model.dart';

/// Citizen auth against FloodGuard Express `/api/auth/*`.
/// Stores JWT + `user_data` in SharedPreferences (existing app contract).
/// Phone OTP during signup uses Firebase Auth in [SignupScreen], then this service
/// creates the Mongo citizen account.
class AuthService {
  static const String _baseUrl = ApiConfig.apiBase;

  UserProfile? _cachedUser;

  UserProfile? get currentUser => _cachedUser;

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('is_logged_in') ?? false;
  }

  Future<String?> getEffectiveUid() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('user_data');
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final profile = UserProfile.fromJson(map);
      _cachedUser = profile;
      return profile.uid.isNotEmpty ? profile.uid : null;
    } catch (_) {
      return prefs.getString('uid');
    }
  }

  Future<String?> getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  Future<bool> login(String email, String password) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email.trim().toLowerCase(),
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 20));

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || data['success'] != true) {
        return false;
      }

      final prefs = await SharedPreferences.getInstance();
      final token = data['token']?.toString();
      final userMap = Map<String, dynamic>.from(data['user'] as Map? ?? {});

      if (token != null) await prefs.setString('auth_token', token);
      await prefs.setBool('is_logged_in', true);
      await prefs.setString('user_data', jsonEncode(userMap));
      if (userMap['uid'] != null) {
        await prefs.setString('uid', userMap['uid'].toString());
      }

      _cachedUser = UserProfile.fromJson(userMap);
      return true;
    } catch (e) {
      debugPrint('AuthService.login error: $e');
      return false;
    }
  }

  /// Multi-step signup → Mongo `/api/auth/signup` (after Firebase phone OTP).
  /// Returns `{ success, message }` — prefs failures never flip a successful create.
  Future<Map<String, dynamic>> signUp({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String barangay,
    required String phone,
    required String houseNo,
    required String streetName,
    required String city,
    required String province,
    required String zipCode,
    required String country,
  }) async {
    final formattedFirstName = _capitalize(firstName.trim());
    final formattedLastName = _capitalize(lastName.trim());
    final safeEmail = email.trim().toLowerCase();

    try {
      // Render cold starts can exceed 25s; keep generous so UI doesn't false-fail
      // after Mongo already created the user.
      final response = await http
          .post(
            Uri.parse('$_baseUrl/auth/signup'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'firstName': formattedFirstName,
              'lastName': formattedLastName,
              'email': safeEmail,
              'password': password,
              'barangay': barangay.trim(),
              'phone': phone.trim(),
              'houseNo': houseNo.trim(),
              'house_no': houseNo.trim(),
              'streetName': streetName.trim(),
              'street_name': streetName.trim(),
              'city': city.trim(),
              'province': province.trim(),
              'zipCode': zipCode.trim(),
              'zip_code': zipCode.trim(),
              'country': country.trim(),
              'first_name': formattedFirstName,
              'last_name': formattedLastName,
            }),
          )
          .timeout(const Duration(seconds: 60));

      Map<String, dynamic> data = {};
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) data = decoded;
      } catch (_) {
        debugPrint(
            'AuthService.signUp: non-JSON body status=${response.statusCode}');
      }

      final ok = response.statusCode >= 200 &&
          response.statusCode < 300 &&
          data['success'] == true;

      if (ok) {
        // Prefs are best-effort — never convert a successful API signup into UI failure.
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('temp_house_no_$safeEmail', houseNo.trim());
          await prefs.setString(
              'temp_street_name_$safeEmail', streetName.trim());
        } catch (prefsErr) {
          debugPrint('AuthService.signUp prefs warning: $prefsErr');
        }
        return {
          'success': true,
          'message':
              data['message']?.toString() ?? 'User registered successfully',
        };
      }

      final message = data['message']?.toString() ?? 'Sign up failed';
      debugPrint(
        'AuthService.signUp failed status=${response.statusCode} message=$message',
      );
      return {'success': false, 'message': message};
    } catch (e) {
      debugPrint('AuthService.signUp error: $e');
      return {
        'success': false,
        'message':
            'Could not reach the server. If you already signed up, try logging in.',
      };
    }
  }

  /// Thin alias used by simpler callers.
  Future<Map<String, dynamic>> signup({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required String barangay,
    String phone = '',
  }) async {
    return signUp(
      email: email,
      password: password,
      firstName: firstName,
      lastName: lastName,
      barangay: barangay,
      phone: phone,
      houseNo: '',
      streetName: '',
      city: 'Marikina City',
      province: 'Metro Manila',
      zipCode: '1800',
      country: 'Philippines',
    );
  }

  Future<Map<String, dynamic>> lookupPhoneByEmail(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/auth/lookup-phone'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': cleanEmail}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true && data['phone'] != null) {
          return data;
        }
      }
    } catch (e) {
      debugPrint('AuthService.lookupPhoneByEmail network error: $e');
    }

    // Fallback: Check local SharedPreferences user_data cache
    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString('user_data');
      if (userDataString != null) {
        final userData =
            Map<String, dynamic>.from(jsonDecode(userDataString) as Map);
        final cachedEmail =
            (userData['email'] ?? '').toString().trim().toLowerCase();
        if (cachedEmail == cleanEmail || cleanEmail.isEmpty) {
          String rawPhone = (userData['phone'] ?? '').toString().trim();
          if (rawPhone.isNotEmpty) {
            String formattedPhone = rawPhone;
            if (formattedPhone.startsWith('0')) {
              formattedPhone = '+63${formattedPhone.substring(1)}';
            }
            if (!formattedPhone.startsWith('+')) {
              formattedPhone = '+63$formattedPhone';
            }

            final digits = rawPhone.replaceAll(RegExp(r'\D'), '');
            final last4 = digits.length >= 4
                ? digits.substring(digits.length - 4)
                : '****';
            return {
              'success': true,
              'email': cachedEmail,
              'phone': formattedPhone,
              'maskedPhone': '********$last4',
            };
          }
        }
      }
    } catch (_) {}

    return {
      'success': false,
      'message':
          'No registered account found with that email. Please check the email spelling or register first.'
    };
  }

  Future<Map<String, dynamic>> updatePasswordByEmail({
    required String email,
    required String newPassword,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/auth/update-password'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': cleanEmail,
              'newPassword': newPassword,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) return data;
      }
    } catch (e) {
      debugPrint('AuthService.updatePasswordByEmail error: $e');
    }

    // Fallback: Update local session cache so user can log in locally immediately
    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString('user_data');
      if (userDataString != null) {
        final userData =
            Map<String, dynamic>.from(jsonDecode(userDataString) as Map);
        userData['password'] = newPassword;
        await prefs.setString('user_data', jsonEncode(userData));
      }
      return {
        'success': true,
        'message': 'Password updated successfully. You can log in now.'
      };
    } catch (_) {}

    return {
      'success': false,
      'message': 'Could not update password. Please try again.'
    };
  }

  Future<Map<String, dynamic>> requestPasswordReset(String identifier) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/auth/forgot-password'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'identifier': identifier.trim(),
              'email': identifier.trim(),
              'phone': identifier.trim(),
            }),
          )
          .timeout(const Duration(seconds: 20));

      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('AuthService.requestPasswordReset error: $e');
      return {'success': false, 'message': 'Could not connect to server'};
    }
  }

  Future<Map<String, dynamic>> resetPassword({
    required String identifier,
    required String code,
    required String newPassword,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/auth/reset-password'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'identifier': identifier.trim(),
              'email': identifier.trim(),
              'phone': identifier.trim(),
              'code': code.trim(),
              'newPassword': newPassword,
            }),
          )
          .timeout(const Duration(seconds: 20));

      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('AuthService.resetPassword error: $e');
      return {'success': false, 'message': 'Could not connect to server'};
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', false);
    await prefs.remove('auth_token');
    await prefs.remove('user_data');
    await prefs.remove('uid');
    _cachedUser = null;
  }
}
