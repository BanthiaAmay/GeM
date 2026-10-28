import 'package:flutter/material.dart';
import '../core/motion.dart';
import '../core/tokens.dart';

/// Wraps a scrollable screen body and shows a subtle "there's more
/// below" cue — a soft white fade at the bottom edge plus a gently
/// bobbing, tappable chevron — whenever the content extends past the
/// visible area. Tapping the chevron scrolls further down. Both the
/// fade and the chevron disappear once the user has scrolled to the
/// bottom, and never appear at all if the content already fits.
///
/// This mirrors the fade-and-arrow scroll cue Apple uses on long
/// marketing pages (apple.com) rather than anything invented here —
/// a soft edge fade signals cut-off content, and a bobbing chevron
/// signals which direction to move (and now doubles as a button).
///
/// [builder] receives the [ScrollController] this widget owns — hand
/// it straight to the scrollable underneath (e.g.
/// `SingleChildScrollView(controller: controller, ...)`).
class ScrollMoreHint extends StatefulWidget {
  final Widget Function(BuildContext context, ScrollController controller)
  builder;

  /// Off where floating chrome already shows there is more below (the
  /// home tab capsule): the fade would wash out content above it.
  final bool enabled;

  /// When provided, this controller is used instead of the widget's own.
  /// The caller is responsible for disposing it.
  final ScrollController? controller;

  const ScrollMoreHint({
    super.key,
    required this.builder,
    this.enabled = true,
    this.controller,
  });

  /// Widget tests set this to true before pumping a screen that uses
  /// [ScrollMoreHint], since `pumpAndSettle()` can never settle while
  /// the chevron's bounce animation repeats forever. Has no effect on
  /// the running app.
  static bool debugDisableBounce = false;

  @override
  State<ScrollMoreHint> createState() => _ScrollMoreHintState();
}

class _ScrollMoreHintState extends State<ScrollMoreHint>
    with SingleTickerProviderStateMixin {
  late final ScrollController _controller;
  late final bool _ownsController;

  /// 0–1: how much of the fade + chevron shows. Follows the scroll
  /// position continuously (no threshold pop) and lives in a notifier so
  /// updating it never rebuilds the scrolling content.
  final _visibility = ValueNotifier<double>(0);
  late final AnimationController _bob = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  late final Animation<double> _bobCurve = CurvedAnimation(
    parent: _bob,
    curve: Curves.easeInOutSine,
  );
  bool? _bounceRunning;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
      _ownsController = false;
    } else {
      _controller = ScrollController();
      _ownsController = true;
    }
    _controller.addListener(_check);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The chevron's bob repeats forever, so it must stop entirely (not
    // just run "softer") under reduced motion — same rule tests apply
    // via debugDisableBounce, but for real users this checks the
    // platform accessibility setting instead.
    final shouldRun =
        !ScrollMoreHint.debugDisableBounce && !Motion.reduced(context);
    if (shouldRun == _bounceRunning) return;
    _bounceRunning = shouldRun;
    if (shouldRun) {
      _bob.repeat(reverse: true);
    } else {
      _bob.stop();
      _bob.value = 0;
    }
  }

  // The fade eases in over the last [_fadeSpan] px of remaining scroll and
  // is fully gone by [_clearance] px from the end — the hint's tap target
  // sits flush with the bottom edge, so it must clear out before a
  // scrolled-to-bottom CTA button reaches that same strip.
  static const _clearance = 24.0;
  static const _fadeSpan = 110.0;

  void _check() {
    if (!_controller.hasClients) return;
    final position = _controller.position;
    final remaining = position.maxScrollExtent - position.pixels;
    final t = ((remaining - _clearance) / _fadeSpan).clamp(0.0, 1.0);
    // smoothstep: soft at both ends
    _visibility.value = t * t * (3 - 2 * t);
  }

  void _scrollMore() {
    if (!_controller.hasClients) return;
    final position = _controller.position;
    final target = (position.pixels + position.viewportDimension * 0.7).clamp(
      0.0,
      position.maxScrollExtent,
    );
    _controller.animateTo(
      target,
      duration: Motion.of(context, Motion.normal),
      curve: Motion.enter,
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_check);
    if (_ownsController) _controller.dispose();
    _visibility.dispose();
    _bob.dispose();
    super.dispose();
  }

  // One continuous frosted-white fade behind the chevron — eased stops, no
  // hard edge where a separate strip used to end. Static: no blur, no
  // animated filter; only its opacity follows the scroll.
  static final _fade = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: const [0, 0.2, 0.4, 0.6, 0.8, 1],
    colors: [
      for (final a in const [0.0, 0.08, 0.3, 0.62, 0.88, 1.0])
        AppColors.surface.withValues(alpha: a),
    ],
  );

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      widget.builder(context, _controller),
      if (widget.enabled)
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: ValueListenableBuilder<double>(
            valueListenable: _visibility,
            builder: (context, v, child) => IgnorePointer(
              ignoring: v < 0.5,
              child: Opacity(opacity: v, child: child),
            ),
            child: RepaintBoundary(
              child: SizedBox(
                height: 96,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    // Pointer-transparent: the fade must never block taps on
                    // the content underneath — only the chevron is tappable.
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(gradient: _fade),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpace.xs),
                      child: Semantics(
                        button: true,
                        label: 'Scroll down',
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _scrollMore,
                          child: Padding(
                            padding: const EdgeInsets.all(9),
                            child: AnimatedBuilder(
                              animation: _bobCurve,
                              builder: (context, _) => Transform.translate(
                                offset: Offset(0, 4 * _bobCurve.value),
                                child: const Icon(
                                  Icons.keyboard_arrow_down,
                                  size: 26,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
    ],
  );
}
