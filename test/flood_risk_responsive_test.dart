import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:floodguard_ai/widgets/flood_warning_scale.dart';
import 'package:floodguard_ai/utils/station_thresholds.dart';

void main() {
  const thresholds = StationThresholds(
    alert: 15.0,
    alarm: 16.0,
    critical: 18.0,
  );

  Widget createWidget({
    required double width,
    required double height,
    double textScale = 1.0,
    double predictedLevel = 14.5,
    String status = 'SAFE',
    bool isTaglish = false,
  }) {
    return MediaQuery(
      data: MediaQueryData(
        size: Size(width, height),
        textScaler: TextScaler.linear(textScale),
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Material(
          child: SingleChildScrollView(
            child: SizedBox(
              width: width,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      isTaglish
                          ? 'BAKIT ITO ANG BANTA NG BAHA?'
                          : 'WHY IS THIS THE FLOOD RISK?',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    FloodWarningScale(
                      predictedLevel: predictedLevel,
                      thresholds: thresholds,
                      status: status,
                      stationName: 'Sto. Niño',
                      isDarkMode: false,
                      isTaglish: isTaglish,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('FloodWarningScale Responsive Layout & No-Overlap QA Matrix', () {
    final testWidths = [320.0, 360.0, 375.0, 390.0, 412.0, 430.0, 480.0];
    final testTextScales = [1.0, 1.3, 1.5];

    for (final width in testWidths) {
      for (final scale in testTextScales) {
        testWidgets(
            'renders cleanly with NO overlap at width ${width.toInt()}px, textScale $scale',
            (tester) async {
          final height = width <= 360 ? 480.0 : 844.0;
          tester.view.physicalSize = Size(width, height);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(
            createWidget(
              width: width,
              height: height,
              textScale: scale,
              predictedLevel: 15.42,
              status: 'ALERT',
            ),
          );
          await tester.pumpAndSettle();

          // 1. Verify Zone headers are present and rendered
          expect(find.text('SAFE'), findsOneWidget);
          expect(find.text('ALERT'), findsOneWidget);
          expect(find.text('ALARM'), findsOneWidget);
          expect(find.text('CRITICAL'), findsOneWidget);

          // 2. Verify threshold boundary labels are rendered
          expect(find.text('15.00 m'), findsOneWidget);
          expect(find.text('16.00 m'), findsOneWidget);
          expect(find.text('18.00 m'), findsOneWidget);

          // 3. Verify predicted level marker text is rendered
          final markerTextFinder = find.text('15.42 m');
          expect(markerTextFinder, findsOneWidget);
          final labelFinder = find.text('Predicted Water Level');
          expect(labelFinder, findsOneWidget);

          // 4. Verify Explanation Card text is rendered
          final explanationFinder =
              find.textContaining('This is why the flood risk is ALERT');
          expect(explanationFinder, findsOneWidget);

          // 5. CRITICAL: Assert NO vertical overlap between badge and explanation card
          final badgeTextRect = tester.getRect(labelFinder);
          final explanationRect = tester.getRect(explanationFinder);

          expect(
            badgeTextRect.bottom,
            lessThan(explanationRect.top),
            reason:
                'Predicted level badge bottom (${badgeTextRect.bottom}) must be strictly above explanation card top (${explanationRect.top}) at width $width, scale $scale',
          );
        });
      }
    }

    testWidgets('Taglish copy renders cleanly without overlap at 320px with 1.3x scale',
        (tester) async {
      tester.view.physicalSize = const Size(320.0, 480.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        createWidget(
          width: 320.0,
          height: 480.0,
          textScale: 1.3,
          predictedLevel: 16.85,
          status: 'ALARM',
          isTaglish: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pagtatayang Lebel'), findsOneWidget);
      expect(find.text('BAKIT ITO ANG BANTA NG BAHA?'), findsOneWidget);

      final labelFinder = find.text('Pagtatayang Lebel');
      final explanationFinder =
          find.textContaining('Ito ang dahilan kung bakit ALARM ang panganib sa baha');
      expect(explanationFinder, findsOneWidget);

      final labelRect = tester.getRect(labelFinder);
      final explanationRect = tester.getRect(explanationFinder);

      expect(labelRect.bottom, lessThan(explanationRect.top));
    });

    testWidgets('Low water level (clamped to left edge) renders cleanly without clipping',
        (tester) async {
      tester.view.physicalSize = const Size(360.0, 640.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        createWidget(
          width: 360.0,
          height: 640.0,
          textScale: 1.0,
          predictedLevel: 11.20,
          status: 'SAFE',
        ),
      );
      await tester.pumpAndSettle();

      final markerRect = tester.getRect(find.text('11.20 m'));
      final explanationRect =
          tester.getRect(find.textContaining('This is why the flood risk is SAFE'));

      expect(markerRect.left, greaterThanOrEqualTo(16.0));
      expect(markerRect.bottom, lessThan(explanationRect.top));
    });

    testWidgets('High water level (clamped to right edge) renders cleanly without clipping',
        (tester) async {
      tester.view.physicalSize = const Size(360.0, 640.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        createWidget(
          width: 360.0,
          height: 640.0,
          textScale: 1.0,
          predictedLevel: 21.50,
          status: 'CRITICAL',
        ),
      );
      await tester.pumpAndSettle();

      final markerRect = tester.getRect(find.text('21.50 m'));
      final explanationRect =
          tester.getRect(find.textContaining('This is why the flood risk is CRITICAL'));

      expect(markerRect.right, lessThanOrEqualTo(360.0));
      expect(markerRect.bottom, lessThan(explanationRect.top));
    });
  });

  group('Forecast Card Water-Level Value Row Responsive QA (English & Tagalog)', () {
    final narrowWidths = [320.0, 360.0, 375.0, 390.0, 412.0];
    const waterLevelValue = 18.03;

    Widget buildForecastWaterLevelCard({
      required double screenWidth,
      required bool isTaglish,
      required String tagalogLabel,
      double labelFontSize = 14.0,
    }) {
      return MediaQuery(
        data: MediaQueryData(size: Size(screenWidth, 800.0)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Material(
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: screenWidth,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    key: const Key('forecast_details_card'),
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                isTaglish ? tagalogLabel : 'Predicted Water Level:',
                                style: TextStyle(
                                  fontSize: labelFontSize,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1E293B),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: constraints.maxWidth * 0.45,
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: Text(
                                  '${waterLevelValue.toStringAsFixed(2)} m',
                                  maxLines: 1,
                                  softWrap: false,
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFFDC2626),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    for (final width in narrowWidths) {
      testWidgets(
          'Water level row (18.03 m) renders without overlap/clipping in English & Tagalog at ${width.toInt()}px',
          (tester) async {
        tester.view.physicalSize = Size(width, 800.0);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        // 1. Check English
        await tester.pumpWidget(
          buildForecastWaterLevelCard(
            screenWidth: width,
            isTaglish: false,
            tagalogLabel: 'Pagtatayang Lebel ng Tubig:',
          ),
        );
        await tester.pumpAndSettle();

        final enLabelFinder = find.text('Predicted Water Level:');
        final enValueFinder = find.text('18.03 m');
        expect(enLabelFinder, findsOneWidget);
        expect(enValueFinder, findsOneWidget);

        final cardRectEn = tester.getRect(find.byKey(const Key('forecast_details_card')));
        final enLabelRect = tester.getRect(enLabelFinder);
        final enValueRect = tester.getRect(enValueFinder);

        expect(enLabelRect.right, lessThanOrEqualTo(enValueRect.left),
            reason: 'English label and 18.03 m must not overlap at width $width');
        expect(enValueRect.right, lessThanOrEqualTo(cardRectEn.right),
            reason: '18.03 m unit "m" must not clip outside card right edge at width $width');

        // 2. Toggle to Tagalog (Home Dashboard copy: Pagtatayang Lebel ng Tubig:)
        await tester.pumpWidget(
          buildForecastWaterLevelCard(
            screenWidth: width,
            isTaglish: true,
            tagalogLabel: 'Pagtatayang Lebel ng Tubig:',
          ),
        );
        await tester.pumpAndSettle();

        final tlLabelFinder = find.text('Pagtatayang Lebel ng Tubig:');
        final tlValueFinder = find.text('18.03 m');
        expect(tlLabelFinder, findsOneWidget);
        expect(tlValueFinder, findsOneWidget);

        final cardRectTl = tester.getRect(find.byKey(const Key('forecast_details_card')));
        final tlLabelRect = tester.getRect(tlLabelFinder);
        final tlValueRect = tester.getRect(tlValueFinder);

        expect(tlLabelRect.right, lessThanOrEqualTo(tlValueRect.left),
            reason: 'Tagalog label and 18.03 m must not overlap at width $width');
        expect(tlValueRect.right, lessThanOrEqualTo(cardRectTl.right),
            reason: '18.03 m unit "m" must not clip outside card right edge in Tagalog at width $width');

        // 3. Check Tagalog (Barangay Sheet / Map Popup copy: Tinatayang Lebel ng Tubig:)
        await tester.pumpWidget(
          buildForecastWaterLevelCard(
            screenWidth: width,
            isTaglish: true,
            tagalogLabel: 'Tinatayang Lebel ng Tubig:',
          ),
        );
        await tester.pumpAndSettle();

        final tlSheetLabelFinder = find.text('Tinatayang Lebel ng Tubig:');
        final tlSheetValueFinder = find.text('18.03 m');
        expect(tlSheetLabelFinder, findsOneWidget);
        expect(tlSheetValueFinder, findsOneWidget);

        final tlSheetLabelRect = tester.getRect(tlSheetLabelFinder);
        final tlSheetValueRect = tester.getRect(tlSheetValueFinder);

        expect(tlSheetLabelRect.right, lessThanOrEqualTo(tlSheetValueRect.left),
            reason: 'Tinatayang Lebel ng Tubig: and 18.03 m must not overlap at width $width');
        expect(tlSheetValueRect.right, lessThanOrEqualTo(cardRectTl.right),
            reason: '18.03 m unit "m" must not clip outside card right edge at width $width');
      });
    }
  });
}
