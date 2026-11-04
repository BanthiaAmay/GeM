import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/motion.dart';
import '../core/theme.dart';

/// Shared UI components. Feature screens compose these instead of styling
/// raw Material widgets; the rules are in DESIGN_SYSTEM.md.

// ─────────────────────────── Buttons ───────────────────────────

enum AppButtonVariant {
  /// Solid ink pill — the one main action on a screen.
  primary,

  /// Outlined pill — an alternative action next to a primary.
  secondary,

  /// Underlined text — low-emphasis ("Not now", "View all").
  tertiary,
}

enum AppButtonSize {
  /// 66px screen call-to-action pinned above the keyboard/bottom bar.
  lg,

  /// 52px in-content button.
  md,

  /// 40px compact button (still a 48px tap target).
  sm,
}

/// The app's button. States: enabled, pressed (0.98 scale + ripple),
/// focused (3px brand ring, keyboard/switch only), disabled (fades to a
/// grey pill; `onPressed: null`), loading (spinner, taps ignored, width
/// held). Set [danger] for destructive confirmations.
class AppButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final IconData? icon;
  final IconData? trailingIcon;
  final bool loading;
  final bool danger;
  final bool expand;

  /// Called when the user taps while the button is disabled (e.g. to
  /// shake and explain what is missing). The button still reports itself
  /// disabled to assistive tech.
  final VoidCallback? onDisabledTap;

  /// Light impact on a successful tap.
  final bool haptic;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.md,
    this.icon,
    this.trailingIcon,
    this.loading = false,
    this.danger = false,
    this.expand = true,
    this.onDisabledTap,
    this.haptic = true,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _pressed = false;
  bool _focused = false;

  bool get _enabled => widget.onPressed != null && !widget.loading;

  void _tap() {
    if (!_enabled) {
      if (!widget.loading) widget.onDisabledTap?.call();
      return;
    }
    if (widget.haptic) HapticFeedback.lightImpact();
    widget.onPressed!();
  }

  void _setPressed(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final reduced = Motion.reduced(context);
    final lg = widget.size == AppButtonSize.lg;
    final sm = widget.size == AppButtonSize.sm;
    final height = switch (widget.size) {
      AppButtonSize.lg => AppSize.buttonLg,
      AppButtonSize.md => AppSize.buttonMd,
      AppButtonSize.sm => AppSize.buttonSm,
    };
    final v = widget.variant;
    final enabled = _enabled;
    final accent = widget.danger ? AppColors.danger : AppColors.ink;

    final Color bg;
    final Color fg;
    final BorderSide side;
    switch (v) {
      case AppButtonVariant.primary:
        bg = enabled || widget.loading ? accent : AppColors.disabled;
        fg = enabled || widget.loading
            ? AppColors.surface
            : AppColors.surface.withValues(alpha: 0.7);
        side = BorderSide.none;
      case AppButtonVariant.secondary:
        bg = AppColors.surface;
        fg = enabled || widget.loading
            ? (widget.danger ? AppColors.danger : AppColors.ink)
            : AppColors.textHint;
        side = BorderSide(
          color: enabled || widget.loading
              ? (widget.danger ? AppColors.danger : AppColors.borderStrong)
              : AppColors.border,
          width: 1.4,
        );
      case AppButtonVariant.tertiary:
        bg = Colors.transparent;
        fg = enabled ? accent : AppColors.textHint;
        side = BorderSide.none;
    }

    final labelStyle = (lg ? AppText.buttonLg : AppText.button).copyWith(
      color: fg,
      decoration: v == AppButtonVariant.tertiary
          ? TextDecoration.underline
          : null,
      decorationColor: fg,
    );
    final iconSize = lg ? AppIconSize.md : AppIconSize.sm + 2;

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, size: iconSize, color: fg),
          const SizedBox(width: AppSpace.sm),
        ],
        Flexible(
          child: Text(
            widget.label,
            style: labelStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (widget.trailingIcon != null) ...[
          const SizedBox(width: AppSpace.sm),
          Icon(widget.trailingIcon, size: iconSize, color: fg),
        ],
      ],
    );

    final keyboardFocus =
        _focused &&
        FocusManager.instance.highlightMode == FocusHighlightMode.traditional;

    Widget button = AnimatedContainer(
      duration: Motion.of(context, Motion.normal),
      height: height,
      decoration: ShapeDecoration(
        color: bg,
        shape: StadiumBorder(side: side),
      ),
      child: Material(
        type: MaterialType.transparency,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: _tap,
          onTapDown: (_) => _setPressed(true),
          onTapUp: (_) => _setPressed(false),
          onTapCancel: () => _setPressed(false),
          onFocusChange: (f) => setState(() => _focused = f),
          overlayColor: WidgetStatePropertyAll(
            (v == AppButtonVariant.primary ? AppColors.surface : AppColors.ink)
                .withValues(alpha: 0.10),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: lg ? AppSpace.xxxl : AppSpace.xxl,
            ),
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedOpacity(
                    duration: Motion.of(context, Motion.fast),
                    opacity: widget.loading ? 0 : 1,
                    child: content,
                  ),
                  if (widget.loading)
                    SizedBox(
                      width: AppIconSize.md - 4,
                      height: AppIconSize.md - 4,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: fg,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    button = DecoratedBox(
      decoration: ShapeDecoration(
        shape: StadiumBorder(
          side: keyboardFocus
              ? const BorderSide(color: AppColors.brand, width: 3)
              : BorderSide.none,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(keyboardFocus ? 3 : 0),
        child: button,
      ),
    );

    button = AnimatedScale(
      scale: !reduced && _pressed && enabled ? 0.98 : 1,
      duration: Motion.of(context, Motion.fast),
      curve: Motion.standard,
      child: button,
    );

    if (sm) {
      // 40px visual, 48px tap target.
      button = Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: button,
      );
    }

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      value: widget.loading ? '…' : null,
      child: ExcludeSemantics(
        child: widget.expand
            ? SizedBox(width: double.infinity, child: button)
            : IntrinsicWidth(child: button),
      ),
    );
  }
}

/// Icon-only button: 48px tap target, 24px glyph, required tooltip so it
/// is always labelled for assistive tech. [tonal] adds a quiet circle.
class AppIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool tonal;
  final Color? color;
  const AppIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.tonal = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: onPressed,
    tooltip: tooltip,
    icon: Icon(icon, color: color),
    style: tonal
        ? IconButton.styleFrom(backgroundColor: AppColors.surfaceMuted)
        : null,
  );
}

// ─────────────────────────── Surfaces ───────────────────────────

enum AppCardTone {
  /// White with a hairline border.
  outlined,

  /// Quiet grey fill, no border (inset panel).
  muted,

  /// Brand-tinted fill (featured / highlighted).
  brand,
}

/// The card surface: radius 16, hairline border, soft resting shadow. Tappable when
/// [onTap] is set (ripple + press feedback).
class AppCard extends StatelessWidget {
  final Widget child;
  final AppCardTone tone;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  final String? semanticLabel;
  const AppCard({
    super.key,
    required this.child,
    this.tone = AppCardTone.outlined,
    this.padding = const EdgeInsets.all(AppSpace.xl),
    this.radius = AppRadius.lg,
    this.onTap,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    final card = Ink(
      decoration: BoxDecoration(
        color: switch (tone) {
          AppCardTone.outlined => AppColors.surface,
          AppCardTone.muted => AppColors.surfaceMuted,
          AppCardTone.brand => AppColors.brandTint,
        },
        borderRadius: r,
        border: tone == AppCardTone.outlined
            ? Border.all(color: AppColors.border)
            : null,
        boxShadow: tone == AppCardTone.outlined ? AppShadow.card : null,
      ),
      child: Padding(padding: padding, child: child),
    );
    final body = SizedBox(
      width: double.infinity,
      child: Material(
        type: MaterialType.transparency,
        child: onTap == null
            ? card
            : InkWell(borderRadius: r, onTap: onTap, child: card),
      ),
    );
    return semanticLabel == null
        ? body
        : Semantics(container: true, label: semanticLabel, child: body);
  }
}

/// Heading for a group of content, with an optional trailing action.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  const SectionHeader(this.title, {super.key, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpace.md),
    child: Row(
      children: [
        Expanded(
          child: Semantics(header: true, child: Text(title, style: AppText.h3)),
        ),
        if (actionLabel != null)
          AppButton(
            label: actionLabel!,
            onPressed: onAction,
            variant: AppButtonVariant.tertiary,
            size: AppButtonSize.sm,
            expand: false,
            haptic: false,
          ),
      ],
    ),
  );
}

// ─────────────────────────── Status ───────────────────────────

enum StatusTone { success, danger, warning, info, neutral }

extension on StatusTone {
  (Color fg, Color bg) get colors => switch (this) {
    StatusTone.success => (AppColors.brand, AppColors.brandTint),
    StatusTone.danger => (AppColors.danger, AppColors.dangerTint),
    StatusTone.warning => (AppColors.warning, AppColors.warningTint),
    StatusTone.info => (AppColors.info, AppColors.infoTint),
    StatusTone.neutral => (AppColors.textSecondary, AppColors.surfaceMuted),
  };
}

/// Small tinted badge: status word, match %, deadline. Colour is never the
/// only signal — always carries text, optionally an icon.
class StatusChip extends StatelessWidget {
  final String label;
  final StatusTone tone;
  final IconData? icon;
  const StatusChip(
    this.label, {
    super.key,
    this.tone = StatusTone.neutral,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = tone.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.md - 2,
          vertical: AppSpace.xs + 1,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: fg),
              const SizedBox(width: AppSpace.xs),
            ],
            Flexible(
              child: Text(label, style: AppText.label.copyWith(color: fg)),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single check-list line: filled green check (done), red alert
/// (needs attention) or hollow circle (pending) beside a label.
enum ItemState { done, attention, pending }

class StatusItem extends StatelessWidget {
  final String label;
  final ItemState state;
  final String? trailing;
  const StatusItem({
    super.key,
    required this.label,
    required this.state,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (state) {
      ItemState.done => (Icons.check_circle, AppColors.brand),
      ItemState.attention => (Icons.error, AppColors.danger),
      ItemState.pending => (Icons.circle_outlined, AppColors.textHint),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
      child: Row(
        children: [
          Icon(icon, size: AppIconSize.md, color: color),
          const SizedBox(width: AppSpace.md),
          Expanded(child: Text(label, style: AppText.body)),
          if (trailing != null)
            Flexible(
              child: Text(
                trailing!,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.bodySmall.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────── Lists ───────────────────────────

/// Label on the left, value on the right — profile fields, bid details.
class KeyValueRow extends StatelessWidget {
  final String label;
  final String value;
  const KeyValueRow(this.label, this.value, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 2, child: Text(label, style: AppText.caption)),
        const SizedBox(width: AppSpace.lg),
        Expanded(
          flex: 3,
          child: Text(
            value.isEmpty ? '—' : value,
            textAlign: TextAlign.end,
            style: AppText.bodySmall.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

/// Column of rows separated by hairlines (no outer divider).
class DividedList extends StatelessWidget {
  final List<Widget> children;
  const DividedList({super.key, required this.children});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0) const Divider(),
        children[i],
      ],
    ],
  );
}

/// Tappable list row: optional tinted icon disc, title, subtitle, chevron.
/// Sits inside an [AppCard] (the row itself has no border).
class AppListTile extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  const AppListTile({
    super.key,
    this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: AppRadius.card,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppSize.tap),
      child: Row(
        children: [
          if (icon != null) ...[
            DecoratedBox(
              decoration: const BoxDecoration(
                color: AppColors.brandTint,
                shape: BoxShape.circle,
              ),
              child: SizedBox(
                width: 40,
                height: 40,
                child: DepthIcon(
                  icon,
                  size: AppIconSize.md - 4,
                  color: AppColors.brand,
                ),
              ),
            ),
            const SizedBox(width: AppSpace.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.body),
                if (subtitle != null) Text(subtitle!, style: AppText.caption),
              ],
            ),
          ),
          trailing ??
              (onTap != null
                  ? const Icon(Icons.chevron_right, size: AppIconSize.md)
                  : const SizedBox.shrink()),
        ],
      ),
    ),
  );
}

// ─────────────────── Loading / empty / error ───────────────────

enum StateKind { loading, empty, error }

/// The one pattern for "nothing to show yet": a spinner (loading), a calm
/// message (empty) or a retryable failure (error).
class StateView extends StatelessWidget {
  final StateKind kind;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  const StateView({
    super.key,
    required this.kind,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final icon = switch (kind) {
      StateKind.loading => null,
      StateKind.empty => Icons.inbox_outlined,
      StateKind.error => Icons.error_outline,
    };
    final color = kind == StateKind.error
        ? AppColors.danger
        : AppColors.textSecondary;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpace.huge,
          horizontal: AppSpace.xxl,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon == null)
                  const SizedBox(
                    width: AppIconSize.lg,
                    height: AppIconSize.lg,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  )
                else
                  Icon(icon, size: AppIconSize.lg + 8, color: color),
                const SizedBox(height: AppSpace.lg),
                Text(title, textAlign: TextAlign.center, style: AppText.h3),
                if (message != null) ...[
                  const SizedBox(height: AppSpace.sm),
                  Text(
                    message!,
                    textAlign: TextAlign.center,
                    style: AppText.secondary(AppText.body),
                  ),
                ],
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: AppSpace.xl),
                  AppButton(
                    label: actionLabel!,
                    onPressed: onAction,
                    variant: AppButtonVariant.secondary,
                    expand: false,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── Progress ───────────────────────────

/// Horizontal progress track. Animates to [value] (0–1); jumps under
/// reduced motion. [color] defaults to ink (flows) — use brand for status.
class AppProgressBar extends StatelessWidget {
  final double value;
  final double height;
  final Color color;
  final String? semanticLabel;
  final Duration? duration;

  /// False when the caller already animates [value] every frame (the
  /// onboarding header) — the bar then draws it as given.
  final bool animated;
  const AppProgressBar({
    super.key,
    required this.value,
    this.height = 5,
    this.color = AppColors.ink,
    this.semanticLabel,
    this.duration,
    this.animated = true,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticLabel,
    value: '${(value.clamp(0, 1) * 100).round()}%',
    child: ExcludeSemantics(
      child: animated
          ? TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: value, end: value),
              duration: Motion.of(context, duration ?? Motion.slow),
              curve: Motion.enter,
              builder: (context, v, _) => _track(v),
            )
          : _track(value),
    ),
  );

  Widget _track(double v) => ClipRRect(
    borderRadius: BorderRadius.circular(height),
    child: SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: AppColors.chartTrack)),
          FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: v.clamp(0.0, 1.0),
            heightFactor: 1,
            child: ColoredBox(color: color),
          ),
        ],
      ),
    ),
  );
}

/// Circular progress with a centred label (e.g. "7 of 9").
class AppProgressRing extends StatelessWidget {
  final double value;
  final double size;
  final double strokeWidth;
  final String label;
  final String? semanticLabel;
  const AppProgressRing({
    super.key,
    required this.value,
    required this.label,
    this.size = 96,
    this.strokeWidth = 8,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticLabel ?? label,
    value: '${(value.clamp(0, 1) * 100).round()}%',
    child: ExcludeSemantics(
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: value, end: value),
              duration: Motion.of(context, Motion.slow),
              curve: Motion.enter,
              builder: (context, v, _) => SizedBox(
                width: size,
                height: size,
                child: CircularProgressIndicator(
                  value: v.clamp(0.0, 1.0),
                  strokeWidth: strokeWidth,
                  strokeCap: StrokeCap.round,
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(strokeWidth + 2),
              child: Center(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: AppText.label,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ─────────────────────────── Sheets ───────────────────────────

/// Drag handle shown at the top of every bottom sheet.
class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 36,
      height: 4,
      margin: const EdgeInsets.only(top: AppSpace.md, bottom: AppSpace.md),
      decoration: BoxDecoration(
        color: AppColors.borderStrong,
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );
}

// ─────────────────────────── Selection controls ───────────────────────────

/// Segmented control for a short, mutually-exclusive set (date range 7D /
/// 30D / 90D). Full-width pill, one segment selected (ink fill). Segments
/// are 48px tall, focusable, and announce their selected state.
class AppSegmentedControl<T> extends StatelessWidget {
  final List<(T value, String label, String? semantic)> options;
  final T value;
  final ValueChanged<T> onChanged;
  final String semanticLabel;
  const AppSegmentedControl({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    required this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: semanticLabel,
    child: Container(
      padding: const EdgeInsets.all(4),
      decoration: const BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.pill)),
      ),
      child: Row(
        children: [
          for (final (v, label, semantic) in options)
            Expanded(
              child: Semantics(
                button: true,
                selected: v == value,
                label: semantic ?? label,
                child: ExcludeSemantics(
                  child: AnimatedContainer(
                    duration: Motion.of(context, Motion.fast),
                    height: AppSize.tap - 8,
                    decoration: ShapeDecoration(
                      color: v == value ? AppColors.ink : Colors.transparent,
                      shape: const StadiumBorder(),
                    ),
                    child: InkWell(
                      customBorder: const StadiumBorder(),
                      onTap: () {
                        if (v != value) {
                          HapticFeedback.selectionClick();
                          onChanged(v);
                        }
                      },
                      child: Center(
                        child: Text(
                          label,
                          style: AppText.label.copyWith(
                            fontSize: 13,
                            color: v == value
                                ? AppColors.surface
                                : AppColors.ink,
                          ),
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
  );
}

/// Horizontally scrolling single-select filter chips ("All", categories…).
/// Selected = ink fill; unselected = outlined. 48px tap height.
class AppChoiceChips<T> extends StatelessWidget {
  final List<(T value, String label)> options;
  final T value;
  final ValueChanged<T> onChanged;
  final String semanticLabel;
  const AppChoiceChips({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    required this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: semanticLabel,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final (v, label) in options)
            Padding(
              padding: const EdgeInsets.only(right: AppSpace.sm),
              child: Semantics(
                button: true,
                selected: v == value,
                label: label,
                child: ExcludeSemantics(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: AppSize.tap),
                    child: Center(
                      child: AnimatedContainer(
                        duration: Motion.of(context, Motion.fast),
                        height: AppSize.buttonSm,
                        decoration: ShapeDecoration(
                          color: v == value ? AppColors.ink : AppColors.surface,
                          shape: StadiumBorder(
                            side: BorderSide(
                              color: v == value
                                  ? AppColors.ink
                                  : AppColors.borderStrong,
                              width: 1.4,
                            ),
                          ),
                        ),
                        child: InkWell(
                          customBorder: const StadiumBorder(),
                          onTap: () {
                            if (v != value) {
                              HapticFeedback.selectionClick();
                              onChanged(v);
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpace.lg,
                            ),
                            child: Center(
                              widthFactor: 1,
                              child: Text(
                                label,
                                style: AppText.label.copyWith(
                                  fontSize: 13,
                                  color: v == value
                                      ? AppColors.surface
                                      : AppColors.ink,
                                ),
                              ),
                            ),
                          ),
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
  );
}

/// Compact dropdown pill ("Last 30 days ▾") that opens a menu of options.
class AppDropdownChip<T> extends StatelessWidget {
  final List<(T value, String label)> options;
  final T value;
  final ValueChanged<T> onChanged;
  final String semanticLabel;
  const AppDropdownChip({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    required this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final current = options.firstWhere((o) => o.$1 == value).$2;
    return PopupMenuButton<T>(
      tooltip: semanticLabel,
      onSelected: onChanged,
      initialValue: value,
      position: PopupMenuPosition.under,
      itemBuilder: (context) => [
        for (final (v, label) in options)
          PopupMenuItem<T>(
            value: v,
            height: AppSize.tap,
            child: Row(
              children: [
                Expanded(child: Text(label, style: AppText.body)),
                if (v == value) const Icon(Icons.check, size: AppIconSize.sm),
              ],
            ),
          ),
      ],
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSize.tap),
        child: Center(
          widthFactor: 1,
          child: Container(
            height: AppSize.buttonSm,
            padding: const EdgeInsets.only(
              left: AppSpace.lg,
              right: AppSpace.md,
            ),
            decoration: const ShapeDecoration(
              shape: StadiumBorder(
                side: BorderSide(color: AppColors.borderStrong, width: 1.4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(current, style: AppText.label.copyWith(fontSize: 13)),
                const SizedBox(width: AppSpace.xs),
                const Icon(Icons.keyboard_arrow_down, size: AppIconSize.md - 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── Keywords ───────────────────────────

/// Free-text tags ("What do you sell?"): an input with an Add button, added
/// tags as removable ink pills, and outlined suggestion pills that add on
/// tap. Commas split entries; case-insensitive duplicates are ignored.
class AppKeywordField extends StatefulWidget {
  final List<String> values;
  final ValueChanged<List<String>> onChanged;
  final List<String> suggestions;
  final String label;
  final String hint;
  final String addLabel;

  /// Accessible label for a tag's remove action; `{keyword}` is replaced.
  final String removeLabel;
  final String suggestionsLabel;
  final String limitMessage;
  final int max;
  final int maxLength;
  const AppKeywordField({
    super.key,
    required this.values,
    required this.onChanged,
    required this.label,
    required this.hint,
    required this.addLabel,
    required this.removeLabel,
    required this.suggestionsLabel,
    required this.limitMessage,
    this.suggestions = const [],
    this.max = 10,
    this.maxLength = 80,
  });

  @override
  State<AppKeywordField> createState() => _AppKeywordFieldState();
}

class _AppKeywordFieldState extends State<AppKeywordField> {
  final _controller = TextEditingController();

  bool _has(String value) =>
      widget.values.any((v) => v.toLowerCase() == value.toLowerCase());

  void _add(String raw) {
    final next = [...widget.values];
    for (final part in raw.split(',')) {
      final value = part.trim();
      if (value.isEmpty || value.length > widget.maxLength) continue;
      if (next.length >= widget.max) break;
      if (!next.any((v) => v.toLowerCase() == value.toLowerCase())) {
        next.add(value);
      }
    }
    _controller.clear();
    if (next.length != widget.values.length) {
      HapticFeedback.selectionClick();
      widget.onChanged(next);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _pill({
    required String label,
    required IconData icon,
    required bool filled,
    required String semantics,
    required VoidCallback onTap,
  }) => Semantics(
    button: true,
    label: semantics,
    child: ExcludeSemantics(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSize.tap),
        child: Center(
          widthFactor: 1,
          child: Material(
            color: filled ? AppColors.ink : AppColors.surface,
            shape: StadiumBorder(
              side: BorderSide(
                color: filled ? AppColors.ink : AppColors.borderStrong,
                width: 1.4,
              ),
            ),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.lg,
                  AppSpace.sm,
                  AppSpace.md,
                  AppSpace.sm,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        style: AppText.label.copyWith(
                          fontSize: 13,
                          color: filled ? AppColors.surface : AppColors.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpace.xs),
                    Icon(
                      icon,
                      size: AppIconSize.sm,
                      color: filled ? AppColors.surface : AppColors.ink,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final full = widget.values.length >= widget.max;
    final suggestions = widget.suggestions.where((s) => !_has(s)).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: AppText.secondary(AppText.bodySmall)),
        const SizedBox(height: AppSpace.sm),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                enabled: !full,
                style: AppText.input,
                textInputAction: TextInputAction.done,
                textCapitalization: TextCapitalization.sentences,
                maxLength: widget.maxLength,
                buildCounter:
                    (
                      _, {
                      required currentLength,
                      required isFocused,
                      maxLength,
                    }) => null,
                decoration: InputDecoration(hintText: widget.hint),
                onSubmitted: _add,
              ),
            ),
            const SizedBox(width: AppSpace.sm),
            AppIconButton(
              icon: Icons.add,
              tooltip: widget.addLabel,
              tonal: true,
              onPressed: full ? null : () => _add(_controller.text),
            ),
          ],
        ),
        if (widget.values.isNotEmpty) ...[
          const SizedBox(height: AppSpace.md),
          Wrap(
            spacing: AppSpace.sm,
            children: [
              for (final value in widget.values)
                _pill(
                  label: value,
                  icon: Icons.close,
                  filled: true,
                  semantics: widget.removeLabel.replaceAll('{keyword}', value),
                  onTap: () => widget.onChanged(
                    widget.values.where((v) => v != value).toList(),
                  ),
                ),
            ],
          ),
        ],
        if (full) ...[
          const SizedBox(height: AppSpace.sm),
          Text(widget.limitMessage, style: AppText.caption),
        ] else if (suggestions.isNotEmpty) ...[
          const SizedBox(height: AppSpace.lg),
          Text(widget.suggestionsLabel, style: AppText.caption),
          const SizedBox(height: AppSpace.xs),
          Wrap(
            spacing: AppSpace.sm,
            children: [
              for (final suggestion in suggestions)
                _pill(
                  label: suggestion,
                  icon: Icons.add,
                  filled: false,
                  semantics: '${widget.addLabel}: $suggestion',
                  onTap: () => _add(suggestion),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Multi-select pills: picked = ink fill with a check, unpicked = outlined.
/// Wraps onto new lines; every pill keeps a 48px tap height.
class AppToggleChips extends StatelessWidget {
  final List<String> options;
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  final String semanticLabel;
  const AppToggleChips({
    super.key,
    required this.options,
    required this.selected,
    required this.onToggle,
    required this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: semanticLabel,
    child: Wrap(
      spacing: AppSpace.sm,
      children: [
        for (final option in options)
          Semantics(
            button: true,
            selected: selected.contains(option),
            label: option,
            child: ExcludeSemantics(
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: AppSize.tap),
                child: Center(
                  widthFactor: 1,
                  child: AnimatedContainer(
                    duration: Motion.of(context, Motion.fast),
                    height: AppSize.buttonSm - 4,
                    decoration: ShapeDecoration(
                      color: selected.contains(option)
                          ? AppColors.ink
                          : AppColors.surface,
                      shape: StadiumBorder(
                        side: BorderSide(
                          color: selected.contains(option)
                              ? AppColors.ink
                              : AppColors.borderStrong,
                          width: 1.4,
                        ),
                      ),
                    ),
                    child: InkWell(
                      customBorder: const StadiumBorder(),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onToggle(option);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpace.md,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (selected.contains(option)) ...[
                              const Icon(
                                Icons.check,
                                size: AppIconSize.sm - 2,
                                color: AppColors.surface,
                              ),
                              const SizedBox(width: AppSpace.xs),
                            ],
                            Text(
                              option,
                              style: AppText.label.copyWith(
                                fontSize: 13,
                                color: selected.contains(option)
                                    ? AppColors.surface
                                    : AppColors.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

// ─────────────────────────── Depth ───────────────────────────

/// Animated depth for artwork (logos, illustrations, icon PNGs): a soft
/// shadow cut to the artwork's own silhouette, a short rise-in that tips up
/// out of a 3D tilt, and a tilt toward the finger while it is pressed.
///
/// The child is painted twice (once blurred, as its shadow), so pass plain
/// artwork only — never text, a Hero or a keyed widget. Reduced motion keeps
/// the shadow and drops all movement.
class Depth extends StatefulWidget {
  final Widget child;

  /// Shadow distance at rest, in logical pixels; also sets its softness.
  final double lift;

  /// Strongest press tilt in radians; 0 turns the press tilt off.
  final double tilt;
  final bool entrance;

  /// Wait before the rise-in starts, for staggered groups.
  final Duration delay;
  const Depth({
    super.key,
    required this.child,
    this.lift = 6,
    this.tilt = 0.18,
    this.entrance = true,
    this.delay = Duration.zero,
  });

  @override
  State<Depth> createState() => _DepthState();
}

class _DepthState extends State<Depth> with SingleTickerProviderStateMixin {
  late final AnimationController _rise = AnimationController(
    vsync: this,
    duration: widget.delay + Motion.emphasis,
  );
  late final Animation<double> _risen = CurvedAnimation(
    parent: _rise,
    curve: Interval(
      widget.delay.inMilliseconds /
          (widget.delay + Motion.emphasis).inMilliseconds,
      1,
      curve: Motion.enter,
    ),
  );

  /// Where the finger is, from -1 to 1 across each axis; zero when lifted.
  Offset _press = Offset.zero;
  bool _reduced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = Motion.reduced(context);
    if (_rise.isAnimating || _rise.isCompleted) return;
    if (!widget.entrance || _reduced) {
      _rise.value = 1;
    } else {
      _rise.forward();
    }
  }

  @override
  void dispose() {
    _rise.dispose();
    super.dispose();
  }

  void _track(PointerEvent event) {
    final size = context.size;
    if (_reduced || widget.tilt == 0 || size == null || size.isEmpty) return;
    setState(
      () => _press = Offset(
        (event.localPosition.dx / size.width * 2 - 1).clamp(-1.0, 1.0),
        (event.localPosition.dy / size.height * 2 - 1).clamp(-1.0, 1.0),
      ),
    );
  }

  void _release(PointerEvent _) {
    if (_press != Offset.zero) setState(() => _press = Offset.zero);
  }

  @override
  Widget build(BuildContext context) {
    final lift = widget.lift;
    final shadow = IgnorePointer(
      child: ExcludeSemantics(
        child: ImageFiltered(
          imageFilter: ui.ImageFilter.blur(
            sigmaX: lift * 0.8,
            sigmaY: lift * 0.8,
          ),
          child: ColorFiltered(
            colorFilter: const ColorFilter.mode(
              AppColors.depthShadow,
              BlendMode.srcIn,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
    return Listener(
      onPointerDown: _track,
      onPointerMove: _track,
      onPointerUp: _release,
      onPointerCancel: _release,
      child: RepaintBoundary(
        child: TweenAnimationBuilder<Offset>(
          tween: Tween(end: _press),
          duration: Motion.of(
            context,
            _press == Offset.zero ? Motion.normal : Motion.fast,
          ),
          curve: Motion.enter,
          builder: (context, press, _) => AnimatedBuilder(
            animation: _risen,
            builder: (context, _) {
              final risen = _risen.value;
              final pushed = 1 - 0.35 * math.min(press.distance, 1);
              return Opacity(
                opacity: risen.clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(0, (1 - risen) * lift * 2.5),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // The shadow stays on the ground: it grows as the art
                      // rises and shortens while the art is pushed down.
                      Transform.translate(
                        offset: Offset(
                          -press.dx * lift * 0.4,
                          lift * (0.3 + 0.7 * risen) * pushed,
                        ),
                        child: shadow,
                      ),
                      Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.0015)
                          ..rotateX(press.dy * widget.tilt - (1 - risen) * 0.55)
                          ..rotateY(-press.dx * widget.tilt),
                        child: widget.child,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// [Depth] for a Material icon: the glyph casts its own soft shadow (no
/// second copy), rises in on first show, and pops up with a quick 3D tip
/// whenever [lifted] turns on (e.g. the selected tab).
class DepthIcon extends StatelessWidget {
  final IconData? icon;
  final double? size;
  final Color? color;
  final bool lifted;
  const DepthIcon(
    this.icon, {
    super.key,
    this.size,
    this.color,
    this.lifted = false,
  });

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: Motion.of(context, Motion.slow),
    curve: Motion.enter,
    builder: (context, risen, _) => TweenAnimationBuilder<double>(
      tween: Tween(end: lifted ? 1 : 0),
      duration: Motion.of(context, Motion.normal),
      curve: Motion.enter,
      builder: (context, up, _) {
        final height = (1.2 + 2.8 * up) * risen;
        // A tip that peaks mid-way through rising or lifting, flat at rest.
        final tip =
            math.sin(risen * math.pi) * 0.5 + math.sin(up * math.pi) * 0.45;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.002)
            ..rotateX(-tip),
          child: Transform.translate(
            offset: Offset(0, -1.5 * up),
            child: Icon(
              icon,
              size: size,
              color: color,
              shadows: [
                Shadow(
                  color: AppColors.depthShadow,
                  blurRadius: 2 + 3 * up,
                  offset: Offset(0, height),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

// ─────────────────────────── Reassurance ───────────────────────────

/// The muted-green "this is prep, not a decision" note used on any
/// screen that asks for a sensitive-feeling figure (turnover, past
/// orders): a green left accent on [AppColors.brandTint], flush with no
/// radius so the accent reads as a rule rather than a card.
class ReassuranceNote extends StatelessWidget {
  final String text;
  const ReassuranceNote(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    child: DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.brandTint,
        border: Border(left: BorderSide(color: AppColors.brand, width: 3)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.lg,
          AppSpace.md,
          AppSpace.lg,
          AppSpace.md,
        ),
        child: Text(text, style: AppText.secondary(AppText.bodySmall)),
      ),
    ),
  );
}

// ─────────────────────────── Search field ───────────────────────────

/// Shared search / filter input used by the universal search page and the
/// Tools hub filter. Styled to spec: grey fill, rounded, no border, leading
/// search icon, trailing clear × when text is present, optional mic for
/// Phase-3 voice input.
class AppSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;
  final bool autofocus;

  /// Show a trailing mic icon (voice search).
  final bool showMic;
  final VoidCallback? onMic;

  /// True while speech recognition is active — shows a pulsing mic.
  final bool isListening;
  final TextInputAction textInputAction;

  const AppSearchField({
    super.key,
    required this.controller,
    required this.hint,
    required this.onChanged,
    this.onSubmitted,
    this.focusNode,
    this.autofocus = false,
    this.showMic = false,
    this.onMic,
    this.isListening = false,
    this.textInputAction = TextInputAction.search,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: AppRadius.input,
      ),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpace.md),
            child: Icon(
              Icons.search,
              size: AppIconSize.md,
              color: AppColors.textHint,
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              autofocus: autofocus,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              textInputAction: textInputAction,
              style: AppText.body,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: AppText.body.copyWith(color: AppColors.textHint),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: AppSpace.md,
                ),
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, v, _) {
              if (v.text.isNotEmpty) {
                return IconButton(
                  icon: const Icon(
                    Icons.close,
                    size: AppIconSize.md - 4,
                    color: AppColors.textHint,
                  ),
                  tooltip: 'Clear',
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                );
              }
              if (showMic) {
                return _PulsingMicButton(
                  isListening: isListening,
                  onTap: onMic,
                );
              }
              return const SizedBox(width: AppSpace.lg);
            },
          ),
        ],
      ),
    );
  }
}

// ── Pulsing mic button for voice search ───────────────────────────────────────

class _PulsingMicButton extends StatefulWidget {
  final bool isListening;
  final VoidCallback? onTap;

  const _PulsingMicButton({required this.isListening, this.onTap});

  @override
  State<_PulsingMicButton> createState() => _PulsingMicButtonState();
}

class _PulsingMicButtonState extends State<_PulsingMicButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: Motion.emphasis);
    _scale = Tween<double>(
      begin: 0.85,
      end: 1.15,
    ).chain(CurveTween(curve: Motion.standard)).animate(_ctrl);
    if (widget.isListening) _startPulse();
  }

  @override
  void didUpdateWidget(_PulsingMicButton old) {
    super.didUpdateWidget(old);
    if (widget.isListening && !old.isListening) {
      _startPulse();
    } else if (!widget.isListening && old.isListening) {
      _ctrl.stop();
      _ctrl.reset();
    }
  }

  void _startPulse() => _ctrl.repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = Motion.reduced(context);
    final icon = Icon(
      widget.isListening ? Icons.mic : Icons.mic_none,
      size: AppIconSize.md - 4,
      color: widget.isListening ? AppColors.brand : AppColors.textHint,
    );
    final btn = IconButton(
      icon: icon,
      tooltip: widget.isListening ? 'Listening…' : 'Voice search',
      onPressed: widget.onTap,
    );
    if (reduced || !widget.isListening) return btn;
    return ScaleTransition(scale: _scale, child: btn);
  }
}
