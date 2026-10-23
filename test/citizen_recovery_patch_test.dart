import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:floodguard_ai/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService.client = null;
  });

  tearDown(() {
    AuthService.client = null;
  });

  group('Citizen Account Recovery (Patch P0-1 Tests)', () {
    test('lookupPhoneByEmail handles HTTP 410 decommissioned safely without leaking cached phone', () async {
      // Setup SharedPreferences with cached user_data that contains a phone number
      SharedPreferences.setMockInitialValues({
        'user_data': jsonEncode({
          'email': 'citizen@example.com',
          'phone': '09171234567',
        }),
      });

      // Mock backend returning HTTP 410 Gone with decommissioned flag
      AuthService.client = MockClient((request) async {
        if (request.url.path.endsWith('/auth/lookup-phone')) {
          return http.Response(
            jsonEncode({
              'success': false,
              'decommissioned': true,
              'message': 'Direct phone lookup is permanently decommissioned for citizen privacy.',
            }),
            410,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final authService = AuthService();
      final res = await authService.lookupPhoneByEmail('citizen@example.com');

      expect(res['success'], isFalse);
      expect(res['decommissioned'], isTrue);
      expect(res['phone'], isNull);
      expect(res['maskedPhone'], isNull);
      expect(res['message'], contains('decommissioned'));
    });

    test('updatePasswordByEmail returns success when backend returns 200', () async {
      AuthService.client = MockClient((request) async {
        if (request.url.path.endsWith('/auth/update-password')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['email'], 'citizen@example.com');
          expect(body['newPassword'], 'StrongPassword123!');
          expect(body['firebaseIdToken'], 'valid_mock_token');
          return http.Response(
            jsonEncode({
              'success': true,
              'message': 'Password updated successfully. You can log in now.',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final authService = AuthService();
      final res = await authService.updatePasswordByEmail(
        email: 'citizen@example.com',
        newPassword: 'StrongPassword123!',
        firebaseIdToken: 'valid_mock_token',
      );

      expect(res['success'], isTrue);
      expect(res['message'], contains('Password updated successfully'));
    });

    test('updatePasswordByEmail returns server error and does NOT fake success via local cache', () async {
      // Pre-seed local cache
      SharedPreferences.setMockInitialValues({
        'user_data': jsonEncode({
          'email': 'citizen@example.com',
          'password': 'old_hashed_password',
        }),
      });

      // Mock backend returning HTTP 403 Forbidden with verified phone mismatch error
      AuthService.client = MockClient((request) async {
        if (request.url.path.endsWith('/auth/update-password')) {
          return http.Response(
            jsonEncode({
              'success': false,
              'message': 'We could not verify this account with the mobile number provided.',
            }),
            403,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final authService = AuthService();
      final res = await authService.updatePasswordByEmail(
        email: 'citizen@example.com',
        newPassword: 'AttackerPassword123!',
        firebaseIdToken: 'mismatched_phone_token',
      );

      // Must be false — must never report success or update cache when server rejected it!
      expect(res['success'], isFalse);
      expect(res['message'], contains('We could not verify this account'));

      final prefs = await SharedPreferences.getInstance();
      final updatedUserData = jsonDecode(prefs.getString('user_data')!) as Map<String, dynamic>;
      expect(updatedUserData['password'], 'old_hashed_password', reason: 'Old password in cache must remain untouched');
    });

    test('updatePasswordByEmail extracts HTTP 429 rate limit message cleanly', () async {
      AuthService.client = MockClient((request) async {
        if (request.url.path.endsWith('/auth/update-password')) {
          return http.Response(
            jsonEncode({
              'error': 'Too many requests',
              'message': 'Too many password recovery attempts. Please wait 15 minutes and try again.',
            }),
            429,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final authService = AuthService();
      final res = await authService.updatePasswordByEmail(
        email: 'citizen@example.com',
        newPassword: 'StrongPassword123!',
        firebaseIdToken: 'any_token',
      );

      expect(res['success'], isFalse);
      expect(res['message'], contains('Too many password recovery attempts'));
    });
  });
}
