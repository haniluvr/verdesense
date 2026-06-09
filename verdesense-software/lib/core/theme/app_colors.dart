import 'package:flutter/material.dart';

class AppColors {
  // Primary Brand Colors — Deep Maroon / Burgundy Palette
  static const Color primaryRose   = Color(0xFF9D5B65); // Muted rose/burgundy accent
  static const Color primaryDark   = Color(0xFF1A0B0E); // Main background — near-black maroon

  // Secondary/Accent
  static const Color accentRose    = Color(0xFFB87480); // Lighter rose
  static const Color accentMuted   = Color(0xFFA38C91); // Muted pinkish-grey

  // Backgrounds & Surface
  static const Color backgroundDark  = Color(0xFF1A0B0E); // Deep maroon (brand-dark)
  static const Color surfaceDark     = Color(0xFF2A161A); // Card surface (brand-card)
  static const Color borderDark      = Color(0xFF4A2B33); // Subtle border
  static const Color backgroundLight = Color(0xFFF8F0F2); // Very soft warm white
  static const Color surfaceLight    = Color(0xFFFFFFFF); // Pure white cards
  static const Color surfaceGlass    = Color(0x1AFFFFFF); // Semi-transparent white

  // Text Colors
  static const Color textLight  = Color(0xFFF3E8EA); // Warm cream-white (brand-text)
  static const Color textGrey   = Color(0xFFA38C91); // Muted pinkish-grey
  static const Color textDark   = Color(0xFF1E1218); // Near-black for light mode

  // Status Colors (keep functional colors sharp)
  static const Color statusSafe     = Color(0xFF10B981); // Emerald Green
  static const Color statusWarning  = Color(0xFFF59E0B); // Amber
  static const Color statusDanger   = Color(0xFFEF4444); // Red
  static const Color statusInactive = Color(0xFF6B7280); // Grey

  // ── Gradients ────────────────────────────────────────────────────────────
  static const LinearGradient brandGradient = LinearGradient(
    colors: [primaryRose, accentRose],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkGradient = LinearGradient(
    colors: [backgroundDark, Color(0xFF2A161A)], // Deep maroon → card maroon
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient lightGradient = LinearGradient(
    colors: [Color(0xFFFAF2F4), Color(0xFFEDD8DC)], // Soft warm off-white
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ── Backwards compat aliases (so callers of old blue names still compile) ─
  static const Color primaryBlue = primaryRose;
  static const Color accentBlue  = accentRose;
  static const Color accentCyan  = accentMuted;
}
