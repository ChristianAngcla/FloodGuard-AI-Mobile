import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_map_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Keep Firebase initialization in case other features need it (like Analytics/Messaging)
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    debugPrint('Firebase Initialization Error: $e');
  }

  // Initialize notifications
  try {
    await NotificationService.initialize();
  } catch (e) {
    debugPrint('Notification Setup Error: $e');
  }

  // Check if user is already logged in
  final prefs = await SharedPreferences.getInstance();
  final bool isLoggedIn = prefs.getBool('is_logged_in') ?? false;
  final bool isDarkMode = prefs.getBool('is_dark_mode') ?? false;
  final bool isTaglish = prefs.getBool('is_taglish') ?? false;

  runApp(FloodGuardApp(
      isLoggedIn: isLoggedIn, isDarkMode: isDarkMode, isTaglish: isTaglish));
}

class FloodGuardApp extends StatelessWidget {
  final bool isLoggedIn;
  final bool isDarkMode;
  final bool isTaglish;
  const FloodGuardApp(
      {super.key,
      required this.isLoggedIn,
      required this.isDarkMode,
      required this.isTaglish});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'FloodGuard',
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      // The Map will ALWAYS be the first screen now
      home:
          HomeMapScreen(initialDarkMode: isDarkMode, initialTaglish: isTaglish),
      routes: {
        '/map': (context) => HomeMapScreen(
            initialDarkMode: isDarkMode, initialTaglish: isTaglish),
        '/signup': (context) =>
            SignupScreen(isDarkMode: isDarkMode, isTaglish: isTaglish),
        '/signin': (context) =>
            LoginScreen(isDarkMode: isDarkMode, isTaglish: isTaglish),
      },
    );
  }
}
