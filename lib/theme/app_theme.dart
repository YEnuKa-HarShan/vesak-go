import 'package:flutter/material.dart';

class AppTheme {
  // Buddhist Color Palette
  static const Color saffron = Color(0xFFFF8C42);
  static const Color gold = Color(0xFFFFD700);
  static const Color lotusPink = Color(0xFFFFB7C5);
  static const Color maroon = Color(0xFF800020);
  static const Color forestGreen = Color(0xFF228B22);
  static const Color navy = Color(0xFF1B2A4A);
  static const Color sand = Color(0xFFF5E6D3);
  static const Color charcoal = Color(0xFF333333);
  static const Color white = Color(0xFFFFFFFF);

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: saffron,
    scaffoldBackgroundColor: sand,
    colorScheme: const ColorScheme.light(
      primary: saffron,
      secondary: gold,
      surface: white,
      error: maroon,
      onPrimary: white,
      onSecondary: charcoal,
      onSurface: charcoal,
      onError: white,
      brightness: Brightness.light,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: navy,
      foregroundColor: white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: saffron,
        foregroundColor: white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: maroon,
        side: const BorderSide(color: maroon),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: saffron,
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: sand),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: sand),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: saffron, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: maroon),
      ),
      labelStyle: const TextStyle(color: charcoal),
      hintStyle: const TextStyle(color: Colors.grey),
    ),
    cardTheme: CardThemeData(
      color: white,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      shadowColor: Colors.black.withOpacity(0.05),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: white,
      selectedColor: saffron,
      labelStyle: const TextStyle(color: charcoal),
      secondaryLabelStyle: const TextStyle(color: white),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      shape: StadiumBorder(
        side: BorderSide(color: sand),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: sand,
      thickness: 1,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: saffron,
      foregroundColor: white,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: saffron,
      unselectedLabelColor: Colors.grey,
      indicatorColor: saffron,
    ),
  );
}
