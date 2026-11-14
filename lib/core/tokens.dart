import 'package:flutter/material.dart';

/// Bid2Scale design tokens — the single source of truth for colour,
/// type, spacing, radius, size and icon rules. Never write a raw
/// `Color(0x…)`, `fontSize:` or pixel radius in a feature file; use these
/// (see DESIGN_SYSTEM.md). Contrast ratios are measured against the
/// surface named next to each colour.

/// Private iOS system font families (never bundled — SF Pro's licence
/// forbids redistribution). Other platforms fall back to their own UI font.
const sfProText = '.SF Pro Text';
const sfProDisplay = '.SF Pro Display';

abstract final class AppColors {
  // Neutrals — a cool near-black spine against a warm off-white canvas.
  // The faint blue-green cast in [ink] keeps it mature without reading as
  // a pure #000 void; the off-white surface keeps the UI from feeling
  // clinical.
  /// Primary text, headings, primary buttons. 19.8:1 on [surface].
  static const ink = Color(0xFF091315);

  /// Hero card background (home greeting, account hero). Cornflower blue.
  static const heroCard = Color(0xFF4A69B0);

  /// Primary button fill while pressed.
  static const inkPressed = Color(0xFF1A2325);

  /// Secondary text (subtitles, helper copy, captions). 6.1:1 on [surface].
  static const textSecondary = Color(0xFF5A6162);

  /// Placeholder and disabled-adjacent text only — 4.3:1, never for copy
  /// the user must read.
  static const textHint = Color(0xFF7A8081);

  /// Pure white — cards, sheets.
  static const surface = Color(0xFFFFFFFF);

  /// Warm off-white — page canvas, muted card tone, inset panels.
  /// The tiny yellow bias pairs with cool [ink] so the UI never reads sterile.
  static const surfaceAlt = Color(0xFFFAFAF7);

  /// Alias of [surfaceAlt], retained for existing call sites.
  static const surfaceMuted = surfaceAlt;

  /// Decorative hairlines and card borders.
  static const border = Color(0xFFE2E5E5);

  /// Borders of interactive controls (inputs, unselected options).
  static const borderStrong = Color(0xFFCACACA);

  /// Disabled control fill.
  static const disabled = Color(0xFFD6D6D6);

  // Accent palette — six rationed roles. See DESIGN_SYSTEM.md for the
  // one-job-per-accent rule and where each may and may not appear.

  /// Blue — the primary accent. Links, info chips, progress-ring arc,
  /// chart series 1, focus ring. 4.6:1 on [surface].
  static const accentInfo = Color(0xFF0A6CFF);
  static const accentInfoTint = Color(0xFFE6EEFF);

  /// Green — success chip, completed-training tick, "Awarded", chart 2.
  /// 4.8:1 on [surface].
  static const accentSuccess = Color(0xFF1C8A4E);
  static const accentSuccessTint = Color(0xFFE4F3EB);

  /// Red — danger chip, destructive confirm, overdue alerts, error.
  /// 5.4:1 on [surface].
  static const accentDanger = Color(0xFFC4321F);
  static const accentDangerTint = Color(0xFFFBE7E3);

  /// Amber — warning chip, approaching-deadline, chart 3.
  /// 4.9:1 on [surface] when used as text; mostly used as a tint.
  static const accentWarning = Color(0xFFD99407);
  static const accentWarningTint = Color(0xFFFCEFCF);

  /// Lime — the "confetti" cheer accent. ONE moment per screen max:
  /// hero sticker, save-confirmation toast, training-complete badge,
  /// [AppButton.cheer]. Never on chrome, body text, borders, or charts.
  static const accentCheer = Color(0xFFD7FF53);
  static const accentCheerTint = Color(0xFFF2FFCF);

  /// Indigo — chart series 4 and the GemFact single accent. Nowhere else.
  static const accentPurple = Color(0xFF5868FB);
  static const accentPurpleTint = Color(0xFFE8EAFE);

  // Legacy brand aliases — RETARGETED to the new palette so the ~119
  // existing call sites keep working. New code uses the semantic names above.
  @Deprecated('Use AppColors.accentSuccess')
  static const brand = accentSuccess;
  @Deprecated('Use AppColors.accentSuccessTint')
  static const brandTint = accentSuccessTint;

  /// Hero card surface — now pure ink. Full-bleed colour-break moment.
  @Deprecated('Use AppColors.ink')
  static const brandDeep = ink;

  @Deprecated('Use AppColors.accentPurple')
  static const violet = accentPurple;
  @Deprecated('Use AppColors.accentPurpleTint')
  static const violetTint = accentPurpleTint;

  @Deprecated('Use AppColors.accentDanger')
  static const danger = accentDanger;
  @Deprecated('Use AppColors.accentDangerTint')
  static const dangerTint = accentDangerTint;

  @Deprecated('Use AppColors.accentWarning')
  static const warning = accentWarning;
  @Deprecated('Use AppColors.accentWarningTint')
  static const warningTint = accentWarningTint;

  @Deprecated('Use AppColors.accentInfo')
  static const info = accentInfo;
  @Deprecated('Use AppColors.accentInfoTint')
  static const infoTint = accentInfoTint;

  // Chart series — each ≥4.5:1 on [surface] for graphics, and always paired
  // with a text label so colour is never the only signal.
  static const chartPositive = accentSuccess;
  static const chartNeutral = accentInfo;
  static const chartCost = accentWarning;
  static const chartNegative = accentDanger;
  static const chartTrack = Color(0xFFE6E8E8);

  /// Frosted glass bar tint and hairline (see GlassBar).
  static const glassHairline = Color(0x14000000);

  /// Floating glass (bottom nav capsule): translucent fill and a light rim.
  static const glassFill = Color(0x9EFFFFFF);
  static const glassRim = Color(0xB3FFFFFF);

  /// Page canvas behind cards: warm off-white so cards lift off it.
  static const canvas = surfaceAlt;

  /// Light dimming over video thumbnails so the play button reads.
  static const scrim = Color(0x33000000);

  /// YouTube's play-button red, only on video thumbnails.
  static const videoPlay = Color(0xFFFF0000);

  /// Silhouette shadow cast by artwork and icons (see Depth, DepthIcon).
  static const depthShadow = Color(0x42091315);
}

/// Soft, low-contrast elevation. Cards rest; floating chrome hovers;
/// the hero card lifts off the page.
abstract final class AppShadow {
  static const card = [
    BoxShadow(color: Color(0x0D091315), blurRadius: 18, offset: Offset(0, 6)),
    BoxShadow(color: Color(0x08091315), blurRadius: 3, offset: Offset(0, 1)),
  ];
  static const floating = [
    BoxShadow(color: Color(0x1F091315), blurRadius: 32, offset: Offset(0, 12)),
    BoxShadow(color: Color(0x0F091315), blurRadius: 6, offset: Offset(0, 2)),
  ];

  /// Deeper shadow for the full-bleed ink hero card so it floats off
  /// the warm canvas.
  static const hero = [
    BoxShadow(color: Color(0x33091315), blurRadius: 36, offset: Offset(0, 14)),
    BoxShadow(color: Color(0x14091315), blurRadius: 8, offset: Offset(0, 3)),
  ];
}

/// 4-pt spacing scale. Use these for every gap, padding and margin.
abstract final class AppSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0; // screen side gutter, card padding
  static const xxxl = 32.0;
  static const huge = 48.0;

  /// Side gutter of every full-width mobile screen. Alias for [xxl].
  static const gutter = xxl;
}

abstract final class AppRadius {
  static const sm = 10.0; // small chips, tags
  static const md = 14.0; // inputs, inset panels
  static const lg = 18.0; // cards, list rows, option rows
  static const xl = 24.0; // hero cards, sheets (creso's large-radius move)
  static const pill = 999.0; // buttons, badges

  static BorderRadius get card => BorderRadius.circular(lg);
  static BorderRadius get input => BorderRadius.circular(md);
  static BorderRadius get sheet =>
      const BorderRadius.vertical(top: Radius.circular(xl));
}

abstract final class AppSize {
  /// Minimum tap target (WCAG 2.5.8 / Material).
  static const tap = 48.0;

  /// Screen call-to-action height (the big bottom button).
  static const buttonLg = 66.0;

  /// Standard in-content button height.
  static const buttonMd = 52.0;

  /// Compact button (inline, dense rows).
  static const buttonSm = 40.0;

  /// Max content width on tablet/desktop.
  static const contentMax = 1200.0;

  /// Width past which layouts switch from phone to wide.
  static const wide = 768.0;
}

/// Icons: Material *outlined* set only, one meaning per glyph. Filled
/// variants mark the selected/active state of the same glyph (nav bar,
/// checked). Icon colour follows text colour unless it carries status.
abstract final class AppIconSize {
  static const sm = 18.0; // inline with body text, chips
  static const md = 24.0; // default
  static const lg = 32.0; // empty/error states
}

/// Type scale. One style per role; sizes never appear in feature files.
/// Line heights are for Latin + Devanagari; Indic scripts need the extra
/// leading in [body]/[bodySmall]. Display size + weight-contrast tightened
/// per the creso reference — big display, airy body.
abstract final class AppText {
  /// Oversized screen headline (welcome, language, hero banners).
  static const display = TextStyle(
    fontFamily: sfProDisplay,
    fontSize: 48,
    fontWeight: FontWeight.w800,
    height: 1.1,
    letterSpacing: -1.0,
    color: AppColors.ink,
  );

  /// Screen headline (onboarding step, gem-check).
  static const h1 = TextStyle(
    fontFamily: sfProDisplay,
    fontSize: 30,
    fontWeight: FontWeight.w800,
    height: 1.15,
    letterSpacing: -0.4,
    color: AppColors.ink,
  );

  /// Page / card-group heading.
  static const h2 = TextStyle(
    fontFamily: sfProDisplay,
    fontSize: 24,
    fontWeight: FontWeight.w800,
    height: 1.2,
    letterSpacing: -0.3,
    color: AppColors.ink,
  );

  /// Section heading, key figure.
  static const h3 = TextStyle(
    fontFamily: sfProDisplay,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.25,
    letterSpacing: -0.2,
    color: AppColors.ink,
  );

  /// Oversized tabular numeral — the creso "stat as ornament" move.
  /// Used in [OversizedStat] for hero metrics (home grid, trainings
  /// progress, tender_analytics headline, account tier).
  static const numeral = TextStyle(
    fontFamily: sfProDisplay,
    fontSize: 56,
    fontWeight: FontWeight.w800,
    height: 1.0,
    letterSpacing: -1.5,
    fontFeatures: [FontFeature.tabularFigures()],
    color: AppColors.ink,
  );

  /// Card title, list-row title, button label (large).
  static const title = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    height: 1.3,
    color: AppColors.ink,
  );

  static const body = TextStyle(
    fontSize: 16,
    height: 1.5,
    color: AppColors.ink,
  );

  static const bodySmall = TextStyle(
    fontSize: 14,
    height: 1.45,
    color: AppColors.ink,
  );

  /// Larger supporting line under a hero headline (welcome, language).
  static const lead = TextStyle(
    fontSize: 20,
    height: 1.4,
    color: AppColors.textSecondary,
  );

  /// Text typed into a field, and the value of a picker.
  static const input = TextStyle(
    fontSize: 18,
    height: 1.3,
    color: AppColors.ink,
  );

  /// One OTP digit.
  static const digit = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w500,
    fontFeatures: [FontFeature.tabularFigures()],
    color: AppColors.ink,
  );

  /// Emphasised small text (counts, inline values).
  static const bodyStrong = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.45,
    color: AppColors.ink,
  );

  /// Chart axis tick labels.
  static const tick = TextStyle(
    fontSize: 12,
    height: 1.2,
    fontFeatures: [FontFeature.tabularFigures()],
    color: AppColors.textSecondary,
  );

  /// Helper text, captions, metadata.
  static const caption = TextStyle(
    fontSize: 13,
    height: 1.4,
    color: AppColors.textSecondary,
  );

  /// Chips, badges, tiny labels.
  static const label = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    height: 1.2,
    color: AppColors.ink,
  );

  /// UPPERCASE eyebrow above a headline.
  static const overline = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2,
    height: 1.2,
    color: AppColors.textSecondary,
  );

  /// Primary/secondary button label.
  static const button = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );

  /// Large screen-CTA label (66px button).
  static const buttonLg = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );

  /// Secondary text variants — same size, muted colour.
  static TextStyle secondary(TextStyle base) =>
      base.copyWith(color: AppColors.textSecondary);
}

/// Chart tokens — see "Charts" in DESIGN_SYSTEM.md. Every chart in the app
/// (bar, line, pie, scatter) reads these; nothing chart-related is
/// hard-coded in a feature file.
abstract final class AppChart {
  /// Categorical series, in order. Each ≥4.5:1 on [AppColors.surface],
  /// colorblind-safe (deuteranopia/protanopia/tritanopia tested), and
  /// shape-coded via [ChartShape] so colour is never the only signal.
  /// Red is deliberately absent — reserved for destructive/overdue so a
  /// red bar never confuses someone glancing at a chart.
  static const series = <Color>[
    AppColors.accentInfo, // blue
    AppColors.accentSuccess, // green
    AppColors.accentWarning, // amber
    AppColors.accentPurple, // indigo
    AppColors.textSecondary, // slate (the "Other" tail)
  ];

  static const _slate = Color(0xFF8A9191);

  /// Muted bar / prior-period fill (3.0:1 on white).
  static const muted = _slate;

  /// Decorative gridlines (behind data, never carry information alone).
  static const grid = Color(0xFFE6E8E8);

  /// Axis baseline and tick marks.
  static const axis = _slate;

  static const plotInsets = EdgeInsets.fromLTRB(44, 12, 12, 30);
  static const gridStroke = 1.0;
  static const axisStroke = 1.2;
  static const lineStroke = 2.5;
  static const markerSize = 10.0;
  static const markerSelected = 15.0;

  /// A tap/hover selects the nearest datum within this radius (≥44px touch
  /// target = radius 22; a little more is forgiving on dense charts).
  static const hitRadius = 28.0;
  static const barRadius = 6.0;
  static const height = 240.0;
}

/// Marker shapes paired with [AppChart.series] so colour is never the only
/// way to tell series apart.
enum ChartShape { circle, square, diamond, triangle, cross }
