import 'package:flutter_test/flutter_test.dart';
import 'package:floodguard_ai/main.dart';

void main() {
  testWidgets('FloodGuardApp builds', (WidgetTester tester) async {
    await tester.pumpWidget(const FloodGuardApp(
      isLoggedIn: false,
      isDarkMode: false,
      isTaglish: false,
    ));
    // Home map is the default route; avoid pumping forever (map timers).
    await tester.pump();
    expect(find.byType(FloodGuardApp), findsOneWidget);
  });
}
