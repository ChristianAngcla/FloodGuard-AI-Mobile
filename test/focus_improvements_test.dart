import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:floodguard_ai/services/flood_api_service.dart';
import 'package:floodguard_ai/widgets/typhoon_update_card.dart';
import 'package:floodguard_ai/widgets/floodguard_modal_dialog.dart';

void main() {
  group('TyphoonUpdateCard Tests', () {
    testWidgets('renders No Active Typhoon state correctly', (tester) async {
      final status = TyphoonStatus(
        hasActiveTyphoon: false,
        isUnavailable: false,
        title: 'Typhoon Update',
        summary:
            'No active typhoon inside the Philippine Area of Responsibility at this time.',
        updatedAt: 'Sep 28, 2026 • 11:00 AM',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TyphoonUpdateCard(
              typhoonStatus: status,
              isDarkMode: false,
              isTaglish: false,
            ),
          ),
        ),
      );

      expect(find.text('TYPHOON UPDATE'), findsOneWidget);
      expect(find.text('DOST-PAGASA'), findsOneWidget);
      expect(
        find.text(
            'No active typhoon inside the Philippine Area of Responsibility at this time.'),
        findsOneWidget,
      );
      expect(find.text('Updated: Sep 28, 2026 • 11:00 AM'), findsOneWidget);
    });

    testWidgets('renders Active Typhoon state with all parameters',
        (tester) async {
      final status = TyphoonStatus(
        hasActiveTyphoon: true,
        isUnavailable: false,
        title: 'Typhoon Update',
        summary: 'Active typhoon Surigae inside PAR.',
        name: 'Queenie',
        internationalName: 'Surigae',
        classification: 'Typhoon',
        location: '14.5°N, 128.0°E',
        maximumWinds: '120 km/h',
        movement: 'West Northwest at 20 km/h',
        heavyRainInfo: 'Heavy to intense rainfall expected over eastern areas.',
        updatedAt: 'Sep 28, 2026 • 11:00 AM',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TyphoonUpdateCard(
              typhoonStatus: status,
              isDarkMode: false,
              isTaglish: false,
            ),
          ),
        ),
      );

      expect(find.text('TYPHOON UPDATE'), findsOneWidget);
      expect(find.text('DOST-PAGASA'), findsOneWidget);
      expect(find.text('Queenie (Surigae)'), findsOneWidget);
      expect(find.text('Typhoon'), findsOneWidget);
      expect(find.text('14.5°N, 128.0°E'), findsOneWidget);
      expect(find.text('120 km/h'), findsOneWidget);
      expect(find.text('West Northwest at 20 km/h'), findsOneWidget);
      expect(
        find.text('Heavy to intense rainfall expected over eastern areas.'),
        findsOneWidget,
      );
      expect(find.text('Updated: Sep 28, 2026 • 11:00 AM'), findsOneWidget);
    });

    testWidgets('renders Unavailable state with clear PAGASA guidance',
        (tester) async {
      final status = TyphoonStatus(
        hasActiveTyphoon: false,
        isUnavailable: true,
        title: 'Typhoon Update',
        summary: 'Typhoon info unavailable.',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TyphoonUpdateCard(
              typhoonStatus: status,
              isDarkMode: false,
              isTaglish: false,
            ),
          ),
        ),
      );

      expect(
        find.text(
            'Typhoon information is temporarily unavailable. Check PAGASA for the latest weather updates.'),
        findsOneWidget,
      );
    });

    testWidgets('renders Taglish copy accurately', (tester) async {
      final status = TyphoonStatus(
        hasActiveTyphoon: false,
        isUnavailable: false,
        title: 'Typhoon Update',
        summary: 'No active typhoon inside PAR.',
        updatedAt: 'Sep 28, 2026 • 11:00 AM',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TyphoonUpdateCard(
              typhoonStatus: status,
              isDarkMode: false,
              isTaglish: true,
            ),
          ),
        ),
      );

      expect(find.text('ULAT SA BAGYO'), findsOneWidget);
      expect(
        find.text(
            'Walang aktibong bagyo sa loob ng Philippine Area of Responsibility sa kasalukuyan.'),
        findsOneWidget,
      );
      expect(find.text('Na-update: Sep 28, 2026 • 11:00 AM'), findsOneWidget);
    });
  });

  group('StayUpdatedReminderCard Tests', () {
    testWidgets('renders caution reminder when prediction is SAFE',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StayUpdatedReminderCard(
              status: 'SAFE',
              hasActiveTyphoon: false,
              isDarkMode: false,
              isTaglish: false,
            ),
          ),
        ),
      );

      expect(find.text('STAY UPDATED'), findsOneWidget);
      expect(
        find.text(
            'FloodGuard predicts a low flood risk for this forecast, but conditions can still change during a typhoon or heavy rain. Keep checking PAGASA and LGU updates and stay prepared.'),
        findsOneWidget,
      );
    });

    testWidgets('renders caution reminder when active typhoon in PAR',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StayUpdatedReminderCard(
              status: 'ALERT',
              hasActiveTyphoon: true,
              isDarkMode: false,
              isTaglish: false,
            ),
          ),
        ),
      );

      expect(find.text('STAY UPDATED'), findsOneWidget);
      expect(
        find.text(
            'A typhoon is currently inside the Philippine Area of Responsibility. Flood conditions may change as weather conditions develop. Keep checking PAGASA and LGU updates and stay prepared.'),
        findsOneWidget,
      );
    });

    testWidgets('renders Taglish reminder copy accurately', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StayUpdatedReminderCard(
              status: 'SAFE',
              hasActiveTyphoon: false,
              isDarkMode: false,
              isTaglish: true,
            ),
          ),
        ),
      );

      expect(find.text('MANATILING LIGTAS AT ALERTO'), findsOneWidget);
      expect(
        find.text(
            'Mababa ang tinatayang panganib sa baha ng FloodGuard para sa pagtatayang ito, ngunit maaaring magbago ang lagay ng panahon tuwing may bagyo o malakas na ulan. Patuloy na subaybayan ang mga anunsyo mula sa PAGASA at Marikina LGU.'),
        findsOneWidget,
      );
    });
  });

  group('Confirm & Send Button Text Alignment Tests', () {
    testWidgets('Confirm & Send button has 48px height and single line centering',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FloodGuardModalDialog(
              title: 'Confirm Help Request',
              message: 'Are you sure you want to send this help request?',
              confirmLabel: 'Confirm & Send',
              cancelLabel: 'Cancel',
              variant: FloodGuardModalVariant.warning,
            ),
          ),
        ),
      );

      final confirmFinder = find.widgetWithText(ElevatedButton, 'Confirm & Send');
      expect(confirmFinder, findsOneWidget);

      final buttonSize = tester.getSize(confirmFinder);
      expect(buttonSize.height, equals(48.0));

      final textWidget = tester.widget<Text>(find.text('Confirm & Send'));
      expect(textWidget.maxLines, equals(1));
      expect(textWidget.textAlign, equals(TextAlign.center));
    });
  });
}
