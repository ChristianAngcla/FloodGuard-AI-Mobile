import 'dart:convert';

import 'package:floodguard_ai/services/location_service.dart';
import 'package:floodguard_ai/widgets/multistep_report_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

HelpRequestLocationResolver _resolver({
  bool servicesEnabled = true,
  LocationPermission permission = LocationPermission.whileInUse,
  LocationPermission? afterRequest,
  HelpRequestCoordinates coords = const HelpRequestCoordinates(
    latitude: 14.6507,
    longitude: 121.1029,
  ),
  bool throwOnCoords = false,
  List<int>? requestCounts,
  List<int>? openSettingsCounts,
}) {
  return HelpRequestLocationResolver(
    isLocationServiceEnabled: () async => servicesEnabled,
    checkPermission: () async => permission,
    requestPermission: () async {
      requestCounts?.add(1);
      return afterRequest ?? permission;
    },
    getCurrentCoordinates: () async {
      if (throwOnCoords) {
        throw Exception('gps unavailable');
      }
      return coords;
    },
    openAppSettings: () async {
      openSettingsCounts?.add(1);
      return true;
    },
  );
}

void main() {
  group('HelpRequestLocationResolver', () {
    test('permission allowed returns coordinates that can be submitted',
        () async {
      final outcome = await _resolver().resolveForSubmit();

      expect(outcome.canSubmit, isTrue);
      expect(outcome.needsOpenSettings, isFalse);
      expect(outcome.coordinates?.latitude, 14.6507);
      expect(outcome.coordinates?.longitude, 121.1029);
    });

    test('denied on first launch re-requests permission on submit', () async {
      final requests = <int>[];
      final outcome = await _resolver(
        permission: LocationPermission.denied,
        afterRequest: LocationPermission.whileInUse,
        requestCounts: requests,
      ).resolveForSubmit();

      expect(requests, isNotEmpty);
      expect(outcome.canSubmit, isTrue);
      expect(outcome.coordinates?.latitude, 14.6507);
    });

    test('permission denied does not allow submit', () async {
      final outcome = await _resolver(
        permission: LocationPermission.denied,
        afterRequest: LocationPermission.denied,
      ).resolveForSubmit();

      expect(outcome.canSubmit, isFalse);
      expect(outcome.failure, HelpRequestLocationFailure.denied);
      expect(outcome.needsOpenSettings, isFalse);
      expect(
        helpRequestLocationMessage(
          failure: outcome.failure!,
          isTaglish: false,
        ),
        kHelpRequestLocationRequiredEn,
      );
    });

    test('permanently denied requires Open Settings and does not submit',
        () async {
      final requests = <int>[];
      final outcome = await _resolver(
        permission: LocationPermission.deniedForever,
        requestCounts: requests,
      ).resolveForSubmit();

      expect(requests, isEmpty);
      expect(outcome.canSubmit, isFalse);
      expect(outcome.failure, HelpRequestLocationFailure.deniedForever);
      expect(outcome.needsOpenSettings, isTrue);
      expect(
        helpRequestLocationMessage(
          failure: outcome.failure!,
          isTaglish: false,
        ),
        kHelpRequestLocationRequiredEn,
      );
    });

    test('does not submit when GPS coordinates cannot be obtained', () async {
      final outcome = await _resolver(throwOnCoords: true).resolveForSubmit();

      expect(outcome.canSubmit, isFalse);
      expect(outcome.failure, HelpRequestLocationFailure.unavailable);
    });
  });

  group('MultistepReportSheet location gate', () {
    Future<void> completeHelpRequestForm(WidgetTester tester) async {
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nangka').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Yes'));
      await tester.pump();
      await tester.tap(find.text('No Flood'));
      await tester.pump();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Yes, I am safe'));
      await tester.pump();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }

    Future<void> pumpSheet(
      WidgetTester tester, {
      required HelpRequestLocationResolver resolver,
      HelpRequestSubmitHook? submit,
    }) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MultistepReportSheet(
              isTaglish: false,
              isDarkMode: false,
              onSuccess: () {},
              onSafe: () {},
              onUnsafe: () {},
              locationResolver: resolver,
              submitFloodReport: submit,
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('permission denied does not send the help request',
        (tester) async {
      var submitted = false;
      await pumpSheet(
        tester,
        resolver: _resolver(
          permission: LocationPermission.denied,
          afterRequest: LocationPermission.denied,
        ),
        submit: ({
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
        }) async {
          submitted = true;
          return true;
        },
      );

      await completeHelpRequestForm(tester);
      await tester.tap(find.text('Submit Report'));
      await tester.pumpAndSettle();

      expect(submitted, isFalse);
      expect(find.text(kHelpRequestLocationRequiredEn), findsOneWidget);
      expect(find.text('Open Settings'), findsNothing);
    });

    testWidgets('permanently denied shows Open Settings and does not send',
        (tester) async {
      var submitted = false;
      final openSettings = <int>[];
      await pumpSheet(
        tester,
        resolver: _resolver(
          permission: LocationPermission.deniedForever,
          openSettingsCounts: openSettings,
        ),
        submit: ({
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
        }) async {
          submitted = true;
          return true;
        },
      );

      await completeHelpRequestForm(tester);
      await tester.tap(find.text('Submit Report'));
      await tester.pumpAndSettle();

      expect(submitted, isFalse);
      expect(find.text(kHelpRequestLocationRequiredEn), findsOneWidget);
      expect(find.text('Open Settings'), findsOneWidget);

      await tester.tap(find.text('Open Settings'));
      await tester.pump();
      expect(openSettings, isNotEmpty);
    });

    testWidgets('permission allowed sends the request with GPS coordinates',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'user_data': jsonEncode({
          'uid': 'test-uid',
          'firstName': 'Test',
          'lastName': 'User',
          'phone': '09171234567',
        }),
      });

      double? sentLat;
      double? sentLng;
      var submitted = false;
      await pumpSheet(
        tester,
        resolver: _resolver(),
        submit: ({
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
        }) async {
          submitted = true;
          sentLat = latitude;
          sentLng = longitude;
          return true;
        },
      );

      await completeHelpRequestForm(tester);
      await tester.tap(find.text('Submit Report'));
      await tester.pumpAndSettle();

      expect(submitted, isTrue);
      expect(sentLat, 14.6507);
      expect(sentLng, 121.1029);
    });
  });
}
