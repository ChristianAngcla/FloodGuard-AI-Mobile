import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:floodguard_ai/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpAtWidth(WidgetTester tester, double width) async {
    final view = tester.view;
    view.physicalSize = Size(width, 800);
    view.devicePixelRatio = 1.0;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);

    final previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed')) {
        return;
      }
      previousOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = previousOnError);

    await tester.pumpWidget(const FloodGuardApp(
      isLoggedIn: false,
      isDarkMode: false,
      isTaglish: false,
    ));
    await tester.pump();
    tester.takeException();
  }

  Rect rectOf(Element element) {
    final box = element.renderObject! as RenderBox;
    final topLeft = box.localToGlobal(Offset.zero);
    final bottomRight =
        box.localToGlobal(Offset(box.size.width, box.size.height));
    return Rect.fromPoints(topLeft, bottomRight);
  }

  void expectBottomLabelOnScreen(
    WidgetTester tester,
    String label,
    double width,
  ) {
    final finder = find.text(label);
    expect(finder, findsWidgets, reason: '$label missing at $width');
    final rect = finder
        .evaluate()
        .map(rectOf)
        .reduce((a, b) => a.bottom >= b.bottom ? a : b);
    expect(rect.left, greaterThanOrEqualTo(-0.5),
        reason: '$label clipped on the left at $width ($rect)');
    expect(rect.right, lessThanOrEqualTo(width + 0.5),
        reason: '$label clipped on the right at $width ($rect)');
    expect(rect.width, greaterThan(28),
        reason: '$label too narrow to read at $width ($rect)');
  }

  for (final width in <double>[360, 412, 430]) {
    testWidgets('bottom nav labels stay on screen at ${width.toInt()}px',
        (tester) async {
      await pumpAtWidth(tester, width);
      for (final label in [
        'Home',
        'Map',
        'Ask for Help',
        'Alerts',
        'My Requests',
      ]) {
        expectBottomLabelOnScreen(tester, label, width);
      }
    });
  }
}
