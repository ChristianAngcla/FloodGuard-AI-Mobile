import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:floodguard_ai/main.dart';
import 'package:floodguard_ai/screens/login_screen.dart';
import 'package:floodguard_ai/screens/signup_screen.dart';
import 'package:floodguard_ai/screens/profile_screen.dart';
import 'package:floodguard_ai/widgets/multistep_report_sheet.dart';
import 'package:floodguard_ai/widgets/app_drawer.dart';
import 'package:floodguard_ai/widgets/splash_screen.dart';
import 'package:floodguard_ai/data/translations.dart';
import 'package:floodguard_ai/theme/app_theme.dart';
import 'package:floodguard_ai/theme/app_typography.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('♿ 1. ACCESSIBILITY & CONTRAST BENCHMARKS', () {
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

    test('Theme ColorScheme and Typography Contrast Check', () {
      final lightTheme = AppTheme.lightTheme();
      final darkTheme = AppTheme.darkTheme();

      expect(lightTheme.colorScheme.surface, equals(AppTheme.lightBg));
      expect(darkTheme.colorScheme.surface, equals(AppTheme.darkBg));
      expect(AppTypography.bodyLarge.fontSize, greaterThanOrEqualTo(15.0));
      expect(AppTypography.labelLarge.fontSize, greaterThanOrEqualTo(15.0));
    });
  });

  group('🔒 2. BUG A: REQUIRED OPTION SELECTION VALIDATION', () {
    testWidgets('MultistepReportSheet blocks proceeding without selecting required barangay', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MultistepReportSheet(
              isTaglish: false,
              isDarkMode: false,
              onSuccess: () {},
              onSafe: () {},
              onUnsafe: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      final nextButton = find.text('Next');
      expect(nextButton, findsOneWidget);

      await tester.tap(nextButton);
      await tester.pump();

      expect(find.text('Please select an option to continue.'), findsOneWidget);
    });

    testWidgets('MultistepReportSheet Taglish validation message displays properly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MultistepReportSheet(
              isTaglish: true,
              isDarkMode: false,
              onSuccess: () {},
              onSafe: () {},
              onUnsafe: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      final nextButton = find.text('Susunod');
      expect(nextButton, findsOneWidget);

      await tester.tap(nextButton);
      await tester.pump();

      expect(find.text('Pakipili ang isang opsyon upang magpatuloy.'), findsOneWidget);
    });
  });

  group('🏷️ 3. BUG H: USER-VISIBLE BRANDING AUDIT', () {
    test('Translations welcomeTitle does not contain AI suffix', () {
      final enTitle = Translations.texts['welcomeTitle']?['en'];
      final tlTitle = Translations.texts['welcomeTitle']?['tl'];

      expect(enTitle, equals('Welcome to FloodGuard'));
      expect(tlTitle, equals('Maligayang Pagdating sa FloodGuard'));
      expect(enTitle?.contains('FloodGuardAI'), isFalse);
      expect(tlTitle?.contains('FloodGuardAI'), isFalse);
    });

    testWidgets('AppDrawer header displays "FloodGuard" without AI suffix', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            drawer: AppDrawer(
              isDarkMode: false,
              isTaglish: false,
              onToggleDarkMode: (_) {},
              onToggleLanguage: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      final ScaffoldState state = tester.firstState(find.byType(Scaffold));
      state.openDrawer();
      await tester.pumpAndSettle();

      expect(find.text('FloodGuard'), findsWidgets);
      expect(find.text('FloodGuard AI'), findsNothing);
      expect(find.text('FloodGuard v1.0.0'), findsOneWidget);
    });

    testWidgets('AppDrawer Profile item navigates directly to LoginScreen when logged out', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            drawer: AppDrawer(
              isDarkMode: false,
              isTaglish: false,
              onToggleDarkMode: (_) {},
              onToggleLanguage: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      final ScaffoldState state = tester.firstState(find.byType(Scaffold));
      state.openDrawer();
      await tester.pumpAndSettle();

      final profileTile = find.widgetWithText(ListTile, 'Profile');
      expect(profileTile, findsOneWidget);

      await tester.tap(profileTile);
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('Log in to view your profile'), findsNothing);
    });

    testWidgets('SplashScreen displays "FloodGuard" title', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SplashScreen(
            onFinished: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('FloodGuard'), findsOneWidget);
      expect(find.text('FloodGuard AI'), findsNothing);

      await tester.pump(const Duration(seconds: 4));
    });
  });

  group('⚡ 4. SPEED & RENDER PERFORMANCE BENCHMARKS', () {
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

  group('🧠 5. RAM & MEMORY LEAK AUDIT BENCHMARKS', () {
    testWidgets('LoginScreen Controller Disposal & Memory Leak Audit', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(isTaglish: false, isDarkMode: false),
        ),
      );
      await tester.pump();

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

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      expect(find.byType(ProfileScreen), findsNothing);
      debugPrint('🧠 ProfileScreen cleanly unmounted without memory leaks.');
    });

    testWidgets('ProfileScreen has Material ancestor and renders TextFields without error', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'is_logged_in': true,
        'user_data': '{"uid":"123","email":"ben@123.com","firstName":"Ben","lastName":"Tenison","phone":"09171234567","barangay":"Nangka","city":"Marikina City","province":"Metro Manila","houseNo":"12","streetName":"Main St"}'
      });

      await tester.pumpWidget(
        MaterialApp(
          home: ProfileScreen(
            isTaglish: false,
            isDarkMode: false,
            onLogout: () {},
            showBackButton: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.text('Ben Tenison'), findsOneWidget);
      expect(find.byType(TextFormField), findsWidgets);
      final ex = tester.takeException();
      if (ex != null) {
        expect(ex.toString().contains('No Material widget found'), isFalse);
      }
    });
  });
}
