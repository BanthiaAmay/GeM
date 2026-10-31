import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/tokens.dart';
import 'brand_logo.dart';
import 'components.dart';

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

/// The compact top bar for onboarding-style screens: one 48pt row (back
/// button, the logo sized to the row, a balancing gap) on frosted glass,
/// with an optional [bottom] (e.g. the progress bar) right under it. Keeps
/// the header short so the question starts high on the screen.
class AppTopBar extends StatelessWidget {
  final VoidCallback? onBack;
  final String backTooltip;
  final Widget? bottom;
  const AppTopBar({
    super.key,
    required this.onBack,
    required this.backTooltip,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) => GlassBar.top(
    padding: EdgeInsets.fromLTRB(
      AppSpace.sm,
      AppSpace.xs,
      AppSpace.lg,
      bottom == null ? AppSpace.xs : AppSpace.md,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (onBack != null)
              AppIconButton(
                onPressed: onBack,
                icon: Icons.arrow_back_ios_new,
                tooltip: backTooltip,
              )
            else
              const SizedBox(width: AppSize.tap),
            const Expanded(
              child: Center(
                child: BrandLogo(variant: BrandLogoVariant.lockup, width: 68),
              ),
            ),
            const SizedBox(width: AppSize.tap),
          ],
        ),
        if (bottom != null) ...[
          const SizedBox(height: AppSpace.sm),
          Padding(
            padding: const EdgeInsets.only(left: AppSpace.sm),
            child: bottom,
          ),
        ],
      ],
    ),
  );
}

/// The bottom action of a screen (Continue, Get started…) as a floating
/// pill: no bar, no divider line behind it — only the button, lifted by a
/// soft shadow, the same way the Home tab capsule floats.
class FloatingActionArea extends StatelessWidget {
  final Widget child;

  /// Shadow under a pill-shaped child; off for a child that isn't one pill.
  final bool elevated;
  const FloatingActionArea({
    super.key,
    required this.child,
    this.elevated = true,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpace.xxl,
      AppSpace.sm,
      AppSpace.xxl,
      AppSpace.md,
    ),
    child: elevated
        ? DecoratedBox(
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.all(Radius.circular(AppRadius.pill)),
              boxShadow: AppShadow.floating,
            ),
            child: child,
          )
        : child,
  );
}
