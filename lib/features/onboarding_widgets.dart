import 'dart:async';
import 'dart:math' show pi, sin;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/motion.dart';
import '../core/theme.dart';
import '../data/app_store.dart';
import 'brand_logo.dart';
import 'components.dart';
import 'glass.dart';
import 'scroll_hint.dart';

/// One entry per screen in the "not yet on GeM" 15-step walkthrough,
/// in the order the flow is actually walked. This is the single
/// source of truth for a screen's section, its position within that
/// section, and (from that) its overall progress — screens identify
/// themselves purely by their route name; they no longer pass
/// progress or label text, so the two can never drift out of sync
/// with each other the way they had (e.g. a step showing "1 OF 6"
/// under the wrong section, or progress running backwards).
class _OnboardingStep {
  final String route;
  final String sectionEn;
  final String sectionHi;
  const _OnboardingStep(this.route, this.sectionEn, this.sectionHi);
}

const _kOnboardingSteps = <_OnboardingStep>[
  _OnboardingStep('flow-name', 'Getting started', 'शुरुआत'),
  _OnboardingStep('flow-phone', 'Getting started', 'शुरुआत'),
  _OnboardingStep('flow-otp', 'Getting started', 'शुरुआत'),
  _OnboardingStep('flow-location', 'Getting started', 'शुरुआत'),
  _OnboardingStep('flow-bizname', 'Your business', 'आपका व्यवसाय'),
  _OnboardingStep('flow-bizform', 'Your business', 'आपका व्यवसाय'),
  _OnboardingStep('flow-sector', 'Your business', 'आपका व्यवसाय'),
  _OnboardingStep('flow-role', 'Your business', 'आपका व्यवसाय'),
  _OnboardingStep('flow-authorised', 'Your business', 'आपका व्यवसाय'),
  _OnboardingStep('flow-turnover', 'GeM bidding', 'GeM बोली'),
  _OnboardingStep('flow-turnover-history', 'GeM bidding', 'GeM बोली'),
  _OnboardingStep('flow-experience', 'GeM bidding', 'GeM बोली'),
  // Only ever reached on the "Yes" branch of flow-experience — a user who
  // answers "No" never sees it, so their own last reading in this section
  // is "3 OF 4" (this table's real length), the same convention already
  // used for the already-on-GeM early exit out of "Get ready" below.
  _OnboardingStep('flow-experience-detail', 'GeM bidding', 'GeM बोली'),
  _OnboardingStep('flow-privacy', 'Get ready', 'तैयार हो जाएँ'),
  _OnboardingStep('flow-records', 'Get ready', 'तैयार हो जाएँ'),
  _OnboardingStep('flow-pan', 'Get ready', 'तैयार हो जाएँ'),
  _OnboardingStep('flow-checklist', 'Get ready', 'तैयार हो जाएँ'),
  _OnboardingStep('flow-video', 'Next step', 'अगला कदम'),
  _OnboardingStep('flow-redirect', 'Next step', 'अगला कदम'),
];

class _StepInfo {
  final String sectionEn;
  final String sectionHi;
  final int step;
  final int total;
  final double progress;
  const _StepInfo(
    this.sectionEn,
    this.sectionHi,
    this.step,
    this.total,
    this.progress,
  );
}

_StepInfo _stepInfoFor(String? route) {
  // Navigator stores settings.name exactly as passed to pushNamed
  // ('/flow-phone'), but the table below keys on the bare route
  // ('flow-phone') — strip the leading slash before matching, or every
  // lookup misses and silently falls back to index 0.
  final normalized = route?.replaceFirst('/', '');
  var index = normalized == null
      ? -1
      : _kOnboardingSteps.indexWhere((e) => e.route == normalized);
  if (index == -1) index = 0;
  final entry = _kOnboardingSteps[index];
  final total = _kOnboardingSteps.where((e) => e.sectionEn == entry.sectionEn).length;
  final step = _kOnboardingSteps
      .take(index + 1)
      .where((e) => e.sectionEn == entry.sectionEn)
      .length;
  return _StepInfo(
    entry.sectionEn,
    entry.sectionHi,
    step,
    total,
    (index + 1) / _kOnboardingSteps.length,
  );
}

/// A single flight shuttle used by every onboarding screen's header
/// Hero: always render the destination's own header rather than
/// interpolating between the old and new one, so nothing flickers or
/// cross-dissolves mid-flight — the header simply appears to stay put
/// while only the body underneath transitions.
Widget _onboardingHeaderShuttle(
  BuildContext flightContext,
  Animation<double> animation,
  HeroFlightDirection flightDirection,
  BuildContext fromHeroContext,
  BuildContext toHeroContext,
) {
  final toHero = toHeroContext.widget as Hero;
  return toHero.child;
}

/// Fades a piece of an onboarding screen in from 12px below, one at a
/// time — [index] 0 starts immediately, each index after that waits
/// an extra [Motion.staggerStep] so the screen reveals in sequence
/// rather than all at once.
///
/// Only plays on a screen's genuine first appearance. A rebuild
/// (e.g. the store notifying a language change) must not replay it —
/// guaranteed here by owning a single [AnimationController] created
/// once in [initState] and never restarted from [build]. Returning to
/// an already-shown screen via back must not replay it either: at the
/// moment this widget mounts, [ModalRoute.of]'s own transition
/// animation is still running (value < 1, not yet completed) for a
/// screen appearing for the first time, but has long since finished
/// (already completed) for a screen that was merely covered and is
/// now being revealed again — so checking that once, in
/// [State.didChangeDependencies] (the first opportunity after mount
/// where reading an inherited widget like [ModalRoute] is actually
/// allowed), tells the two cases apart without any extra bookkeeping.
class StaggeredEntrance extends StatefulWidget {
  final int index;
  final Widget child;
  const StaggeredEntrance({
    super.key,
    required this.index,
    required this.child,
  });

  @override
  State<StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<StaggeredEntrance>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 400);

  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  Timer? _delayTimer;
  bool _skip = false;
  bool _decided = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _duration);
    final curved = CurvedAnimation(parent: _controller, curve: Motion.enter);
    _fade = curved;
    _slide = curved.drive(
      Tween<Offset>(begin: const Offset(0, 12), end: Offset.zero),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ModalRoute.of (and MediaQuery-based Motion.reduced) can't be
    // called from initState — Flutter asserts against completing an
    // inherited-widget dependency before initState returns — so this
    // one-time decision is made here instead, on the first dependency
    // resolution right after mount, guarded to run exactly once.
    if (_decided) return;
    _decided = true;
    final routeAnimation = ModalRoute.of(context)?.animation;
    _skip = Motion.reduced(context) || (routeAnimation?.isCompleted ?? false);
    if (_skip) {
      _controller.value = 1;
    } else {
      final delay = Motion.staggerStep * widget.index;
      _delayTimer = Timer(delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_skip) return widget.child;
    // FadeTransition (not a raw Opacity in an AnimatedBuilder) so the
    // card underneath isn't recomposited from scratch every tick; the
    // RepaintBoundary keeps that same card's own repaints from
    // bleeding into whatever sits next to it while it's moving.
    return FadeTransition(
      opacity: _fade,
      child: AnimatedBuilder(
        animation: _slide,
        child: RepaintBoundary(child: widget.child),
        builder: (context, child) =>
            Transform.translate(offset: _slide.value, child: child),
      ),
    );
  }
}

/// Shared chrome for every screen in the "not yet on GeM" onboarding
/// walkthrough: back arrow, logo, progress bar, section/step labels,
/// headline, optional subtitle, the screen's own content, and a
/// Continue button (disabled when [onContinue] is null).
///
/// Progress, section and step are derived internally from the current
/// route's name (see [_kOnboardingSteps]) — callers no longer pass
/// them directly.
class OnboardingStepScaffold extends StatefulWidget {
  final AppStore store;
  final VoidCallback onBack;
  final String headline;
  final String? subtitle;
  final List<Widget> children;
  final String continueLabel;
  final VoidCallback? onContinue;

  const OnboardingStepScaffold({
    super.key,
    required this.store,
    required this.onBack,
    required this.headline,
    this.subtitle,
    required this.children,
    required this.continueLabel,
    required this.onContinue,
  });

  @override
  State<OnboardingStepScaffold> createState() =>
      _OnboardingStepScaffoldState();
}

class _OnboardingStepScaffoldState extends State<OnboardingStepScaffold> {
  /// Shared across every screen's own State instance (not per-widget):
  /// whichever screen last became the topmost route left its own
  /// progress here, so the next screen to appear — whether that's a
  /// forward push or a screen being revealed again after a pop — knows
  /// where to animate the bar *from*.
  static double lastProgress = 0.0;

  double _beginProgress = 0.0;
  double _target = 0.0;

  // TweenAnimationBuilder only re-seeds its start value from `begin`
  // on the build where this key first appears — on every later
  // rebuild it just eases from wherever it currently sits to the new
  // `end`. Reusing the same key would therefore make the *second*
  // didChangeDependencies (e.g. reappearing after a pop) silently do
  // nothing, since its `end` hasn't actually changed from this
  // instance's own point of view. Handing it a fresh key each time
  // forces a real re-seed from `_beginProgress`, so a screen with a
  // lower progress than whatever covered it genuinely animates
  // backward when revealed again, instead of just sitting there.
  Key _barKey = UniqueKey();

  // AnimatedSwitcher never animates the very first child a brand new
  // instance is given (there's nothing to transition from). Since a
  // fresh OnboardingStepScaffold is mounted for every forward push,
  // that would make the label cross-fade never actually play on the
  // one path that matters most. Mounting an invisible, identically
  // sized placeholder for exactly one frame, then swapping to the
  // real content, gives AnimatedSwitcher a genuine "old child" to
  // transition away from without shifting the layout.
  bool _showLabels = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _showLabels = true);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-runs whenever this route's current/covered status flips (a
    // screen is pushed on top of this one, or popped to reveal it
    // again), because build() below depends on ModalRoute.of(context)
    // — so this naturally re-triggers the tween in both directions:
    // forward when a new screen appears, backward when returning to
    // one that was already showing a lower progress value.
    final route = ModalRoute.of(context)?.settings.name;
    final target = _stepInfoFor(route).progress;
    setState(() {
      _beginProgress = lastProgress;
      _target = target;
      _barKey = UniqueKey();
    });
    lastProgress = target;
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    final route = ModalRoute.of(context)?.settings.name;
    final info = _stepInfoFor(route);
    final reduced = Motion.reduced(context);
    final sectionLabel = s.t(info.sectionEn, info.sectionHi);
    final stepLabel = s.t(
      '{section} · {step} OF {total}',
      '{section} · {step} में से {total}',
      vars: {
        'section': sectionLabel.toUpperCase(),
        'step': '${info.step}',
        'total': '${info.total}',
      },
    );
    final labelBlock = _OnboardingLabelBlock(
      sectionLabel: sectionLabel,
      stepLabel: stepLabel,
    );

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Fixed navigation chrome — the one place blur belongs
            // (Apple HIG: blur signals content scrolling behind
            // fixed chrome, not decoration). Content scrolls under
            // this bar, matching an iOS translucent nav bar. Hero'd
            // so it visually stays in place across screens instead
            // of being torn down and rebuilt on every push/pop.
            Hero(
              tag: 'onboarding-header',
              flightShuttleBuilder: _onboardingHeaderShuttle,
              child: GlassBar.top(
                child: Column(
                  children: [
                    Row(
                      children: [
                        AppIconButton(
                          onPressed: widget.onBack,
                          icon: Icons.arrow_back_ios_new,
                          tooltip: s.t('Back', 'वापस'),
                        ),
                        const Expanded(
                          child: BrandLogo(
                            variant: BrandLogoVariant.lockup,
                            width: 150,
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TweenAnimationBuilder<double>(
                      key: _barKey,
                      tween: Tween<double>(
                        begin: _beginProgress,
                        end: _target,
                      ),
                      duration: reduced ? Duration.zero : Motion.slow,
                      curve: Motion.enter,
                      builder: (context, value, child) {
                        return AppProgressBar(
                          value: value.clamp(0.02, 0.98),
                          animated: false,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ScrollMoreHint(
                builder: (context, scrollController) => SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 60),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedSwitcher(
                        duration: reduced ? Duration.zero : Motion.fast,
                        transitionBuilder: (child, animation) =>
                            FadeTransition(
                              opacity: animation,
                              child: AnimatedBuilder(
                                animation: animation,
                                builder: (context, builtChild) =>
                                    Transform.translate(
                                      offset: Offset(
                                        0,
                                        6 * (1 - animation.value),
                                      ),
                                      child: builtChild,
                                    ),
                                child: child,
                              ),
                            ),
                        child: _showLabels
                            ? KeyedSubtree(
                                key: const ValueKey('labels-shown'),
                                child: labelBlock,
                              )
                            : KeyedSubtree(
                                key: const ValueKey('labels-hidden'),
                                child: Opacity(
                                  opacity: 0,
                                  child: labelBlock,
                                ),
                              ),
                      ),
                      const SizedBox(height: 14),
                      StaggeredEntrance(
                        index: 0,
                        child: Text(
                          widget.headline,
                          style: AppText.h1,
                        ),
                      ),
                      if (widget.subtitle != null) ...[
                        const SizedBox(height: 12),
                        StaggeredEntrance(
                          index: 1,
                          child: Text(
                            widget.subtitle!,
                            style: AppText.secondary(AppText.body),
                          ),
                        ),
                      ],
                      const SizedBox(height: 28),
                      for (var i = 0; i < widget.children.length; i++)
                        StaggeredEntrance(
                          index: (i + 2).clamp(0, 7),
                          child: widget.children[i],
                        ),
                    ],
                  ),
                ),
              ),
            ),
            GlassBar.bottom(
              child: _OnboardingContinueButton(
                label: widget.continueLabel,
                onContinue: widget.onContinue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The Continue button: the shared large [AppButton], plus a shake and
/// haptic (see [ShakeOnError]) when tapped before the step is valid. It
/// still reports itself disabled to assistive tech.
class _OnboardingContinueButton extends StatefulWidget {
  final String label;
  final VoidCallback? onContinue;
  const _OnboardingContinueButton({
    required this.label,
    required this.onContinue,
  });

  @override
  State<_OnboardingContinueButton> createState() =>
      _OnboardingContinueButtonState();
}

class _OnboardingContinueButtonState extends State<_OnboardingContinueButton> {
  final _shake = ShakeController();

  @override
  Widget build(BuildContext context) => ShakeOnError(
    controller: _shake,
    child: AppButton(
      label: widget.label,
      onPressed: widget.onContinue,
      onDisabledTap: _shake.shake,
      size: AppButtonSize.lg,
    ),
  );
}

/// Lets a caller trigger a [ShakeOnError]'s animation imperatively —
/// e.g. from a Continue button's tap handler when the step isn't
/// valid yet.
class ShakeController {
  VoidCallback? _play;
  void shake() => _play?.call();
}

/// Wraps [child] and, on [controller].shake(), plays a short decaying
/// horizontal shake (±6px, 3 cycles over 360ms) plus a medium haptic —
/// the standard "that's not valid" cue for onboarding inputs. Under
/// reduced motion, only the haptic fires.
class ShakeOnError extends StatefulWidget {
  final Widget child;
  final ShakeController controller;
  const ShakeOnError({
    super.key,
    required this.child,
    required this.controller,
  });

  @override
  State<ShakeOnError> createState() => _ShakeOnErrorState();
}

class _ShakeOnErrorState extends State<ShakeOnError>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 360),
  );

  @override
  void initState() {
    super.initState();
    widget.controller._play = _play;
  }

  @override
  void didUpdateWidget(covariant ShakeOnError oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller._play = null;
      widget.controller._play = _play;
    }
  }

  void _play() {
    HapticFeedback.mediumImpact();
    if (Motion.reduced(context)) return;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    if (widget.controller._play == _play) widget.controller._play = null;
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, child) {
      final t = _controller.value;
      final decay = 1 - t;
      final offset = t == 0 ? 0.0 : sin(t * 3 * 2 * pi) * 6 * decay;
      return Transform.translate(offset: Offset(offset, 0), child: child);
    },
    child: widget.child,
  );
}

/// The section and step text shown under the header — pulled out so
/// the same visual content can be rendered both for real and, once
/// invisibly, as the placeholder [OnboardingStepScaffold] swaps away
/// from a frame later to give its [AnimatedSwitcher] something to
/// transition from.
class _OnboardingLabelBlock extends StatelessWidget {
  final String sectionLabel;
  final String stepLabel;
  const _OnboardingLabelBlock({
    required this.sectionLabel,
    required this.stepLabel,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        sectionLabel,
        style: AppText.secondary(AppText.bodySmall),
      ),
      const SizedBox(height: 16),
      Text(
        stepLabel,
        style: AppText.overline,
      ),
    ],
  );
}

/// A labeled text input, styled to match the mockups.
class OnboardingTextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;
  final String? prefixText;
  final ValueChanged<String>? onChanged;

  const OnboardingTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.keyboardType,
    this.prefixText,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: AppText.secondary(AppText.bodySmall),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: controller,
        keyboardType: keyboardType,
        onChanged: onChanged,
        style: AppText.input,
        decoration: InputDecoration(hintText: hint, prefixText: prefixText),
      ),
    ],
  );
}

/// The pixel density the mockup artwork under `assets/` was exported
/// at (mockup width 887px for a 390pt-wide phone) — so each image shows
/// at the size it has in the design without a hand-tuned width.
const _artScale = 2.27;

/// A screen's illustration, centred and scaled down (never up) to fit.
class OnboardingArt extends StatelessWidget {
  final String name;
  final double topGap;
  const OnboardingArt(this.name, {super.key, this.topGap = 24});

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: topGap),
    child: Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Image.asset(
          'assets/illustrations/$name.png',
          scale: _artScale,
          excludeFromSemantics: true,
        ),
      ),
    ),
  );
}

/// An illustration with the user's own text written onto it — the
/// name card and the parcel label. [textBox] is where the text sits as
/// fractions (left, top, right, bottom) of the artwork; long text
/// shrinks to fit rather than overflowing.
class OnboardingTextArt extends StatelessWidget {
  final String name;
  final Size pixelSize;
  final Rect textBox;
  final double angle;
  final String text;
  final String placeholder;
  final TextStyle style;
  const OnboardingTextArt({
    super.key,
    required this.name,
    required this.pixelSize,
    required this.textBox,
    required this.angle,
    required this.text,
    required this.placeholder,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    final w = pixelSize.width / _artScale;
    final h = pixelSize.height / _artScale;
    final empty = text.trim().isEmpty;
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: w,
            height: h,
            child: Stack(
              children: [
                Image.asset(
                  'assets/illustrations/$name.png',
                  width: w,
                  height: h,
                  excludeFromSemantics: true,
                ),
                Positioned(
                  left: textBox.left * w,
                  top: textBox.top * h,
                  width: textBox.width * w,
                  height: textBox.height * h,
                  child: Transform.rotate(
                    angle: angle,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: AnimatedSwitcher(
                        duration: Motion.of(context, Motion.fast),
                        child: Text(
                          empty ? placeholder : text.trim(),
                          key: ValueKey(empty ? '' : text.trim()),
                          maxLines: 1,
                          style: empty
                              ? style.copyWith(color: AppColors.textHint)
                              : style,
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
    );
  }
}

/// Leading artwork of an option row: custom line art when [asset] is
/// given (in a fixed [slot] so every label lines up), else a Material icon.
class OnboardingIcon extends StatelessWidget {
  final IconData? icon;
  final String? asset;
  final double slot;
  const OnboardingIcon({
    super.key,
    required this.icon,
    required this.asset,
    required this.slot,
  });

  @override
  Widget build(BuildContext context) {
    if (asset == null) return Icon(icon, size: 24, color: AppColors.ink);
    return SizedBox(
      width: slot,
      child: Align(
        alignment: Alignment.centerLeft,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Image.asset(
            'assets/icons/$asset.png',
            scale: _artScale,
            excludeFromSemantics: true,
          ),
        ),
      ),
    );
  }
}

/// The "press" feedback shared by every tappable onboarding option:
/// scales down slightly while held, eases back on release or cancel.
/// Mixed into each option's own State — rather than factored into a
/// separate wrapper widget — so each of
/// [OnboardingPickerField]/[OnboardingRadioOption]/[OnboardingCheckOption]
/// is itself a genuine StatefulWidget owning its own press state,
/// without repeating the same few lines three times.
mixin _PressScaleMixin<T extends StatefulWidget> on State<T> {
  bool _pressed = false;

  void handleTapDown([TapDownDetails? details]) {
    if (!_pressed) setState(() => _pressed = true);
  }

  void handleTapUp([TapUpDetails? details]) {
    if (_pressed) setState(() => _pressed = false);
  }

  void handleTapCancel() {
    if (_pressed) setState(() => _pressed = false);
  }

  Widget pressScale(BuildContext context, Widget child) {
    final reduced = Motion.reduced(context);
    return AnimatedScale(
      scale: !reduced && _pressed ? 0.98 : 1.0,
      duration: reduced ? Duration.zero : Motion.fast,
      curve: Motion.standard,
      child: child,
    );
  }
}

/// A tappable field that looks like the state/district pickers in the
/// mockups (leading icon, value text, trailing chevron) and opens a
/// simple bottom-sheet list to choose from.
class OnboardingPickerField extends StatefulWidget {
  final IconData icon;
  final String value;
  final String hint;
  final List<String> options;
  final ValueChanged<String> onSelected;
  final AppStore s;

  const OnboardingPickerField({
    super.key,
    required this.icon,
    required this.value,
    required this.hint,
    required this.options,
    required this.onSelected,
    required this.s,
  });

  @override
  State<OnboardingPickerField> createState() => _OnboardingPickerFieldState();
}

class _OnboardingPickerFieldState extends State<OnboardingPickerField>
    with _PressScaleMixin<OnboardingPickerField> {
  Future<void> _openPicker() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      sheetAnimationStyle: AnimationStyle(
        duration: Motion.of(context, Motion.slow),
        reverseDuration: Motion.of(context, Motion.normal),
        curve: Motion.enter,
      ),
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.7,
          ),
          child: ListView(
            children: [
              const SheetHandle(),
              for (final option in widget.options)
                ListTile(
                  title: Text(option),
                  trailing: option == widget.value
                      ? const Icon(Icons.check, color: AppColors.ink)
                      : null,
                  onTap: () => Navigator.of(context).pop(option),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) {
      HapticFeedback.selectionClick();
      widget.onSelected(picked);
    }
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: widget.value.isNotEmpty,
    label: widget.value.isEmpty ? widget.hint : widget.value,
    child: GestureDetector(
      onTap: _openPicker,
      onTapDown: handleTapDown,
      onTapUp: handleTapUp,
      onTapCancel: handleTapCancel,
      child: pressScale(
        context,
        AnimatedContainer(
          duration: Motion.of(context, Motion.fast),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.borderStrong),
            borderRadius: AppRadius.input,
          ),
          child: Row(
            children: [
              Icon(widget.icon, size: 22, color: AppColors.ink),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.value.isEmpty ? widget.hint : widget.value,
                  style: widget.value.isEmpty
                      ? AppText.input.copyWith(color: AppColors.textHint)
                      : AppText.input,
                ),
              ),
              const Icon(Icons.keyboard_arrow_down, color: AppColors.ink),
            ],
          ),
        ),
      ),
    ),
  );
}

/// The trailing radio-style indicator for [OnboardingRadioOption]: an
/// outer ring plus an inner dot that scales in from nothing when this
/// option becomes the selected one, and back out when another option
/// is chosen instead.
class _RadioIndicator extends StatelessWidget {
  final bool selected;
  const _RadioIndicator({required this.selected});

  @override
  Widget build(BuildContext context) {
    final reduced = Motion.reduced(context);
    return AnimatedContainer(
      duration: reduced ? Duration.zero : Motion.fast,
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? AppColors.ink : AppColors.borderStrong,
          width: 1.6,
        ),
      ),
      child: Center(
        child: AnimatedScale(
          scale: selected ? 1 : 0,
          duration: reduced ? Duration.zero : Motion.fast,
          curve: Motion.enter,
          child: Container(
            width: 12,
            height: 12,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}

/// A single-select option row with a leading icon and trailing
/// radio-style indicator, used for business form / sector / role /
/// readiness questions throughout this flow.
class OnboardingRadioOption extends StatefulWidget {
  final IconData? icon;
  /// Artwork from `assets/icons/` (name without extension); wins over [icon].
  final String? iconAsset;
  /// Width reserved for the leading artwork so labels stay aligned.
  final double iconSlot;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget? trailingField;

  const OnboardingRadioOption({
    super.key,
    this.icon,
    this.iconAsset,
    this.iconSlot = 52,
    required this.label,
    required this.selected,
    required this.onTap,
    this.trailingField,
  });

  @override
  State<OnboardingRadioOption> createState() => _OnboardingRadioOptionState();
}

class _OnboardingRadioOptionState extends State<OnboardingRadioOption>
    with _PressScaleMixin<OnboardingRadioOption> {
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: widget.selected,
    label: widget.label,
    child: GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      onTapDown: handleTapDown,
      onTapUp: handleTapUp,
      onTapCancel: handleTapCancel,
      child: pressScale(
        context,
        AnimatedContainer(
          duration: Motion.of(context, Motion.fast),
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            border: Border.all(
              color: widget.selected ? AppColors.ink : AppColors.borderStrong,
              width: widget.selected ? 1.4 : 1,
            ),
            borderRadius: AppRadius.input,
            color: widget.selected ? AppColors.surfaceMuted : AppColors.surface,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  OnboardingIcon(
                    icon: widget.icon,
                    asset: widget.iconAsset,
                    slot: widget.iconSlot,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      widget.label,
                      style: AppText.h3,
                    ),
                  ),
                  _RadioIndicator(selected: widget.selected),
                ],
              ),
              if (widget.trailingField != null && widget.selected) ...[
                const SizedBox(height: 12),
                widget.trailingField!,
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

/// The trailing checkbox indicator for [OnboardingCheckOption]: a box
/// that fills in while a tick draws itself across it stroke-by-stroke
/// (via [PathMetric.extractPath] over a growing length), rather than
/// simply swapping between two static icons.
class _CheckIndicator extends StatefulWidget {
  final bool checked;
  const _CheckIndicator({required this.checked});

  @override
  State<_CheckIndicator> createState() => _CheckIndicatorState();
}

class _CheckIndicatorState extends State<_CheckIndicator>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 220);
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _duration,
      value: widget.checked ? 1 : 0,
    );
  }

  @override
  void didUpdateWidget(_CheckIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.checked == widget.checked) return;
    if (Motion.reduced(context)) {
      _controller.value = widget.checked ? 1 : 0;
    } else if (widget.checked) {
      _controller.forward(from: 0);
    } else {
      _controller.reverse(from: 1);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) => Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: widget.checked ? AppColors.ink : AppColors.borderStrong,
        ),
        color: Color.lerp(AppColors.surface, AppColors.ink, _controller.value),
      ),
      child: CustomPaint(
        painter: _CheckTickPainter(progress: _controller.value),
      ),
    ),
  );
}

/// Draws a checkmark whose stroke length grows from 0 to full over
/// [_CheckIndicatorState._duration], so the tick appears to draw
/// itself rather than simply fading or popping in.
class _CheckTickPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;
  const _CheckTickPainter({
    required this.progress,
    this.color = AppColors.surface,
    this.strokeWidth = 2.2,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final path = Path()
      ..moveTo(size.width * 0.22, size.height * 0.52)
      ..lineTo(size.width * 0.42, size.height * 0.72)
      ..lineTo(size.width * 0.78, size.height * 0.30);

    final extracted = Path();
    for (final metric in path.computeMetrics()) {
      extracted.addPath(
        metric.extractPath(0, metric.length * progress),
        Offset.zero,
      );
    }

    canvas.drawPath(
      extracted,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _CheckTickPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth;
}

/// A multi-select option row (checkbox), used for the business-records
/// checklist.
class OnboardingCheckOption extends StatefulWidget {
  final IconData? icon;
  /// Artwork from `assets/icons/` (name without extension); wins over [icon].
  final String? iconAsset;
  /// Width reserved for the leading artwork so labels stay aligned.
  final double iconSlot;
  final String label;
  final String? sublabel;
  final bool checked;
  final VoidCallback onTap;

  const OnboardingCheckOption({
    super.key,
    this.icon,
    this.iconAsset,
    this.iconSlot = 52,
    required this.label,
    this.sublabel,
    required this.checked,
    required this.onTap,
  });

  @override
  State<OnboardingCheckOption> createState() => _OnboardingCheckOptionState();
}

class _OnboardingCheckOptionState extends State<OnboardingCheckOption>
    with _PressScaleMixin<OnboardingCheckOption> {
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: widget.checked,
    label: widget.label,
    child: GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      onTapDown: handleTapDown,
      onTapUp: handleTapUp,
      onTapCancel: handleTapCancel,
      child: pressScale(
        context,
        AnimatedContainer(
          duration: Motion.of(context, Motion.fast),
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            border: Border.all(
              color: widget.checked ? AppColors.ink : AppColors.borderStrong,
              width: widget.checked ? 1.4 : 1,
            ),
            borderRadius: AppRadius.input,
            color: widget.checked ? AppColors.surfaceMuted : AppColors.surface,
          ),
          child: Row(
            children: [
              OnboardingIcon(
                icon: widget.icon,
                asset: widget.iconAsset,
                slot: widget.iconSlot,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.label,
                      style: AppText.input,
                    ),
                    if (widget.sublabel != null)
                      Text(
                        widget.sublabel!,
                        style: AppText.caption,
                      ),
                  ],
                ),
              ),
              _CheckIndicator(checked: widget.checked),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Shows a brief, full-screen checkpoint when the user finishes a
/// section of onboarding: a circle draws itself, a tick draws inside
/// it, then [message] (already translated by the caller — e.g.
/// `s.t('Getting started complete', 'शुरुआत पूर्ण')`) fades in below.
/// Returns once the sequence finishes or the user taps to skip it.
///
/// An [OverlayEntry] rather than a route: this is a transient
/// decoration on top of whatever screen triggered it, not a real
/// navigation destination — it shouldn't appear in history or affect
/// back-button behaviour.
Future<void> showSectionComplete(BuildContext context, String message) {
  final completer = Completer<void>();
  final overlayState = Overlay.of(context);
  late OverlayEntry entry;
  var removed = false;
  void remove() {
    if (removed) return;
    removed = true;
    entry.remove();
    if (!completer.isCompleted) completer.complete();
  }

  entry = OverlayEntry(
    builder: (context) =>
        _SectionCompleteOverlay(message: message, onFinished: remove),
  );
  overlayState.insert(entry);
  return completer.future;
}

class _SectionCompleteOverlay extends StatefulWidget {
  final String message;
  final VoidCallback onFinished;
  const _SectionCompleteOverlay({
    required this.message,
    required this.onFinished,
  });

  @override
  State<_SectionCompleteOverlay> createState() =>
      _SectionCompleteOverlayState();
}

class _SectionCompleteOverlayState extends State<_SectionCompleteOverlay>
    with TickerProviderStateMixin {
  static const _circleDraw = Duration(milliseconds: 300);
  static const _checkDraw = Duration(milliseconds: 300);
  static const _textFade = Duration(milliseconds: 160);
  static const _hold = Duration(milliseconds: 400);
  static const _fadeOut = Duration(milliseconds: 160);
  static const _reducedHold = Duration(milliseconds: 500);

  late final AnimationController _circle;
  late final AnimationController _check;
  late final AnimationController _text;
  late final AnimationController _fade;
  // Drives the pause between the text appearing and the fade-out
  // starting. Deliberately a ticking AnimationController rather than
  // a bare Future.delayed: nothing is visually changing during the
  // hold, but a plain timer schedules no frames, so widget tests'
  // pumpAndSettle() (which stops once nothing more is scheduled)
  // would consider the sequence "settled" and never advance the
  // clock far enough for it to fire — exactly the gap a ticking
  // controller (which keeps requesting frames for its own duration)
  // doesn't have.
  late final AnimationController _holdTimer;
  bool _reduced = false;
  bool _decided = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _circle = AnimationController(vsync: this, duration: _circleDraw);
    _check = AnimationController(vsync: this, duration: _checkDraw);
    _text = AnimationController(vsync: this, duration: _textFade);
    _fade = AnimationController(vsync: this, duration: _fadeOut);
    _holdTimer = AnimationController(vsync: this, duration: _hold);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_decided) return;
    _decided = true;
    _reduced = Motion.reduced(context);
    unawaited(_run());
  }

  Future<void> _run() async {
    if (_reduced) {
      _circle.value = 1;
      _check.value = 1;
      _text.value = 1;
      HapticFeedback.mediumImpact();
      await _holdTimer.animateTo(1, duration: _reducedHold);
      _finish();
      return;
    }
    await _circle.forward();
    if (_finished || !mounted) return;
    await _check.forward();
    if (_finished || !mounted) return;
    HapticFeedback.mediumImpact();
    await _text.forward();
    if (_finished || !mounted) return;
    await _holdTimer.forward();
    if (_finished || !mounted) return;
    await _fade.forward();
    _finish();
  }

  // Tapping anywhere skips straight to the end — used both by the
  // skip gesture and by _run() finishing normally.
  void _finish() {
    if (_finished) return;
    _finished = true;
    widget.onFinished();
  }

  @override
  void dispose() {
    _circle.dispose();
    _check.dispose();
    _text.dispose();
    _fade.dispose();
    _holdTimer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: _finish,
    // FadeTransition, not a raw Opacity, over this full-screen
    // Material — ReverseAnimation gives the 1-value fade-out for
    // free without an extra AnimatedBuilder rebuilding the subtree.
    child: FadeTransition(
      opacity: ReverseAnimation(_fade),
      child: Material(
        color: AppColors.surface,
        child: SizedBox.expand(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_circle, _check]),
                    builder: (context, _) => CustomPaint(
                      size: const Size(56, 56),
                      painter: _SectionCirclePainter(
                        circleProgress: _reduced ? 1 : _circle.value,
                        checkProgress: _reduced ? 1 : _check.value,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FadeTransition(
                  opacity: _text,
                  child: Text(
                    widget.message,
                    style: AppText.title,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// The 56px circle outline (sweeping in as a growing arc) with
/// [_CheckTickPainter]'s tick reused inside it, in black rather than
/// the checkbox's white-on-dark treatment.
class _SectionCirclePainter extends CustomPainter {
  final double circleProgress;
  final double checkProgress;
  const _SectionCirclePainter({
    required this.circleProgress,
    required this.checkProgress,
  });

  static const _strokeWidth = 2.6;

  @override
  void paint(Canvas canvas, Size size) {
    if (circleProgress > 0) {
      final rect = Rect.fromLTWH(
        _strokeWidth / 2,
        _strokeWidth / 2,
        size.width - _strokeWidth,
        size.height - _strokeWidth,
      );
      canvas.drawArc(
        rect,
        -pi / 2,
        2 * pi * circleProgress,
        false,
        Paint()
          ..color = AppColors.ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = _strokeWidth
          ..strokeCap = StrokeCap.round,
      );
    }
    if (checkProgress > 0) {
      _CheckTickPainter(
        progress: checkProgress,
        color: AppColors.ink,
        strokeWidth: _strokeWidth,
      ).paint(canvas, size);
    }
  }

  @override
  bool shouldRepaint(covariant _SectionCirclePainter oldDelegate) =>
      oldDelegate.circleProgress != circleProgress ||
      oldDelegate.checkProgress != checkProgress;
}
