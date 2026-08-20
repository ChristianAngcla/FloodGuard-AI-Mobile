import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../firebase_options.dart';

const _emergencyChannel = AndroidNotificationChannel(
  'floodguard_emergency',
  'FloodGuard Emergency Alerts',
  description: 'High-priority FloodGuard flood alerts.',
  importance: Importance.max,
);

final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  await NotificationService.persistMessage(message);
}

/// FCM setup + barangay topic subscribe via existing `/api/user/subscribe`.
class NotificationService {
  static const String _baseUrl = ApiConfig.apiBase;
  static String? _fcmToken;
  static AuthorizationStatus? _authorizationStatus;
  static bool _initialized = false;
  static StreamSubscription<String>? _tokenRefreshSubscription;

  static String topicForBarangay(String barangay) {
    final normalized = barangay
        .trim()
        .toLowerCase()
        .replaceAll('ñ', 'n')
        .replaceAll(RegExp(r'[áàäâãå]'), 'a')
        .replaceAll(RegExp(r'[éèëê]'), 'e')
        .replaceAll(RegExp(r'[íìïî]'), 'i')
        .replaceAll(RegExp(r'[óòöôõ]'), 'o')
        .replaceAll(RegExp(r'[úùüû]'), 'u')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return 'barangay_$normalized';
  }

  static Future<void> initialize() async {
    if (_initialized) return;
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      _authorizationStatus = settings.authorizationStatus;
      debugPrint('FCM authorizationStatus=${settings.authorizationStatus}');

      await _initializeLocalNotifications();

      _fcmToken = await messaging.getToken();
      debugPrint('FCM token exists=${_fcmToken?.isNotEmpty == true}');
      if (kDebugMode && _fcmToken != null && _fcmToken!.isNotEmpty) {
        final token = _fcmToken!;
        debugPrint(
            'FCM token prefix=${token.substring(0, token.length.clamp(0, 12))}');
      }

      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedMessage);
      _tokenRefreshSubscription =
          messaging.onTokenRefresh.listen((token) async {
        _fcmToken = token;
        debugPrint('FCM token refreshed; re-establishing stored subscription');
        await _resubscribeStoredBarangay();
      });

      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        await persistMessage(initialMessage);
        debugPrint('FCM initial messageId=${initialMessage.messageId}');
      }
      _initialized = true;
    } catch (e) {
      debugPrint('NotificationService.initialize error: $e');
    }
  }

  static Future<void> _initializeLocalNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _localNotifications.initialize(settings);
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_emergencyChannel);
  }

  static Future<void> subscribeToBarangay(String barangay) async {
    if (barangay.trim().isEmpty) return;
    final topic = topicForBarangay(barangay);
    try {
      if (_authorizationStatus == AuthorizationStatus.denied) {
        debugPrint(
            'FCM subscribe failed topic=$topic reason=permission_denied');
        return;
      }
      _fcmToken ??= await FirebaseMessaging.instance.getToken();
      final token = _fcmToken;
      if (token == null || token.isEmpty) {
        debugPrint('No FCM token — skip subscribe for $barangay');
        return;
      }

      await FirebaseMessaging.instance.subscribeToTopic(topic);

      final response = await http
          .post(
            Uri.parse('$_baseUrl/user/subscribe'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'token': token, 'barangay': barangay}),
          )
          .timeout(const Duration(seconds: 15));
      debugPrint(
          'FCM subscribe response topic=$topic status=${response.statusCode} body=${response.body}');
      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint('FCM subscribe failed topic=$topic reason=http_failure');
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('subscribed_barangay', barangay);
      debugPrint('FCM subscription active topic=$topic');
    } catch (e) {
      debugPrint(
          'FCM subscribe failed topic=${topicForBarangay(barangay)} reason=$e');
    }
  }

  static Future<void> _resubscribeStoredBarangay() async {
    final prefs = await SharedPreferences.getInstance();
    final barangay = prefs.getString('subscribed_barangay');
    if (barangay != null && barangay.isNotEmpty) {
      await subscribeToBarangay(barangay);
    }
  }

  static Future<void> unsubscribeFromBarangay(String barangay) async {
    if (barangay.trim().isEmpty) return;
    try {
      final topic = topicForBarangay(barangay);
      await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('subscribed_barangay');
      debugPrint('FCM unsubscribed topic=$topic');
    } catch (e) {
      debugPrint(
          'FCM unsubscribe failed topic=${topicForBarangay(barangay)} reason=$e');
    }
  }

  static Future<void> persistMessage(RemoteMessage message) async {
    final title =
        message.notification?.title ?? message.data['title'] ?? 'Alert';
    final body = message.notification?.body ?? message.data['body'] ?? '';
    final id = message.messageId ?? '${title}_$body';
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('app_alerts') ?? [];
      final alreadyStored = list.any((entry) {
        final decoded = jsonDecode(entry) as Map<String, dynamic>;
        return decoded['messageId'] == id;
      });
      if (alreadyStored) return;
      list.insert(
        0,
        jsonEncode({
          'id': id,
          'messageId': message.messageId,
          'title': title,
          'body': body,
          'data': message.data,
          'topic': message.from,
          'timestamp': DateTime.now().toIso8601String(),
          'isRead': false,
        }),
      );
      // Keep last 50
      if (list.length > 50) {
        list.removeRange(50, list.length);
      }
      await prefs.setStringList('app_alerts', list);
    } catch (e) {
      debugPrint('FCM alert persistence failed messageId=$id reason=$e');
    }
  }

  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    await persistMessage(message);
    final title =
        message.notification?.title ?? message.data['title'] ?? 'Alert';
    final body = message.notification?.body ?? message.data['body'] ?? '';
    await _localNotifications.show(
      message.hashCode,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'floodguard_emergency',
          'FloodGuard Emergency Alerts',
          channelDescription: 'High-priority FloodGuard flood alerts.',
          importance: Importance.max,
          priority: Priority.max,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: jsonEncode(message.data),
    );
    debugPrint(
        'FCM onMessage messageId=${message.messageId} title=$title topic=${message.from}');
  }

  static Future<void> _handleOpenedMessage(RemoteMessage message) async {
    await persistMessage(message);
    debugPrint('FCM onMessageOpenedApp messageId=${message.messageId}');
  }

  static Future<void> dispose() async {
    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;
    _initialized = false;
  }
}
