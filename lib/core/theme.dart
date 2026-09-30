import 'package:flutter/material.dart';

const ink = Color(0xFF17191C);
const green = Color(0xFF17191C);
const canvas = Color(0xFFFAFAF9);
const muted = Color(0xFF525963);
const line = Color(0xFFDDE0E3);
const lime = Color(0xFFF0F1F2);
const subtle = Color(0xFFF5F6F7);
const success = Color(0xFF18734B);
const warning = Color(0xFF945600);

// Apple's own San Francisco typeface, referenced by the private family
// names iOS already exposes for its system font — never bundled as
// asset files, since SF Pro's license restricts redistribution. This
// mirrors how apple.com itself styles text (`-apple-system`): Display
// for headlines set at 20pt and above, Text below that, exactly where
// Apple's own type ramp switches between the two optical sizes.
const sfProText = '.SF Pro Text';
const sfProDisplay = '.SF Pro Display';

ThemeData saathiTheme() => ThemeData(
  useMaterial3: true,
  fontFamily: sfProText,
  fontFamilyFallback: const ['NotoSansDevanagari'],
  scaffoldBackgroundColor: canvas,
  colorScheme: ColorScheme.fromSeed(
    seedColor: ink,
    primary: ink,
    surface: Colors.white,
    surfaceContainerLow: subtle,
    onSurface: ink,
  ),
  textTheme: const TextTheme(
    headlineLarge: TextStyle(
      fontFamily: sfProDisplay,
      fontSize: 42,
      fontWeight: FontWeight.w700,
      height: 1.15,
      letterSpacing: -1.5,
      color: ink,
    ),
    headlineMedium: TextStyle(
      fontFamily: sfProDisplay,
      fontSize: 30,
      fontWeight: FontWeight.w700,
      letterSpacing: -.8,
      color: ink,
    ),
    titleLarge: TextStyle(
      fontFamily: sfProDisplay,
      fontSize: 22,
      fontWeight: FontWeight.w600,
      color: ink,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: ink,
    ),
    bodyLarge: TextStyle(fontSize: 16, height: 1.5, color: muted),
    bodyMedium: TextStyle(fontSize: 14, height: 1.45, color: muted),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.all(18),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: line),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: line),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(48, 50),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 17),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(48, 50),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      side: const BorderSide(color: line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
  ),
  dividerTheme: const DividerThemeData(color: line, space: 32),
);
