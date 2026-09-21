import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:floodguard_ai/widgets/flood_legend_card.dart';
import 'package:floodguard_ai/widgets/floodguard_modal_dialog.dart';
import 'package:floodguard_ai/widgets/welcome_popup.dart';

void main() {
  group('FloodLegendCard Risk Presentation Tests', () {
    testWidgets('renders Flood Risk Levels title in collapsed state',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FloodLegendCard(
              isDarkMode: false,
              isTaglish: false,
              isExpanded: false,
              onToggle: () {},
            ),
          ),
        ),
      );

      expect(find.text('Flood Risk Levels'), findsOneWidget);
    });

    testWidgets(
        'renders 4 risk levels and plain-language guidance when expanded',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FloodLegendCard(
              isDarkMode: false,
              isTaglish: false,
              isExpanded: true,
              onToggle: () {},
            ),
          ),
        ),
      );

      // Title
      expect(find.text('Flood Risk Levels'), findsOneWidget);

      // 4 Risk Levels
      expect(find.text('CRITICAL'), findsOneWidget);
      expect(find.text('ALARM'), findsOneWidget);
      expect(find.text('ALERT'), findsOneWidget);
      expect(find.text('SAFE'), findsOneWidget);

      // Plain language guidance
      expect(find.text('Critical flood risk predicted.'), findsOneWidget);
      expect(find.text('Higher flood risk predicted.'), findsOneWidget);
      expect(find.text('Early flood warning.'), findsOneWidget);
      expect(find.text('Little to no immediate flood concern.'), findsOneWidget);

      // NO misleading universal meter thresholds
      expect(find.text('≥ 18m'), findsNothing);
      expect(find.text('≥ 16m'), findsNothing);
      expect(find.text('≥ 15m'), findsNothing);
      expect(find.text('< 15m'), findsNothing);

      // Station variance disclaimer note
      expect(
        find.textContaining('Station thresholds vary (Sto. Niño, Nangka, Tumana)'),
        findsOneWidget,
      );
    });

    testWidgets('renders Taglish copy accurately when isTaglish is true',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FloodLegendCard(
              isDarkMode: false,
              isTaglish: true,
              isExpanded: true,
              onToggle: () {},
            ),
          ),
        ),
      );

      expect(find.text('Antas ng Panganib sa Baha'), findsOneWidget);
      expect(find.text('Kritikal na panganib sa baha.'), findsOneWidget);
      expect(find.text('Mababa o walang banta sa ngayon.'), findsOneWidget);
    });
  });

  group('FloodGuardModalDialog Tests', () {
    testWidgets('renders destructive modal with icon, title, message, and actions',
        (tester) async {
      bool? dialogResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  dialogResult = await FloodGuardModalDialog.show(
                    context,
                    title: 'Delete Confirmation',
                    message: 'Are you sure you want to proceed with deletion?',
                    variant: FloodGuardModalVariant.destructive,
                    confirmLabel: 'Delete',
                    cancelLabel: 'Cancel',
                  );
                },
                child: const Text('Open Modal'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      expect(find.text('Delete Confirmation'), findsOneWidget);
      expect(find.text('Are you sure you want to proceed with deletion?'),
          findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // Tap confirm
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(dialogResult, isTrue);
    });

    testWidgets('renders modal dialog with custom content widget',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FloodGuardModalDialog(
              title: 'Send Help Request?',
              message: 'Please review your information before sending this request to the LGU.',
              content: const Column(
                children: [
                  Text('Help Type: Medical'),
                  Text('Urgency: Immediate'),
                ],
              ),
              variant: FloodGuardModalVariant.warning,
              confirmLabel: 'Confirm & Send',
              cancelLabel: 'Cancel',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Send Help Request?'), findsOneWidget);
      expect(find.text('Please review your information before sending this request to the LGU.'), findsOneWidget);
      expect(find.text('Help Type: Medical'), findsOneWidget);
      expect(find.text('Urgency: Immediate'), findsOneWidget);
      expect(find.text('Confirm & Send'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });
  });

  group('WelcomePopup Flood Risk Levels Presentation Tests', () {
    testWidgets('renders Flood Risk Levels and does NOT contain universal meters',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WelcomePopup(
              isDarkMode: false,
              isTaglish: false,
              onOpenFloodMap: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Title
      expect(find.text('Flood Risk Levels'), findsOneWidget);

      // 4 Risk Levels
      expect(find.text('CRITICAL — EVACUATE'), findsOneWidget);
      expect(find.text('ALARM — PREPARE'), findsOneWidget);
      expect(find.text('ALERT — STAY ALERT'), findsOneWidget);
      expect(find.text('SAFE — LOW RISK'), findsOneWidget);

      // Descriptions
      expect(find.text('Severe risk'), findsOneWidget);
      expect(find.text('High risk'), findsOneWidget);
      expect(find.text('Moderate risk'), findsOneWidget);
      expect(find.text('Low risk'), findsOneWidget);

      // NO universal meter thresholds
      expect(find.text('≥ 18m'), findsNothing);
      expect(find.text('≥ 16m'), findsNothing);
      expect(find.text('≥ 15m'), findsNothing);
      expect(find.text('< 15m'), findsNothing);

      // Station threshold note
      expect(find.text('Note: Thresholds vary by monitoring station.'), findsOneWidget);
    });
  });
}
