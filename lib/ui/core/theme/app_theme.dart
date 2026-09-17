import 'package:flutter/material.dart';
import '../../../domain/models/app_settings.dart';
import 'color_tokens.dart';

class AppTheme {
  static ThemeData getTheme(ThemeModeOption mode) {
    return switch (mode) {
      ThemeModeOption.cleanLight => lightTheme,
      ThemeModeOption.oledBlack => oledTheme,
      ThemeModeOption.modernDark => darkTheme,
    };
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'Segoe UI',
      scaffoldBackgroundColor: ColorTokens.darkBgApp,
      cardColor: ColorTokens.darkBgSurface,
      dividerColor: ColorTokens.darkBorderSubtle,
      colorScheme: const ColorScheme.dark(
        primary: ColorTokens.accentPrimary,
        secondary: ColorTokens.accentSecondary,
        surface: ColorTokens.darkBgSurface,
        error: ColorTokens.statusError,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: ColorTokens.darkBgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: ColorTokens.darkBorderSubtle),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: ColorTokens.darkBgElevated,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: ColorTokens.darkBorderSubtle),
        ),
        textStyle: const TextStyle(fontSize: 12, color: ColorTokens.darkTextPrimary),
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: 'Segoe UI',
      scaffoldBackgroundColor: ColorTokens.lightBgApp,
      cardColor: ColorTokens.lightBgSurface,
      dividerColor: ColorTokens.lightBorderSubtle,
      colorScheme: const ColorScheme.light(
        primary: ColorTokens.accentPrimary,
        secondary: ColorTokens.accentSecondary,
        surface: ColorTokens.lightBgSurface,
        error: ColorTokens.statusError,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: ColorTokens.lightBgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: ColorTokens.lightBorderSubtle),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: ColorTokens.lightBgElevated,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: ColorTokens.lightBorderSubtle),
        ),
        textStyle: const TextStyle(fontSize: 12, color: ColorTokens.lightTextPrimary),
      ),
    );
  }

  static ThemeData get oledTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'Segoe UI',
      scaffoldBackgroundColor: ColorTokens.oledBgApp,
      cardColor: ColorTokens.oledBgSurface,
      dividerColor: ColorTokens.oledBorderSubtle,
      colorScheme: const ColorScheme.dark(
        primary: ColorTokens.accentSecondary,
        secondary: ColorTokens.accentPrimary,
        surface: ColorTokens.oledBgSurface,
        error: ColorTokens.statusError,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: ColorTokens.oledBgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: ColorTokens.oledBorderSubtle),
        ),
      ),
    );
  }
}
