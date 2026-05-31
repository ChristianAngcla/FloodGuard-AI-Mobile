import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('📩 Background Message Received: ${message.toMap()}');

  final title = message.notification?.title ??
      message.data['title'] ??
      message.data['heading'] ??
      "ALERT";
  final body = message.notification?.body ??
      message.data['body'] ??
      message.data['message'] ??
      "";

  if (title.isNotEmpty || body.isNotEmpty) {
    final prefs = await SharedPreferences.getInstance();
    List<String> alerts = prefs.getStringList('app_alerts') ?? [];
    final alertData = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'title': title,
      'body': body,
      'timestamp': DateTime.now().toIso8601String(),
      'isRead': false,
    };
    alerts.insert(0, jsonEncode(alertData));
    await prefs.setStringList('app_alerts', alerts);
  }
}

class NotificationService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  static Future<void> initialize() async {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // 1. Request permission (especially for iOS and Android 13+)
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: true,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('🔔 User granted notification permission');
    } else if (settings.authorizationStatus ==
        AuthorizationStatus.provisional) {
      debugPrint('🔔 User granted provisional notification permission');
    } else {
      debugPrint('❌ User declined or has not accepted notification permission');
    }

    // 🔑 Log the FCM token for debugging (helps verify correct Firebase project)
    try {
      String? token = await _fcm.getToken();
      debugPrint('🔑 FCM TOKEN AT INIT: $token');
    } catch (e) {
      debugPrint('⚠️ Could not get FCM token: $e');
    }

    // Automatically subscribe to global topics for all users (logged in or not)
    try {
      await _fcm.subscribeToTopic('all_users');
      await _fcm.subscribeToTopic('all');
      await _fcm.subscribeToTopic('alerts');
      debugPrint('✅ Subscribed to global topics: all_users, all, alerts');
    } catch (e) {
      debugPrint('❌ Error subscribing to global topics: $e');
    }

    // 🔄 Re-subscribe to topics when FCM token is refreshed
    // (e.g. after app reinstall, cleared data, or token rotation)
    _fcm.onTokenRefresh.listen((newToken) async {
      debugPrint('🔄 FCM TOKEN REFRESHED: $newToken');
      try {
        await _fcm.subscribeToTopic('all_users');
        await _fcm.subscribeToTopic('all');
        await _fcm.subscribeToTopic('alerts');
        debugPrint('✅ Re-subscribed to global topics after token refresh');

        // Re-subscribe to user's barangay if available
        final prefs = await SharedPreferences.getInstance();
        final userDataString = prefs.getString('user_data');
        if (userDataString != null) {
          try {
            final userData = jsonDecode(userDataString);
            final barangay = userData['barangay'] ?? '';
            if (barangay.isNotEmpty) {
              await subscribeToBarangay(barangay);
              debugPrint('✅ Re-subscribed to barangay: $barangay after token refresh');
            }
          } catch (e) {
            debugPrint('⚠️ Could not re-subscribe to barangay: $e');
          }
        }
      } catch (e) {
        debugPrint('❌ Error re-subscribing after token refresh: $e');
      }
    });

    // 2. Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('📩 Foreground Message Received: ${message.toMap()}');

      // Handle both notification messages and data-only messages
      final title = message.notification?.title ??
          message.data['title'] ??
          message.data['heading'] ??
          "ALERT";
      final body = message.notification?.body ??
          message.data['body'] ??
          message.data['message'] ??
          "";

      if (title.isNotEmpty || body.isNotEmpty) {
        _saveAlertLocal(title, body);
        _showForegroundDialog(title, body);
      }
    });

    // 3. Handle when the app is opened via a notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('🚀 App opened from notification: ${message.toMap()}');
      final title = message.notification?.title ??
          message.data['title'] ??
          message.data['heading'] ??
          "ALERT";
      final body = message.notification?.body ??
          message.data['body'] ??
          message.data['message'] ??
          "";

      if (title.isNotEmpty || body.isNotEmpty) {
        _saveAlertLocal(title, body);
      }
    });
  }

  static Future<void> _saveAlertLocal(String title, String body) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> alerts = prefs.getStringList('app_alerts') ?? [];
      final alertData = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'title': title,
        'body': body,
        'timestamp': DateTime.now().toIso8601String(),
        'isRead': false,
      };
      alerts.insert(0, jsonEncode(alertData));
      await prefs.setStringList('app_alerts', alerts);
    } catch (e) {
      debugPrint('Error saving alert: $e');
    }
  }

  // Helper to safely format FCM topics (Firebase rejects spaces and 'ñ')
  static String _formatTopicName(String barangay) {
    String normalized = barangay.toLowerCase().replaceAll('ñ', 'n');
    normalized = normalized.replaceAll(
        RegExp(r'[^a-z0-9\s]'), ''); // Remove special chars but keep spaces
    return 'barangay_${normalized.replaceAll(RegExp(r'\s+'), '_').trim()}';
  }

  // 4. Subscribe to a specific barangay
  static Future<void> subscribeToBarangay(String barangay) async {
    debugPrint('🔔 STARTING SUBSCRIPTION FOR: $barangay');
    // FCM topics cannot have spaces or special characters
    String topic = _formatTopicName(barangay);
    String simpleTopic = barangay
        .toLowerCase()
        .replaceAll('ñ', 'n')
        .replaceAll(RegExp(r'[^a-z0-9]'), '');

    try {
      // Always subscribe directly via FCM first to guarantee the device registers for notifications!
      await _fcm.subscribeToTopic(topic);
      await _fcm.subscribeToTopic(simpleTopic);
      await _fcm.subscribeToTopic('all_users');
      await _fcm.subscribeToTopic('all');
      await _fcm.subscribeToTopic('alerts');
      debugPrint(
          '✅ DIRECT SUBSCRIPTION SUCCESS: $topic, $simpleTopic, all_users');

      String? token = await _fcm.getToken();
      debugPrint('🔑 FCM DEVICE TOKEN: $token');
      debugPrint('📌 TARGET TOPIC: $topic');

      // On Web, we MUST subscribe via the server
      // On Mobile, we can do it directly or via the server. We'll use the server for both for consistency.
      final response = await http.post(
        Uri.parse(
            'https://floodguard-database.onrender.com/api/user/subscribe'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'token': token,
          'barangay': barangay,
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ SERVER: Successfully subscribed $token to $topic');
      } else {
        // Fallback for mobile if server fails
        await _fcm.subscribeToTopic(topic);
        debugPrint('✅ FALLBACK: Subscribed to $topic directly');
      }
    } catch (e) {
      debugPrint('❌ Error subscribing to topic $topic: $e');
    }
  }

  // 5. Unsubscribe (useful for Logout)
  static Future<void> unsubscribeFromBarangay(String barangay) async {
    String topic = _formatTopicName(barangay);
    try {
      await _fcm.unsubscribeFromTopic(topic);
      debugPrint('🔕 Unsubscribed from alerts for: $topic');
    } catch (e) {
      debugPrint('❌ Error unsubscribing from topic $topic: $e');
    }
  }

  // 6. Show the foreground dialog
  static void _showForegroundDialog(String title, String body) {
    // We use the global navigatorKey from main.dart
    // Need to import it or define it in a way that's accessible.
    // For now I'll assume it's imported or I'll just use a generic way.

    final context = navigatorKey.currentContext;
    if (context == null) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF253B50) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1A2B3C);
    final subTextColor = isDark ? Colors.white70 : Colors.grey[700];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 600),
          curve: Curves.elasticOut,
          builder: (context, value, child) {
            return Transform.scale(
              scale: value,
              child: child,
            );
          },
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.15),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.warning_rounded,
                    color: Colors.red,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.red,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: subTextColor,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'TAKE ACTION',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Dismiss',
                    style: TextStyle(
                      color: subTextColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
