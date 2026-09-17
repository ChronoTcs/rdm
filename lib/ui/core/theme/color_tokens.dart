import 'package:flutter/material.dart';

/// Semantic Design Tokens for RDM Desktop
/// Supports Clean Light, Modern Dark, and OLED Black themes
class ColorTokens {
  // --- Modern Dark (Default Palette) ---
  static const Color darkBgApp = Color(0xFF0C0D12); // Deep Obsidian
  static const Color darkBgSurface = Color(0xFF161720); // Island Surface
  static const Color darkBgElevated = Color(0xFF1F212C); // Card Elevated
  static const Color darkBorderSubtle = Color(0xFF262837);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextMuted = Color(0xFF64748B);

  // --- Clean Light (Modern Minimalist Palette) ---
  static const Color lightBgApp = Color(0xFFEFF1F6); // Soft Silver Canvas
  static const Color lightBgSurface = Color(0xFFFFFFFF); // Pure White Island
  static const Color lightBgElevated = Color(0xFFF6F7FB); // Card Elevated
  static const Color lightBorderSubtle = Color(0xFFE2E6EF);
  static const Color lightTextPrimary = Color(0xFF111827);
  static const Color lightTextSecondary = Color(0xFF64748B);
  static const Color lightTextMuted = Color(0xFF94A3B8);

  // --- OLED Black ---
  static const Color oledBgApp = Color(0xFF000000);
  static const Color oledBgSurface = Color(0xFF0B0C10);
  static const Color oledBgElevated = Color(0xFF14161E);
  static const Color oledBorderSubtle = Color(0xFF1E212B);
  static const Color oledTextPrimary = Color(0xFFFFFFFF);
  static const Color oledTextSecondary = Color(0xFF94A3B8);
  static const Color oledTextMuted = Color(0xFF64748B);

  // --- Brand Accents & Gradients ---
  static const Color accentPrimary = Color(0xFF6366F1); // Electric Indigo
  static const Color accentSecondary = Color(0xFF818CF8); // Soft Indigo
  static const Color accentTertiary = Color(0xFF06B6D4); // Cyan
  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF6366F1), Color(0xFF38BDF8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient progressGradient = LinearGradient(
    colors: [Color(0xFF6366F1), Color(0xFF06B6D4)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  // --- Status Indicators ---
  static const Color statusActive = Color(0xFF38BDF8); // Sky Cyan (Downloading)
  static const Color statusDone = Color(0xFF22C55E); // Emerald Green (Completed)
  static const Color statusPause = Color(0xFFF59E0B); // Amber Gold (Paused / Expired)
  static const Color statusError = Color(0xFFEF4444); // Vivid Red (Error)

  // --- Category Accent Dots ---
  static const Color categoryCompressed = Color(0xFFF59E0B); // Amber
  static const Color categoryVideo = Color(0xFFA855F7); // Purple
  static const Color categoryAudio = Color(0xFFEC4899); // Pink
  static const Color categoryDocuments = Color(0xFF3B82F6); // Blue
  static const Color categoryPrograms = Color(0xFF06B6D4); // Cyan

  /// Resolve contextual semantic colors based on [Theme.of(context).brightness]
  static AppColorScheme of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOled = Theme.of(context).scaffoldBackgroundColor == oledBgApp;

    if (isOled) {
      return const AppColorScheme(
        canvasBg: oledBgApp,
        cardSurface: oledBgSurface,
        cardElevated: oledBgElevated,
        borderSubtle: oledBorderSubtle,
        textPrimary: oledTextPrimary,
        textSecondary: oledTextSecondary,
        textMuted: oledTextMuted,
        isDark: true,
      );
    }

    if (isDark) {
      return const AppColorScheme(
        canvasBg: darkBgApp,
        cardSurface: darkBgSurface,
        cardElevated: darkBgElevated,
        borderSubtle: darkBorderSubtle,
        textPrimary: darkTextPrimary,
        textSecondary: darkTextSecondary,
        textMuted: darkTextMuted,
        isDark: true,
      );
    }

    return const AppColorScheme(
      canvasBg: lightBgApp,
      cardSurface: lightBgSurface,
      cardElevated: lightBgElevated,
      borderSubtle: lightBorderSubtle,
      textPrimary: lightTextPrimary,
      textSecondary: lightTextSecondary,
      textMuted: lightTextMuted,
      isDark: false,
    );
  }
}

/// Resolved color scheme for instant context-aware styling
class AppColorScheme {
  const AppColorScheme({
    required this.canvasBg,
    required this.cardSurface,
    required this.cardElevated,
    required this.borderSubtle,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.isDark,
  });

  final Color canvasBg;
  Color get canvasBackground => canvasBg;
  final Color cardSurface;
  final Color cardElevated;
  final Color borderSubtle;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final bool isDark;
}
