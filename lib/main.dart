import 'package:flutter/material.dart';
import 'screens/loading_screen.dart';

void main() {
  runApp(const PhishNetApp());
}

class PhishNetApp extends StatelessWidget {
  const PhishNetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PhishNet',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        // Blue & white scheme matching the mockup.
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7BE0),
          primary: const Color(0xFF2E7BE0),
          background: const Color(0xFFEAF1FB),
        ),
        scaffoldBackgroundColor: const Color(0xFFEAF1FB),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFEAF1FB),
          foregroundColor: Colors.black87,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2E7BE0),
            foregroundColor: Colors.white,
          ),
        ),
      ),
      // main.dart only decides the FIRST screen shown.
      // All other navigation happens inside the screens themselves.
      home: const LoadingScreen(),
    );
  }
}
