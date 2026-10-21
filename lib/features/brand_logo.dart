import 'package:flutter/material.dart';

/// Which of the three approved Bid2Scale logo assets to render.
///
/// These are the fixed brand assets — the arrow mark, wordmark, and
/// tagline are never recreated, retyped, or approximated in code.
/// Only these three PNGs (exported from the approved artwork) are
/// ever shown; pick the variant, don't touch the artwork.
enum BrandLogoVariant {
  /// Icon + wordmark + tagline. Splash, welcome, and other
  /// brand-introduction screens.
  full,

  /// Icon + wordmark, no tagline. Onboarding headers and other
  /// standard branded surfaces (anywhere with a back button).
  lockup,

  /// Icon glyph only. App icon and compact placements (e.g. a tight
  /// app-bar corner).
  mark,
}

/// The one shared logo component for the whole app. Every screen
/// that shows the Bid2Scale logo should use this widget rather
/// than reference the image assets directly, so there is a single
/// place controlling how the approved artwork is displayed.
class BrandLogo extends StatelessWidget {
  final BrandLogoVariant variant;
  final double width;

  const BrandLogo({super.key, required this.variant, required this.width});

  static const _assetFor = {
    BrandLogoVariant.full: 'assets/brand/bid2scale-logo-full.png',
    BrandLogoVariant.lockup: 'assets/brand/bid2scale-logo-lockup.png',
    BrandLogoVariant.mark: 'assets/brand/bid2scale-logo-mark.png',
  };

  @override
  Widget build(BuildContext context) => Image.asset(
    _assetFor[variant]!,
    width: width,
    fit: BoxFit.contain,
  );
}
