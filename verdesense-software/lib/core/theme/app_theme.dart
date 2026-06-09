import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  // ─── DARK THEME ────────────────────────────────────────────────────────────
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primaryRose,
        primary: AppColors.primaryRose,
        secondary: AppColors.accentRose,
        surface: AppColors.surfaceDark,
        error: AppColors.statusDanger,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: AppColors.backgroundDark,

      // Typography — Inter to match target design feel
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: const TextStyle(color: AppColors.textLight, fontWeight: FontWeight.bold),
        headlineMedium: const TextStyle(color: AppColors.textLight, fontWeight: FontWeight.w600),
        titleLarge: const TextStyle(color: AppColors.textLight, fontWeight: FontWeight.w600),
        bodyLarge: const TextStyle(color: AppColors.textLight),
        bodyMedium: const TextStyle(color: AppColors.textGrey),
      ),

      // Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryRose,
          foregroundColor: Colors.white,
          elevation: 4,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.5),
          shadowColor: AppColors.primaryRose.withValues(alpha: 0.4),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
          side: const BorderSide(color: AppColors.borderDark),
        ),
      ),

      // Input Decoration — rounded pill style from target design
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceDark,
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(50), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(50),
            borderSide: const BorderSide(color: AppColors.borderDark)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(50),
            borderSide: const BorderSide(color: AppColors.primaryRose, width: 2)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(50),
            borderSide: const BorderSide(color: AppColors.statusDanger)),
        labelStyle: const TextStyle(color: AppColors.textGrey),
        hintStyle: TextStyle(color: AppColors.textGrey.withValues(alpha: 0.6)),
        prefixIconColor: AppColors.primaryRose,
      ),

      // Card Theme
      cardTheme: CardThemeData(
        color: AppColors.surfaceDark,
        elevation: 4,
        shadowColor: Colors.black.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.borderDark, width: 1),
        ),
        margin: const EdgeInsets.only(bottom: 16),
      ),

      // Icon Theme
      iconTheme: const IconThemeData(color: AppColors.textLight),

      dividerTheme: const DividerThemeData(color: AppColors.borderDark),

      // App Bar
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.backgroundDark,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.textLight),
        titleTextStyle: TextStyle(
          color: AppColors.textLight,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
    );
  }

  // ─── LIGHT THEME ───────────────────────────────────────────────────────────
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primaryRose,
        primary: AppColors.primaryRose,
        secondary: AppColors.accentRose,
        surface: Colors.white,
        error: AppColors.statusDanger,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: AppColors.backgroundLight,

      // Typography
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.light().textTheme).copyWith(
        displayLarge: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w800),
        headlineMedium: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold),
        titleLarge: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w700),
        bodyLarge: const TextStyle(color: Color(0xFF4A2B33)),
        bodyMedium: const TextStyle(color: Color(0xFF7A5560)),
      ),

      // Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryRose,
          foregroundColor: Colors.white,
          elevation: 4,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.5),
          shadowColor: AppColors.primaryRose.withValues(alpha: 0.3),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
          side: BorderSide(color: AppColors.primaryRose.withValues(alpha: 0.4)),
        ),
      ),

      // Input Decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(50), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(50),
            borderSide: BorderSide(color: AppColors.primaryRose.withValues(alpha: 0.2))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(50),
            borderSide: const BorderSide(color: AppColors.primaryRose, width: 2)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(50),
            borderSide: const BorderSide(color: AppColors.statusDanger)),
        labelStyle: const TextStyle(color: Color(0xFF7A5560)),
        hintStyle: const TextStyle(color: Color(0xFFA38C91)),
        prefixIconColor: AppColors.primaryRose,
      ),

      // Card Theme
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 4,
        shadowColor: AppColors.primaryRose.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.primaryRose.withValues(alpha: 0.1)),
        ),
        margin: const EdgeInsets.only(bottom: 16),
      ),

      // Icon Theme
      iconTheme: const IconThemeData(color: AppColors.textDark),

      dividerTheme: DividerThemeData(color: AppColors.primaryRose.withValues(alpha: 0.15)),

      // App Bar
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.backgroundLight,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textDark),
        titleTextStyle: const TextStyle(
          color: AppColors.textDark,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
    );
  }
}
