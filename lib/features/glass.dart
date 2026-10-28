import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/tokens.dart';

/// A translucent, frosted "glass" bar in the style of iOS navigation
/// and tool bars: content scrolling underneath shows through as a
/// soft blur, tinted with a light scrim so foreground content (text,
/// buttons, icons) stays legible no matter what's behind it.
///
/// This is deliberately the *only* place blur appears in the app —
/// Apple's own HIG reserves it for chrome that sits above scrolling
/// content or a dismissable sheet (`blur-purpose`), never as
/// decoration on ordinary cards or list rows. Use [GlassBar.top] for
/// a header pinned above scrollable content and [GlassBar.bottom]
/// for an action bar pinned below it; both keep a hairline divider on
/// the edge that touches the content, matching iOS nav/tool bars.
class GlassBar extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Border border;

  const GlassBar({
    super.key,
    required this.child,
    required this.padding,
    required this.border,
  });

  factory GlassBar.top({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.fromLTRB(24, 12, 24, 14),
  }) => GlassBar(
    padding: padding,
    border: const Border(
      bottom: BorderSide(color: AppColors.glassHairline, width: 0.6),
    ),
    child: child,
  );

  factory GlassBar.bottom({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.fromLTRB(24, 14, 24, 24),
  }) => GlassBar(
    padding: padding,
    border: const Border(
      top: BorderSide(color: AppColors.glassHairline, width: 0.6),
    ),
    child: child,
  );

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    // This bar sits fixed above scrolling content, so the blur has
    // to resample every scroll frame regardless; the boundary just
    // keeps that repaint from also forcing the content around it (or
    // vice versa) to repaint.
    child: ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.78),
            border: border,
          ),
          child: child,
        ),
      ),
    ),
  );
}

/// Floating frosted capsule (the phone tab bar): everything scrolling
/// behind it is blurred, with a soft shadow so it hovers above the page.
class GlassCapsule extends StatelessWidget {
  final Widget child;
  const GlassCapsule({super.key, required this.child});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      borderRadius: BorderRadius.all(Radius.circular(AppRadius.pill)),
      boxShadow: AppShadow.floating,
    ),
    child: RepaintBoundary(
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.pill)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.sm,
              vertical: AppSpace.xs + 2,
            ),
            decoration: BoxDecoration(
              color: AppColors.glassFill,
              borderRadius: const BorderRadius.all(
                Radius.circular(AppRadius.pill),
              ),
              border: Border.all(color: AppColors.glassRim, width: 1),
            ),
            child: child,
          ),
        ),
      ),
    ),
  );
}
