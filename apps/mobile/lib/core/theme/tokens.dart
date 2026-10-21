import 'package:flutter/material.dart';

abstract final class Tokens {
  static const accent = Color(0xff245c49);
  static const ink = Color(0xff173b27);
  static const muted = Color(0xff607366);
  static const border = Color(0xffdbeade);
  static const pale = Color(0xfff6f5ed);
  static const workspace = Color(0xfff6f5ed);
  static const panelBorder = Color(0xffdfeae2);
  static const rowBorder = Color(0xffbdd8c4);
  static const rowText = Color(0xff19743a);
  static const sidebar = Color(0xff104c2b);
  static const selected = Color(0xffe7eadb);
  static const badge = Color(0xffe8f5eb);
  static const badgeText = Color(0xff1e6736);
  static const badgeBorder = Color(0xffd9ecde);
  static const warning = Color(0xfff0f7dc);
  static const warningText = Color(0xff52622d);
  static const warningBorder = Color(0xffdce6c5);
  static const disabled = Color(0xfff2f5f2);
  static const disabledText = Color(0xff657569);
  static const disabledBorder = Color(0xffe1e9e3);
  static const error = Color(0xfffff6f3);
  static const errorText = Color(0xff803f2b);
  static const errorBorder = Color(0xffebd7cf);
  static const fieldBorder = Color(0xffd8e5dc);
  static const panelRadius = 13.0;
  static const buttonRadius = 10.0;
  static const rowRadius = 8.0;
  static const phonePadding = 16.0;
  static const tabletPadding = 25.0;
  static const sidebarBreakpoint = 900.0;
}

ThemeData appTheme() {
  final color = ColorScheme.fromSeed(
    seedColor: Tokens.accent,
    primary: Tokens.accent,
    secondary: Tokens.accent,
    onSecondary: Colors.white,
    onPrimary: Colors.white,
    surface: Colors.white,
    onSurface: Tokens.ink,
    error: Tokens.errorText,
  );
  final base = ThemeData(
    useMaterial3: false,
    colorScheme: color,
    scaffoldBackgroundColor: Tokens.workspace,
    fontFamily: 'Inter',
  );
  final text = base.textTheme
      .apply(bodyColor: Tokens.ink, displayColor: Tokens.ink)
      .copyWith(
        headlineLarge: const TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w600,
          color: Tokens.ink,
          letterSpacing: -1.35,
          height: 1.15,
        ),
        headlineMedium: const TextStyle(
          fontSize: 25,
          fontWeight: FontWeight.w600,
          color: Tokens.ink,
          letterSpacing: -1.125,
          height: 1.15,
        ),
        titleLarge: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: Tokens.ink,
          letterSpacing: -.8,
        ),
        titleMedium: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Tokens.ink,
          letterSpacing: -.45,
        ),
        bodyMedium: const TextStyle(
          fontSize: 13,
          color: Tokens.ink,
          height: 1.65,
        ),
        bodySmall: const TextStyle(
          fontSize: 12,
          color: Tokens.muted,
          height: 1.5,
        ),
        labelLarge: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      );
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: Tokens.fieldBorder),
  );
  return base.copyWith(
    textTheme: text.apply(fontFamily: 'Inter'),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Tokens.ink,
      elevation: 0,
      centerTitle: false,
      toolbarHeight: 68,
    ),
    dividerTheme: const DividerThemeData(
      color: Tokens.border,
      space: 24,
      thickness: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: border,
      enabledBorder: border,
      disabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: Tokens.accent, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      errorMaxLines: 3,
      labelStyle: const TextStyle(fontSize: 12, color: Color(0xff45684e)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Tokens.accent,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(0, 46),
        padding: const EdgeInsets.symmetric(horizontal: 19, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xff1a5730),
        side: const BorderSide(color: Color(0xffcbded0)),
        minimumSize: const Size(0, 46),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Tokens.accent,
        minimumSize: const Size(44, 44),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: Colors.transparent,
      selectedColor: const Color(0xffe1f0e5),
      labelStyle: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 11,
        color: Color(0xff6a8473),
      ),
      secondaryLabelStyle: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 11,
        color: Color(0xff156d32),
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: Tokens.ink,
      behavior: SnackBarBehavior.floating,
    ),
  );
}
