import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  AppTheme
//  Single source of truth for all visual tokens.
//  Usage:  MaterialApp(theme: AppTheme.light)
// ─────────────────────────────────────────────────────────────────────────────
abstract final class AppTheme {
  // ── Brand colours ─────────────────────────────────────────────────────────
  // Main brand colours:
  // - #A07DD1 : soft purple (primary)
  // - #79DAC7 : mint green (secondary)
  static const Color primary = Color(0xFFA07DD1);
  static const Color primaryContainer = Color(0xFFB89BE0);
  static const Color secondary = Color(0xFF79DAC7);
  static const Color error = Color(0xFFB00020);
  // App background
  static const Color surface = Color(0xFFFFFCEB);
  static const Color onSurface = Color(0xFF22232A);

  // ── Status colours (used for donation status chips & map pins) ─────────────
  static const Color statusPending = Color(0xFF4E7BBE);       // Muted blue
  static const Color statusClaimed = Color(0xFFF2A451);       // Soft amber
  static const Color statusCompleted = Color(0xFF4D9A7B);     // Deep teal-green
  static const Color statusExpiringSoon = Color(0xFFC94A4A);  // Warm red

  // ── Shared shape ──────────────────────────────────────────────────────────
  static const BorderRadius radiusMd = BorderRadius.all(Radius.circular(12));
  static const BorderRadius radiusLg = BorderRadius.all(Radius.circular(20));

  // ── Light ThemeData ───────────────────────────────────────────────────────
  static ThemeData get light {
    final baseScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
      surface: surface,
      error: error,
    );
    final colorScheme = baseScheme.copyWith(
      primary: primary,
      onPrimary: Colors.white,
      primaryContainer: primaryContainer,
      secondary: secondary,
      secondaryContainer: const Color(0xFFE1DFEF),
      onSecondaryContainer: onSurface,
    );

    // Build the Inter-based text theme
    final textTheme = GoogleFonts.interTextTheme(
      ThemeData.light().textTheme,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: surface,
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: onSurface,
        centerTitle: true,
        elevation: 0.5,
        titleTextStyle: GoogleFonts.inter(
          color: onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          minimumSize: const Size.fromHeight(52),
          shape: const RoundedRectangleBorder(borderRadius: radiusMd),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: radiusMd,
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radiusMd,
          borderSide: BorderSide(color: colorScheme.outline.withValues(alpha: 0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radiusMd,
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: radiusMd,
          borderSide: BorderSide(color: colorScheme.error),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 2,
        shadowColor: Colors.black12,
        shape: const RoundedRectangleBorder(borderRadius: radiusMd),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: radiusMd),
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: GoogleFonts.inter(color: colorScheme.onInverseSurface),
      ),
    );
  }
}
