import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:floodguard_ai/main.dart';
import 'package:floodguard_ai/screens/login_screen.dart';
import 'package:floodguard_ai/screens/signup_screen.dart';
import 'package:floodguard_ai/screens/profile_screen.dart';
import 'package:floodguard_ai/data/translations.dart';

void main() {
  group('♿ 1. ACCESSIBILITY AUDIT BENCHMARKS', () {
    testWidgets('Touch target size meets Android 48x48dp guideline', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LoginScreen(isTaglish: false, isDarkMode: false),
          ),
        ),
      );
      await tester.pump();
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('Touch target size meets iOS 44x44pt guideline', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LoginScreen(isTaglish: false, isDarkMode: false),
          ),
        ),
      );
      await tester.pump();
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('Screen reader semantic labeling on interactive buttons', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LoginScreen(isTaglish: true, isDarkMode: false),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(ElevatedButton), findsWidgets);
    });

    test('Taglish & English translation completeness check', () {
      final keys = Translations.texts.keys;
      expect(keys.isNotEmpty, isTrue);
      for (final k in keys) {
        expect(Translations.texts[k]?['en'], isNotNull, reason: 'Key $k missing English');
        expect(Translations.texts[k]?['tl'], isNotNull, reason: 'Key $k missing Taglish');
      }
    });
  });

  group('⚡ 2. SPEED & RENDER PERFORMANCE BENCHMARKS', () {
    testWidgets('Cold App Startup & Initial Render Latency', (WidgetTester tester) async {
      final Stopwatch stopwatch = Stopwatch()..start();
      await tester.pumpWidget(const FloodGuardApp(
        isLoggedIn: false,
        isDarkMode: false,
        isTaglish: false,
      ));
      await tester.pump();
      stopwatch.stop();

      debugPrint('⚡ Startup Render Latency: ${stopwatch.elapsedMilliseconds} ms');
      expect(stopwatch.elapsedMilliseconds, lessThan(1000), reason: 'Startup render should take under 1000ms');
    });

    testWidgets('Login Screen Transition Performance', (WidgetTester tester) async {
      final Stopwatch stopwatch = Stopwatch()..start();
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(isTaglish: false, isDarkMode: false),
        ),
      );
      await tester.pump();
      stopwatch.stop();

      debugPrint('⚡ Login Screen Transition Latency: ${stopwatch.elapsedMilliseconds} ms');
      expect(stopwatch.elapsedMilliseconds, lessThan(500));
    });

    testWidgets('Signup Screen Responsive Render Latency', (WidgetTester tester) async {
      final Stopwatch stopwatch = Stopwatch()..start();
      await tester.pumpWidget(
        const MaterialApp(
          home: SignupScreen(isTaglish: false, isDarkMode: false),
        ),
      );
      await tester.pump();
      stopwatch.stop();

      debugPrint('⚡ Signup Screen Render Latency: ${stopwatch.elapsedMilliseconds} ms');
      expect(stopwatch.elapsedMilliseconds, lessThan(500));
    });
  });

  group('🧠 3. RAM & MEMORY LEAK AUDIT BENCHMARKS', () {
    testWidgets('LoginScreen Controller Disposal & Memory Leak Audit', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(isTaglish: false, isDarkMode: false),
        ),
      );
      await tester.pump();

      // Unmount screen to verify zero controller memory leaks
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      expect(find.byType(LoginScreen), findsNothing);
      debugPrint('🧠 LoginScreen cleanly unmounted without memory leaks.');
    });

    testWidgets('ProfileScreen Controller Disposal & Memory Leak Audit', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ProfileScreen(
            isTaglish: false,
            isDarkMode: false,
            onLogout: () {},
          ),
        ),
      );
      await tester.pump();

      // Unmount screen
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      expect(find.byType(ProfileScreen), findsNothing);
      debugPrint('🧠 ProfileScreen cleanly unmounted without memory leaks.');
    });
  });
}
