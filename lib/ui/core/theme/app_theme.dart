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
      brightness: Brightness.dark,
      scaffoldBackgroundColor: ColorTokens.darkBgApp,
      cardColor: ColorTokens.darkBgSurface,
      dividerColor: ColorTokens.darkBorderSubtle,
      colorScheme: const ColorScheme.dark(
        primary: ColorTokens.accentPrimary,
        surface: ColorTokens.darkBgSurface,
        error: ColorTokens.statusError,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: ColorTokens.darkBgSurface,
        elevation: 0,
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: ColorTokens.lightBgApp,
      cardColor: ColorTokens.lightBgSurface,
      dividerColor: ColorTokens.lightBorderSubtle,
      colorScheme: const ColorScheme.light(
        primary: ColorTokens.accentPrimary,
        surface: ColorTokens.lightBgSurface,
        error: ColorTokens.statusError,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: ColorTokens.lightBgSurface,
        elevation: 0,
      ),
    );
  }

  static ThemeData get oledTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: ColorTokens.oledBgApp,
      cardColor: ColorTokens.oledBgSurface,
      dividerColor: ColorTokens.oledBorderSubtle,
      colorScheme: const ColorScheme.dark(
        primary: ColorTokens.accentSecondary,
        surface: ColorTokens.oledBgSurface,
        error: ColorTokens.statusError,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: ColorTokens.oledBgSurface,
        elevation: 0,
      ),
    );
  }
}
