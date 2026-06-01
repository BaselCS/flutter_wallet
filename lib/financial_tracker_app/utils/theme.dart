import 'package:flutter/material.dart';

class AppTheme {
  static const Color bgColor = Color(0xFFF6F4EF);
  static const Color surfaceColor = Color(0xFFFFFFFF);
  static const Color primaryColor = Color(0xFF1F5B54);
  static const Color accentColor = Color(0xFFB84B4B);
  static const Color outlineColor = Color(0xFFD8D1C6);
  static const Color highlightColor = Color(0xFFECE6D8);
  static const Color secondarySurface = Color(0xFFE9E2D6);
  static const Color circleBg = Color(0xFFF3EFE8);

  static ThemeData buildTheme() {
    return ThemeData(
      scaffoldBackgroundColor: bgColor,
      colorScheme: ColorScheme.fromSeed(seedColor: primaryColor),
      useMaterial3: true,
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
    );
  }
}
