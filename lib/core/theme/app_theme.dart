import 'package:flutter/material.dart';

class AppTheme {
  // Tasarımdaki Renkler
  static const Color primary = Color(0xFF4A90E2); // Calming blue
  static const Color secondary = Color(0xFF50E3C2); // Vibrant green

  static const Color bgLight = Color(0xFFF8F9FA);
  static const Color textDark = Color(0xFF343A40);

  // Rating Renkleri
  static const Color ratingHigh = Color(0xFF28A745); // > 4.0
  static const Color ratingMedium = Color(0xFFFFC107); // 2.5 - 4.0
  static const Color ratingLow = Color(0xFFDC3545); // < 2.5

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: bgLight,
      primaryColor: primary,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        secondary: secondary,
        surface: Colors.white,
      ),
      fontFamily: 'Inter', // Eğer font eklemediysen varsayılan kullanılır
      appBarTheme: const AppBarTheme(
        backgroundColor: bgLight,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}
