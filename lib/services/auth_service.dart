import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Update this to match your Flask server's IP and port!
  // Note: Your Flask script uses port 5000.
  // For the Android Emulator, use the special IP 10.0.2.2 to connect to your PC.
  final String _flaskApiUrl = 'http://10.0.2.2:5000/api';

  // GET CURRENT USER
  User? get currentUser => _auth.currentUser;

  // UNIFIED AUTH CHECKS
  Future<bool> isLoggedIn() async {
    // Check Firebase
    if (_auth.currentUser != null) return true;

    // Check Custom Session
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('is_logged_in') ?? false;
  }

  Future<String?> getEffectiveUid() async {
    // Check Firebase
    if (_auth.currentUser != null) return _auth.currentUser!.uid;

    // Check Custom Session
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('user_data');
    if (userDataString != null) {
      final userData = jsonDecode(userDataString);
      return userData['uid'] ?? userData['id']; // Support both keys
    }
    return null;
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  // 1. SIGN UP (MongoDB)
  Future<bool> signUp({
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

    try {
      final response = await http.post(
        Uri.parse('https://floodguard-database.onrender.com/api/auth/signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'firstName': formattedFirstName,
          'lastName': formattedLastName,
          'email': email,
          'password': password,
          'barangay': barangay,
          'phone': phone,
          'houseNo': houseNo,
          'house_no': houseNo,
          'streetName': streetName,
          'street_name': streetName,
          'city': city,
          'province': province,
          'zipCode': zipCode,
          'zip_code': zipCode,
          'country': country,
          'first_name': formattedFirstName,
          'last_name': formattedLastName,
        }),
      );

      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        // Since the backend MongoDB schema is dropping houseNo and streetName, we save them locally
        final prefs = await SharedPreferences.getInstance();
        final safeEmail = email.trim().toLowerCase();
        await prefs.setString('temp_house_no_$safeEmail', houseNo);
        await prefs.setString('temp_street_name_$safeEmail', streetName);
        return true;
      }
      return false;
    } catch (e) {
      print("MongoDB Sign Up Error: $e");
      return false;
    }
  }

  // 2. LOGIN (MongoDB)
  Future<bool> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('https://floodguard-database.onrender.com/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        final prefs = await SharedPreferences.getInstance();

        // Recover dropped backend fields from local cache
        Map<String, dynamic> user = data['user'];
        final safeEmail = email.trim().toLowerCase();
        final tempHouse = prefs.getString('temp_house_no_$safeEmail');
        final tempStreet = prefs.getString('temp_street_name_$safeEmail');

        if (tempHouse != null &&
            (user['house_no'] == null || user['house_no'] == '')) {
          user['house_no'] = tempHouse;
          user['houseNo'] = tempHouse;
        }
        if (tempStreet != null &&
            (user['street_name'] == null || user['street_name'] == '')) {
          user['street_name'] = tempStreet;
          user['streetName'] = tempStreet;
        }

        await prefs.setString('user_data', jsonEncode(user));
        await prefs.setString('auth_token', data['token']);
        await prefs.setBool('is_logged_in', true);
        return true;
      }
      return false;
    } catch (e) {
      print("MongoDB Login Error: $e");
      return false;
    }
  }

  // 3. LOGOUT
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();

    // Unsubscribe from notifications before clearing
    final userDataString = prefs.getString('user_data');
    if (userDataString != null) {
      final userData = jsonDecode(userDataString);
      final barangay = userData['barangay'];
      if (barangay != null) {
        try {
          await NotificationService.unsubscribeFromBarangay(
              barangay.toString());
        } catch (e) {
          print("Notification Unsubscribe Error: $e");
        }
      }
    }

    // Clear auth session only — keep theme/language preferences
    await prefs.remove('user_data');
    await prefs.remove('auth_token');
    await prefs.setBool('is_logged_in', false);

    // Also sign out from Firebase just in case
    await _auth.signOut();
  }

  /// Request a password reset code (MongoDB auth — not Firebase email reset).
  /// Returns the demo_code when the API includes it (for testing without SMTP).
  Future<Map<String, dynamic>> requestPasswordReset(String email) async {
    try {
      final response = await http.post(
        Uri.parse(
            'https://floodguard-database.onrender.com/api/auth/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email.trim().toLowerCase()}),
      );
      final data = jsonDecode(response.body);
      return Map<String, dynamic>.from(data as Map);
    } catch (e) {
      print("Forgot password error: $e");
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(
            'https://floodguard-database.onrender.com/api/auth/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email.trim().toLowerCase(),
          'code': code.trim(),
          'newPassword': newPassword,
        }),
      );
      final data = jsonDecode(response.body);
      return Map<String, dynamic>.from(data as Map);
    } catch (e) {
      print("Reset password error: $e");
      return {'success': false, 'message': e.toString()};
    }
  }
}
