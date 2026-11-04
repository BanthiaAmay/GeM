import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/models.dart' show money;
import '../core/motion.dart';
import '../core/theme.dart';
import 'components.dart';
import '../data/app_store.dart';

void go(BuildContext context, AppStore store, String page) {
  store.event(
    'cta_clicked',
    page: ModalRoute.of(context)?.settings.name,
    props: {'destination': page},
  );
  Navigator.of(context).pushNamed('/$page');
}

Future<void> openLink(BuildContext context, AppStore store, String url) async {
  store.event('external_link_clicked', props: {'host': Uri.parse(url).host});
  try {
    if (!await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    )) {
      throw Exception();
    }
  } catch (_) {
    if (context.mounted) {
      message(
        context,
        store.t(
          'Could not open the link. Please try again.',
          'लिंक नहीं खुला। दोबारा कोशिश करें।',
        ),
      );
    }
  }
}

void message(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

/// Padded [AppCard] for page-level groups (tool forms, results, tips).
class Panel extends StatelessWidget {
  final Widget child;
  final AppCardTone tone;
  final Color? color;
  final EdgeInsets padding;
  const Panel({
    super.key,
    required this.child,
    this.tone = AppCardTone.outlined,
    this.color,
    this.padding = const EdgeInsets.all(AppSpace.xxl),
  });
  @override
  Widget build(BuildContext context) => color == null
      ? AppCard(
          tone: tone,
          padding: padding,
          radius: AppRadius.xl,
          child: child,
        )
      : Container(
          width: double.infinity,
          padding: padding,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: AppColors.border),
          ),
          child: child,
        );
}

class Heading extends StatelessWidget {
  final String eyebrow, title, subtitle;
  const Heading(this.eyebrow, this.title, this.subtitle, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpace.xxxl),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: AppText.overline.copyWith(color: AppColors.brand),
        ),
        const SizedBox(height: AppSpace.md),
        Semantics(header: true, child: Text(title, style: AppText.h1)),
        const SizedBox(height: AppSpace.md),
        Text(subtitle, style: AppText.secondary(AppText.body)),
      ],
    ),
  );
}

/// Tinted status badge (see [StatusChip]).
class Tag extends StatelessWidget {
  final String label;
  const Tag(this.label, {super.key});
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: StatusChip(label, tone: StatusTone.success),
  );
}

/// A labelled figure: caption, big value, supporting detail.
class Stat extends StatelessWidget {
  final String label;
  final Widget value;
  final String detail;
  const Stat(this.label, this.value, this.detail, {super.key});
  @override
  Widget build(BuildContext context) => Panel(
    tone: AppCardTone.outlined,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.caption),
        const SizedBox(height: AppSpace.md),
        DefaultTextStyle.merge(style: AppText.h2, child: value),
        const SizedBox(height: AppSpace.sm),
        Text(detail, style: AppText.caption),
      ],
    ),
  );
}

/// Animates a result figure from whatever it previously showed to
/// [value] over [Motion.emphasis] with [Motion.enter] curve, rendering
/// it through [format] — the shared engine behind [AnimatedMoney] and
/// [AnimatedPercent]. Relies on [TweenAnimationBuilder] only reseeding
/// its `begin` on the very first build: later rebuilds (a recalculated
/// result) animate from the currently-displayed value, not from zero.
/// Under reduced motion, the new value is shown immediately.
class AnimatedNumber extends StatelessWidget {
  final double value;
  final String Function(double) format;
  final TextStyle? style;
  const AnimatedNumber({
    super.key,
    required this.value,
    required this.format,
    this.style,
  });

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween<double>(begin: value, end: value),
    duration: Motion.of(context, Motion.emphasis),
    curve: Motion.enter,
    builder: (context, v, _) => Text(format(v), style: style),
  );
}

/// A one-shot fade + 12px rise for a widget that appears after some
/// action (e.g. a calculator's result card) rather than being present
/// from the first frame. Plays once when it mounts; a rebuild that
/// keeps the same child in the tree does not replay it — only
/// removing and re-adding the widget (e.g. clearing then
/// recalculating a result) does. Reduced motion shows [child]
/// immediately.
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  const FadeSlideIn({super.key, required this.child});

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Motion.normal,
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Motion.enter,
  );
  bool _decided = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Motion.reduced reads MediaQuery, which can't be resolved from
    // initState — deferred here and guarded to run exactly once.
    if (_decided) return;
    _decided = true;
    if (Motion.reduced(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _curve,
    child: AnimatedBuilder(
      animation: _curve,
      // A RepaintBoundary around the (often large/text-heavy) result
      // card so the translate below doesn't force it to re-rasterize
      // every tick.
      child: RepaintBoundary(child: widget.child),
      builder: (context, child) => Transform.translate(
        offset: Offset(0, (1 - _curve.value) * 12),
        child: child,
      ),
    ),
  );
}

/// A ₹ result figure (revenue range, target price, ROI figures,
/// setup/fees) that counts smoothly to its new value instead of
/// snapping, formatted with [money].
class AnimatedMoney extends StatelessWidget {
  final double value;
  final TextStyle? style;
  const AnimatedMoney({super.key, required this.value, this.style});

  @override
  Widget build(BuildContext context) =>
      AnimatedNumber(value: value, format: (v) => money(v), style: style);
}

/// The percentage counterpart of [AnimatedMoney] — one decimal place,
/// same counting-up treatment.
class AnimatedPercent extends StatelessWidget {
  final double value;
  final TextStyle? style;
  const AnimatedPercent({super.key, required this.value, this.style});

  @override
  Widget build(BuildContext context) => AnimatedNumber(
    value: value,
    format: (v) => '${v.toStringAsFixed(1)}%',
    style: style,
  );
}

class ResponsiveRow extends StatelessWidget {
  final List<Widget> children;
  final double breakpoint;
  const ResponsiveRow({
    super.key,
    required this.children,
    this.breakpoint = 700,
  });
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) => c.maxWidth < breakpoint
        ? Column(
            children: [
              for (final w in children)
                Padding(padding: const EdgeInsets.only(bottom: 16), child: w),
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(width: 20),
                Expanded(child: children[i]),
              ],
            ],
          ),
  );
}

class NextActions extends StatelessWidget {
  final AppStore store;
  final String next;
  const NextActions(this.store, this.next, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpace.xxl),
    child: Wrap(
      spacing: AppSpace.md,
      runSpacing: AppSpace.md,
      children: [
        AppButton(
          label: '${store.t('Continue', 'आगे बढ़ें')}: ${store.toolName(next)}',
          onPressed: () => go(context, store, next),
          trailingIcon: Icons.arrow_forward,
          expand: false,
        ),
        AppButton(
          label: store.t('See my full report', 'मेरी पूरी रिपोर्ट देखें'),
          onPressed: () => go(context, store, 'report'),
          variant: AppButtonVariant.secondary,
          expand: false,
        ),
      ],
    ),
  );
}

class SourceNote extends StatelessWidget {
  final AppStore store;
  final String label, url;
  const SourceNote(this.store, this.label, this.url, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpace.md),
    child: InkWell(
      onTap: () => openLink(context, store, url),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSize.tap),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(
              Icons.open_in_new,
              size: AppIconSize.sm,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: Text(
                label,
                style: AppText.caption.copyWith(
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
