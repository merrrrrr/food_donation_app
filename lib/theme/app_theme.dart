import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  AppTheme
//  Single source of truth for all visual tokens.
//  Usage:  MaterialApp(theme: AppTheme.light)
// ─────────────────────────────────────────────────────────────────────────────
abstract final class AppTheme {
  // ── Brand colours ─────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF2E7D32);     // Forest green
  static const Color primaryContainer = Color(0xFFA5D6A7);
  static const Color secondary = Color(0xFFF57F17);   // Warm amber accent
  static const Color error = Color(0xFFB00020);
  static const Color surface = Color(0xFFF9FBF9);
  static const Color onSurface = Color(0xFF1B2320);

  // ── Status colours (used for donation status chips & map pins) ─────────────
  static const Color statusPending = Color(0xFF1565C0);   // Blue
  static const Color statusClaimed = Color(0xFFF57F17);   // Amber
  static const Color statusCompleted = Color(0xFF2E7D32); // Green
  static const Color statusExpiringSoon = Color(0xFFC62828); // Red

  // ── Shared shape ──────────────────────────────────────────────────────────
  static const BorderRadius radiusMd = BorderRadius.all(Radius.circular(12));
  static const BorderRadius radiusLg = BorderRadius.all(Radius.circular(20));

  // ── Light ThemeData ───────────────────────────────────────────────────────
  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
      surface: surface,
      error: error,
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
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        centerTitle: true,
        elevation: 0,
        titleTextStyle: GoogleFonts.inter(
          color: colorScheme.onPrimary,
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
