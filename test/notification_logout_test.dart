import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:floodguard_ai/services/notification_service.dart';
import 'package:floodguard_ai/services/auth_service.dart';
import 'package:floodguard_ai/screens/alerts_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('User-Scoped Alert History & Logout Notification Cleanup', () {
    late List<String> unsubscriptionLog;
    late int localTrayCancelCount;

    setUp(() {
      unsubscriptionLog = [];
      localTrayCancelCount = 0;

      NotificationService.testUnsubscribeFromTopic = (topic) async {
        unsubscriptionLog.add(topic);
      };

      NotificationService.testCancelAllLocalNotifications = () async {
        localTrayCancelCount++;
      };
    });

    tearDown(() {
      NotificationService.testUnsubscribeFromTopic = null;
      NotificationService.testCancelAllLocalNotifications = null;
    });

    test('cleanupOnLogout() preserves user-scoped alert history, cancels tray, and unsubscribes FCM', () async {
      SharedPreferences.setMockInitialValues({
        'is_logged_in': true,
        'uid': 'user_a',
        'app_alerts_user_a': [
          jsonEncode({
            'id': 'alert_1',
            'title': 'CRITICAL Flood Warning',
            'body': 'Sto. Niño water level 18.2m',
            'timestamp': '2026-10-16T12:00:00Z',
          }),
          jsonEncode({
            'id': 'test_alert_1',
            'title': 'FloodGuard TEST ALERT - Malanday',
            'body': 'TEST ONLY: Simulated alert for Malanday.',
            'timestamp': '2026-10-16T12:05:00Z',
          }),
        ],
        'confirmed_fcm_topic': 'barangay_tumana',
        'active_notification_barangay': 'Tumana',
        'active_notification_topic': 'barangay_tumana',
        'notification_routing_mode': 'currentLocation',
      });

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('app_alerts_user_a')?.length, 2);
      expect(prefs.getString('confirmed_fcm_topic'), 'barangay_tumana');

      bool streamFired = false;
      final sub = NotificationService.onAlertsUpdated.stream.listen((_) {
        streamFired = true;
      });

      await NotificationService.cleanupOnLogout();
      await Future.delayed(const Duration(milliseconds: 50));

      // 1. Verify app_alerts_user_a is PRESERVED in SharedPreferences
      expect(prefs.getStringList('app_alerts_user_a')?.length, 2,
          reason: 'User alerts must NOT be deleted from disk on logout');

      // 2. Verify local notification tray cancelAll was executed
      expect(localTrayCancelCount, 1);

      // 3. Verify topic unsubscription was executed for active topic
      expect(unsubscriptionLog, contains('barangay_tumana'));

      // 4. Verify user routing preferences were cleared
      expect(prefs.getString('confirmed_fcm_topic'), isNull);
      expect(prefs.getString('active_notification_barangay'), isNull);
      expect(prefs.getString('active_notification_topic'), isNull);
      expect(prefs.getString('notification_routing_mode'), isNull);

      // 5. Verify reactive UI notification stream fired
      expect(streamFired, isTrue);

      await sub.cancel();
    });

    test('AuthService.logout() clears session but preserves app_alerts_<uid>', () async {
      SharedPreferences.setMockInitialValues({
        'is_logged_in': true,
        'auth_token': 'mock_jwt_token_123',
        'user_data': '{"id":"user_a","barangay":"Malanday"}',
        'uid': 'user_a',
        'app_alerts_user_a': [
          jsonEncode({
            'id': 'alert_1',
            'title': 'Flood Alert',
            'body': 'Water level rising',
          }),
          jsonEncode({
            'id': 'test_alert_1',
            'title': 'FloodGuard TEST ALERT - Malanday',
            'body': 'TEST ONLY: test alert body',
          }),
        ],
        'confirmed_fcm_topic': 'barangay_malanday',
      });

      final authService = AuthService();
      await authService.logout();

      final prefs = await SharedPreferences.getInstance();

      // Auth state must be wiped
      expect(prefs.getBool('is_logged_in'), isFalse);
      expect(prefs.getString('auth_token'), isNull);
      expect(prefs.getString('user_data'), isNull);
      expect(prefs.getString('uid'), isNull);

      // Notification routing and tray cleaned up
      expect(localTrayCancelCount, 1);
      expect(unsubscriptionLog, contains('barangay_malanday'));

      // User A's alerts remain stored for when User A logs back in
      expect(prefs.getStringList('app_alerts_user_a')?.length, 2);

      // In logged-out state, active storage key returns null
      final storageKey = await NotificationService.getActiveAlertsStorageKey();
      expect(storageKey, isNull);
    });

    test('User A logs out -> User B logs in (sees only User B alerts) -> User A logs back in (User A alerts return)', () async {
      final prefs = await SharedPreferences.getInstance();

      // Step 1: User A is logged in with real + [TEST] alerts
      await prefs.setBool('is_logged_in', true);
      await prefs.setString('auth_token', 'token_user_a');
      await prefs.setString('uid', 'user_a');
      await prefs.setStringList('app_alerts_user_a', [
        jsonEncode({
          'id': 'user_a_real_alert',
          'title': 'Flood Alert - Tumana',
          'body': 'Water level reached 15.5m',
        }),
        jsonEncode({
          'id': 'user_a_test_alert',
          'title': 'FloodGuard TEST ALERT - Tumana',
          'body': 'TEST ONLY: Simulated alert for Tumana',
        }),
      ]);

      // Check User A storage key and count
      expect(await NotificationService.getActiveAlertsStorageKey(), 'app_alerts_user_a');
      expect(prefs.getStringList('app_alerts_user_a')?.length, 2);

      // Step 2: User A logs out
      final authService = AuthService();
      await authService.logout();

      // User A logged out -> storage key is null
      expect(await NotificationService.getActiveAlertsStorageKey(), isNull);

      // Step 3: User B logs in on same device
      await prefs.setBool('is_logged_in', true);
      await prefs.setString('auth_token', 'token_user_b');
      await prefs.setString('uid', 'user_b');
      await prefs.setStringList('app_alerts_user_b', [
        jsonEncode({
          'id': 'user_b_alert',
          'title': 'Flood Alert - Malanday',
          'body': 'Water level normal',
        }),
      ]);

      // User B sees only User B alerts
      expect(await NotificationService.getActiveAlertsStorageKey(), 'app_alerts_user_b');
      final userBAlerts = prefs.getStringList('app_alerts_user_b') ?? [];
      expect(userBAlerts.length, 1);
      expect(userBAlerts.first, contains('user_b_alert'));
      expect(userBAlerts.first, isNot(contains('user_a')));

      // Step 4: User B logs out
      await authService.logout();
      expect(await NotificationService.getActiveAlertsStorageKey(), isNull);

      // Step 5: User A logs back in
      await prefs.setBool('is_logged_in', true);
      await prefs.setString('auth_token', 'token_user_a_returned');
      await prefs.setString('uid', 'user_a');

      expect(await NotificationService.getActiveAlertsStorageKey(), 'app_alerts_user_a');
      final returnedUserAAlerts = prefs.getStringList('app_alerts_user_a') ?? [];
      expect(returnedUserAAlerts.length, 2);
      expect(returnedUserAAlerts[0], contains('user_a_real_alert'));
      expect(returnedUserAAlerts[1], contains('user_a_test_alert'));
    });

    testWidgets('AlertsScreen displays alerts when logged in and empty state when logged out',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'is_logged_in': true,
        'uid': 'user_a',
        'app_alerts_user_a': [
          jsonEncode({
            'id': 'user_a_alert',
            'title': 'ALARM: Flood Alert - Tumana',
            'body': 'Water level 16.20m',
            'isRead': false,
            'timestamp': DateTime.now().toIso8601String(),
          }),
        ],
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: AlertsScreen(
            isTaglish: false,
            isDarkMode: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially shows User A's alert card
      expect(find.text('ALARM: High Flood Risk'), findsOneWidget);
      expect(find.text('Barangay Tumana'), findsOneWidget);

      // Trigger logout via AuthService
      final auth = AuthService();
      await auth.logout();
      await tester.pumpAndSettle();

      // In logged-out state, alert is gone and empty state shows
      expect(find.text('ALARM: High Flood Risk'), findsNothing);
      expect(find.text('Barangay Tumana'), findsNothing);
      expect(find.text('No Alerts Yet'), findsOneWidget);
    });

    testWidgets('AlertsScreen migrates legacy app_alerts key to user-scoped key',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'is_logged_in': true,
        'uid': 'user_migrated',
        'app_alerts': [
          jsonEncode({
            'id': 'legacy_alert_1',
            'title': 'ALERT: Flood Alert - Nangka',
            'body': 'Water level 15.10m',
            'isRead': false,
            'timestamp': DateTime.now().toIso8601String(),
          }),
        ],
      });

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('app_alerts')?.length, 1);
      expect(prefs.getStringList('app_alerts_user_migrated'), isNull);

      await tester.pumpWidget(
        const MaterialApp(
          home: AlertsScreen(
            isTaglish: false,
            isDarkMode: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Alert rendered
      expect(find.text('ALERT: Moderate Flood Risk'), findsOneWidget);

      // Legacy key migrated to user-scoped key
      expect(prefs.getStringList('app_alerts'), isNull);
      expect(prefs.getStringList('app_alerts_user_migrated')?.length, 1);
    });
  });
}
