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
  description: 'Flood warning and evacuation notifications from FloodGuard',
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
  debugPrint('[FCM MOBILE] Background message received: id=${message.messageId}');
  await NotificationService.persistMessage(message);
}

/// FCM setup + barangay topic subscribe via backend `/api/user/subscribe`.
class NotificationService {
  static const String _baseUrl = ApiConfig.apiBase;
  static String? _fcmToken;
  static AuthorizationStatus? _authorizationStatus;
  static bool _initialized = false;
  static StreamSubscription<String>? _tokenRefreshSubscription;

  /// Canonical FCM topic for a barangay name.
  /// Examples:
  /// - Malanday -> barangay_malanday
  /// - Tumana -> barangay_tumana
  /// - Concepcion Uno -> barangay_concepcion_uno
  /// - Concepcion Dos -> barangay_concepcion_dos
  /// - Marikina Heights -> barangay_marikina_heights
  /// - Santo Niño -> barangay_santo_nino
  /// - Tañong -> barangay_tanong
  /// - Jesus Dela Peña -> barangay_jesus_dela_pena
  static String topicForBarangay(String barangay) {
    final normalized = barangay
        .trim()
        .toLowerCase()
        .replaceAll('ñ', 'n')
        .replaceAll('Ñ', 'n')
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
      final projectId = DefaultFirebaseOptions.currentPlatform.projectId;
      debugPrint('[FCM MOBILE] Initializing NotificationService for project: $projectId');

      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      _authorizationStatus = settings.authorizationStatus;
      debugPrint('[FCM MOBILE] Notification permission status: ${settings.authorizationStatus}');

      await _initializeLocalNotifications();

      _fcmToken = await messaging.getToken();
      final hasToken = _fcmToken != null && _fcmToken!.isNotEmpty;
      debugPrint('[FCM MOBILE] FCM token acquired: $hasToken');
      if (hasToken) {
        final prefix = _fcmToken!.substring(0, _fcmToken!.length.clamp(0, 12));
        debugPrint('[FCM MOBILE] FCM token prefix: $prefix...');
      }

      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedMessage);

      _tokenRefreshSubscription =
          messaging.onTokenRefresh.listen((newToken) async {
        _fcmToken = newToken;
        debugPrint('[FCM MOBILE] FCM token refreshed; updating stored subscription');
        await _resubscribeStoredBarangay();
      });

      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('[FCM MOBILE] Initial app launch message: ${initialMessage.messageId}');
        await persistMessage(initialMessage);
      }
      _initialized = true;
      debugPrint('[FCM MOBILE] NotificationService initialized successfully');
    } catch (e) {
      debugPrint('[FCM MOBILE] Initialization error: $e');
    }
  }

  static Future<void> _initializeLocalNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('[FCM MOBILE] Local notification response clicked: ${response.payload}');
      },
    );
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
            '[FCM MOBILE] Subscribe aborted: Notification permission denied. Topic=$topic');
        return;
      }
      _fcmToken ??= await FirebaseMessaging.instance.getToken();
      final token = _fcmToken;
      if (token == null || token.isEmpty) {
        debugPrint('[FCM MOBILE] No FCM token available to subscribe for $barangay ($topic)');
        return;
      }

      debugPrint('[FCM MOBILE] Subscribing device to topic: $topic ($barangay)');
      await FirebaseMessaging.instance.subscribeToTopic(topic);
      debugPrint('[FCM MOBILE] FCM topic subscription successful: $topic');

      final url = Uri.parse('$_baseUrl/user/subscribe');
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'token': token, 'barangay': barangay}),
          )
          .timeout(const Duration(seconds: 15));

      debugPrint(
          '[FCM MOBILE] Backend registration -> status=${response.statusCode}, topic=$topic, response=${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('subscribed_barangay', barangay);
        debugPrint('[FCM MOBILE] Stored subscribed_barangay=$barangay in preferences');
      } else {
        debugPrint('[FCM MOBILE] Backend subscribe returned status ${response.statusCode}');
      }
    } catch (e) {
      debugPrint(
          '[FCM MOBILE] Subscription error for $barangay ($topic): $e');
    }
  }

  static Future<void> _resubscribeStoredBarangay() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final barangay = prefs.getString('subscribed_barangay');
      if (barangay != null && barangay.isNotEmpty) {
        debugPrint('[FCM MOBILE] Resubscribing stored barangay: $barangay');
        await subscribeToBarangay(barangay);
      }
    } catch (e) {
      debugPrint('[FCM MOBILE] Resubscribe error: $e');
    }
  }

  static Future<void> unsubscribeFromBarangay(String barangay) async {
    if (barangay.trim().isEmpty) return;
    final topic = topicForBarangay(barangay);
    try {
      debugPrint('[FCM MOBILE] Unsubscribing from topic: $topic ($barangay)');
      await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('subscribed_barangay');
      debugPrint('[FCM MOBILE] Unsubscribed and cleared stored barangay preference');
    } catch (e) {
      debugPrint(
          '[FCM MOBILE] Unsubscribe error for $barangay ($topic): $e');
    }
  }

  static Future<void> persistMessage(RemoteMessage message) async {
    final title =
        message.notification?.title ?? message.data['title'] ?? 'Flood Alert';
    final body = message.notification?.body ?? message.data['body'] ?? '';
    final id = message.messageId ?? '${title}_${DateTime.now().millisecondsSinceEpoch}';
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('app_alerts') ?? [];
      final alreadyStored = list.any((entry) {
        try {
          final decoded = jsonDecode(entry) as Map<String, dynamic>;
          return decoded['messageId'] == id || decoded['id'] == id;
        } catch (_) {
          return false;
        }
      });
      if (alreadyStored) {
        debugPrint('[FCM MOBILE] Alert with id=$id already persisted, skipping duplicate');
        return;
      }

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
      debugPrint('[FCM MOBILE] Persisted alert id=$id. Total alerts count=${list.length}');
    } catch (e) {
      debugPrint('[FCM MOBILE] Failed to persist alert messageId=$id: $e');
    }
  }

  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    await persistMessage(message);
    final title =
        message.notification?.title ?? message.data['title'] ?? 'Flood Alert';
    final body = message.notification?.body ?? message.data['body'] ?? '';
    await _localNotifications.show(
      message.hashCode,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'floodguard_emergency',
          'FloodGuard Emergency Alerts',
          channelDescription:
              'Flood warning and evacuation notifications from FloodGuard',
          importance: Importance.max,
          priority: Priority.max,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: jsonEncode(message.data),
    );
    debugPrint(
        '[FCM MOBILE] onMessage received: id=${message.messageId}, title=$title, body=$body, topic=${message.from}');
  }

  static Future<void> _handleOpenedMessage(RemoteMessage message) async {
    await persistMessage(message);
    debugPrint('[FCM MOBILE] onMessageOpenedApp received: id=${message.messageId}');
  }

  static Future<void> dispose() async {
    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;
    _initialized = false;
  }
}
