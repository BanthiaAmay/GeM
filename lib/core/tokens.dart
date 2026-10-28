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
  // Neutrals
  /// Primary text, headings, primary button fill. 18.3:1 on [surface].
  static const ink = Color(0xFF151515);

  /// Primary button fill while pressed.
  static const inkPressed = Color(0xFF3A3A3A);

  /// Secondary text (subtitles, helper copy, captions). 5.6:1 on [surface].
  static const textSecondary = Color(0xFF5F6873);

  /// Placeholder and disabled-adjacent text only — 3.2:1, never for copy
  /// the user must read.
  static const textHint = Color(0xFF8A9199);

  /// Page and card surface.
  static const surface = Color(0xFFFFFFFF);

  /// Quiet tinted surface: selected rows, chips, inset panels.
  static const surfaceMuted = Color(0xFFF5F6F4);

  /// Decorative hairlines and card borders.
  static const border = Color(0xFFE1E5E2);

  /// Borders of interactive controls (inputs, unselected options).
  static const borderStrong = Color(0xFFC9CFCB);

  /// Disabled control fill.
  static const disabled = Color(0xFFCCCCCC);

  // Brand + status. Each has a `*Tint` fill that carries its text colour
  // at ≥5:1 (chips, badges, banners).
  /// Brand green: positive state, "ready", links. 6.9:1 on [surface].
  static const brand = Color(0xFF22654C);
  static const brandTint = Color(0xFFE5F1EA);

  /// Urgent / error / destructive. 6.5:1 on [surface].
  static const danger = Color(0xFFB3261E);
  static const dangerTint = Color(0xFFFCE9E7);

  /// Caution ("needs attention"). Text on [warningTint] 5.7:1.
  static const warning = Color(0xFF8A5300);
  static const warningTint = Color(0xFFFFF1D6);

  /// Neutral information.
  static const info = Color(0xFF1F5F8B);
  static const infoTint = Color(0xFFE6F0F7);

  // Chart series — each ≥3:1 on [surface] for graphics, and always paired
  // with a text label so colour is never the only signal.
  static const chartPositive = brand;
  static const chartNeutral = Color(0xFF2B6A99);
  static const chartCost = Color(0xFFB26A00);
  static const chartNegative = danger;
  static const chartTrack = Color(0xFFE4E7E5);

  /// Frosted glass bar tint and hairline (see GlassBar).
  static const glassHairline = Color(0x14000000);

  /// Floating glass (bottom nav capsule): translucent fill and a light rim.
  static const glassFill = Color(0x9EFFFFFF);
  static const glassRim = Color(0xB3FFFFFF);

  /// Page canvas behind cards: a hair off white so cards lift off it.
  static const canvas = Color(0xFFF6F7F5);

  /// Silhouette shadow cast by artwork and icons (see Depth, DepthIcon).
  static const depthShadow = Color(0x42101C15);
}

/// Soft, low-contrast elevation. Cards rest; floating chrome hovers.
abstract final class AppShadow {
  static const card = [
    BoxShadow(color: Color(0x0D101C15), blurRadius: 18, offset: Offset(0, 6)),
    BoxShadow(color: Color(0x08101C15), blurRadius: 3, offset: Offset(0, 1)),
  ];
  static const floating = [
    BoxShadow(color: Color(0x1F101C15), blurRadius: 32, offset: Offset(0, 12)),
    BoxShadow(color: Color(0x0F101C15), blurRadius: 6, offset: Offset(0, 2)),
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

  /// Side gutter of every full-width mobile screen.
  static const gutter = 24.0;
}

abstract final class AppRadius {
  static const sm = 8.0; // small chips, tags
  static const md = 14.0; // inputs, option rows, inset panels
  static const lg = 16.0; // cards, list rows, option rows
  static const xl = 20.0; // hero cards, sheets
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
/// leading in [body]/[bodySmall].
abstract final class AppText {
  static const display = TextStyle(
    fontFamily: sfProDisplay,
    fontSize: 40,
    fontWeight: FontWeight.w800,
    height: 1.15,
    color: AppColors.ink,
  );

  /// Screen headline (onboarding step, gem-check).
  static const h1 = TextStyle(
    fontFamily: sfProDisplay,
    fontSize: 30,
    fontWeight: FontWeight.w800,
    height: 1.15,
    color: AppColors.ink,
  );

  /// Page / card-group heading.
  static const h2 = TextStyle(
    fontFamily: sfProDisplay,
    fontSize: 24,
    fontWeight: FontWeight.w800,
    height: 1.2,
    color: AppColors.ink,
  );

  /// Section heading, key figure.
  static const h3 = TextStyle(
    fontFamily: sfProDisplay,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.25,
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
  /// Categorical series, in order. All ≥5.4:1 on white (safe as a fill under
  /// white labels). Hue alone never identifies a series: each also gets a
  /// marker shape ([shapes]) and a text label/legend entry.
  static const series = <Color>[
    AppColors.brand, // green
    Color(0xFF2B6A99), // blue
    Color(0xFF9A5B00), // amber
    Color(0xFF6A4C93), // purple
    AppColors.textSecondary, // slate
  ];

  /// Muted bar / prior-period fill (3.0:1 on white).
  static const muted = Color(0xFF8A969F);

  /// Decorative gridlines (behind data, never carry information alone).
  static const grid = Color(0xFFE6EAE7);

  /// Axis baseline and tick marks.
  static const axis = Color(0xFF8A969F);

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
