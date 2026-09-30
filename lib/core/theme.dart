import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'tokens.dart';

export 'tokens.dart';

/// The one app theme. Every Material widget the app uses inherits its
/// look from here, so feature code only overrides on purpose. Values come
/// from `tokens.dart`; the rules are in DESIGN_SYSTEM.md.
ThemeData saathiTheme() {
  const scheme = ColorScheme.light(
    primary: AppColors.ink,
    onPrimary: AppColors.surface,
    secondary: AppColors.brand,
    onSecondary: AppColors.surface,
    error: AppColors.danger,
    onError: AppColors.surface,
    surface: AppColors.surface,
    onSurface: AppColors.ink,
    onSurfaceVariant: AppColors.textSecondary,
    outline: AppColors.borderStrong,
    outlineVariant: AppColors.border,
    surfaceContainerLowest: AppColors.surface,
    surfaceContainerLow: AppColors.surfaceMuted,
    surfaceContainer: AppColors.surfaceMuted,
    surfaceContainerHigh: AppColors.surfaceMuted,
    surfaceContainerHighest: AppColors.surfaceMuted,
  );

  final pill = WidgetStatePropertyAll<OutlinedBorder>(
    const StadiumBorder(),
  );
  final label = WidgetStatePropertyAll<TextStyle>(AppText.button);

  // Keyboard/switch focus: a 3px brand ring on every button kind.
  BorderSide? focusSide(Set<WidgetState> s, BorderSide? rest) =>
      s.contains(WidgetState.focused)
      ? const BorderSide(color: AppColors.brand, width: 3)
      : rest;

  return ThemeData(
    useMaterial3: true,
    fontFamily: sfProText,
    // One fallback family per supported script (Marathi/Hindi share
    // Devanagari). Flutter tries each in order until a glyph is found,
    // so this list must cover every script in `supportedLanguages`
    // (core/models.dart) — add the new script's font here when a new
    // language is added, or its text silently falls back to whatever
    // (if anything) the OS itself ships for that script.
    fontFamilyFallback: const [
      'NotoSansDevanagari', // hi, mr
      'NotoSansBengali', // bn
      'NotoSansGujarati', // gu
      'NotoSansGurmukhi', // pa
      'NotoSansTamil', // ta
      'NotoSansTelugu', // te
      'NotoSansKannada', // kn
    ],
    scaffoldBackgroundColor: AppColors.surface,
    canvasColor: AppColors.surface,
    colorScheme: scheme,
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    splashFactory: InkRipple.splashFactory,
    // A single, calm slide-transition on every platform (including
    // low-end Android and web) rather than each platform's own
    // default — keeps page-to-page motion restrained and consistent.
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
      },
    ),
    textTheme: const TextTheme(
      displayLarge: AppText.display,
      headlineLarge: AppText.h1,
      headlineMedium: AppText.h2,
      headlineSmall: AppText.h3,
      titleLarge: AppText.h3,
      titleMedium: AppText.title,
      titleSmall: AppText.bodySmall,
      bodyLarge: AppText.body,
      bodyMedium: AppText.bodySmall,
      bodySmall: AppText.caption,
      labelLarge: AppText.button,
      labelMedium: AppText.label,
      labelSmall: AppText.label,
    ),
    iconTheme: const IconThemeData(
      size: AppIconSize.md,
      color: AppColors.ink,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpace.lg + 2,
        vertical: AppSpace.lg + 2,
      ),
      hintStyle: AppText.body.copyWith(color: AppColors.textHint),
      labelStyle: AppText.body.copyWith(color: AppColors.textSecondary),
      helperStyle: AppText.caption,
      helperMaxLines: 3,
      errorStyle: AppText.caption.copyWith(color: AppColors.danger),
      errorMaxLines: 3,
      border: OutlineInputBorder(
        borderRadius: AppRadius.input,
        borderSide: const BorderSide(color: AppColors.borderStrong),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.input,
        borderSide: const BorderSide(color: AppColors.borderStrong),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.input,
        borderSide: const BorderSide(color: AppColors.ink, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppRadius.input,
        borderSide: const BorderSide(color: AppColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: AppRadius.input,
        borderSide: const BorderSide(color: AppColors.danger, width: 1.6),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.input,
        borderSide: const BorderSide(color: AppColors.border),
      ),
    ),
    // Primary: solid ink pill.
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(
          Size(AppSize.tap, AppSize.buttonMd),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: AppSpace.xxl),
        ),
        shape: pill,
        textStyle: label,
        elevation: const WidgetStatePropertyAll(0),
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.disabled)
              ? AppColors.disabled
              : s.contains(WidgetState.pressed)
              ? AppColors.inkPressed
              : AppColors.ink,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.disabled)
              ? AppColors.surface.withValues(alpha: 0.7)
              : AppColors.surface,
        ),
        side: WidgetStateProperty.resolveWith((s) => focusSide(s, null)),
      ),
    ),
    // Secondary: outlined pill.
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(
          Size(AppSize.tap, AppSize.buttonMd),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: AppSpace.xxl),
        ),
        shape: pill,
        textStyle: label,
        elevation: const WidgetStatePropertyAll(0),
        backgroundColor: const WidgetStatePropertyAll(AppColors.surface),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.disabled)
              ? AppColors.textHint
              : AppColors.ink,
        ),
        overlayColor: WidgetStatePropertyAll(
          AppColors.ink.withValues(alpha: 0.06),
        ),
        side: WidgetStateProperty.resolveWith(
          (s) => focusSide(
            s,
            BorderSide(
              color: s.contains(WidgetState.disabled)
                  ? AppColors.border
                  : AppColors.borderStrong,
              width: 1.4,
            ),
          ),
        ),
      ),
    ),
    // Tertiary: text-only.
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(
          Size(AppSize.tap, AppSize.tap),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: AppSpace.md),
        ),
        shape: pill,
        textStyle: WidgetStatePropertyAll(
          AppText.button.copyWith(fontSize: 15),
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.disabled)
              ? AppColors.textHint
              : AppColors.ink,
        ),
        overlayColor: WidgetStatePropertyAll(
          AppColors.ink.withValues(alpha: 0.06),
        ),
        side: WidgetStateProperty.resolveWith((s) => focusSide(s, null)),
      ),
    ),
    // Icon button: 48px target, quiet hover/press wash.
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(
          Size(AppSize.tap, AppSize.tap),
        ),
        iconSize: const WidgetStatePropertyAll(AppIconSize.md),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.disabled)
              ? AppColors.textHint
              : AppColors.ink,
        ),
        overlayColor: WidgetStatePropertyAll(
          AppColors.ink.withValues(alpha: 0.08),
        ),
        side: WidgetStateProperty.resolveWith((s) => focusSide(s, null)),
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.card,
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      titleTextStyle: AppText.h3,
      contentTextStyle: AppText.body.copyWith(color: AppColors.textSecondary),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.sheet),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.ink,
      contentTextStyle: AppText.bodySmall.copyWith(color: AppColors.surface),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.input),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.border,
      thickness: 1,
      space: 1,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.brand,
      linearTrackColor: AppColors.chartTrack,
      circularTrackColor: AppColors.chartTrack,
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? AppColors.ink
            : AppColors.surface,
      ),
      checkColor: const WidgetStatePropertyAll(AppColors.surface),
      side: const BorderSide(color: AppColors.borderStrong, width: 1.6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.input,
        side: const BorderSide(color: AppColors.border),
      ),
      textStyle: AppText.body,
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: AppColors.ink,
      textColor: AppColors.ink,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      textStyle: AppText.caption.copyWith(color: AppColors.surface),
    ),
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: Colors.transparent,
      selectedIconTheme: IconThemeData(color: AppColors.brand),
      unselectedIconTheme: IconThemeData(color: AppColors.textSecondary),
    ),
  );
}
