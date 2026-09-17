import 'package:flutter/material.dart';

class ColorTokens {
  // Modern Dark (Default)
  static const Color darkBgApp = Color(0xFF0F172A); // Slate 900
  static const Color darkBgSurface = Color(0xFF1E293B); // Slate 800
  static const Color darkBgElevated = Color(0xFF334155); // Slate 700
  static const Color darkBorderSubtle = Color(0xFF334155);
  static const Color darkTextPrimary = Color(0xFFF8FAFC); // Slate 50
  static const Color darkTextSecondary = Color(0xFF94A3B8); // Slate 400

  // Clean Light
  static const Color lightBgApp = Color(0xFFF8FAFC); // Slate 50
  static const Color lightBgSurface = Color(0xFFFFFFFF); // Pure White
  static const Color lightBgElevated = Color(0xFFF1F5F9); // Slate 100
  static const Color lightBorderSubtle = Color(0xFFE2E8F0);
  static const Color lightTextPrimary = Color(0xFF0F172A); // Slate 900
  static const Color lightTextSecondary = Color(0xFF64748B); // Slate 500

  // OLED Black
  static const Color oledBgApp = Color(0xFF000000);
  static const Color oledBgSurface = Color(0xFF0B0F17);
  static const Color oledBgElevated = Color(0xFF161E2E);
  static const Color oledBorderSubtle = Color(0xFF1E293B);
  static const Color oledTextPrimary = Color(0xFFFFFFFF);
  static const Color oledTextSecondary = Color(0xFF94A3B8);

  // Semantics & Accents
  static const Color accentPrimary = Color(0xFF6366F1); // Indigo 500
  static const Color accentSecondary = Color(0xFF818CF8); // Indigo 400
  static const Color statusActive = Color(0xFF38BDF8); // Sky 400
  static const Color statusDone = Color(0xFF22C55E); // Green 500
  static const Color statusPause = Color(0xFFF59E0B); // Amber 500
  static const Color statusError = Color(0xFFEF4444); // Red 500
}
