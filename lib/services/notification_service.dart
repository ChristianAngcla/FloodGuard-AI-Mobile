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
import 'location_service.dart';

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

enum NotificationRoutingMode {
  currentLocation,
  registeredFallback,
  none;

  String toStorageString() {
    switch (this) {
      case NotificationRoutingMode.currentLocation:
        return 'current_location';
      case NotificationRoutingMode.registeredFallback:
        return 'registered_barangay_fallback';
      case NotificationRoutingMode.none:
        return 'none';
    }
  }

  static NotificationRoutingMode fromStorageString(String? raw) {
    switch (raw) {
      case 'current_location':
        return NotificationRoutingMode.currentLocation;
      case 'registered_barangay_fallback':
        return NotificationRoutingMode.registeredFallback;
      default:
        return NotificationRoutingMode.none;
    }
  }
}

class NotificationRoutingResult {
  final String? activeBarangay;
  final String? activeTopic;
  final NotificationRoutingMode routingMode;
  final String? previousBarangay;
  final String? previousTopic;
  final bool unsubscribed;
  final bool subscribed;
  final String? registeredFallback;
  final String? currentDetectedBarangay;

  const NotificationRoutingResult({
    this.activeBarangay,
    this.activeTopic,
    required this.routingMode,
    this.previousBarangay,
    this.previousTopic,
    this.unsubscribed = false,
    this.subscribed = false,
    this.registeredFallback,
    this.currentDetectedBarangay,
  });

  @override
  String toString() =>
      'NotificationRoutingResult(active: $activeBarangay, topic: $activeTopic, mode: $routingMode, unsubs: $unsubscribed, subs: $subscribed)';
}

/// FCM setup + barangay topic subscribe via backend `/api/user/subscribe`.
class NotificationService {
  static const String _baseUrl = ApiConfig.apiBase;
  static String? _fcmToken;
  static AuthorizationStatus? _authorizationStatus;
  static bool _initialized = false;
  static StreamSubscription<String>? _tokenRefreshSubscription;

  static const String keyActiveBarangay = 'active_notification_barangay';
  static const String keyActiveTopic = 'active_notification_topic';
  static const String keyRoutingMode = 'notification_routing_mode';
  static const String keyRegisteredFallback = 'registered_fallback_barangay';
  static const String keySubscribedBarangay = 'subscribed_barangay';

  @visibleForTesting
  static Future<void> Function(String topic)? testSubscribeToTopic;

  @visibleForTesting
  static Future<void> Function(String topic)? testUnsubscribeFromTopic;

  @visibleForTesting
  static Future<bool> Function(String token, String barangay)? testRegisterBackend;

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
    final canonical = LocationService.canonicalizeBarangay(barangay);
    final normalized = canonical
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

  static Future<void> _internalSubscribe(String barangay) async {
    final topic = topicForBarangay(barangay);
    if (testSubscribeToTopic != null) {
      await testSubscribeToTopic!(topic);
    } else {
      if (_authorizationStatus == AuthorizationStatus.denied) {
        debugPrint(
            '[FCM MOBILE] Subscribe aborted: Notification permission denied. Topic=$topic');
        return;
      }
      try {
        _fcmToken ??= await FirebaseMessaging.instance.getToken();
        await FirebaseMessaging.instance.subscribeToTopic(topic);
      } catch (e) {
        debugPrint('[FCM MOBILE] FCM subscribeToTopic error: $e');
      }
    }

    final token = _fcmToken ?? 'test_token';
    if (testRegisterBackend != null) {
      await testRegisterBackend!(token, barangay);
    } else {
      try {
        final url = Uri.parse('$_baseUrl/user/subscribe');
        await http
            .post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'token': token, 'barangay': barangay}),
            )
            .timeout(const Duration(seconds: 15));
      } catch (e) {
        debugPrint('[FCM MOBILE] Backend registration error: $e');
      }
    }
  }

  static Future<void> _internalUnsubscribe(String barangay) async {
    final topic = topicForBarangay(barangay);
    if (testUnsubscribeFromTopic != null) {
      await testUnsubscribeFromTopic!(topic);
    } else {
      try {
        await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
      } catch (e) {
        debugPrint('[FCM MOBILE] FCM unsubscribeFromTopic error: $e');
      }
    }
  }

  /// Central synchronization method coordinating active current-location topic
  /// and registered-barangay fallback according to the Single Active Location-Target Topic Rule.
  static Future<NotificationRoutingResult> syncBarangayNotificationRouting({
    String? currentDetectedBarangay,
    String? registeredBarangay,
    bool force = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Determine target barangay & routing mode according to priority rules:
    // Priority 1: Current detected location inside canonical Marikina barangays
    // Priority 2: Registered profile barangay fallback
    String? targetBarangay;
    NotificationRoutingMode targetMode;

    final canonicalDetected =
        LocationService.canonicalizeBarangay(currentDetectedBarangay);
    final isDetectedValid =
        LocationService.isCanonicalMarikinaBarangay(canonicalDetected);

    final canonicalRegistered =
        LocationService.canonicalizeBarangay(registeredBarangay);
    final isRegisteredValid =
        LocationService.isCanonicalMarikinaBarangay(canonicalRegistered);

    if (isDetectedValid) {
      targetBarangay = canonicalDetected;
      targetMode = NotificationRoutingMode.currentLocation;
    } else if (isRegisteredValid) {
      targetBarangay = canonicalRegistered;
      targetMode = NotificationRoutingMode.registeredFallback;
    } else {
      targetBarangay = null;
      targetMode = NotificationRoutingMode.none;
    }

    // Persist updated registered fallback if valid
    if (isRegisteredValid) {
      await prefs.setString(keyRegisteredFallback, canonicalRegistered);
    }

    // 2. Read existing active state
    final previousBarangay = prefs.getString(keyActiveBarangay) ??
        prefs.getString(keySubscribedBarangay);
    final previousTopic =
        previousBarangay != null && previousBarangay.isNotEmpty
            ? topicForBarangay(previousBarangay)
            : null;

    final targetTopic = targetBarangay != null && targetBarangay.isNotEmpty
        ? topicForBarangay(targetBarangay)
        : null;

    bool didUnsubscribe = false;
    bool didSubscribe = false;

    // 3. Single Active Location-Target Topic Rule:
    // If target equals current active topic and not forcing refresh:
    if (!force &&
        targetBarangay == previousBarangay &&
        targetBarangay != null) {
      await prefs.setString(keyRoutingMode, targetMode.toStorageString());
      debugPrint(
          '[FCM ROUTING] Active topic unchanged: $targetTopic ($targetBarangay). Mode: ${targetMode.toStorageString()}');
      return NotificationRoutingResult(
        activeBarangay: targetBarangay,
        activeTopic: targetTopic,
        routingMode: targetMode,
        previousBarangay: previousBarangay,
        previousTopic: previousTopic,
        unsubscribed: false,
        subscribed: false,
        registeredFallback: prefs.getString(keyRegisteredFallback),
        currentDetectedBarangay: isDetectedValid ? canonicalDetected : null,
      );
    }

    // Unsubscribe from previous topic if switching or clearing
    if (previousBarangay != null &&
        previousBarangay.isNotEmpty &&
        previousBarangay != targetBarangay) {
      debugPrint(
          '[FCM ROUTING] Unsubscribing from stale topic: $previousTopic ($previousBarangay)');
      await _internalUnsubscribe(previousBarangay);
      didUnsubscribe = true;
    }

    // Subscribe to new target topic
    if (targetBarangay != null && targetBarangay.isNotEmpty) {
      debugPrint(
          '[FCM ROUTING] Subscribing to new topic: $targetTopic ($targetBarangay) [Mode: ${targetMode.toStorageString()}]');
      await _internalSubscribe(targetBarangay);
      didSubscribe = true;

      await prefs.setString(keyActiveBarangay, targetBarangay);
      await prefs.setString(keyActiveTopic, targetTopic!);
      await prefs.setString(keyRoutingMode, targetMode.toStorageString());
      await prefs.setString(keySubscribedBarangay, targetBarangay);
    } else {
      // Clear routing state
      await prefs.remove(keyActiveBarangay);
      await prefs.remove(keyActiveTopic);
      await prefs.setString(
          keyRoutingMode, NotificationRoutingMode.none.toStorageString());
      await prefs.remove(keySubscribedBarangay);
    }

    return NotificationRoutingResult(
      activeBarangay: targetBarangay,
      activeTopic: targetTopic,
      routingMode: targetMode,
      previousBarangay: previousBarangay,
      previousTopic: previousTopic,
      unsubscribed: didUnsubscribe,
      subscribed: didSubscribe,
      registeredFallback: prefs.getString(keyRegisteredFallback),
      currentDetectedBarangay: isDetectedValid ? canonicalDetected : null,
    );
  }

  /// One-shot synchronization using current device environment (GPS detection + registered fallback).
  static Future<NotificationRoutingResult> syncFromCurrentEnvironment({
    String? registeredBarangay,
    Duration timeout = const Duration(seconds: 8),
    bool force = false,
  }) async {
    String? reg = registeredBarangay;
    if (reg == null || reg.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString('user_data');
      if (userDataString != null) {
        try {
          final data = jsonDecode(userDataString) as Map<String, dynamic>;
          reg = data['barangay']?.toString();
        } catch (_) {}
      }
      reg ??= prefs.getString(keyRegisteredFallback);
    }

    String? detectedBarangay;
    try {
      detectedBarangay =
          await LocationService.resolveCurrentLocationBarangay(timeout: timeout);
    } catch (e) {
      debugPrint('[FCM ROUTING] Location resolution failed or timed out: $e');
      detectedBarangay = null;
    }

    return await syncBarangayNotificationRouting(
      currentDetectedBarangay: detectedBarangay,
      registeredBarangay: reg,
      force: force,
    );
  }

  /// Cleans up the active barangay topic subscription on user logout.
  static Future<void> cleanupOnLogout() async {
    final prefs = await SharedPreferences.getInstance();
    final activeBarangay = prefs.getString(keyActiveBarangay) ??
        prefs.getString(keySubscribedBarangay);
    if (activeBarangay != null && activeBarangay.isNotEmpty) {
      debugPrint(
          '[FCM ROUTING] Logout cleanup: unsubscribing from $activeBarangay');
      await _internalUnsubscribe(activeBarangay);
    }

    await prefs.remove(keyActiveBarangay);
    await prefs.remove(keyActiveTopic);
    await prefs.remove(keyRoutingMode);
    await prefs.remove(keyRegisteredFallback);
    await prefs.remove(keySubscribedBarangay);
  }

  static Future<void> subscribeToBarangay(String barangay) async {
    await syncBarangayNotificationRouting(registeredBarangay: barangay);
  }

  static Future<void> _resubscribeStoredBarangay() async {
    await syncFromCurrentEnvironment(force: true);
  }

  static Future<void> unsubscribeFromBarangay(String barangay) async {
    await cleanupOnLogout();
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
