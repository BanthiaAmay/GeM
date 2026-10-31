import 'package:flutter/material.dart';

/// The app's shared motion vocabulary: calm and precise, the way
/// Apple's own apps move, rather than anything bouncy or attention-
/// seeking. New animations should reach for these tokens instead of
/// inventing their own durations or curves, so the whole app moves
/// the same way.
///
/// Nothing here exceeds [emphasis] — the ceiling for a frequently
/// used path — and every curve is a plain ease, never an
/// elastic/bounce curve.
class Motion {
  Motion._();

  /// A tap's own feedback: an icon nudging into place, a small
  /// indicator sliding under a selected option. Fast enough to read
  /// as instant response rather than a separate animation.
  static const fast = Duration(milliseconds: 160);

  /// The default for most transitions: a tab's content swapping, a
  /// sheet settling, a hint fading in or out.
  static const normal = Duration(milliseconds: 280);

  /// For animations covering real distance or a larger change of
  /// state, e.g. a scroll-to spanning most of the viewport.
  static const slow = Duration(milliseconds: 450);

  /// The upper bound for anything on a frequently used path — reserved
  /// for the rare moment that deliberately wants a beat of emphasis.
  static const emphasis = Duration(milliseconds: 600);

  /// Soft ease-out: quick to start, gentle to settle. The default for
  /// anything appearing, growing, or moving into place — no bounce,
  /// no overshoot.
  static const enter = Cubic(0.22, 1, 0.36, 1);

  /// The mirror of [enter], for things leaving or shrinking away.
  static const exit = Cubic(0.4, 0, 1, 1);

  /// Soft on both ends — for elements that move back and forth (e.g.
  /// a gentle bob) or otherwise need to never look mechanical.
  static const standard = Curves.easeInOutCubic;

  /// The gap between each item in a staggered sequence (e.g. a list
  /// of cards entering one after another).
  static const staggerStep = Duration(milliseconds: 60);

  /// True when the platform/user has requested reduced motion (an
  /// accessibility setting, exposed on every platform this app runs
  /// on including web). Decorative or repeating animations —
  /// anything not tied to conveying a state change — should check
  /// this and not run at all, rather than merely running softer.
  static bool reduced(BuildContext c) =>
      debugReducedOverride ?? (MediaQuery.maybeDisableAnimationsOf(c) ?? false);

  /// Test-only escape hatch for the one place a [BuildContext] isn't
  /// available to check reduced motion: a [PageRouteBuilder]'s own
  /// `transitionDuration`, fixed at construction time inside
  /// `onGenerateRoute` (which Flutter never hands a context). Real
  /// app code must never set this — it exists only so a widget test
  /// can force route *durations*, not just their curves/content, to
  /// collapse under reduced motion. See [SoftRoute]/[FadeRoute] in
  /// `core/transitions.dart`.
  static bool? debugReducedOverride;

  /// [d] under normal conditions, or [Duration.zero] under reduced
  /// motion — for animations driven by an explicit duration (e.g.
  /// `animateTo`) rather than a widget that can be skipped outright.
  static Duration of(BuildContext c, Duration d) =>
      reduced(c) ? Duration.zero : d;
}
