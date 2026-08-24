import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:floodguard_ai/screens/barangay_details_sheet.dart';

void main() {
  Future<void> pumpSheet(WidgetTester tester, Size size) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(size: size),
        child: const MaterialApp(
          home: Scaffold(
            body: BarangayDetailsSheet(
              barangayName: 'Santo Niño',
              isTaglish: false,
              isDarkMode: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('Santo Niño flood assessment sheet is content-sized',
      (tester) async {
    const size = Size(400, 800);
    await pumpSheet(tester, size);

    expect(find.text('Flood Risk Assessment'), findsOneWidget);
    expect(find.text('Station: Sto. Niño River'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final sheetSize = tester.getSize(find.byType(BarangayDetailsSheet));
    expect(sheetSize.height, lessThan(size.height * 0.70));
    expect(sheetSize.height, greaterThan(200));
  });

  testWidgets('sheet stays compact on a smaller phone', (tester) async {
    const size = Size(320, 568);
    await pumpSheet(tester, size);

    expect(find.text('Flood Risk Assessment'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final sheetSize = tester.getSize(find.byType(BarangayDetailsSheet));
    expect(sheetSize.height, lessThan(size.height * 0.85));
  });
}
