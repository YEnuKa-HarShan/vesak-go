import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // ─────────────────────────────────────────────
  //  Core palette
  // ─────────────────────────────────────────────

  static const Color primary = Color(0xFF4338CA); // indigo-700
  static const Color accent = Color(0xFFF59E0B); // amber-400

  // Glassmorphism surface tokens
  static const Color glassBase = Color(0xFFF0F2FF); // page bg
  static const Color glassSurface = Colors.white; // card fill base
  static const Color glassBorder = Color(0xFFFFFFFF); // border tint

  // Text
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);

  // Semantic
  static const Color error = Color(0xFFDC2626);
  static const Color success = Color(0xFF10B981);

  // Timeline
  static const Color timelineActive = Color(0xFF4338CA);
  static const Color timelineInactive = Color(0xFFD1D5DB);

  // Year section tints (very light, glass-friendly)
  static const Color event2026 = Color(0xFFEEF2FF); // indigo-50
  static const Color event2025 = Color(0xFFFEF3C7); // amber-50
  static const Color event2024 = Color(0xFFECFDF5); // emerald-50
  static const Color event2023 = Color(0xFFFDF2F8); // pink-50
  static const Color event2022 = Color(0xFFF5F3FF); // violet-50

  // Year accent colours (used in timeline & event headers)
  static const Color yearAccent2026 = Color(0xFF4338CA);
  static const Color yearAccent2025 = Color(0xFFF59E0B);
  static const Color yearAccent2024 = Color(0xFF10B981);
  static const Color yearAccent2023 = Color(0xFFEC4899);
  static const Color yearAccent2022 = Color(0xFF8B5CF6);

  // Ambient blob colours (background decoration)
  static const Color blobPrimary = Color(0xFF4338CA); // 12 % opacity
  static const Color blobAccent = Color(0xFFF59E0B); // 10 % opacity
  static const Color blobEmerald = Color(0xFF10B981); //  8 % opacity

  // ─────────────────────────────────────────────
  //  Background (no gradient — pure flat colour)
  // ─────────────────────────────────────────────

  static const Color background = Color(0xFFF0F2FF);
  static const Color surface = Color(0xFFFFFFFF);

  // ─────────────────────────────────────────────
  //  ThemeData
  // ─────────────────────────────────────────────

  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: background,

        colorScheme: const ColorScheme.light(
          primary: primary,
          secondary: accent,
          surface: surface,
          error: error,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: textPrimary,
          onError: Colors.white,
        ),

        // ── AppBar ──────────────────────────────────
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: textPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),

        // ── Typography ──────────────────────────────
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: textPrimary,
            letterSpacing: -0.8,
          ),
          headlineMedium: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: textPrimary,
            letterSpacing: -0.5,
          ),
          titleLarge: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
          titleMedium: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
          bodyLarge: TextStyle(fontSize: 16, color: textPrimary, height: 1.5),
          bodyMedium: TextStyle(fontSize: 14, color: textPrimary, height: 1.5),
          bodySmall: TextStyle(fontSize: 12, color: textSecondary),
          labelSmall: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: textSecondary,
            letterSpacing: 0.8,
          ),
        ),

        // ── Elevated Button ─────────────────────────
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        // ── Outlined Button ─────────────────────────
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: primary,
            side: const BorderSide(color: primary),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),

        // ── Text Button ─────────────────────────────
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: primary),
        ),

        // ── Input Decoration ────────────────────────
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withOpacity(0.70),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.5)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: primary, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: error),
          ),
          labelStyle: const TextStyle(color: textSecondary),
          hintStyle: const TextStyle(color: textSecondary),
        ),

        // ── Card ────────────────────────────────────
        cardTheme: CardThemeData(
          color: Colors.white.withOpacity(0.65),
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.white.withOpacity(0.7), width: 1),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
        ),

        // ── Chip ────────────────────────────────────
        chipTheme: ChipThemeData(
          backgroundColor: Colors.white.withOpacity(0.55),
          selectedColor: primary.withOpacity(0.12),
          labelStyle: const TextStyle(color: textPrimary),
          secondaryLabelStyle: const TextStyle(color: primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.grey.withOpacity(0.25)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4),
        ),

        // ── Divider ─────────────────────────────────
        dividerTheme: DividerThemeData(
          color: Colors.grey.withOpacity(0.20),
          thickness: 1,
        ),

        // ── FAB ─────────────────────────────────────
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
        ),

        // ── Bottom Sheet ────────────────────────────
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
        ),

        // ── Tab Bar ─────────────────────────────────
        tabBarTheme: TabBarThemeData(
          labelColor: primary,
          unselectedLabelColor: textSecondary,
          indicatorColor: primary,
          dividerColor: Colors.transparent,
          overlayColor: WidgetStateProperty.all(Colors.transparent),
        ),
      );
}
