import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:floodguard_ai/services/flood_api_service.dart';
import 'package:floodguard_ai/services/auth_service.dart';
import 'package:floodguard_ai/widgets/multistep_report_sheet.dart';
import 'package:floodguard_ai/services/location_service.dart';

HelpRequestLocationResolver _mockLocationResolver() {
  return HelpRequestLocationResolver(
    isLocationServiceEnabled: () async => true,
    checkPermission: () async => LocationPermission.whileInUse,
    requestPermission: () async => LocationPermission.whileInUse,
    getCurrentCoordinates: () async => const HelpRequestCoordinates(
      latitude: 14.6507,
      longitude: 121.1029,
    ),
    openAppSettings: () async => true,
  );
}

Widget _buildReportSheetApp({
  HelpRequestSubmitHook? submitHook,
  bool isTaglish = false,
}) {
  return MaterialApp(
    home: Scaffold(
      body: MultistepReportSheet(
        isTaglish: isTaglish,
        isDarkMode: false,
        onSuccess: () {},
        onSafe: () {},
        onUnsafe: () {},
        locationResolver: _mockLocationResolver(),
        submitFloodReport: submitHook,
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'user_data': jsonEncode({
        'uid': 'citizen-user-001',
        'firstName': 'Juan',
        'lastName': 'Dela Cruz',
        'phone': '09171234567',
        'email': 'juan@example.com',
        'barangay': 'Nangka',
      }),
      'auth_token': 'mock-jwt-token',
      'is_logged_in': true,
    });
    FloodApiService.client = null;
    AuthService.client = null;
    FloodApiService.lastHelpRequestError = null;
    FloodApiService.lastHelpRequestRetryAfterSeconds = null;
    FloodApiService.lastRateLimitMessage = null;
    FloodApiService.lastRateLimitRetryAfterSeconds = null;
    FloodApiService.lastStatusRateLimited = false;
    FloodApiService.lastProfileSaveError = null;
    FloodApiService.lastProfileSaveRateLimited = false;
  });

  tearDown(() {
    FloodApiService.client = null;
    AuthService.client = null;
  });

  group('Scenario A: Rapid Help Request submit taps produce only 1 active HTTP request', () {
    test('FloodApiService rejects concurrent submit calls while in flight', () async {
      int requestCount = 0;
      FloodApiService.client = MockClient((request) async {
        if (request.url.path.endsWith('/reports')) {
          requestCount++;
          // Delay to simulate network in flight
          await Future.delayed(const Duration(milliseconds: 150));
          return http.Response(
            jsonEncode({'success': true, 'message': 'Report received'}),
            201,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 404);
      });

      // Fire two submits nearly simultaneously
      final future1 = FloodApiService.submitFloodReport(
        location: 'J.P. Rizal St, Nangka',
        isRaining: true,
        isSafe: false,
        uid: 'citizen-user-001',
        reporterName: 'Juan Dela Cruz',
        reporterPhone: '09171234567',
        latitude: 14.6507,
        longitude: 121.1029,
        helpNeeded: 'Evacuation',
      );

      final future2 = FloodApiService.submitFloodReport(
        location: 'J.P. Rizal St, Nangka',
        isRaining: true,
        isSafe: false,
        uid: 'citizen-user-001',
        reporterName: 'Juan Dela Cruz',
        reporterPhone: '09171234567',
        latitude: 14.6507,
        longitude: 121.1029,
        helpNeeded: 'Evacuation',
      );

      final results = await Future.wait([future1, future2]);
      expect(results[0], isTrue, reason: 'First request should succeed');
      expect(results[1], isFalse, reason: 'Second request while in flight must be rejected');
      expect(requestCount, equals(1), reason: 'Only 1 active HTTP request should have been dispatched');
      expect(FloodApiService.isHelpReportInFlight, isFalse, reason: 'Lock must reset after completion');
    });

    testWidgets('MultistepReportSheet UI button lock prevents duplicate submit taps', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      int submitCallCount = 0;
      Future<bool> submitHook({
        required String location,
        required bool isRaining,
        required bool isSafe,
        required String uid,
        double? floodDepth,
        String? floodLevel,
        String? reporterName,
        String? reporterPhone,
        required double latitude,
        required double longitude,
        String? status,
        String? helpNeeded,
        String? helpType,
        String? helpSubtype,
        String? waterLevel,
        String? evacuationObstacle,
        String? vulnerablePerson,
        String? urgency,
        String? details,
      }) async {
        submitCallCount++;
        await Future.delayed(const Duration(milliseconds: 200));
        return true;
      }

      await tester.pumpWidget(_buildReportSheetApp(submitHook: submitHook));
      await tester.pumpAndSettle();

      // Step 0: Select Medical
      await tester.tap(find.text('Medical'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Step 1: Injury & Urgency
      await tester.tap(find.text('Injury'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Immediate / Life-threatening'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Immediate / Life-threatening'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Step 2: Location
      expect(find.text('Incident Location'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Barangka').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Step 3: Review & Confirm
      await tester.ensureVisible(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      // Tap CONFIRM to open modal
      await tester.tap(find.text('CONFIRM'));
      await tester.pumpAndSettle();

      expect(find.text('Send Help Request?'), findsOneWidget);
      final confirmBtn = find.text('Confirm & Send');
      expect(confirmBtn, findsOneWidget);

      // Tap confirm button
      await tester.tap(confirmBtn);
      await tester.pump(); // Start execution

      // While in flight, tap again if button still found
      if (confirmBtn.evaluate().isNotEmpty) {
        await tester.tap(confirmBtn, warnIfMissed: false);
        await tester.pump();
      }

      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(submitCallCount, equals(1), reason: 'UI lock should permit only 1 submission');
    });
  });

  group('Scenario B: Backend Help Request cooldown 429 displays backend cooldown message', () {
    test('429 cooldown response captures exact backend cooldown message and retry seconds', () async {
      const cooldownMsg = 'Please wait 18 more minute(s) before submitting another request.';
      FloodApiService.client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'success': false,
            'cooldown': true,
            'message': cooldownMsg,
            'retryAfterSeconds': 1080,
          }),
          429,
          headers: {
            'content-type': 'application/json',
            'retry-after': '1080',
          },
        );
      });

      final result = await FloodApiService.submitFloodReport(
        location: 'Tumana',
        isRaining: false,
        isSafe: false,
        uid: 'citizen-user-001',
        latitude: 14.6507,
        longitude: 121.1029,
      );

      expect(result, isFalse);
      expect(FloodApiService.lastHelpRequestError, equals(cooldownMsg));
      expect(FloodApiService.lastHelpRequestRetryAfterSeconds, equals(1080));
    });

    testWidgets('MultistepReportSheet surfaces backend cooldown message to citizen', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const cooldownMsg = 'Please wait 18 more minute(s) before submitting another request.';
      FloodApiService.client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'success': false,
            'cooldown': true,
            'message': cooldownMsg,
            'retryAfterSeconds': 1080,
          }),
          429,
          headers: {'content-type': 'application/json'},
        );
      });

      // Use default submitFloodReport in MultistepReportSheet (which calls FloodApiService)
      await tester.pumpWidget(_buildReportSheetApp());
      await tester.pumpAndSettle();

      // Step 0: Select Medical
      await tester.tap(find.text('Medical'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Step 1: Injury & Urgency
      await tester.tap(find.text('Injury'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Immediate / Life-threatening'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Immediate / Life-threatening'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Step 2: Location
      expect(find.text('Incident Location'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Barangka').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Step 3: Review & Confirm
      await tester.ensureVisible(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      // Tap CONFIRM to open modal
      await tester.tap(find.text('CONFIRM'));
      await tester.pumpAndSettle();

      // Confirm & Send
      await tester.tap(find.text('Confirm & Send'));
      await tester.pumpAndSettle();

      // Cooldown message must be displayed on screen
      expect(find.text(cooldownMsg), findsOneWidget);
    });
  });

  group('Scenario C: Backend generic API 429 displays standard message without leaking internals', () {
    test('extract429Message falls back to user-friendly message when message key missing', () {
      final responseWithJson = http.Response(
        jsonEncode({'error': 'Too Many Requests'}),
        429,
      );
      final msg1 = FloodApiService.extract429Message(responseWithJson);
      expect(msg1, equals('Too many requests. Please wait a moment and try again.'));

      final responseWithHtml = http.Response(
        '<html><body><h1>429 Too Many Requests</h1><p>Rate limit exceeded at /api/forecasts</p></body></html>',
        429,
      );
      final msg2 = FloodApiService.extract429Message(responseWithHtml);
      expect(msg2, equals('Too many requests. Please wait a moment and try again.'));
      expect(msg2.contains('<html>'), isFalse, reason: 'Must not leak raw HTML');
      expect(msg2.contains('/api/forecasts'), isFalse, reason: 'Must not leak internal backend paths');
    });

    test('extract429Message safely preserves provided backend message', () {
      final response = http.Response(
        jsonEncode({'message': 'You have exceeded the request quota for this station.'}),
        429,
      );
      final msg = FloodApiService.extract429Message(response);
      expect(msg, equals('You have exceeded the request quota for this station.'));
    });

    test('extractRetryAfterSeconds extracts from header or body', () {
      final respWithHeader = http.Response('{}', 429, headers: {'retry-after': '45'});
      expect(FloodApiService.extractRetryAfterSeconds(respWithHeader), equals(45));

      final respWithResetHeader = http.Response('{}', 429, headers: {'ratelimit-reset': '30'});
      expect(FloodApiService.extractRetryAfterSeconds(respWithResetHeader), equals(30));

      final respWithBody = http.Response(jsonEncode({'retryAfterSeconds': 60}), 429);
      expect(FloodApiService.extractRetryAfterSeconds(respWithBody), equals(60));
    });
  });

  group('Scenario D: Rapid forecast & status refresh triggers only 1 active request (coalesced)', () {
    test('getAllBarangayFloodData coalesces simultaneous calls', () async {
      int statusHitCount = 0;
      FloodApiService.client = MockClient((request) async {
        if (request.url.path.endsWith('/status')) {
          statusHitCount++;
          await Future.delayed(const Duration(milliseconds: 100));
          return http.Response(
            jsonEncode({
              'telemetry_sensors': {'sto_nino': 12.0, 'tumana': 11.5, 'nangka': 10.2},
              'pagasa_telemetry': {
                'sto_nino': {'sensorStatus': 'VALID'},
                'tumana': {'sensorStatus': 'VALID'},
                'nangka': {'sensorStatus': 'VALID'},
              },
              'prediction': {'rivers': {}},
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 404);
      });

      // Call 3 times concurrently
      final f1 = FloodApiService.getAllBarangayFloodData(forceRefresh: true);
      final f2 = FloodApiService.getAllBarangayFloodData(forceRefresh: true);
      final f3 = FloodApiService.getAllBarangayFloodData(forceRefresh: true);

      final results = await Future.wait([f1, f2, f3]);
      expect(results[0].length, equals(16));
      expect(results[1].length, equals(16));
      expect(results[2].length, equals(16));
      expect(statusHitCount, equals(1), reason: 'Concurrent calls must coalesce into a single HTTP request');
    });

    test('fetchDailyForecasts coalesces simultaneous calls', () async {
      int dailyHitCount = 0;
      FloodApiService.client = MockClient((request) async {
        if (request.url.path.endsWith('/forecasts/daily')) {
          dailyHitCount++;
          await Future.delayed(const Duration(milliseconds: 100));
          return http.Response(
            jsonEncode({
              'stations': {
                'sto_nino': {'predictedWaterLevel': 12.5, 'statusBand': 'NORMAL'},
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 404);
      });

      final f1 = FloodApiService.fetchDailyForecasts(forceRefresh: true);
      final f2 = FloodApiService.fetchDailyForecasts(forceRefresh: true);
      final results = await Future.wait([f1, f2]);

      expect(results[0], isNotNull);
      expect(results[1], isNotNull);
      expect(dailyHitCount, equals(1), reason: 'Concurrent daily forecast fetches must coalesce');
    });

    test('fetchTyphoonStatus coalesces simultaneous calls', () async {
      int typhoonHitCount = 0;
      FloodApiService.client = MockClient((request) async {
        if (request.url.path.endsWith('/typhoon/current')) {
          typhoonHitCount++;
          await Future.delayed(const Duration(milliseconds: 100));
          return http.Response(
            jsonEncode({
              'success': true,
              'hasActiveCyclone': false,
              'bulletinNumber': 0,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 404);
      });

      final f1 = FloodApiService.fetchTyphoonStatus(forceRefresh: true);
      final f2 = FloodApiService.fetchTyphoonStatus(forceRefresh: true);
      final results = await Future.wait([f1, f2]);

      expect(results[0], isNotNull);
      expect(results[1], isNotNull);
      expect(typhoonHitCount, equals(1), reason: 'Concurrent typhoon fetches must coalesce');
    });
  });

  group('Scenario E: Rapid profile save triggers only 1 update request & handles 429', () {
    test('saveUserProfile rejects concurrent calls while in flight', () async {
      int saveCount = 0;
      FloodApiService.client = MockClient((request) async {
        if (request.url.path.contains('/user/profile')) {
          saveCount++;
          await Future.delayed(const Duration(milliseconds: 150));
          return http.Response(
            jsonEncode({'success': true, 'message': 'Profile updated'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 404);
      });

      final f1 = FloodApiService.saveUserProfile(
        uid: 'user-001',
        email: 'user@example.com',
        firstName: 'Juan',
        lastName: 'Dela Cruz',
        phone: '09171234567',
        houseNo: '123',
        streetName: 'Rizal',
        barangay: 'Nangka',
        city: 'Marikina City',
        province: 'Metro Manila',
        zipCode: '1800',
        country: 'Philippines',
      );

      final f2 = FloodApiService.saveUserProfile(
        uid: 'user-001',
        email: 'user@example.com',
        firstName: 'Juan',
        lastName: 'Dela Cruz',
        phone: '09171234567',
        houseNo: '123',
        streetName: 'Rizal',
        barangay: 'Nangka',
        city: 'Marikina City',
        province: 'Metro Manila',
        zipCode: '1800',
        country: 'Philippines',
      );

      final results = await Future.wait([f1, f2]);
      expect(results[0], isTrue, reason: 'First profile save should succeed');
      expect(results[1], isFalse, reason: 'Concurrent profile save while in flight must be rejected');
      expect(saveCount, equals(1), reason: 'Only 1 HTTP call made');
      expect(FloodApiService.isProfileSaveInFlight, isFalse, reason: 'In-flight lock resets');
    });

    test('saveUserProfile properly captures 429 rate limit response', () async {
      const profile429Msg = 'Too many profile updates. Please try again in a few minutes.';
      FloodApiService.client = MockClient((request) async {
        return http.Response(
          jsonEncode({'message': profile429Msg}),
          429,
          headers: {'content-type': 'application/json'},
        );
      });

      final saved = await FloodApiService.saveUserProfile(
        uid: 'user-001',
        email: 'user@example.com',
        firstName: 'Juan',
        lastName: 'Dela Cruz',
        phone: '09171234567',
        houseNo: '123',
        streetName: 'Rizal',
        barangay: 'Nangka',
        city: 'Marikina City',
        province: 'Metro Manila',
        zipCode: '1800',
        country: 'Philippines',
      );

      expect(saved, isFalse);
      expect(FloodApiService.lastProfileSaveRateLimited, isTrue);
      expect(FloodApiService.lastProfileSaveError, equals(profile429Msg));
    });
  });

  group('Scenario F: Normal under-threshold requests succeed as before', () {
    test('Normal under-threshold Help Request submission succeeds', () async {
      FloodApiService.client = MockClient((request) async {
        return http.Response(
          jsonEncode({'success': true, 'message': 'Report received'}),
          201,
          headers: {'content-type': 'application/json'},
        );
      });

      final result = await FloodApiService.submitFloodReport(
        location: 'Marikina Heights',
        isRaining: false,
        isSafe: false,
        uid: 'user-001',
        latitude: 14.6507,
        longitude: 121.1029,
        helpNeeded: 'Medical',
      );

      expect(result, isTrue);
      expect(FloodApiService.lastHelpRequestError, isNull);
    });

    test('Normal under-threshold auth login succeeds', () async {
      AuthService.client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'success': true,
            'token': 'valid-jwt-token',
            'user': {
              'uid': 'user-123',
              'email': 'citizen@example.com',
              'firstName': 'Citizen',
              'lastName': 'One',
              'barangay': 'Concepcion Uno',
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final authService = AuthService();
      final ok = await authService.login('citizen@example.com', 'password123');
      expect(ok, isTrue);
      expect(authService.lastAuthError, isNull);
    });
  });

  group('Scenario G: Network failure displays connection error, distinct from HTTP 429', () {
    test('getAllBarangayFloodData distinguishes 429 from network failure', () async {
      // 1. HTTP 429
      FloodApiService.client = MockClient((request) async {
        return http.Response(
          jsonEncode({'message': 'Rate limit exceeded on telemetry'}),
          429,
          headers: {'content-type': 'application/json'},
        );
      });

      await FloodApiService.getAllBarangayFloodData(forceRefresh: true);
      expect(FloodApiService.lastStatusRateLimited, isTrue);
      expect(FloodApiService.lastRateLimitMessage, equals('Rate limit exceeded on telemetry'));

      // 2. Real network failure (e.g. 500 or socket exception)
      FloodApiService.client = MockClient((request) async {
        throw http.ClientException('Connection refused');
      });

      await FloodApiService.getAllBarangayFloodData(forceRefresh: true);
      expect(FloodApiService.lastStatusRateLimited, isFalse,
          reason: 'Network failure must not be marked as a rate limit');
    });

    test('AuthService login distinguishes 429 from invalid credentials & network failure', () async {
      // 1. Rate limited 429
      AuthService.client = MockClient((request) async {
        return http.Response(
          jsonEncode({'message': 'Too many login attempts. Please try again later.'}),
          429,
          headers: {'content-type': 'application/json'},
        );
      });

      final auth = AuthService();
      final res429 = await auth.login('test@example.com', 'pass');
      expect(res429, isFalse);
      expect(auth.lastAuthError, equals('Too many login attempts. Please try again later.'));

      // 2. Invalid credentials (401 / success: false)
      AuthService.client = MockClient((request) async {
        return http.Response(
          jsonEncode({'success': false, 'message': 'Invalid email or password'}),
          401,
          headers: {'content-type': 'application/json'},
        );
      });

      final resCreds = await auth.login('test@example.com', 'wrong');
      expect(resCreds, isFalse);
      expect(auth.lastAuthError, equals('Invalid email or password'));

      // 3. Network connection error
      AuthService.client = MockClient((request) async {
        throw http.ClientException('Connection failed');
      });

      final resNet = await auth.login('test@example.com', 'pass');
      expect(resNet, isFalse);
      expect(auth.lastAuthError, equals('Connection failed. Check server status.'));
    });

    test('fetchMyHelpRequests throws RateLimitException on 429, Exception on other failure', () async {
      // 1. HTTP 429
      FloodApiService.client = MockClient((request) async {
        return http.Response(
          jsonEncode({'message': 'Rate limit exceeded on reports'}),
          429,
          headers: {'content-type': 'application/json'},
        );
      });

      await expectLater(
        FloodApiService.fetchMyHelpRequests(),
        throwsA(isA<RateLimitException>().having(
          (e) => e.message,
          'message',
          'Rate limit exceeded on reports',
        )),
      );

      // 2. Server failure (500)
      FloodApiService.client = MockClient((request) async {
        return http.Response('Server Error', 500);
      });

      await expectLater(
        FloodApiService.fetchMyHelpRequests(),
        throwsA(isA<Exception>().having(
          (e) => e is RateLimitException,
          'is not RateLimitException',
          isFalse,
        )),
      );
    });
  });
}
