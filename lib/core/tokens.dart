import 'package:flutter/material.dart';

/// Bid2Scale design tokens — the single source of truth for colour,
/// type, spacing, radius, size and icon rules. Never write a raw
/// `Color(0x…)`, `fontSize:` or pixel radius in a feature file; use these
/// (see DESIGN_SYSTEM.md). Contrast ratios are measured against the
/// surface named next to each colour.
///
/// Apple-inspired monochrome palette. Every historical semantic name
/// (brand, brandTint, brandDeep, violet, violetTint) is preserved so
/// feature code keeps working, but the hues collapse to black / charcoal
/// / grey. Status colours (danger, warning, info) remain, muted, for
/// meaningful system signals only — never as chrome.

/// Private iOS system font families (never bundled — SF Pro's licence
/// forbids redistribution). Other platforms fall back to their own UI font.
const sfProText = '.SF Pro Text';
const sfProDisplay = '.SF Pro Display';

abstract final class AppColors {
  // ─── Neutrals ───────────────────────────────────────────────────
  /// Primary text, headings, primary button fill — the "ink" of the
  /// interface. Apple's dark charcoal, slightly off-black for
  /// comfortable reading. 17.6:1 on [surface].
  static const ink = Color(0xFF1D1D1F);

  /// Primary button fill while pressed — one notch lighter than [ink].
  static const inkPressed = Color(0xFF424245);

  /// Secondary text (subtitles, helper copy, captions). Apple's
  /// secondary system grey. 5.3:1 on [surface].
  static const textSecondary = Color(0xFF6E6E73);

  /// Placeholder and disabled-adjacent text only — 3.6:1, never for copy
  /// the user must read.
  static const textHint = Color(0xFF86868B);

  /// Page and card surface.
  static const surface = Color(0xFFFFFFFF);

  /// Quiet tinted surface: selected rows, chips, inset panels. Apple's
  /// soft grey, barely distinguishable from [surface] but enough to
  /// group content.
  static const surfaceMuted = Color(0xFFF5F5F7);

  /// Decorative hairlines and card borders — Apple's separator grey.
  static const border = Color(0xFFD2D2D7);

  /// Borders of interactive controls (inputs, unselected options) — one
  /// step stronger than [border] for a visible edge.
  static const borderStrong = Color(0xFFA1A1A6);

  /// Disabled control fill.
  static const disabled = Color(0xFFE5E5EA);

  // ─── Brand / accent (preserved names, monochrome values) ────────
  /// Primary accent — formerly brand green, now the same ink as text so
  /// chrome reads as one monochrome system. Use for interactive accents,
  /// selection, focused state. The matching tint is [brandTint]; neither
  /// signals "positive" any more — see [success] for that.
  /// 17.6:1 on [surface].
  static const brand = Color(0xFF1D1D1F);

  /// Tinted surface paired with [brand] — featured cards, chips,
  /// selected rows. Apple's elevated-surface grey.
  static const brandTint = Color(0xFFF5F5F7);

  /// Deepest surface — the hero card / splash background. Pure black
  /// with white content on top. Replaces the old forest green.
  static const brandDeep = Color(0xFF000000);

  /// Second accent slot — previously the Find Bids violet. Now folded
  /// into the monochrome scale: same ink as [brand] so the tile reads
  /// consistently with every other quick action.
  static const violet = Color(0xFF1D1D1F);

  /// Paired tint for [violet] — slightly cooler grey so the Find Bids
  /// tile stays distinguishable from the brand tile beside it.
  static const violetTint = Color(0xFFEFEFF2);

  // ─── Status (semantic only — sparingly used) ────────────────────
  // Each has a `*Tint` fill that carries its text colour at ≥5:1 (chips,
  // badges, banners). These are the only non-grey colours in the system
  // and never appear on chrome — only on true status signals.

  /// Urgent / error / destructive. Apple system red family. 5.9:1 on [surface].
  static const danger = Color(0xFFBF1E2E);
  static const dangerTint = Color(0xFFFDECEC);

  /// Caution ("needs attention"). Apple-aligned amber. Text on
  /// [warningTint] 5.7:1.
  static const warning = Color(0xFF8A5300);
  static const warningTint = Color(0xFFFFF4E0);

  /// Neutral information — Apple system blue family.
  static const info = Color(0xFF0066CC);
  static const infoTint = Color(0xFFE6F0FA);

  /// Positive result ("ready", success). Kept as a small green signal
  /// so the one place it legitimately needs to read "safe / passed"
  /// still can — but never used on chrome.
  static const success = Color(0xFF248A3D);
  static const successTint = Color(0xFFE5F2E8);

  // ─── Chart series (monochromatic + status accents) ──────────────
  // Each ≥3:1 on [surface] for graphics; hue is never the only signal
  // (every series also gets a marker shape and a text label).
  static const chartPositive = success;
  static const chartNeutral = Color(0xFF424245);
  static const chartCost = warning;
  static const chartNegative = danger;
  static const chartTrack = Color(0xFFE5E5EA);

  /// Frosted glass bar tint and hairline (see GlassBar).
  static const glassHairline = Color(0x14000000);

  /// Floating glass (bottom nav capsule): translucent fill and a light rim.
  static const glassFill = Color(0xC7FFFFFF);
  static const glassRim = Color(0xE0FFFFFF);

  /// Page canvas behind cards — Apple's "grouped background" grey,
  /// one tone cooler than [surface] so white cards lift off it.
  static const canvas = Color(0xFFF2F2F7);

  /// Light dimming over video thumbnails so the play button reads.
  static const scrim = Color(0x33000000);

  /// YouTube's play-button red, only on video thumbnails.
  static const videoPlay = Color(0xFFFF0000);

  /// Silhouette shadow cast by artwork and icons (see Depth, DepthIcon).
  /// Neutral grey (no green tint) matches the monochrome system.
  static const depthShadow = Color(0x33000000);
}

/// Soft, low-contrast elevation. Cards rest; floating chrome hovers.
/// Apple keeps shadows restrained — just enough to lift a surface,
/// never a drop.
abstract final class AppShadow {
  static const card = [
    BoxShadow(color: Color(0x0A000000), blurRadius: 16, offset: Offset(0, 4)),
    BoxShadow(color: Color(0x05000000), blurRadius: 2, offset: Offset(0, 1)),
  ];
  static const floating = [
    BoxShadow(color: Color(0x1A000000), blurRadius: 28, offset: Offset(0, 10)),
    BoxShadow(color: Color(0x0D000000), blurRadius: 4, offset: Offset(0, 2)),
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
  static const sm = 8.0; // small chips, tags
  static const md = 12.0; // inputs, inset panels — Apple's 12pt corner
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
/// Weights lean on Apple's Display / Text pair — Display for headlines,
/// Text for anything under 20pt. Line heights are for Latin +
/// Devanagari; Indic scripts need the extra leading in [body] /
/// [bodySmall].
abstract final class AppText {
  static const display = TextStyle(
    fontFamily: sfProDisplay,
    fontSize: 44,
    fontWeight: FontWeight.w700,
    height: 1.1,
    letterSpacing: -0.5,
    color: AppColors.ink,
  );

  /// Screen headline (onboarding step, gem-check).
  static const h1 = TextStyle(
    fontFamily: sfProDisplay,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 1.15,
    letterSpacing: -0.4,
    color: AppColors.ink,
  );

  /// Page / card-group heading.
  static const h2 = TextStyle(
    fontFamily: sfProDisplay,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.3,
    color: AppColors.ink,
  );

  /// Section heading, key figure.
  static const h3 = TextStyle(
    fontFamily: sfProDisplay,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.25,
    letterSpacing: -0.2,
    color: AppColors.ink,
  );

  /// Card title, list-row title, button label (large).
  static const title = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: -0.1,
    color: AppColors.ink,
  );

  static const body = TextStyle(
    fontSize: 16,
    height: 1.45,
    color: AppColors.ink,
  );

  static const bodySmall = TextStyle(
    fontSize: 14,
    height: 1.45,
    color: AppColors.ink,
  );

  /// Larger supporting line under a hero headline (welcome, language).
  static const lead = TextStyle(
    fontSize: 19,
    height: 1.4,
    color: AppColors.textSecondary,
  );

  /// Text typed into a field, and the value of a picker.
  static const input = TextStyle(
    fontSize: 17,
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
    fontSize: 11,
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
    fontWeight: FontWeight.w600,
    height: 1.2,
    color: AppColors.ink,
  );

  /// UPPERCASE eyebrow above a headline — Apple-style tight tracking
  /// on a small caps label.
  static const overline = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.0,
    height: 1.2,
    color: AppColors.textSecondary,
  );

  /// Primary/secondary button label.
  static const button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: -0.1,
  );

  /// Large screen-CTA label (66px button).
  static const buttonLg = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: -0.1,
  );

  /// Secondary text variants — same size, muted colour.
  static TextStyle secondary(TextStyle base) =>
      base.copyWith(color: AppColors.textSecondary);
}

/// Chart tokens — see "Charts" in DESIGN_SYSTEM.md. Every chart in the app
/// (bar, line, pie, scatter) reads these; nothing chart-related is
/// hard-coded in a feature file.
///
/// Monochromatic by default — Apple's data-vis discipline. Hue returns
/// only where a series has a true status meaning (positive / negative /
/// cost).
abstract final class AppChart {
  /// Categorical series, in order. A monochrome ramp from ink down to
  /// mid-grey, with the brand accent at the head. Hue alone never
  /// identifies a series: each also gets a marker shape ([shapes]) and
  /// a text label/legend entry. All ≥4:1 on white for fills under white
  /// labels.
  static const series = <Color>[
    AppColors.ink, // near-black
    Color(0xFF424245), // charcoal
    Color(0xFF6E6E73), // slate
    Color(0xFF86868B), // mid-grey
    Color(0xFFAEAEB2), // soft grey
  ];

  static const _slate = Color(0xFF86868B);

  /// Muted bar / prior-period fill (3.0:1 on white).
  static const muted = _slate;

  /// Decorative gridlines (behind data, never carry information alone).
  static const grid = Color(0xFFE5E5EA);

  /// Axis baseline and tick marks.
  static const axis = _slate;

  static const plotInsets = EdgeInsets.fromLTRB(44, 12, 12, 30);
  static const gridStroke = 1.0;
  static const axisStroke = 1.0;
  static const lineStroke = 2.0;
  static const markerSize = 8.0;
  static const markerSelected = 13.0;

  /// A tap/hover selects the nearest datum within this radius (≥44px touch
  /// target = radius 22; a little more is forgiving on dense charts).
  static const hitRadius = 28.0;
  static const barRadius = 4.0;
  static const height = 240.0;
}

/// Marker shapes paired with [AppChart.series] so colour is never the only
/// way to tell series apart.
enum ChartShape { circle, square, diamond, triangle, cross }
