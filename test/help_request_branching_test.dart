import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:floodguard_ai/widgets/multistep_report_sheet.dart';
import 'package:floodguard_ai/services/location_service.dart';

HelpRequestLocationResolver _dummyResolver() {
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

Widget _buildTestApp({
  required HelpRequestSubmitHook submitHook,
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
        locationResolver: _dummyResolver(),
        submitFloodReport: submitHook,
      ),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'user_data': jsonEncode({
        'uid': 'test-uid-123',
        'firstName': 'Juan',
        'lastName': 'Dela Cruz',
        'phone': '09171234567',
      }),
    });
  });

  group('Help Request Flow - No Safe / No Stranded options', () {
    testWidgets('Screen does NOT offer "I am safe" or "Stranded" options',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildTestApp(submitHook: ({
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
      }) async => true));
      await tester.pumpAndSettle();

      // Step 0 options
      expect(find.text('Medical'), findsOneWidget);
      expect(find.text('Evacuation'), findsOneWidget);
      expect(find.text('Other Emergency'), findsOneWidget);

      // Must NOT contain safe or stranded options
      expect(find.text('I am safe'), findsNothing);
      expect(find.text('I need help'), findsNothing);
      expect(find.text('Yes, I am safe'), findsNothing);
      expect(find.text('Stranded'), findsNothing);
    });

    testWidgets('Step 0 requires selecting a help type before proceeding',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildTestApp(submitHook: ({
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
      }) async => true));
      await tester.pumpAndSettle();

      // Tap Next without selecting
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Still on Step 0, error shown
      expect(find.text('Please select what help you need.'), findsOneWidget);
      expect(find.text('Medical'), findsOneWidget);
    });
  });

  group('Help Request Flow - Medical Branch Submission', () {
    testWidgets('Medical path collects subtype, urgency and submits with isSafe=false',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      Map<String, dynamic> captured = {};

      await tester.pumpWidget(_buildTestApp(
        submitHook: ({
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
          captured = {
            'location': location,
            'isSafe': isSafe,
            'helpType': helpType,
            'helpSubtype': helpSubtype,
            'urgency': urgency,
            'details': details,
            'latitude': latitude,
            'longitude': longitude,
          };
          return true;
        },
      ));
      await tester.pumpAndSettle();

      // Step 0: Select Medical
      await tester.tap(find.text('Medical'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Step 1: Medical details
      expect(find.text('Medical Assistance Details'), findsOneWidget);
      expect(find.text('Injury'), findsOneWidget);
      expect(find.text('Medical emergency'), findsOneWidget);
      expect(find.text('Help for another person'), findsOneWidget);

      await tester.tap(find.text('Injury'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Step 2: Location
      expect(find.text('Incident Location'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Barangka').last);
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextField, 'Street or Landmark (Optional)'),
          'Near Concepcion Market');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Step 3: Review & Confirm
      expect(find.text('Review & Confirm Help Request'), findsOneWidget);
      expect(find.text('Injury'), findsOneWidget);
      expect(find.text('Near Concepcion Market, Barangka'), findsOneWidget);

      // Agree to legal notice
      await tester.ensureVisible(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      // Confirm submission
      await tester.tap(find.text('CONFIRM'));
      await tester.pumpAndSettle();

      expect(find.text('Send Help Request?'), findsOneWidget);
      await tester.tap(find.text('Confirm & Send'));
      await tester.pumpAndSettle();

      expect(captured['isSafe'], isFalse);
      expect(captured['helpType'], 'Medical');
      expect(captured['helpSubtype'], 'Injury');
      expect(captured['urgency'], 'Immediate / Life-threatening');
      expect(captured['location'], 'Near Concepcion Market, Barangka');
      expect(captured['latitude'], 14.6507);
    });
  });

  group('Help Request Flow - Evacuation Branch Submissions', () {
    testWidgets('Evacuation -> Rising floodwater requires water level and maps depth',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      Map<String, dynamic> captured = {};

      await tester.pumpWidget(_buildTestApp(
        submitHook: ({
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
          captured = {
            'isSafe': isSafe,
            'helpType': helpType,
            'helpSubtype': helpSubtype,
            'waterLevel': waterLevel,
            'floodLevel': floodLevel,
            'floodDepth': floodDepth,
          };
          return true;
        },
      ));
      await tester.pumpAndSettle();

      // Step 0: Evacuation
      await tester.tap(find.text('Evacuation'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Step 1: Evacuation reason
      expect(find.text('Evacuation Assistance'), findsOneWidget);
      await tester.tap(find.text('Floodwater is rising'));
      await tester.pumpAndSettle();

      // Try Next without selecting water level
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Please specify the estimated floodwater level.'),
          findsOneWidget);

      // Select Knee to waist
      await tester.ensureVisible(find.text('Knee to waist'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Knee to waist'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Step 2: Location
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tumana').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Step 3: Confirmation
      await tester.ensureVisible(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      await tester.tap(find.text('CONFIRM'));
      await tester.pumpAndSettle();

      expect(find.text('Send Help Request?'), findsOneWidget);
      await tester.tap(find.text('Confirm & Send'));
      await tester.pumpAndSettle();

      expect(captured['isSafe'], isFalse);
      expect(captured['helpType'], 'Evacuation');
      expect(captured['helpSubtype'], 'Floodwater is rising');
      expect(captured['waterLevel'], 'Knee to waist');
      expect(captured['floodLevel'], 'Knee to Waist');
      expect(captured['floodDepth'], 0.7);
    });

    testWidgets('Evacuation -> Vulnerable person requires person selection',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      Map<String, dynamic> captured = {};

      await tester.pumpWidget(_buildTestApp(
        submitHook: ({
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
          captured = {
            'isSafe': isSafe,
            'helpType': helpType,
            'helpSubtype': helpSubtype,
            'vulnerablePerson': vulnerablePerson,
          };
          return true;
        },
      ));
      await tester.pumpAndSettle();

      // Step 0: Evacuation
      await tester.tap(find.text('Evacuation'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Step 1: Vulnerable person
      await tester.tap(find.text('Need assistance for a vulnerable person'));
      await tester.pumpAndSettle();

      // Select Elderly person
      await tester.ensureVisible(find.text('Elderly person'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Elderly person'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Step 2: Location
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Malanday').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Step 3: Confirmation
      await tester.ensureVisible(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      await tester.tap(find.text('CONFIRM'));
      await tester.pumpAndSettle();

      expect(find.text('Send Help Request?'), findsOneWidget);
      await tester.tap(find.text('Confirm & Send'));
      await tester.pumpAndSettle();

      expect(captured['isSafe'], isFalse);
      expect(captured['helpType'], 'Evacuation');
      expect(captured['helpSubtype'], 'Need assistance for a vulnerable person');
      expect(captured['vulnerablePerson'], 'Elderly person');
    });
  });

  group('Help Request Flow - EDIT Button Navigation', () {
    testWidgets('EDIT button on Confirmation screen navigates back to Step 2',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildTestApp(
        submitHook: ({
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
        }) async => true,
      ));
      await tester.pumpAndSettle();

      // Step 0: Medical
      await tester.tap(find.text('Medical'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Step 1: Injury
      await tester.tap(find.text('Injury'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Step 2: Location
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Barangka').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Step 3: Confirmation - Verify EDIT button exists
      expect(find.text('EDIT'), findsOneWidget);
      expect(find.text('CONFIRM'), findsOneWidget);

      // Tap EDIT to go back
      await tester.tap(find.text('EDIT'));
      await tester.pumpAndSettle();

      // We should be back at Step 2 (Incident Location)
      expect(find.text('Incident Location'), findsOneWidget);
      expect(find.text('CONFIRM'), findsNothing);
      expect(find.text('Next'), findsOneWidget);
    });
  });

  group('Help Request Flow - Confirmation Modal & Clean Success State', () {
    testWidgets(
        'Modal shows branch details, Cancel preserves form, Confirm submits and shows success dialog without responder dispatch claims',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      int submitCount = 0;
      await tester.pumpWidget(_buildTestApp(
        submitHook: ({
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
          submitCount++;
          return true;
        },
      ));
      await tester.pumpAndSettle();

      // Step 0: Medical
      await tester.tap(find.text('Medical'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Step 1: Injury
      await tester.tap(find.text('Injury'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Step 2: Location
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Barangka').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Step 3: Confirmation
      // Tap legal agreement
      await tester.ensureVisible(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      // Tap CONFIRM
      await tester.ensureVisible(find.text('CONFIRM'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CONFIRM'));
      await tester.pumpAndSettle();

      // Verify modal dialog appears
      expect(find.text('Send Help Request?'), findsOneWidget);
      expect(find.text('Please review your information before sending this request to the LGU.'), findsOneWidget);
      expect(find.text('Medical:'), findsOneWidget);
      expect(find.text('Injury'), findsWidgets);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Confirm & Send'), findsOneWidget);

      // Verify Cancel keeps sheet intact and does not submit
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(submitCount, 0);
      expect(find.text('Send Help Request?'), findsNothing);
      expect(find.text('Review & Confirm Help Request'), findsOneWidget);
      expect(find.text('CONFIRM'), findsOneWidget);

      // Tap CONFIRM again
      await tester.tap(find.text('CONFIRM'));
      await tester.pumpAndSettle();

      // Tap Confirm & Send
      await tester.tap(find.text('Confirm & Send'));
      await tester.pumpAndSettle();

      expect(submitCount, 1);
      // Clean success state
      expect(find.text('Help Request Sent'), findsOneWidget);
      expect(find.text('Your request has been submitted to the LGU.'), findsOneWidget);
      // Must NOT claim responders dispatched
      expect(find.textContaining('responders dispatched'), findsNothing);
      expect(find.textContaining('help is on the way'), findsNothing);
    });
  });
}
