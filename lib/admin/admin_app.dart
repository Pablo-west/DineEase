import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'admin_auth_gate.dart';

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    const ColorScheme scheme = ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xff1f3a5f),
      onPrimary: Colors.white,
      secondary: Color(0xffef6f6c),
      onSecondary: Colors.white,
      error: Color(0xffb42318),
      onError: Colors.white,
      surface: Color(0xfff7f4ef),
      onSurface: Color(0xff1f2430),
    );

    return MaterialApp(
      title: 'DineEase Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: scheme,
        scaffoldBackgroundColor: scheme.surface,
        canvasColor: scheme.surface,
        useMaterial3: true,
        textTheme: GoogleFonts.dmSansTextTheme().apply(
          bodyColor: scheme.onSurface,
          displayColor: scheme.onSurface,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: scheme.primary.withValues(alpha: 0.2),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: scheme.primary.withValues(alpha: 0.15),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: scheme.primary, width: 1.4),
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      home: const AdminAuthGate(),
    );
  }
}
