import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'screens/loading_screen.dart';
import 'screens/reset_password_screen.dart';
import 'services/auth_service.dart';
import 'services/reset_link.dart';
import 'widgets/auth_widgets.dart';
import 'theme/app_colors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const PhishNetApp());
}

class PhishNetApp extends StatelessWidget {
  final AuthService? authService;

  const PhishNetApp({super.key, this.authService});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PhishNet',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          secondary: AppColors.highlight,
          surface: AppColors.background,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.text,
          elevation: 0,
        ),
        textTheme: const TextTheme().apply(
          bodyColor: AppColors.black,
          displayColor: AppColors.black,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
      home: LoadingScreen(authService: authService),
      // Password-reset links (see README "Password reset links") arrive as
      // route names via Flutter deep linking and open the Reset screen.
      onGenerateRoute: (settings) {
        // Opened from the hosted "Email verified" page: re-check the session
        // so a now-verified user lands on Home.
        if (settings.name?.startsWith('/email-verified') ?? false) {
          return fadeRoute(
            LoadingScreen(authService: authService, clearStack: true),
          );
        }
        final code = parseResetCode(settings.name);
        if (code == null) return null;
        return fadeRoute(
          ResetPasswordScreen(oobCode: code, authService: authService),
        );
      },
      onUnknownRoute: (_) => fadeRoute(LoadingScreen(authService: authService)),
    );
  }
}
