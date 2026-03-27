import 'package:flutter/material.dart';

class AppTheme {
  // Brand Colors (Neo-Brutalist / Emergency theme)
  static const Color primary = Color(0xFFFF5252); // Vibrant Red
  static const Color secondary = Color(0xFFFFD740); // Alert Yellow
  static const Color background = Color(0xFFF4F4F4); // Off-white
  static const Color darkText = Color(0xFF1A1A1A); // Deep Black
  static const Color surface = Colors.white;

  // Sharp, brutalist border
  static const double borderWidth = 3.0;
  static const BorderRadius borderRadius = BorderRadius.all(Radius.circular(0)); // Sharp corners

  // Deep solid shadow
  static List<BoxShadow> buildShadow([Color color = darkText]) {
    return [
      BoxShadow(
        color: color,
        offset: const Offset(6, 6),
        blurRadius: 0,
        spreadRadius: 0,
      )
    ];
  }

  static ThemeData get lightTheme {
    return ThemeData(
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: secondary,
        surface: surface,
        onSurface: darkText,
      ),
      textTheme: ThemeData.light().textTheme.apply(
        bodyColor: darkText,
        displayColor: darkText,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: darkText),
        titleTextStyle: const TextStyle(
          color: darkText,
          fontSize: 24,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: darkText.withOpacity(0.5),
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: const RoundedRectangleBorder(
            borderRadius: borderRadius,
            side: BorderSide(color: darkText, width: borderWidth),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ).copyWith(
          overlayColor: MaterialStateProperty.all(darkText.withOpacity(0.1)),
        ),
      ),
      cardTheme: const CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(
          borderRadius: borderRadius,
          side: BorderSide(color: darkText, width: borderWidth),
        ),
      ),
    );
  }
}
