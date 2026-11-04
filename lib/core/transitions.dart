import 'package:flutter/material.dart';
import 'motion.dart';
import '../core/tokens.dart';

/// Pass this as a route's [RouteSettings.arguments] to request the
/// quiet cross-fade ([FadeRoute]) instead of the app's usual
/// [SoftRoute] slide-and-fade — for moments (the splash hand-off,
/// finishing onboarding) that read better as a plain reveal than a
/// lateral move.
const fadeOnlyTransition = #fadeOnlyTransition;

/// The platform accessibility flag, read without a [BuildContext] —
/// route transition *durations* are fixed at construction time
/// (inside `onGenerateRoute`, which has no context), so they can't
/// react to [Motion.reduced] the way a widget's build method can.
/// [Motion.debugReducedOverride] lets a widget test force this too,
/// so a route's own duration (not just its curve/content, which
/// `transitionsBuilder` already gates via [Motion.reduced]) also
/// collapses under a test's reduced-motion setup.
bool get _reducedPlatform =>
    Motion.debugReducedOverride ??
    WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations;

/// The app's default page transition: quiet and editorial. The
/// incoming page fades in while easing in from the right; the page
/// underneath dims very slightly and drifts left, rather than either
/// page snapping away. Under reduced motion this collapses to a
/// brief plain cross-fade instead of merely running the same slide
/// softer.
///
/// [settings] is always forwarded to the superclass so web's hash
/// routing (`/#/revenue` etc.) keeps working off [RouteSettings.name].
class SoftRoute<T> extends PageRouteBuilder<T> {
  SoftRoute({required WidgetBuilder builder, required RouteSettings settings})
    : super(
        settings: settings,
        opaque: true,
        barrierColor: AppColors.surface,
        maintainState: true,
        transitionDuration: _reducedPlatform
            ? const Duration(milliseconds: 150)
            : Motion.normal + const Duration(milliseconds: 40), // 320ms
        reverseTransitionDuration: _reducedPlatform
            ? const Duration(milliseconds: 150)
            : const Duration(milliseconds: 260),
        pageBuilder: (context, animation, secondaryAnimation) =>
            builder(context),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          if (_reducedPlatform || Motion.reduced(context)) {
            return FadeTransition(opacity: animation, child: child);
          }
          // Forward playback (push) eases with Motion.enter; playing
          // the same controller in reverse (pop) eases with
          // Motion.exit instead — mirrored on both the incoming and
          // outgoing layers below.
          final incoming = CurvedAnimation(
            parent: animation,
            curve: Motion.enter,
            reverseCurve: Motion.exit,
          );
          final outgoing = CurvedAnimation(
            parent: secondaryAnimation,
            curve: Motion.enter,
            reverseCurve: Motion.exit,
          );
          return FadeTransition(
            opacity: incoming,
            child: SlideTransition(
              position: incoming.drive(
                Tween<Offset>(begin: const Offset(0.06, 0), end: Offset.zero),
              ),
              child: FadeTransition(
                opacity: outgoing.drive(Tween<double>(begin: 1, end: 0.85)),
                child: SlideTransition(
                  position: outgoing.drive(
                    Tween<Offset>(
                      begin: Offset.zero,
                      end: const Offset(-0.03, 0),
                    ),
                  ),
                  child: child,
                ),
              ),
            ),
          );
        },
      );
}

/// A plain, quiet cross-fade — no slide — for the two moments that
/// should read as a reveal rather than a move: handing off from the
/// splash screen, and landing on Home once onboarding finishes.
class FadeRoute<T> extends PageRouteBuilder<T> {
  FadeRoute({required WidgetBuilder builder, required RouteSettings settings})
    : super(
        settings: settings,
        opaque: true,
        maintainState: true,
        transitionDuration: _reducedPlatform
            ? const Duration(milliseconds: 150)
            : Motion.slow,
        reverseTransitionDuration: _reducedPlatform
            ? const Duration(milliseconds: 150)
            : Motion.slow,
        pageBuilder: (context, animation, secondaryAnimation) =>
            builder(context),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
      );
}
