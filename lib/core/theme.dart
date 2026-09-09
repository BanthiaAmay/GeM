import 'package:flutter/material.dart';

const ink = Color(0xFF163E36);
const green = Color(0xFF22654C);
const canvas = Color(0xFFF6F7F2);
const muted = Color(0xFF62716B);
const line = Color(0xFFDFE5DD);
const lime = Color(0xFFE4EDB1);
ThemeData saathiTheme() => ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: canvas,
  colorScheme: ColorScheme.fromSeed(
    seedColor: green,
    primary: green,
    surface: Colors.white,
    onSurface: ink,
  ),
  textTheme: const TextTheme(
    headlineLarge: TextStyle(
      fontSize: 42,
      fontWeight: FontWeight.w700,
      height: 1.15,
      letterSpacing: -1.5,
      color: ink,
    ),
    headlineMedium: TextStyle(
      fontSize: 30,
      fontWeight: FontWeight.w700,
      letterSpacing: -.8,
      color: ink,
    ),
    titleLarge: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w600,
      color: ink,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: ink,
    ),
    bodyLarge: TextStyle(fontSize: 16, height: 1.6, color: muted),
    bodyMedium: TextStyle(fontSize: 14, height: 1.5, color: muted),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(48, 50),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      side: const BorderSide(color: line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  ),
  dividerTheme: const DividerThemeData(color: line, space: 32),
);
