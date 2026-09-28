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

    testWidgets('renders Single Active Typhoon state (1 storm)',
        (tester) async {
      final status = TyphoonStatus(
        hasActiveTyphoon: true,
        activeCount: 1,
        isUnavailable: false,
        title: 'Typhoon Update',
        summary: 'Active typhoon Surigae inside PAR.',
        name: 'Queenie',
        internationalName: 'Surigae',
        classification: 'Typhoon',
        location: '14.5°N, 128.0°E',
        maximumWinds: '120 km/h',
        gustiness: 'up to 150 km/h',
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
      expect(
        find.text(
            '1 active weather system inside the Philippine Area of Responsibility.'),
        findsOneWidget,
      );
      expect(find.text('Typhoon Queenie (Surigae)'), findsOneWidget);
      expect(find.text('Typhoon'), findsOneWidget);
      expect(find.text('14.5°N, 128.0°E'), findsOneWidget);
      expect(find.text('120 km/h'), findsOneWidget);
      expect(find.text('up to 150 km/h'), findsOneWidget);
      expect(find.text('West Northwest at 20 km/h'), findsOneWidget);
      expect(
        find.text('Heavy to intense rainfall expected over eastern areas.'),
        findsOneWidget,
      );
      expect(find.text('Updated: Sep 28, 2026 • 11:00 AM'), findsOneWidget);
    });

    testWidgets(
        'renders Multiple Active Typhoons (2 storms matching mockup media_1790578433213.png)',
        (tester) async {
      final maria = TyphoonItem(
        name: 'Maria',
        displayName: 'Typhoon Maria',
        classification: 'Typhoon',
        maximumWinds: '120 km/h',
        gustiness: 'up to 150 km/h',
        movement: 'West Northwest at 15 km/h',
        heavyRainInfo: 'Moderate to heavy rain possible',
      );

      final nestor = TyphoonItem(
        name: 'Nestor',
        displayName: 'Tropical Storm Nestor',
        classification: 'Tropical Storm',
        maximumWinds: '85 km/h',
        gustiness: 'up to 105 km/h',
        movement: 'North at 20 km/h',
        heavyRainInfo: 'Light to moderate rain possible',
      );

      final status = TyphoonStatus(
        hasActiveTyphoon: true,
        activeCount: 2,
        isUnavailable: false,
        title: 'Typhoon Update',
        summary: '2 active weather systems inside PAR.',
        typhoons: [maria, nestor],
        updatedAt: 'Sep 28, 2026 • 2:39 PM',
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
            '2 active weather systems inside the Philippine Area of Responsibility.'),
        findsOneWidget,
      );

      // First sub-card (Typhoon Maria)
      expect(find.text('Typhoon Maria'), findsOneWidget);
      expect(find.text('Typhoon'), findsOneWidget);
      expect(find.text('120 km/h'), findsOneWidget);
      expect(find.text('up to 150 km/h'), findsOneWidget);
      expect(find.text('West Northwest at 15 km/h'), findsOneWidget);
      expect(find.text('Moderate to heavy rain possible'), findsOneWidget);

      // Second sub-card (Tropical Storm Nestor)
      expect(find.text('Tropical Storm Nestor'), findsOneWidget);
      expect(find.text('Tropical Storm'), findsOneWidget);
      expect(find.text('85 km/h'), findsOneWidget);
      expect(find.text('up to 105 km/h'), findsOneWidget);
      expect(find.text('North at 20 km/h'), findsOneWidget);
      expect(find.text('Light to moderate rain possible'), findsOneWidget);

      expect(find.text('Updated: Sep 28, 2026 • 2:39 PM'), findsOneWidget);
    });

    testWidgets('renders 3 Active Typhoons inside PAR', (tester) async {
      final t1 = TyphoonItem(
        name: 'Ambo',
        displayName: 'Tropical Depression Ambo',
        classification: 'Tropical Depression',
        maximumWinds: '55 km/h',
      );
      final t2 = TyphoonItem(
        name: 'Butchoy',
        displayName: 'Severe Tropical Storm Butchoy',
        classification: 'Severe Tropical Storm',
        maximumWinds: '100 km/h',
      );
      final t3 = TyphoonItem(
        name: 'Carina',
        displayName: 'Typhoon Carina',
        classification: 'Typhoon',
        maximumWinds: '140 km/h',
      );

      final status = TyphoonStatus(
        hasActiveTyphoon: true,
        activeCount: 3,
        isUnavailable: false,
        title: 'Typhoon Update',
        summary: '3 active weather systems inside PAR.',
        typhoons: [t1, t2, t3],
        updatedAt: 'Sep 28, 2026 • 5:00 PM',
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
            '3 active weather systems inside the Philippine Area of Responsibility.'),
        findsOneWidget,
      );
      expect(find.text('Tropical Depression Ambo'), findsOneWidget);
      expect(find.text('Severe Tropical Storm Butchoy'), findsOneWidget);
      expect(find.text('Typhoon Carina'), findsOneWidget);
    });

    testWidgets('omits rows when optional fields are null (no Unknown text)',
        (tester) async {
      final minimalStorm = TyphoonItem(
        name: 'Danas',
        displayName: 'Tropical Storm Danas',
        classification: 'Tropical Storm',
        location: '15.0°N, 125.0°E',
      );

      final status = TyphoonStatus(
        hasActiveTyphoon: true,
        activeCount: 1,
        isUnavailable: false,
        title: 'Typhoon Update',
        summary: '1 active weather system.',
        typhoons: [minimalStorm],
        updatedAt: 'Sep 28, 2026 • 8:00 AM',
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

      expect(find.text('Tropical Storm Danas'), findsOneWidget);
      expect(find.text('15.0°N, 125.0°E'), findsOneWidget);
      expect(find.text('Maximum Winds:'), findsNothing);
      expect(find.text('Gustiness:'), findsNothing);
      expect(find.text('Moving:'), findsNothing);
      expect(find.text('Rain Information:'), findsNothing);
      expect(find.text('Unknown'), findsNothing);
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
            'FloodGuard provides a day-to-day flood forecast. Sudden heavy rain, flash-flood conditions, and typhoon weather can change quickly. Even when the current forecast is SAFE, keep checking PAGASA and Marikina LGU updates and stay prepared.'),
        findsOneWidget,
      );
    });

    testWidgets('renders caution reminder when single active typhoon in PAR',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StayUpdatedReminderCard(
              status: 'ALERT',
              hasActiveTyphoon: true,
              activeCount: 1,
              isDarkMode: false,
              isTaglish: false,
            ),
          ),
        ),
      );

      expect(find.text('STAY UPDATED'), findsOneWidget);
      expect(
        find.text(
            'FloodGuard provides a day-to-day flood forecast. A tropical cyclone is currently inside PAR, and rain and river conditions can change quickly. Keep checking PAGASA and Marikina LGU updates and stay prepared.'),
        findsOneWidget,
      );
    });

    testWidgets('renders caution reminder when multiple active typhoons in PAR',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StayUpdatedReminderCard(
              status: 'ALARM',
              hasActiveTyphoon: true,
              activeCount: 2,
              isDarkMode: false,
              isTaglish: false,
            ),
          ),
        ),
      );

      expect(find.text('STAY UPDATED'), findsOneWidget);
      expect(
        find.text(
            'FloodGuard provides a day-to-day flood forecast. Active tropical cyclones are currently inside PAR, and rain and river conditions can change quickly. Keep checking PAGASA and Marikina LGU updates and stay prepared.'),
        findsOneWidget,
      );
    });

    testWidgets('renders Taglish reminder copy accurately for SAFE',
        (tester) async {
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
            'Araw-araw na flood forecast ang binibigay ng FloodGuard. Ang biglaang malakas na ulan, flash flood, at lagay ng bagyo ay mabilis magbago. Kahit SAFE ang kasalukuyang forecast, patuloy na subaybayan ang mga anunsyo ng PAGASA at Marikina LGU at manatiling handa.'),
        findsOneWidget,
      );
    });

    testWidgets('renders Taglish reminder copy accurately for active cyclone',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StayUpdatedReminderCard(
              status: 'SAFE',
              hasActiveTyphoon: true,
              activeCount: 2,
              isDarkMode: false,
              isTaglish: true,
            ),
          ),
        ),
      );

      expect(find.text('MANATILING LIGTAS AT ALERTO'), findsOneWidget);
      expect(
        find.text(
            'Araw-araw na flood forecast ang binibigay ng FloodGuard. May mga aktibong bagyo sa loob ng PAR ngayon, at ang ulan at antas ng ilog ay maaaring mabilis magbago. Patuloy na subaybayan ang mga anunsyo ng PAGASA at Marikina LGU at manatiling handa.'),
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

      final confirmFinder =
          find.widgetWithText(ElevatedButton, 'Confirm & Send');
      expect(confirmFinder, findsOneWidget);

      final buttonSize = tester.getSize(confirmFinder);
      expect(buttonSize.height, equals(48.0));

      final textWidget = tester.widget<Text>(find.text('Confirm & Send'));
      expect(textWidget.maxLines, equals(1));
      expect(textWidget.textAlign, equals(TextAlign.center));
    });
  });
}
