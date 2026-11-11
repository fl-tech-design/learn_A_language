import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Central color palette and theme constants – 1:1 from constants.py.
class AppTheme {
  AppTheme._();

  // ── Farben (constants.py lines 46-87) ──────────────────────────
  static const Color black = Color(0xFF000000);
  static const Color grey1 = Color(0xFF262626);
  static const Color grey2 = Color(0xFF4D4D4D);
  static const Color grey3 = Color(0xFF737373);
  static const Color grey4 = Color(0xFF999999);
  static const Color grey5 = Color(0xFFBFBFBF);
  static const Color grey6 = Color(0xFFE5E5E5);

  static const Color blue1 = Color(0xFF000080);
  static const Color blue2 = Color(0xFF00008B);
  static const Color blue3 = Color(0xFF0000CD);

  static const Color green1 = Color(0xFF006400);
  static const Color green2 = Color(0xFF228B22);
  static const Color green3 = Color(0xFF00FF00);

  static const Color red1 = Color(0xFF8B0000);
  static const Color red2 = Color(0xFFFF0000);

  static const Color orange1 = Color(0xFFFFA500);
  static const Color orange2 = Color(0xFFFF4500);

  static const Color yellow1 = Color(0xFFFFD700);
  static const Color yellow2 = Color(0xFFFFF000);

  static const Color lightBlue1 = Color(0xFF87CEFA);
  static const Color lightBlue2 = Color(0xFFADD880);
  static const Color lightBlue3 = Color(0xFFB0C4DE);

  static const Color cyan1 = Color(0xFF40E0D0);
  static const Color cyan2 = Color(0xFF00FFFF);
  static const Color cyan3 = Color(0xFF7FFFD4);

  static const Color magenta1 = Color(0xFF8B008B);
  static const Color magenta2 = Color(0xFFFF00FF);

  static const Color purple1 = Color(0xFFA020F0);

  /// Primary button/label and popup background color.
  static const Color colorPrimary = Color(0xFF1CB9EC);

  /// Button press opacity.
  static const double btnDown = 0.8;

  // ── Layout-Maße (constants.py lines 90-109) ────────────────────
  static const double boxTitleHeight = 0.05;
  static const double boxBottomHeight = 0.1;
  /// Feste Mindesthöhen, damit Titel-/Bottom-Bar auch im Querformat lesbar bleiben.
  static const double titleBarMinHeight = 48.0;
  static const double bottomBarMinHeight = 72.0;
  static const double buttonHeight = 56.0;
  static const double buttonFontSize = 18.0;
  static const double contentPadding = 10.0;
  static const double contentSpacing = 8.0;

  static const double titleFontSize = 20.0;
  static const double lblFontSize = 18.0;
  static const double btnFontSize = 18.0;
  static const double infFontSize = 14.0;
  static const double smallFontSize = 12.0;

  // App version
  static const String versionNr = '1.3.0';
  static const String appTitle = 'learn A language';

  /// Platform-safe app exit (kills process on desktop, pops on mobile).
  static void closeApp() {
    if (Platform.isAndroid || Platform.isIOS) {
      SystemNavigator.pop();
    } else {
      exit(0);
    }
  }

  // ── ThemeData ─────────────────────────────────────────────────
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: grey1,
      primaryColor: colorPrimary,
      colorScheme: const ColorScheme.dark(
        primary: colorPrimary,
        secondary: colorPrimary,
        surface: grey1,
      ),
      fontFamily: 'Jura',
      appBarTheme: const AppBarTheme(
        backgroundColor: grey1,
        foregroundColor: colorPrimary,
        elevation: 0,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: colorPrimary),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorPrimary,
          side: const BorderSide(color: colorPrimary, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: colorPrimary),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: colorPrimary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }
}
