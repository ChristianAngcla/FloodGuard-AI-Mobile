import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';

/// FCM setup + barangay topic subscribe via existing `/api/user/subscribe`.
class NotificationService {
  static const String _baseUrl = ApiConfig.apiBase;
  static String? _fcmToken;

  static Future<void> initialize() async {
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      _fcmToken = await messaging.getToken();
      debugPrint('FCM token ready: ${_fcmToken != null}');

      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedMessage);
    } catch (e) {
      debugPrint('NotificationService.initialize error: $e');
    }
  }

  static Future<void> subscribeToBarangay(String barangay) async {
    if (barangay.trim().isEmpty) return;
    try {
      _fcmToken ??= await FirebaseMessaging.instance.getToken();
      final token = _fcmToken;
      if (token == null || token.isEmpty) {
        debugPrint('No FCM token — skip subscribe for $barangay');
        return;
      }

      final topic =
          'barangay_${barangay.toLowerCase().replaceAll(RegExp(r'\s+'), '_')}';
      await FirebaseMessaging.instance.subscribeToTopic(topic);

      await http
          .post(
            Uri.parse('$_baseUrl/user/subscribe'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'token': token, 'barangay': barangay}),
          )
          .timeout(const Duration(seconds: 15));

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('subscribed_barangay', barangay);
      debugPrint('Subscribed to $topic');
    } catch (e) {
      debugPrint('NotificationService.subscribeToBarangay error: $e');
    }
  }

  static Future<void> unsubscribeFromBarangay(String barangay) async {
    if (barangay.trim().isEmpty) return;
    try {
      final topic =
          'barangay_${barangay.toLowerCase().replaceAll(RegExp(r'\s+'), '_')}';
      await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('subscribed_barangay');
      debugPrint('Unsubscribed from $topic');
    } catch (e) {
      debugPrint('NotificationService.unsubscribeFromBarangay error: $e');
    }
  }

  static Future<void> _persistAlert({
    required String title,
    required String body,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('app_alerts') ?? [];
      list.insert(
        0,
        jsonEncode({
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'title': title,
          'body': body,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );
      // Keep last 50
      if (list.length > 50) {
        list.removeRange(50, list.length);
      }
      await prefs.setStringList('app_alerts', list);
    } catch (e) {
      debugPrint('persist alert error: $e');
    }
  }

  static void _handleForegroundMessage(RemoteMessage message) {
    final title = message.notification?.title ?? message.data['title'] ?? 'Alert';
    final body = message.notification?.body ?? message.data['body'] ?? '';
    _persistAlert(title: title, body: body);
  }

  static void _handleOpenedMessage(RemoteMessage message) {
    final title = message.notification?.title ?? message.data['title'] ?? 'Alert';
    final body = message.notification?.body ?? message.data['body'] ?? '';
    _persistAlert(title: title, body: body);
  }
}
