import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/models.dart' show money;
import '../core/motion.dart';
import '../core/theme.dart';

/// Chart kit. One look for every chart in the app:
///  * bars 12px tall, rounded, on a [AppColors.chartTrack] rail;
///  * every bar has a text label AND its number — colour is never the
///    only signal;
///  * an axis with ticks in Indian compact units (₹1.5 L, ₹2 Cr);
///  * series colours are the `AppColors.chart*` tokens (≥3:1 on white);
///  * bars grow in once (Motion.slow); under reduced motion they appear
///    at full size;
///  * each chart is one Semantics node reading its data aloud.
/// Charts are drawn with CustomPainter — no chart dependency.

/// ₹ in compact Indian units for axis ticks: ₹950, ₹12 K, ₹1.5 L, ₹2 Cr.
String moneyCompact(double v) {
  final a = v.abs();
  final sign = v < 0 ? '−' : '';
  String trim(double x) =>
      x.toStringAsFixed(x >= 10 || x == x.roundToDouble() ? 0 : 1);
  if (a >= 1e7) return '$sign₹${trim(a / 1e7)} Cr';
  if (a >= 1e5) return '$sign₹${trim(a / 1e5)} L';
  if (a >= 1e3) return '$sign₹${trim(a / 1e3)} K';
  return '$sign₹${a.round()}';
}

/// Rounds [v] up to a 1/2/5 × 10ⁿ value so axis ends are tidy.
double niceCeil(double v) {
  if (v <= 0) return 1;
  final exp = math.pow(10, (math.log(v) / math.ln10).floor()).toDouble();
  final f = v / exp;
  final n = f <= 1 ? 1 : (f <= 2 ? 2 : (f <= 5 ? 5 : 10));
  return n * exp;
}

const _barHeight = 12.0;

class _Axis extends StatelessWidget {
  final double min;
  final double max;
  final List<double> ticks;
  const _Axis({required this.min, required this.max, required this.ticks});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final w = c.maxWidth;
      final range = max - min;
      return SizedBox(
        height: 20,
        child: Stack(
          children: [
            for (final t in ticks)
              Positioned(
                left: ((t - min) / range * w).clamp(0, w).toDouble(),
                top: 0,
                child: FractionalTranslation(
                  translation: Offset(
                    t == min && ticks.first == t
                        ? 0
                        : (t == max && ticks.last == t ? -1 : -0.5),
                    0,
                  ),
                  child: Text(moneyCompact(t), style: AppText.caption),
                ),
              ),
          ],
        ),
      );
    },
  );
}

class _BarsPainter extends CustomPainter {
  final List<(double from, double to, Color color)> bars;
  final double min;
  final double max;
  final double t; // 0–1 grow-in
  final double? zero;
  const _BarsPainter({
    required this.bars,
    required this.min,
    required this.max,
    required this.t,
    this.zero,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final range = max - min;
    double x(double v) => (v - min) / range * size.width;
    final rail = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(size.height / 2),
    );
    canvas.drawRRect(rail, Paint()..color = AppColors.chartTrack);
    final base = zero ?? min;
    for (final (from, to, color) in bars) {
      // grow outward from the baseline (or the bar's own start)
      final a = x(from), b = x(to);
      final origin = zero != null ? x(base) : a;
      final left = origin + (math.min(a, b) - origin) * t;
      final right = origin + (math.max(a, b) - origin) * t;
      if (right - left <= 0) continue;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(left, 0, math.max(right, left + 2), size.height),
          Radius.circular(size.height / 2),
        ),
        Paint()..color = color,
      );
    }
    if (zero != null && min < 0) {
      final zx = x(zero!);
      canvas.drawLine(
        Offset(zx, -3),
        Offset(zx, size.height + 3),
        Paint()
          ..color = AppColors.ink
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) =>
      old.t != t ||
      old.min != min ||
      old.max != max ||
      old.bars != bars ||
      old.zero != zero;
}

class ChartGrowIn extends StatelessWidget {
  final Widget Function(double t) builder;
  const ChartGrowIn({super.key, required this.builder});

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween<double>(begin: 0, end: 1),
    duration: Motion.of(context, Motion.slow),
    curve: Motion.enter,
    builder: (context, t, _) => builder(t),
  );
}

/// A low–high range on a ₹ axis (revenue scenario): one bar spanning the
/// range, both ends labelled with their name and value.
class RangeChart extends StatelessWidget {
  final double low;
  final double high;
  final String lowLabel;
  final String highLabel;
  const RangeChart({
    super.key,
    required this.low,
    required this.high,
    required this.lowLabel,
    required this.highLabel,
  });

  @override
  Widget build(BuildContext context) {
    final max = niceCeil(high * 1.1);
    return Semantics(
      container: true,
      label: '$lowLabel ${money(low)}, $highLabel ${money(high)}',
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _EndLabel(label: lowLabel, value: money(low)),
                  ),
                  Expanded(
                    child: _EndLabel(
                      label: highLabel,
                      value: money(high),
                      alignEnd: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.md),
              ChartGrowIn(
                builder: (t) => SizedBox(
                  height: _barHeight,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _BarsPainter(
                      bars: [(low, high, AppColors.chartPositive)],
                      min: 0,
                      max: max,
                      t: t,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.sm),
              _Axis(min: 0, max: max, ticks: [0, max / 2, max]),
            ],
          ),
        ),
      ),
    );
  }
}

class _EndLabel extends StatelessWidget {
  final String label;
  final String value;
  final bool alignEnd;
  const _EndLabel({
    required this.label,
    required this.value,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: alignEnd
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start,
    children: [
      Text(label, style: AppText.caption),
      Text(value, style: AppText.title),
    ],
  );
}

/// One slice of a [CompositionBar].
class ChartSlice {
  final String label;
  final double value;
  final Color color;
  const ChartSlice(this.label, this.value, this.color);
}

/// A whole split into parts (price = cost + profit): a stacked bar plus a
/// legend giving each part's name, ₹ value and share.
class CompositionBar extends StatelessWidget {
  final List<ChartSlice> slices;
  const CompositionBar({super.key, required this.slices});

  @override
  Widget build(BuildContext context) {
    final total = slices.fold<double>(0, (a, s) => a + math.max(0, s.value));
    String pct(double v) =>
        total <= 0 ? '0%' : '${(math.max(0, v) / total * 100).round()}%';
    return Semantics(
      container: true,
      label: [
        for (final s in slices) '${s.label} ${money(s.value)} ${pct(s.value)}',
      ].join(', '),
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ChartGrowIn(
                builder: (t) => ClipRRect(
                  borderRadius: BorderRadius.circular(_barHeight / 2),
                  child: SizedBox(
                    height: _barHeight + 4,
                    child: Row(
                      children: [
                        for (var i = 0; i < slices.length; i++)
                          if (slices[i].value > 0)
                            Expanded(
                              flex: math.max(
                                1,
                                (slices[i].value / total * 1000 * t).round(),
                              ),
                              child: Padding(
                                padding: EdgeInsets.only(
                                  right: i < slices.length - 1 ? 2 : 0,
                                ),
                                child: ColoredBox(color: slices[i].color),
                              ),
                            ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.lg),
              for (final s in slices)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.sm),
                  child: Row(
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: s.color,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const SizedBox(width: 12, height: 12),
                      ),
                      const SizedBox(width: AppSpace.sm),
                      Expanded(child: Text(s.label, style: AppText.bodySmall)),
                      Text(
                        money(s.value),
                        style: AppText.bodySmall.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(
                        width: 48,
                        child: Text(
                          pct(s.value),
                          textAlign: TextAlign.end,
                          style: AppText.caption,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One row of [ValueBars].
class ChartValue {
  final String label;
  final double value;

  /// Overrides the default green (≥0) / red (<0) colouring.
  final Color? color;
  const ChartValue(this.label, this.value, {this.color});
}

/// Horizontal bars sharing one ₹ axis; supports negative values (bar goes
/// left of a zero line). Each row: label left, value right, bar below.
class ValueBars extends StatelessWidget {
  final List<ChartValue> items;
  const ValueBars({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final lo = math.min(0.0, items.map((i) => i.value).reduce(math.min));
    final hi = math.max(0.0, items.map((i) => i.value).reduce(math.max));
    final maxAxis = hi <= 0 ? 0.0 : niceCeil(hi * 1.05);
    final minAxis = lo >= 0 ? 0.0 : -niceCeil(-lo * 1.05);
    final min = minAxis, max = maxAxis == 0 ? 1.0 : maxAxis;
    final ticks = <double>[if (min < 0) min, 0, if (max > 0) max];
    return Semantics(
      container: true,
      label: [for (final i in items) '${i.label} ${money(i.value)}'].join(', '),
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final i in items) ...[
                Row(
                  children: [
                    Expanded(child: Text(i.label, style: AppText.caption)),
                    Text(
                      money(i.value),
                      style: AppText.title.copyWith(
                        color: i.value < 0 ? AppColors.danger : AppColors.ink,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.sm),
                ChartGrowIn(
                  builder: (t) => SizedBox(
                    height: _barHeight,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: _BarsPainter(
                        bars: [
                          (
                            0,
                            i.value,
                            i.color ??
                                (i.value < 0
                                    ? AppColors.chartNegative
                                    : AppColors.chartPositive),
                          ),
                        ],
                        min: min,
                        max: max,
                        zero: 0,
                        t: t,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.lg),
              ],
              _Axis(min: min, max: max, ticks: ticks),
            ],
          ),
        ),
      ),
    );
  }
}
