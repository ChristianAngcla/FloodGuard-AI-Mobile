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
  final String syncStatus; // 'synced' | 'pending'

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
    this.syncStatus = 'synced',
  });

  @override
  String toString() =>
      'NotificationRoutingResult(active: $activeBarangay, topic: $activeTopic, mode: $routingMode, unsubs: $unsubscribed, subs: $subscribed, syncStatus: $syncStatus)';
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

  // Explicit Synchronization State Keys (M7)
  static const String keyConfirmedTopic = 'confirmed_fcm_topic';
  static const String keyDesiredTopic = 'desired_fcm_topic';
  static const String keyPendingCleanupTopic = 'pending_cleanup_topic';
  static const String keySyncStatus = 'fcm_sync_status'; // 'synced' | 'pending'

  static final StreamController<void> onAlertsUpdated =
      StreamController<void>.broadcast();

  static final StreamController<Map<String, dynamic>> onNotificationTapped =
      StreamController<Map<String, dynamic>>.broadcast();

  @visibleForTesting
  static Future<void> Function(String topic)? testSubscribeToTopic;

  @visibleForTesting
  static Future<void> Function(String topic)? testUnsubscribeFromTopic;

  @visibleForTesting
  static Future<bool> Function(String token, String barangay)? testRegisterBackend;

  @visibleForTesting
  static bool? testSubscribeSuccess;

  @visibleForTesting
  static bool? testUnsubscribeSuccess;

  /// Canonical barangay topic dictionary for all 16 Marikina barangays.
  static const Map<String, String> barangayTopicMap = {
    'Barangka': 'barangay_barangka',
    'Calumpang': 'barangay_calumpang',
    'Concepcion Dos': 'barangay_concepcion_dos',
    'Concepcion Uno': 'barangay_concepcion_uno',
    'Fortune': 'barangay_fortune',
    'Industrial Valley (IVC)': 'barangay_industrial_valley',
    'Jesus Dela Peña': 'barangay_jesus_dela_pena',
    'Malanday': 'barangay_malanday',
    'Marikina Heights': 'barangay_marikina_heights',
    'Nangka': 'barangay_nangka',
    'Parang': 'barangay_parang',
    'San Roque': 'barangay_san_roque',
    'Santa Elena': 'barangay_santa_elena',
    'Santo Niño': 'barangay_santo_nino',
    'Tañong': 'barangay_tanong',
    'Tumana': 'barangay_tumana',
  };

  /// Canonical FCM topic for a barangay name.
  static String topicForBarangay(String barangay) {
    final canonical = LocationService.canonicalizeBarangay(barangay);
    if (barangayTopicMap.containsKey(canonical)) {
      return barangayTopicMap[canonical]!;
    }
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

    if (normalized == 'industrial_valley_ivc' ||
        normalized == 'industrial_valley_complex' ||
        normalized == 'industrial_valley' ||
        normalized == 'ivc') {
      return 'barangay_industrial_valley';
    }
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
        onNotificationTapped.add(initialMessage.data);
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
        Map<String, dynamic> data = {};
        if (response.payload != null && response.payload!.isNotEmpty) {
          try {
            data = jsonDecode(response.payload!) as Map<String, dynamic>;
          } catch (_) {}
        }
        onNotificationTapped.add(data);
      },
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_emergencyChannel);
  }

  static Future<bool> _internalSubscribe(String barangay) async {
    final topic = topicForBarangay(barangay);
    if (testSubscribeSuccess == false) {
      debugPrint('[FCM MOBILE] Simulated subscribe failure for $topic');
      return false;
    }

    if (testSubscribeToTopic != null) {
      try {
        await testSubscribeToTopic!(topic);
      } catch (e) {
        debugPrint('[FCM MOBILE] Test subscribeToTopic exception: $e');
        return false;
      }
    } else {
      if (_authorizationStatus == AuthorizationStatus.denied) {
        debugPrint(
            '[FCM MOBILE] Subscribe aborted: Notification permission denied. Topic=$topic');
        return false;
      }
      try {
        _fcmToken ??= await FirebaseMessaging.instance.getToken();
        await FirebaseMessaging.instance.subscribeToTopic(topic);
      } catch (e) {
        debugPrint('[FCM MOBILE] FCM subscribeToTopic error: $e');
        return false;
      }
    }

    final token = _fcmToken ?? 'test_token';
    if (testRegisterBackend != null) {
      try {
        await testRegisterBackend!(token, barangay);
      } catch (e) {
        debugPrint('[FCM MOBILE] Test registerBackend exception: $e');
      }
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
    return true;
  }

  static Future<bool> _internalUnsubscribeTopic(String topic) async {
    if (testUnsubscribeSuccess == false) {
      debugPrint('[FCM MOBILE] Simulated unsubscribe failure for $topic');
      return false;
    }

    if (testUnsubscribeFromTopic != null) {
      try {
        await testUnsubscribeFromTopic!(topic);
        return true;
      } catch (e) {
        debugPrint('[FCM MOBILE] Test unsubscribeFromTopic exception: $e');
        return false;
      }
    } else {
      try {
        await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
        return true;
      } catch (e) {
        debugPrint('[FCM MOBILE] FCM unsubscribeFromTopic error: $e');
        return false;
      }
    }
  }

  /// Central synchronization method coordinating active current-location topic
  /// and registered-barangay fallback according to the Single Active Location-Target Topic Rule.
  static Future<NotificationRoutingResult> syncBarangayNotificationRouting({
    String? currentDetectedBarangay,
    String? registeredBarangay,
    bool force = false,
    bool? isGuest,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // Guest check: Unauthenticated guests should NOT subscribe to location topics
    final bool guest = isGuest ??
        (prefs.getBool('is_logged_in') == false &&
            registeredBarangay == null &&
            prefs.getString('user_data') == null);

    if (guest) {
      debugPrint('[FCM ROUTING] Guest mode active — cleaning up location subscriptions');
      final active = prefs.getString(keyConfirmedTopic) ??
          prefs.getString(keyActiveTopic) ??
          prefs.getString(keySubscribedBarangay);
      if (active != null && active.isNotEmpty) {
        final topic = active.startsWith('barangay_') ? active : topicForBarangay(active);
        final unsubsOk = await _internalUnsubscribeTopic(topic);
        if (unsubsOk) {
          await prefs.remove(keyPendingCleanupTopic);
        } else {
          await prefs.setString(keyPendingCleanupTopic, topic);
        }
      }
      await prefs.remove(keyActiveBarangay);
      await prefs.remove(keyActiveTopic);
      await prefs.remove(keyConfirmedTopic);
      await prefs.remove(keyDesiredTopic);
      await prefs.setString(
          keyRoutingMode, NotificationRoutingMode.none.toStorageString());
      await prefs.remove(keySubscribedBarangay);
      await prefs.setString(keySyncStatus, 'synced');
      return const NotificationRoutingResult(
        routingMode: NotificationRoutingMode.none,
        syncStatus: 'synced',
      );
    }

    // 0. Retry any pending cleanup topic from a prior failed unsubscription
    final pendingCleanup = prefs.getString(keyPendingCleanupTopic);
    if (pendingCleanup != null && pendingCleanup.isNotEmpty) {
      debugPrint('[FCM ROUTING] Retrying pending cleanup for topic: $pendingCleanup');
      final cleanupOk = await _internalUnsubscribeTopic(pendingCleanup);
      if (cleanupOk) {
        await prefs.remove(keyPendingCleanupTopic);
        debugPrint('[FCM ROUTING] Pending cleanup succeeded for $pendingCleanup');
      }
    }

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

    // 2. Read existing active state and desired topic
    final previousBarangay = prefs.getString(keyActiveBarangay) ??
        prefs.getString(keySubscribedBarangay);
    final previousTopic = prefs.getString(keyConfirmedTopic) ??
        prefs.getString(keyActiveTopic) ??
        (previousBarangay != null && previousBarangay.isNotEmpty
            ? topicForBarangay(previousBarangay)
            : null);

    final targetTopic = targetBarangay != null && targetBarangay.isNotEmpty
        ? topicForBarangay(targetBarangay)
        : null;

    if (targetTopic != null) {
      await prefs.setString(keyDesiredTopic, targetTopic);
    } else {
      await prefs.remove(keyDesiredTopic);
    }

    bool didUnsubscribe = false;
    bool didSubscribe = false;

    // 3. Single Active Location-Target Topic Rule:
    // If target equals current confirmed topic and not forcing refresh:
    if (!force &&
        targetBarangay == previousBarangay &&
        targetBarangay != null &&
        prefs.getString(keyConfirmedTopic) == targetTopic) {
      await prefs.setString(keyRoutingMode, targetMode.toStorageString());
      final hasPendingCleanup = prefs.getString(keyPendingCleanupTopic) != null;
      final status = hasPendingCleanup ? 'pending' : 'synced';
      await prefs.setString(keySyncStatus, status);
      debugPrint(
          '[FCM ROUTING] Active topic unchanged: $targetTopic ($targetBarangay). Status: $status');
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
        syncStatus: status,
      );
    }

    // 4. Safe Topic Switch Order (M7):
    // Step A: Subscribe to NEW topic first
    // Step B: Only after success mark NEW confirmed
    // Step C: Then unsubscribe OLD topic
    // A failed NEW subscription must leave the previous confirmed topic active.
    if (targetBarangay != null && targetBarangay.isNotEmpty && targetTopic != null) {
      debugPrint(
          '[FCM ROUTING] Subscribing to new topic: $targetTopic ($targetBarangay) [Mode: ${targetMode.toStorageString()}]');
      final subsOk = await _internalSubscribe(targetBarangay);
      if (subsOk) {
        didSubscribe = true;
        await prefs.setString(keyConfirmedTopic, targetTopic);
        await prefs.setString(keyActiveBarangay, targetBarangay);
        await prefs.setString(keyActiveTopic, targetTopic);
        await prefs.setString(keyRoutingMode, targetMode.toStorageString());
        await prefs.setString(keySubscribedBarangay, targetBarangay);

        // Step C: Then unsubscribe OLD topic
        if (previousTopic != null &&
            previousTopic.isNotEmpty &&
            previousTopic != targetTopic) {
          debugPrint('[FCM ROUTING] Unsubscribing from stale topic: $previousTopic');
          final unsubsOk = await _internalUnsubscribeTopic(previousTopic);
          if (unsubsOk) {
            didUnsubscribe = true;
            if (prefs.getString(keyPendingCleanupTopic) == previousTopic) {
              await prefs.remove(keyPendingCleanupTopic);
            }
          } else {
            await prefs.setString(keyPendingCleanupTopic, previousTopic);
            debugPrint('[FCM ROUTING] Unsubscribe failed; stored in pending cleanup: $previousTopic');
          }
        }

        final hasPendingCleanup = prefs.getString(keyPendingCleanupTopic) != null;
        final status = hasPendingCleanup ? 'pending' : 'synced';
        await prefs.setString(keySyncStatus, status);

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
          syncStatus: status,
        );
      } else {
        // Step D: A failed NEW subscription must leave the previous confirmed topic active!
        await prefs.setString(keySyncStatus, 'pending');
        debugPrint('[FCM ROUTING] Subscription failed for $targetTopic; previous confirmed topic remains active: $previousTopic');
        return NotificationRoutingResult(
          activeBarangay: previousBarangay,
          activeTopic: previousTopic,
          routingMode: targetMode,
          previousBarangay: previousBarangay,
          previousTopic: previousTopic,
          unsubscribed: false,
          subscribed: false,
          registeredFallback: prefs.getString(keyRegisteredFallback),
          currentDetectedBarangay: isDetectedValid ? canonicalDetected : null,
          syncStatus: 'pending',
        );
      }
    } else {
      // Clear routing state (target is none)
      if (previousTopic != null && previousTopic.isNotEmpty) {
        debugPrint('[FCM ROUTING] Clearing active topic: unsubscribing from $previousTopic');
        final unsubsOk = await _internalUnsubscribeTopic(previousTopic);
        if (unsubsOk) {
          didUnsubscribe = true;
          if (prefs.getString(keyPendingCleanupTopic) == previousTopic) {
            await prefs.remove(keyPendingCleanupTopic);
          }
        } else {
          await prefs.setString(keyPendingCleanupTopic, previousTopic);
        }
      }
      await prefs.remove(keyConfirmedTopic);
      await prefs.remove(keyActiveBarangay);
      await prefs.remove(keyActiveTopic);
      await prefs.setString(
          keyRoutingMode, NotificationRoutingMode.none.toStorageString());
      await prefs.remove(keySubscribedBarangay);
      await prefs.remove(keyDesiredTopic);
      final hasPendingCleanup = prefs.getString(keyPendingCleanupTopic) != null;
      final status = hasPendingCleanup ? 'pending' : 'synced';
      await prefs.setString(keySyncStatus, status);
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
      syncStatus: prefs.getString(keySyncStatus) ?? 'synced',
    );
  }

  /// One-shot synchronization using current device environment (GPS detection + registered fallback).
  static Future<NotificationRoutingResult> syncFromCurrentEnvironment({
    String? registeredBarangay,
    Duration timeout = const Duration(seconds: 8),
    bool force = false,
    bool? isGuest,
  }) async {
    String? reg = registeredBarangay;
    final prefs = await SharedPreferences.getInstance();

    final bool guest = isGuest ??
        (prefs.getBool('is_logged_in') == false &&
            reg == null &&
            prefs.getString('user_data') == null);

    if (guest) {
      return await syncBarangayNotificationRouting(isGuest: true);
    }

    if (reg == null || reg.isEmpty) {
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
      isGuest: false,
    );
  }

  /// Cleans up the active barangay topic subscription on user logout.
  static Future<void> cleanupOnLogout() async {
    final prefs = await SharedPreferences.getInstance();
    final confirmed = prefs.getString(keyConfirmedTopic) ??
        prefs.getString(keyActiveTopic) ??
        prefs.getString(keySubscribedBarangay);
    if (confirmed != null && confirmed.isNotEmpty) {
      final topic = confirmed.startsWith('barangay_') ? confirmed : topicForBarangay(confirmed);
      debugPrint('[FCM ROUTING] Logout cleanup: unsubscribing from $topic');
      final unsubsOk = await _internalUnsubscribeTopic(topic);
      if (!unsubsOk) {
        await prefs.setString(keyPendingCleanupTopic, topic);
      } else if (prefs.getString(keyPendingCleanupTopic) == topic) {
        await prefs.remove(keyPendingCleanupTopic);
      }
    }

    final pendingCleanup = prefs.getString(keyPendingCleanupTopic);
    if (pendingCleanup != null && pendingCleanup.isNotEmpty) {
      final cleanupOk = await _internalUnsubscribeTopic(pendingCleanup);
      if (cleanupOk) {
        await prefs.remove(keyPendingCleanupTopic);
      }
    }

    await prefs.remove(keyConfirmedTopic);
    await prefs.remove(keyDesiredTopic);
    await prefs.remove(keyActiveBarangay);
    await prefs.remove(keyActiveTopic);
    await prefs.remove(keyRoutingMode);
    await prefs.remove(keyRegisteredFallback);
    await prefs.remove(keySubscribedBarangay);

    final remainingCleanup = prefs.getString(keyPendingCleanupTopic);
    await prefs.setString(keySyncStatus, (remainingCleanup != null && remainingCleanup.isNotEmpty) ? 'pending' : 'synced');
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
      await prefs.reload();
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
      onAlertsUpdated.add(null);
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
    onNotificationTapped.add(message.data);
  }

  static Future<void> dispose() async {
    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;
    _initialized = false;
  }
}
