import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:floodguard_ai/services/notification_service.dart';
import 'package:floodguard_ai/services/location_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FCM Topic Name Parity', () {
    test('canonical barangay topics match server formatter examples', () {
      expect(NotificationService.topicForBarangay('Santo Niño'),
          'barangay_santo_nino');
      expect(NotificationService.topicForBarangay('Tañong'), 'barangay_tanong');
      expect(NotificationService.topicForBarangay('Jesus Dela Peña'),
          'barangay_jesus_dela_pena');
      expect(NotificationService.topicForBarangay('Concepcion Uno'),
          'barangay_concepcion_uno');
      expect(NotificationService.topicForBarangay('Concepcion Dos'),
          'barangay_concepcion_dos');
      expect(NotificationService.topicForBarangay('San Roque'),
          'barangay_san_roque');
      expect(NotificationService.topicForBarangay('Santa Elena'),
          'barangay_santa_elena');
      expect(NotificationService.topicForBarangay('Fortune'),
          'barangay_fortune');
      expect(NotificationService.topicForBarangay('Malanday'),
          'barangay_malanday');
      expect(NotificationService.topicForBarangay('Marikina Heights'),
          'barangay_marikina_heights');
      expect(NotificationService.topicForBarangay('Nangka'),
          'barangay_nangka');
      expect(NotificationService.topicForBarangay('Parang'),
          'barangay_parang');
      expect(NotificationService.topicForBarangay('Tumana'),
          'barangay_tumana');
      expect(NotificationService.topicForBarangay('Barangka'),
          'barangay_barangka');
      expect(NotificationService.topicForBarangay('Calumpang'),
          'barangay_calumpang');
      expect(NotificationService.topicForBarangay('Industrial Valley Complex'),
          'barangay_industrial_valley');
      expect(NotificationService.topicForBarangay('Industrial Valley (IVC)'),
          'barangay_industrial_valley');
    });

    test('handles variations with accents, uppercase, and minor differences', () {
      expect(NotificationService.topicForBarangay('SANTO NIÑO'),
          'barangay_santo_nino');
      expect(NotificationService.topicForBarangay('Sto. Nino'),
          'barangay_santo_nino');
      expect(NotificationService.topicForBarangay('Tanong'),
          'barangay_tanong');
      expect(NotificationService.topicForBarangay('Jesus Dela Pena'),
          'barangay_jesus_dela_pena');
      expect(NotificationService.topicForBarangay('IVC'),
          'barangay_industrial_valley');
      expect(NotificationService.topicForBarangay('Industrial Valley'),
          'barangay_industrial_valley');
    });
  });

  group('Geolocation FCM Notification Routing', () {
    late Set<String> activeSubscriptions;
    late List<String> operationLog;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      activeSubscriptions = {};
      operationLog = [];

      NotificationService.testSubscribeToTopic = (topic) async {
        operationLog.add('sub:$topic');
        activeSubscriptions.add(topic);
      };

      NotificationService.testUnsubscribeFromTopic = (topic) async {
        operationLog.add('unsub:$topic');
        activeSubscriptions.remove(topic);
      };

      NotificationService.testRegisterBackend = (token, barangay) async {
        operationLog.add('backend:$barangay');
        return true;
      };
    });

    List<String> topicOps() =>
        operationLog.where((op) => op.startsWith('unsub:') || op.startsWith('sub:')).toList();

    tearDown(() {
      NotificationService.testSubscribeToTopic = null;
      NotificationService.testUnsubscribeFromTopic = null;
      NotificationService.testRegisterBackend = null;
    });

    test('Scenario A: User is in Tumana with registered fallback Nangka -> subscribes Tumana (currentLocation)', () async {
      final result = await NotificationService.syncBarangayNotificationRouting(
        currentDetectedBarangay: 'Tumana',
        registeredBarangay: 'Nangka',
      );

      expect(result.activeBarangay, 'Tumana');
      expect(result.activeTopic, 'barangay_tumana');
      expect(result.routingMode, NotificationRoutingMode.currentLocation);
      expect(result.registeredFallback, 'Nangka');
      expect(activeSubscriptions, {'barangay_tumana'});
      expect(topicOps(), ['sub:barangay_tumana']);
      expect(operationLog, contains('backend:Tumana'));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('active_notification_barangay'), 'Tumana');
      expect(prefs.getString('active_notification_topic'), 'barangay_tumana');
      expect(prefs.getString('notification_routing_mode'), 'current_location');
      expect(prefs.getString('registered_fallback_barangay'), 'Nangka');
    });

    test('Scenario B: User moves from Tumana to Nangka -> unsubs Tumana, subs Nangka (single active topic)', () async {
      // Start in Tumana
      await NotificationService.syncBarangayNotificationRouting(
        currentDetectedBarangay: 'Tumana',
        registeredBarangay: 'Concepcion Uno',
      );
      expect(activeSubscriptions, {'barangay_tumana'});
      operationLog.clear();

      // Move to Nangka
      final result = await NotificationService.syncBarangayNotificationRouting(
        currentDetectedBarangay: 'Nangka',
        registeredBarangay: 'Concepcion Uno',
      );

      expect(result.activeBarangay, 'Nangka');
      expect(result.activeTopic, 'barangay_nangka');
      expect(result.routingMode, NotificationRoutingMode.currentLocation);
      // Safe order: Subscribe NEW first, then unsubscribe OLD
      expect(topicOps(), ['sub:barangay_nangka', 'unsub:barangay_tumana']);
      expect(operationLog, contains('backend:Nangka'));
      expect(activeSubscriptions, {'barangay_nangka'});
      expect(activeSubscriptions.length, 1);
    });

    test('Scenario C: User stays in Nangka -> idempotent re-sync executes 0 network calls', () async {
      await NotificationService.syncBarangayNotificationRouting(
        currentDetectedBarangay: 'Nangka',
        registeredBarangay: 'Concepcion Uno',
      );
      operationLog.clear();

      // Re-sync with same location
      final result = await NotificationService.syncBarangayNotificationRouting(
        currentDetectedBarangay: 'Nangka',
        registeredBarangay: 'Concepcion Uno',
      );

      expect(result.activeBarangay, 'Nangka');
      expect(operationLog, isEmpty); // No unneeded unsubscribe or subscribe
      expect(activeSubscriptions, {'barangay_nangka'});
    });

    test('Scenario D: Current location unavailable -> uses registered fallback', () async {
      final result = await NotificationService.syncBarangayNotificationRouting(
        currentDetectedBarangay: null,
        registeredBarangay: 'Malanday',
      );

      expect(result.activeBarangay, 'Malanday');
      expect(result.activeTopic, 'barangay_malanday');
      expect(result.routingMode, NotificationRoutingMode.registeredFallback);
      expect(activeSubscriptions, {'barangay_malanday'});
    });

    test('Scenario E: User moves outside Marikina -> falls back to registered barangay', () async {
      // Start inside Marikina in Barangka
      await NotificationService.syncBarangayNotificationRouting(
        currentDetectedBarangay: 'Barangka',
        registeredBarangay: 'Parang',
      );
      expect(activeSubscriptions, {'barangay_barangka'});
      operationLog.clear();

      // Location becomes null (e.g. user traveled to Quezon City / Manila)
      final result = await NotificationService.syncBarangayNotificationRouting(
        currentDetectedBarangay: null,
        registeredBarangay: 'Parang',
      );

      expect(result.activeBarangay, 'Parang');
      expect(result.activeTopic, 'barangay_parang');
      expect(result.routingMode, NotificationRoutingMode.registeredFallback);
      expect(topicOps(), ['sub:barangay_parang', 'unsub:barangay_barangka']);
      expect(operationLog, contains('backend:Parang'));
      expect(activeSubscriptions, {'barangay_parang'});
    });

    test('Scenario F: User moves back into Marikina -> auto-promotes from fallback to GPS', () async {
      // In fallback mode on Parang
      await NotificationService.syncBarangayNotificationRouting(
        currentDetectedBarangay: null,
        registeredBarangay: 'Parang',
      );
      expect(activeSubscriptions, {'barangay_parang'});
      operationLog.clear();

      // Detected in Santo Niño
      final result = await NotificationService.syncBarangayNotificationRouting(
        currentDetectedBarangay: 'Santo Niño',
        registeredBarangay: 'Parang',
      );

      expect(result.activeBarangay, 'Santo Niño');
      expect(result.activeTopic, 'barangay_santo_nino');
      expect(result.routingMode, NotificationRoutingMode.currentLocation);
      expect(topicOps(), ['sub:barangay_santo_nino', 'unsub:barangay_parang']);
      expect(operationLog, contains('backend:Santo Niño'));
      expect(activeSubscriptions, {'barangay_santo_nino'});
    });

    test('Scenario H: Registered fallback changed while GPS unavailable -> switches fallback topic', () async {
      // Fallback on Tumana
      await NotificationService.syncBarangayNotificationRouting(
        currentDetectedBarangay: null,
        registeredBarangay: 'Tumana',
      );
      expect(activeSubscriptions, {'barangay_tumana'});
      operationLog.clear();

      // Profile updated to Nangka while GPS still unavailable
      final result = await NotificationService.syncBarangayNotificationRouting(
        currentDetectedBarangay: null,
        registeredBarangay: 'Nangka',
      );

      expect(result.activeBarangay, 'Nangka');
      expect(result.activeTopic, 'barangay_nangka');
      expect(result.routingMode, NotificationRoutingMode.registeredFallback);
      expect(topicOps(), ['sub:barangay_nangka', 'unsub:barangay_tumana']);
      expect(operationLog, contains('backend:Nangka'));
      expect(activeSubscriptions, {'barangay_nangka'});
    });

    test('Scenario I: Registered fallback changed while GPS routing is ACTIVE -> keeps GPS topic, updates stored fallback', () async {
      // In Barangka via GPS
      await NotificationService.syncBarangayNotificationRouting(
        currentDetectedBarangay: 'Barangka',
        registeredBarangay: 'Tumana',
      );
      expect(activeSubscriptions, {'barangay_barangka'});
      operationLog.clear();

      // Profile updated to Nangka, but user is still detected in Barangka
      final result = await NotificationService.syncBarangayNotificationRouting(
        currentDetectedBarangay: 'Barangka',
        registeredBarangay: 'Nangka',
      );

      expect(result.activeBarangay, 'Barangka');
      expect(result.activeTopic, 'barangay_barangka');
      expect(result.routingMode, NotificationRoutingMode.currentLocation);
      expect(result.registeredFallback, 'Nangka');
      // No unsub/sub calls because active topic hasn't changed!
      expect(operationLog, isEmpty);
      expect(activeSubscriptions, {'barangay_barangka'});

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('registered_fallback_barangay'), 'Nangka');
      expect(prefs.getString('active_notification_barangay'), 'Barangka');
    });

    test('Scenario J: GPS lost after registered change -> seamlessly activates new fallback', () async {
      // Continuing from Scenario I: in Barangka with updated fallback Nangka
      await NotificationService.syncBarangayNotificationRouting(
        currentDetectedBarangay: 'Barangka',
        registeredBarangay: 'Nangka',
      );
      operationLog.clear();

      // GPS lost
      final result = await NotificationService.syncBarangayNotificationRouting(
        currentDetectedBarangay: null,
        registeredBarangay: 'Nangka',
      );

      expect(result.activeBarangay, 'Nangka');
      expect(result.activeTopic, 'barangay_nangka');
      expect(result.routingMode, NotificationRoutingMode.registeredFallback);
      expect(topicOps(), ['sub:barangay_nangka', 'unsub:barangay_barangka']);
      expect(operationLog, contains('backend:Nangka'));
      expect(activeSubscriptions, {'barangay_nangka'});
    });

    test('Scenario K: Logout -> cleans up active topic and clears all routing SharedPreferences', () async {
      // Active in Tañong
      await NotificationService.syncBarangayNotificationRouting(
        currentDetectedBarangay: 'Tañong',
        registeredBarangay: 'Tumana',
      );
      expect(activeSubscriptions, {'barangay_tanong'});
      operationLog.clear();

      // Logout
      await NotificationService.cleanupOnLogout();

      expect(topicOps(), ['unsub:barangay_tanong']);
      expect(activeSubscriptions, isEmpty);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('active_notification_barangay'), isNull);
      expect(prefs.getString('active_notification_topic'), isNull);
      expect(prefs.getString('notification_routing_mode'), isNull);
      expect(prefs.getString('registered_fallback_barangay'), isNull);
      expect(prefs.getString('subscribed_barangay'), isNull);
    });

    test('Scenario L: Neither GPS nor registered fallback available -> mode none', () async {
      final result = await NotificationService.syncBarangayNotificationRouting(
        currentDetectedBarangay: null,
        registeredBarangay: null,
      );

      expect(result.activeBarangay, isNull);
      expect(result.activeTopic, isNull);
      expect(result.routingMode, NotificationRoutingMode.none);
      expect(activeSubscriptions, isEmpty);
      expect(operationLog, isEmpty);
    });

    test('Scenario M: Multi-hop migration strictly adheres to Single Active Topic rule', () async {
      final path = [
        'Marikina Heights',
        'Parang',
        'Fortune',
        'Nangka',
        'Concepcion Uno',
        'Tumana',
      ];

      for (final barangay in path) {
        await NotificationService.syncBarangayNotificationRouting(
          currentDetectedBarangay: barangay,
          registeredBarangay: 'Santa Elena',
        );
        // At every single hop, there must be exactly 1 active topic
        expect(activeSubscriptions.length, 1);
        expect(activeSubscriptions.first, NotificationService.topicForBarangay(barangay));
      }
    });

    test('Scenario N: syncFromCurrentEnvironment routes to registered fallback when GPS unavailable', () async {
      final result = await NotificationService.syncFromCurrentEnvironment(
        registeredBarangay: 'Fortune',
        timeout: const Duration(milliseconds: 50),
      );

      expect(result.activeBarangay, 'Fortune');
      expect(result.activeTopic, 'barangay_fortune');
      expect(result.routingMode, NotificationRoutingMode.registeredFallback);
      expect(activeSubscriptions, {'barangay_fortune'});
    });

    test('Scenario O: Subscription failure leaves confirmed topic unchanged and sets status pending', () async {
      // Start in Tumana successfully
      await NotificationService.syncBarangayNotificationRouting(
        currentDetectedBarangay: 'Tumana',
        registeredBarangay: 'Tumana',
      );
      expect(activeSubscriptions, {'barangay_tumana'});
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('confirmed_fcm_topic'), 'barangay_tumana');
      expect(prefs.getString('fcm_sync_status'), 'synced');

      // Simulate subscribe failure when moving to Nangka
      NotificationService.testSubscribeSuccess = false;
      final result = await NotificationService.syncBarangayNotificationRouting(
        currentDetectedBarangay: 'Nangka',
        registeredBarangay: 'Tumana',
      );

      expect(result.subscribed, isFalse);
      expect(result.syncStatus, 'pending');
      expect(prefs.getString('fcm_sync_status'), 'pending');
      expect(prefs.getString('desired_fcm_topic'), 'barangay_nangka');
      // Confirmed topic was not updated to desired topic on failure
      expect(prefs.getString('confirmed_fcm_topic'), isNot('barangay_nangka'));

      // Restore subscribe success and re-sync -> should succeed and mark synced
      NotificationService.testSubscribeSuccess = true;
      final retryResult = await NotificationService.syncBarangayNotificationRouting(
        currentDetectedBarangay: 'Nangka',
        registeredBarangay: 'Tumana',
      );
      expect(retryResult.subscribed, isTrue);
      expect(retryResult.syncStatus, 'synced');
      expect(prefs.getString('confirmed_fcm_topic'), 'barangay_nangka');
      expect(prefs.getString('fcm_sync_status'), 'synced');
      NotificationService.testSubscribeSuccess = null;
    });

    test('Scenario P: Unsubscribe failure retains topic in pending_cleanup_topic and retries', () async {
      // Start in Malanday
      await NotificationService.syncBarangayNotificationRouting(
        currentDetectedBarangay: 'Malanday',
        registeredBarangay: 'Malanday',
      );
      expect(activeSubscriptions, {'barangay_malanday'});

      // Simulate unsubscribe failure when switching to Parang
      NotificationService.testUnsubscribeSuccess = false;
      final result = await NotificationService.syncBarangayNotificationRouting(
        currentDetectedBarangay: 'Parang',
        registeredBarangay: 'Malanday',
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('pending_cleanup_topic'), 'barangay_malanday');
      expect(result.syncStatus, 'pending');

      // Subsequent sync with unsubs fixed -> clears pending cleanup
      NotificationService.testUnsubscribeSuccess = true;
      await NotificationService.syncBarangayNotificationRouting(
        currentDetectedBarangay: 'Parang',
        registeredBarangay: 'Malanday',
        force: true,
      );

      expect(prefs.getString('pending_cleanup_topic'), isNull);
      expect(prefs.getString('fcm_sync_status'), 'synced');
      NotificationService.testUnsubscribeSuccess = null;
    });

    test('Scenario Q: Unauthenticated guest does not subscribe to location topics and cleans up active', () async {
      // Active user in Tumana
      await NotificationService.syncBarangayNotificationRouting(
        currentDetectedBarangay: 'Tumana',
        registeredBarangay: 'Tumana',
      );
      expect(activeSubscriptions, {'barangay_tumana'});

      // Guest access
      final result = await NotificationService.syncBarangayNotificationRouting(
        currentDetectedBarangay: 'Tumana',
        isGuest: true,
      );

      expect(result.routingMode, NotificationRoutingMode.none);
      expect(result.syncStatus, 'synced');
      expect(activeSubscriptions, isEmpty);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('active_notification_topic'), isNull);
      expect(prefs.getString('confirmed_fcm_topic'), isNull);
    });
  });

  group('LocationService Barangay Resolution', () {
    test('canonicalizeBarangay normalizes all 16 Marikina barangays', () {
      expect(LocationService.canonicalizeBarangay('Barangka'), 'Barangka');
      expect(LocationService.canonicalizeBarangay('barangka'), 'Barangka');
      expect(LocationService.canonicalizeBarangay('santo nino'), 'Santo Niño');
      expect(LocationService.canonicalizeBarangay('SANTO NIÑO'), 'Santo Niño');
      expect(LocationService.canonicalizeBarangay('Sto. Nino'), 'Santo Niño');
      expect(LocationService.canonicalizeBarangay('tanong'), 'Tañong');
      expect(LocationService.canonicalizeBarangay('Tañong'), 'Tañong');
      expect(LocationService.canonicalizeBarangay('jesus dela pena'), 'Jesus Dela Peña');
      expect(LocationService.canonicalizeBarangay('Jesus Dela Peña'), 'Jesus Dela Peña');
      expect(LocationService.canonicalizeBarangay('IVC'), 'Industrial Valley (IVC)');
      expect(LocationService.canonicalizeBarangay('Industrial Valley Complex'), 'Industrial Valley (IVC)');
      expect(LocationService.canonicalizeBarangay('Industrial Valley'), 'Industrial Valley (IVC)');
      expect(LocationService.canonicalizeBarangay('Concepcion 1'), 'Concepcion Uno');
      expect(LocationService.canonicalizeBarangay('Concepcion 2'), 'Concepcion Dos');
    });

    test('point in polygon algorithm correctly identifies points inside and outside polygon', () {
      // Simple unit square polygon: (0,0), (10,0), (10,10), (0,10)
      final square = [
        [0.0, 0.0],
        [10.0, 0.0],
        [10.0, 10.0],
        [0.0, 10.0],
      ];

      expect(LocationService.isPointInPolygon(5.0, 5.0, square), isTrue);
      expect(LocationService.isPointInPolygon(15.0, 5.0, square), isFalse);
      expect(LocationService.isPointInPolygon(-1.0, 5.0, square), isFalse);
      expect(LocationService.isPointInPolygon(5.0, 15.0, square), isFalse);
    });

    test('resolves barangay using mock boundaries', () async {
      LocationService.setMockBarangayBoundaries({
        'Tumana': [
          [
            [121.090, 14.650],
            [121.090, 14.665],
            [121.105, 14.665],
            [121.105, 14.650],
          ]
        ],
        'Nangka': [
          [
            [121.105, 14.665],
            [121.105, 14.680],
            [121.120, 14.680],
            [121.120, 14.665],
          ]
        ],
      });

      // Point in Tumana box (lat: 14.655, lng: 121.095)
      expect(await LocationService.resolveBarangayFromCoordinates(14.655, 121.095), 'Tumana');

      // Point in Nangka box (lat: 14.670, lng: 121.110)
      expect(await LocationService.resolveBarangayFromCoordinates(14.670, 121.110), 'Nangka');

      // Point outside both boxes
      expect(await LocationService.resolveBarangayFromCoordinates(14.500, 121.000), isNull);
    });

    test('resolves real centroids from assets/marikina1.geojson', () async {
      // Clear mock boundaries so it loads from asset
      LocationService.setMockBarangayBoundaries(null);

      expect(await LocationService.resolveBarangayFromCoordinates(14.657487, 121.098655), 'Tumana');
      expect(await LocationService.resolveBarangayFromCoordinates(14.668938, 121.110584), 'Nangka');
      expect(await LocationService.resolveBarangayFromCoordinates(14.652105, 121.107812), 'Concepcion Uno');
      expect(await LocationService.resolveBarangayFromCoordinates(14.630095, 121.082725), 'Barangka');
      expect(await LocationService.resolveBarangayFromCoordinates(14.646875, 121.094595), 'Malanday');
      expect(await LocationService.resolveBarangayFromCoordinates(14.624231, 121.101124), 'San Roque');
      expect(await LocationService.resolveBarangayFromCoordinates(14.632505, 121.101080), 'Santa Elena');

      // Outside Marikina
      expect(await LocationService.resolveBarangayFromCoordinates(14.5995, 120.9842), isNull);
    });
  });
}
