import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme.dart';
import 'charts.dart' show ChartGrowIn, moneyCompact;

/// Analytics chart kit — bar, line, pie and scatter — built on one shared
/// interactive surface. Rules (also in DESIGN_SYSTEM.md → Charts):
///  * same insets, gridlines, axis, tick type and colours in all four;
///  * hover (pointer), tap / horizontal-drag (touch) and arrow keys
///    (keyboard) select the nearest datum; Esc clears;
///  * the selection shows as a tooltip AND as a text line under the chart
///    (a live region), so nothing depends on hovering or on colour;
///  * every chart is one Semantics node that reads all its data;
///  * data appears once with a grow-in (instant under reduced motion);
///  * series are told apart by colour + marker shape + label, never colour
///    alone.

// ───────────────────────── helpers ─────────────────────────

/// 1/2/5×10ⁿ step that fits ~[target] ticks into [max].
List<double> niceTicks(double max, {int target = 4}) {
  if (max <= 0) return [0, 1];
  final raw = max / target;
  final exp = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
  final f = raw / exp;
  final step = (f <= 1 ? 1 : (f <= 2 ? 2 : (f <= 5 ? 5 : 10))) * exp;
  final s = step < 1 ? 1.0 : step;
  final ticks = <double>[];
  for (var v = 0.0; v < max + s; v += s) {
    ticks.add(v);
    if (v >= max) break;
  }
  return ticks;
}

/// Whole-number percentages that sum to exactly 100 (largest remainder).
List<int> percentages(List<double> values) {
  final total = values.fold<double>(0, (a, b) => a + b);
  if (total <= 0) return List.filled(values.length, 0);
  final raw = [for (final v in values) v / total * 100];
  final floors = [for (final r in raw) r.floor()];
  var left = 100 - floors.fold<int>(0, (a, b) => a + b);
  final order = List.generate(raw.length, (i) => i)
    ..sort((a, b) => (raw[b] - floors[b]).compareTo(raw[a] - floors[a]));
  for (final i in order) {
    if (left <= 0) break;
    floors[i]++;
    left--;
  }
  return floors;
}

TextPainter _tp(String text, TextStyle style, {double? maxWidth}) =>
    TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth ?? double.infinity);

void _label(
  Canvas c,
  String text,
  Offset at, {
  TextStyle style = AppText.tick,
  double anchorX = 0.5,
  double anchorY = 0,
}) {
  final t = _tp(text, style);
  t.paint(c, Offset(at.dx - t.width * anchorX, at.dy - t.height * anchorY));
}

void _paintMarker(
  Canvas c,
  Offset p,
  double size,
  ChartShape shape,
  Paint fill, {
  Paint? outline,
}) {
  final r = size / 2;
  final path = Path();
  switch (shape) {
    case ChartShape.circle:
      path.addOval(Rect.fromCircle(center: p, radius: r));
    case ChartShape.square:
      path.addRect(
        Rect.fromCenter(center: p, width: size * 0.9, height: size * 0.9),
      );
    case ChartShape.diamond:
      path
        ..moveTo(p.dx, p.dy - r * 1.2)
        ..lineTo(p.dx + r * 1.2, p.dy)
        ..lineTo(p.dx, p.dy + r * 1.2)
        ..lineTo(p.dx - r * 1.2, p.dy)
        ..close();
    case ChartShape.triangle:
      path
        ..moveTo(p.dx, p.dy - r * 1.15)
        ..lineTo(p.dx + r * 1.15, p.dy + r * 0.9)
        ..lineTo(p.dx - r * 1.15, p.dy + r * 0.9)
        ..close();
    case ChartShape.cross:
      final w = r * 0.55;
      path
        ..addRect(Rect.fromCenter(center: p, width: size * 1.05, height: w * 2))
        ..addRect(
          Rect.fromCenter(center: p, width: w * 2, height: size * 1.05),
        );
  }
  c.drawPath(path, fill);
  if (outline != null) c.drawPath(path, outline);
}

Rect _plotArea(Size size, {EdgeInsets? insets}) {
  final i = insets ?? AppChart.plotInsets;
  return Rect.fromLTRB(
    i.left,
    i.top,
    size.width - i.right,
    size.height - i.bottom,
  );
}

void _paintYGrid(
  Canvas c,
  Rect area,
  List<double> ticks,
  double yMax,
  double yMin,
  String Function(double) format,
) {
  final grid = Paint()
    ..color = AppChart.grid
    ..strokeWidth = AppChart.gridStroke;
  for (final t in ticks) {
    final y = area.bottom - (t - yMin) / (yMax - yMin) * area.height;
    c.drawLine(Offset(area.left, y), Offset(area.right, y), grid);
    _label(c, format(t), Offset(area.left - 8, y), anchorX: 1, anchorY: 0.5);
  }
  c.drawLine(
    Offset(area.left, area.bottom),
    Offset(area.right, area.bottom),
    Paint()
      ..color = AppChart.axis
      ..strokeWidth = AppChart.axisStroke,
  );
}

// ───────────────────────── tooltip ─────────────────────────

class _Tooltip extends StatelessWidget {
  final String text;
  final Offset anchor;
  final Size bounds;
  const _Tooltip({
    required this.text,
    required this.anchor,
    required this.bounds,
  });

  @override
  Widget build(BuildContext context) {
    final style = AppText.label.copyWith(
      color: AppColors.surface,
      fontWeight: FontWeight.w600,
    );
    final lines = text.split('\n');
    final width = math.min(
      lines.map((l) => _tp(l, style).width).fold<double>(0, math.max) + 20,
      math.max(0.0, bounds.width - 8),
    );
    final height = lines.length * 16.0 + 14;
    final left = (anchor.dx - width / 2)
        .clamp(0.0, math.max(0.0, bounds.width - width))
        .toDouble();
    var top = anchor.dy - height - 12;
    if (top < 0) top = anchor.dy + 14;
    return Positioned(
      left: left,
      top: top,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.ink,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: math.max(0.0, width - 20)),
              child: Text(text, textAlign: TextAlign.center, style: style),
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── interactive surface ─────────────────────────

/// Hover / tap / drag / keyboard selection, tooltip, focus ring and the
/// live text readout shared by every chart.
class _ChartSurface extends StatefulWidget {
  final double height;
  final int count;
  final int? Function(Offset local, Size size) nearest;
  final Offset Function(int index, Size size) anchor;
  final String Function(int index) tooltip;
  final String Function(int index) readout;
  final String hint;
  final CustomPainter Function(double t, int? active, Size size) painter;
  final List<int>? order;
  final ValueChanged<int?>? onActive;
  final String semanticLabel;
  final bool horizontalScrub;
  const _ChartSurface({
    super.key,
    required this.height,
    required this.count,
    required this.nearest,
    required this.anchor,
    required this.tooltip,
    required this.readout,
    required this.hint,
    required this.painter,
    required this.semanticLabel,
    this.order,
    this.onActive,
    this.horizontalScrub = true,
  });

  @override
  State<_ChartSurface> createState() => _ChartSurfaceState();
}

class _ChartSurfaceState extends State<_ChartSurface> {
  int? _pinned;
  int? _hover;
  bool _focused = false;
  final _node = FocusNode(debugLabel: 'chart');

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  int? get _active => _hover ?? _pinned;

  void _set({int? pinned, int? hover, bool clearPinned = false}) {
    final before = _active;
    setState(() {
      if (clearPinned) _pinned = null;
      if (pinned != null) _pinned = pinned;
      _hover = hover;
    });
    if (before != _active) widget.onActive?.call(_active);
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final order = widget.order ?? List.generate(widget.count, (i) => i);
    if (order.isEmpty) return KeyEventResult.ignored;
    final cur = _active == null ? -1 : order.indexOf(_active!);
    final k = event.logicalKey;
    int? next;
    if (k == LogicalKeyboardKey.arrowRight ||
        k == LogicalKeyboardKey.arrowDown) {
      next = order[(cur + 1) % order.length];
    } else if (k == LogicalKeyboardKey.arrowLeft ||
        k == LogicalKeyboardKey.arrowUp) {
      next = order[cur <= 0 ? order.length - 1 : cur - 1];
    } else if (k == LogicalKeyboardKey.home) {
      next = order.first;
    } else if (k == LogicalKeyboardKey.end) {
      next = order.last;
    } else if (k == LogicalKeyboardKey.escape) {
      _set(clearPinned: true);
      return KeyEventResult.handled;
    } else {
      return KeyEventResult.ignored;
    }
    _set(pinned: next);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final active = _active;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, c) {
            final size = Size(c.maxWidth, widget.height);
            final ring =
                _focused &&
                FocusManager.instance.highlightMode ==
                    FocusHighlightMode.traditional;
            return Semantics(
              container: true,
              label: widget.semanticLabel,
              child: ExcludeSemantics(
                child: Focus(
                  focusNode: _node,
                  onKeyEvent: _key,
                  onFocusChange: (f) => setState(() => _focused = f),
                  child: MouseRegion(
                    onHover: (e) =>
                        _set(hover: widget.nearest(e.localPosition, size)),
                    onExit: (_) => _set(),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (d) {
                        _node.requestFocus();
                        final i = widget.nearest(d.localPosition, size);
                        i == null ? _set(clearPinned: true) : _set(pinned: i);
                      },
                      onHorizontalDragUpdate: widget.horizontalScrub
                          ? (d) {
                              final i = widget.nearest(d.localPosition, size);
                              if (i != null) _set(pinned: i);
                            }
                          : null,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          border: Border.all(
                            color: ring ? AppColors.brand : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: SizedBox(
                          width: size.width,
                          height: size.height,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned.fill(
                                child: RepaintBoundary(
                                  child: ChartGrowIn(
                                    builder: (t) => CustomPaint(
                                      painter: widget.painter(t, active, size),
                                    ),
                                  ),
                                ),
                              ),
                              if (active != null && active < widget.count)
                                _Tooltip(
                                  text: widget.tooltip(active),
                                  anchor: widget.anchor(active, size),
                                  bounds: size,
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
          },
        ),
        const SizedBox(height: AppSpace.sm),
        Semantics(
          liveRegion: true,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 36),
            child: Text(
              active != null && active < widget.count
                  ? widget.readout(active)
                  : widget.hint,
              style: active != null ? AppText.bodyStrong : AppText.caption,
            ),
          ),
        ),
      ],
    );
  }
}

// ───────────────────────── legend ─────────────────────────

/// Colour + shape sample used in legends (never colour alone).
class ChartSwatch extends StatelessWidget {
  final Color color;
  final ChartShape shape;
  final bool hollow;
  const ChartSwatch({
    super.key,
    required this.color,
    this.shape = ChartShape.square,
    this.hollow = false,
  });

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size(16, 16),
    painter: _SwatchPainter(color, shape, hollow),
  );
}

class _SwatchPainter extends CustomPainter {
  final Color color;
  final ChartShape shape;
  final bool hollow;
  const _SwatchPainter(this.color, this.shape, this.hollow);

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()
      ..color = hollow ? AppColors.surface : color
      ..style = PaintingStyle.fill;
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    _paintMarker(
      canvas,
      size.center(Offset.zero),
      12,
      shape,
      fill,
      outline: line,
    );
  }

  @override
  bool shouldRepaint(_SwatchPainter o) =>
      o.color != color || o.shape != shape || o.hollow != hollow;
}

// ───────────────────────── bar chart ─────────────────────────

class BarDatum {
  final String label;
  final double value;

  /// Full description — tooltip and text readout ("22/9 · 8 bids").
  final String detail;
  const BarDatum(this.label, this.value, this.detail);
}

/// Vertical bars comparing counts across a dimension (periods, categories).
/// The latest — or the selected — bar is green, the rest muted grey; every
/// bar carries its value above it.
class AppBarChart extends StatelessWidget {
  final List<BarDatum> data;
  final String semanticLabel;
  final String hint;
  const AppBarChart({
    super.key,
    required this.data,
    required this.semanticLabel,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final maxV = data.map((d) => d.value).fold<double>(0, math.max);
    final ticks = niceTicks(maxV);
    final yMax = ticks.last;
    return _ChartSurface(
      key: ValueKey(Object.hashAll(data.map((d) => d.detail))),
      height: AppChart.height,
      count: data.length,
      semanticLabel: '$semanticLabel: ${data.map((d) => d.detail).join('; ')}',
      hint: hint,
      nearest: (p, size) {
        final a = _plotArea(size);
        if (p.dx < a.left - 8 || p.dx > a.right + 8) return null;
        final slot = a.width / data.length;
        return ((p.dx - a.left) / slot).floor().clamp(0, data.length - 1);
      },
      anchor: (i, size) {
        final a = _plotArea(size);
        final slot = a.width / data.length;
        final h = data[i].value / yMax * a.height;
        return Offset(a.left + slot * (i + 0.5), a.bottom - h - 18);
      },
      tooltip: (i) => data[i].detail,
      readout: (i) => data[i].detail,
      painter: (t, active, size) => _BarPainter(data, ticks, yMax, t, active),
    );
  }
}

class _BarPainter extends CustomPainter {
  final List<BarDatum> data;
  final List<double> ticks;
  final double yMax;
  final double t;
  final int? active;
  const _BarPainter(this.data, this.ticks, this.yMax, this.t, this.active);

  @override
  void paint(Canvas canvas, Size size) {
    final a = _plotArea(size);
    _paintYGrid(canvas, a, ticks, yMax, 0, (v) => v.round().toString());
    final slot = a.width / data.length;
    final barW = math.min(slot * 0.55, 44.0);
    final hi = active ?? data.length - 1;
    for (var i = 0; i < data.length; i++) {
      final cx = a.left + slot * (i + 0.5);
      final h = data[i].value / yMax * a.height * t;
      final rect = Rect.fromLTWH(cx - barW / 2, a.bottom - h, barW, h);
      final rr = RRect.fromRectAndCorners(
        rect,
        topLeft: const Radius.circular(AppChart.barRadius),
        topRight: const Radius.circular(AppChart.barRadius),
      );
      canvas.drawRRect(
        rr,
        Paint()..color = i == hi ? AppChart.series[0] : AppChart.muted,
      );
      if (i == active) {
        canvas.drawRRect(
          rr.inflate(2),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = AppColors.ink,
        );
      }
      if (t > 0.6) {
        _label(
          canvas,
          data[i].value.round().toString(),
          Offset(cx, a.bottom - h - 4),
          style: AppText.tick.copyWith(
            color: i == hi ? AppChart.series[0] : AppColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
          anchorY: 1,
        );
      }
      _label(
        canvas,
        data[i].label,
        Offset(cx, a.bottom + 8),
        style: i == active
            ? AppText.tick.copyWith(
                color: AppColors.ink,
                fontWeight: FontWeight.w700,
              )
            : AppText.tick,
      );
    }
  }

  @override
  bool shouldRepaint(_BarPainter o) =>
      o.t != t || o.active != active || o.data != data;
}

// ───────────────────────── line chart ─────────────────────────

class LineDatum {
  final String label;
  final double value;
  final double? previous;
  final String detail;
  const LineDatum(this.label, this.value, this.detail, {this.previous});
}

/// A value over time as a line with point markers; an optional dashed line
/// shows the previous period for comparison.
class AppLineChart extends StatelessWidget {
  final List<LineDatum> data;
  final String semanticLabel;
  final String hint;
  const AppLineChart({
    super.key,
    required this.data,
    required this.semanticLabel,
    required this.hint,
  });

  bool get _hasPrev => data.any((d) => d.previous != null);

  @override
  Widget build(BuildContext context) {
    final maxV = data
        .expand((d) => [d.value, d.previous ?? 0])
        .fold<double>(0, math.max);
    final ticks = niceTicks(maxV);
    final yMax = ticks.last;
    Offset pt(int i, Size size, double v) {
      final a = _plotArea(size);
      final slot = a.width / data.length;
      return Offset(a.left + slot * (i + 0.5), a.bottom - v / yMax * a.height);
    }

    return _ChartSurface(
      key: ValueKey(Object.hashAll(data.map((d) => d.detail))),
      height: AppChart.height,
      count: data.length,
      semanticLabel: '$semanticLabel: ${data.map((d) => d.detail).join('; ')}',
      hint: hint,
      nearest: (p, size) {
        int? best;
        var bd = double.infinity;
        for (var i = 0; i < data.length; i++) {
          final d = (pt(i, size, data[i].value).dx - p.dx).abs();
          if (d < bd) {
            bd = d;
            best = i;
          }
        }
        return bd <= AppChart.hitRadius * 1.6 ? best : null;
      },
      anchor: (i, size) => pt(i, size, data[i].value),
      tooltip: (i) => data[i].detail,
      readout: (i) => data[i].detail,
      painter: (t, active, size) =>
          _LinePainter(data, ticks, yMax, t, active, _hasPrev),
    );
  }
}

class _LinePainter extends CustomPainter {
  final List<LineDatum> data;
  final List<double> ticks;
  final double yMax;
  final double t;
  final int? active;
  final bool hasPrev;
  const _LinePainter(
    this.data,
    this.ticks,
    this.yMax,
    this.t,
    this.active,
    this.hasPrev,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final a = _plotArea(size);
    _paintYGrid(canvas, a, ticks, yMax, 0, (v) => v.round().toString());
    final slot = a.width / data.length;
    Offset pt(int i, double v) =>
        Offset(a.left + slot * (i + 0.5), a.bottom - v / yMax * a.height);

    void stroke(List<Offset> pts, Paint paint, {bool dashed = false}) {
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (final p in pts.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      for (final m in path.computeMetrics()) {
        final len = m.length * t;
        if (!dashed) {
          canvas.drawPath(m.extractPath(0, len), paint);
        } else {
          var d = 0.0;
          while (d < len) {
            canvas.drawPath(m.extractPath(d, math.min(d + 6, len)), paint);
            d += 11;
          }
        }
      }
    }

    if (hasPrev) {
      final prev = [
        for (var i = 0; i < data.length; i++) pt(i, data[i].previous ?? 0),
      ];
      stroke(
        prev,
        Paint()
          ..color = AppChart.muted
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
        dashed: true,
      );
    }
    final pts = [for (var i = 0; i < data.length; i++) pt(i, data[i].value)];
    stroke(
      pts,
      Paint()
        ..color = AppChart.series[0]
        ..style = PaintingStyle.stroke
        ..strokeWidth = AppChart.lineStroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    final last = data.length - 1;
    for (var i = 0; i < pts.length; i++) {
      if (t < (i + 1) / data.length * 0.98 && t < 1) continue;
      final on = i == active;
      final filled = on || (active == null && i == last);
      _paintMarker(
        canvas,
        pts[i],
        on ? AppChart.markerSelected : AppChart.markerSize,
        ChartShape.circle,
        Paint()..color = filled ? AppChart.series[0] : AppColors.surface,
        outline: Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = on ? 3 : 2.2
          ..color = on ? AppColors.ink : AppChart.series[0],
      );
      _label(
        canvas,
        data[i].label,
        Offset(pts[i].dx, a.bottom + 8),
        style: on
            ? AppText.tick.copyWith(
                color: AppColors.ink,
                fontWeight: FontWeight.w700,
              )
            : AppText.tick,
      );
    }
  }

  @override
  bool shouldRepaint(_LinePainter o) =>
      o.t != t || o.active != active || o.data != data;
}

/// Legend line for a two-series line chart (current vs previous).
class LineLegend extends StatelessWidget {
  final String current;
  final String previous;
  const LineLegend({super.key, required this.current, required this.previous});

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: AppSpace.xl,
    runSpacing: AppSpace.sm,
    children: [
      _LineKey(color: AppChart.series[0], label: current, dashed: false),
      _LineKey(color: AppChart.muted, label: previous, dashed: true),
    ],
  );
}

class _LineKey extends StatelessWidget {
  final Color color;
  final String label;
  final bool dashed;
  const _LineKey({
    required this.color,
    required this.label,
    required this.dashed,
  });

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      CustomPaint(
        size: const Size(28, 10),
        painter: _KeyPainter(color, dashed),
      ),
      const SizedBox(width: AppSpace.sm),
      Text(label, style: AppText.caption),
    ],
  );
}

class _KeyPainter extends CustomPainter {
  final Color color;
  final bool dashed;
  const _KeyPainter(this.color, this.dashed);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final y = size.height / 2;
    if (!dashed) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    } else {
      for (var x = 0.0; x < size.width; x += 9) {
        canvas.drawLine(
          Offset(x, y),
          Offset(math.min(x + 5, size.width), y),
          p,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_KeyPainter o) => o.color != color || o.dashed != dashed;
}

// ───────────────────────── pie chart ─────────────────────────

class PieDatum {
  final String label;
  final double value;
  final int series; // index into AppChart.series
  const PieDatum(this.label, this.value, this.series);
}

/// Composition of a whole: pie + total + a legend that doubles as the
/// control — tap a row to hide/show that category (shares recompute).
/// Slices are labelled with their percentage; the legend lists each
/// category's count and share, and the total.
class AppPieChart extends StatefulWidget {
  final List<PieDatum> data;
  final String totalLabel;
  final String totalWord;
  final String semanticLabel;
  final String hint;
  final String hideHint;
  final String Function(PieDatum d, int pct) detail;
  const AppPieChart({
    super.key,
    required this.data,
    required this.totalLabel,
    required this.totalWord,
    required this.semanticLabel,
    required this.hint,
    required this.hideHint,
    required this.detail,
  });

  @override
  State<AppPieChart> createState() => _AppPieChartState();
}

class _AppPieChartState extends State<AppPieChart> {
  final _hidden = <int>{};
  int? _active; // index into data

  List<int> get _visible => [
    for (var i = 0; i < widget.data.length; i++)
      if (!_hidden.contains(i)) i,
  ];

  @override
  Widget build(BuildContext context) {
    final vis = _visible;
    final values = [for (final i in vis) widget.data[i].value];
    final pcts = percentages(values);
    final total = values.fold<double>(0, (a, b) => a + b);
    final allPct = <int, int>{
      for (var k = 0; k < vis.length; k++) vis[k]: pcts[k],
    };
    // angle ranges for visible slices
    final ranges = <(double, double)>[];
    var start = -math.pi / 2;
    for (final v in values) {
      final sweep = total <= 0 ? 0.0 : v / total * 2 * math.pi;
      ranges.add((start, sweep));
      start += sweep;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Text(
            '${widget.totalLabel} ${total.round()} ${widget.totalWord}',
            style: AppText.h2,
          ),
        ),
        const SizedBox(height: AppSpace.lg),
        _ChartSurface(
          key: ValueKey(vis.join(',')),
          height: 260,
          count: vis.length,
          horizontalScrub: false,
          semanticLabel:
              '${widget.semanticLabel}: ${[for (final i in vis) widget.detail(widget.data[i], allPct[i]!)].join('; ')}',
          hint: widget.hint,
          onActive: (a) => setState(() => _active = a == null ? null : vis[a]),
          nearest: (p, size) {
            final c = size.center(Offset.zero);
            final r = math.min(size.width, size.height) / 2 - 12;
            final d = p - c;
            if (d.distance > r + 8 || vis.isEmpty) return null;
            var ang = math.atan2(d.dy, d.dx);
            if (ang < -math.pi / 2) ang += 2 * math.pi;
            for (var k = 0; k < ranges.length; k++) {
              final (s, sw) = ranges[k];
              var a0 = s;
              if (a0 < -math.pi / 2) a0 += 2 * math.pi;
              if (ang >= a0 && ang <= a0 + sw) return k;
            }
            return ranges.isEmpty ? null : ranges.length - 1;
          },
          anchor: (k, size) {
            final c = size.center(Offset.zero);
            final r = math.min(size.width, size.height) / 2 - 12;
            final (s, sw) = ranges[k];
            final mid = s + sw / 2;
            return c + Offset(math.cos(mid), math.sin(mid)) * (r * 0.72);
          },
          tooltip: (k) => widget.detail(widget.data[vis[k]], allPct[vis[k]]!),
          readout: (k) => widget.detail(widget.data[vis[k]], allPct[vis[k]]!),
          painter: (t, active, size) => _PiePainter(
            [for (final i in vis) widget.data[i]],
            ranges,
            [for (final i in vis) allPct[i]!],
            t,
            active,
          ),
        ),
        const SizedBox(height: AppSpace.md),
        const Divider(),
        for (var i = 0; i < widget.data.length; i++)
          _LegendRow(
            datum: widget.data[i],
            pct: allPct[i],
            hidden: _hidden.contains(i),
            highlighted: _active == i,
            canHide: _hidden.contains(i) || vis.length > 1,
            onToggle: () => setState(() {
              HapticFeedback.selectionClick();
              if (_hidden.contains(i)) {
                _hidden.remove(i);
              } else if (vis.length > 1) {
                _hidden.add(i);
              }
              _active = null;
            }),
            hideHint: widget.hideHint,
          ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
          child: Row(
            children: [
              Expanded(
                child: Text(widget.totalLabel, style: AppText.bodyStrong),
              ),
              Text('${total.round()}', style: AppText.bodyStrong),
              const SizedBox(width: 56),
            ],
          ),
        ),
      ],
    );
  }
}

class _LegendRow extends StatelessWidget {
  final PieDatum datum;
  final int? pct;
  final bool hidden;
  final bool highlighted;
  final bool canHide;
  final VoidCallback onToggle;
  final String hideHint;
  const _LegendRow({
    required this.datum,
    required this.pct,
    required this.hidden,
    required this.highlighted,
    required this.canHide,
    required this.onToggle,
    required this.hideHint,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppChart.series[datum.series % AppChart.series.length];
    final shape = ChartShape.values[datum.series % ChartShape.values.length];
    return Semantics(
      button: true,
      toggled: !hidden,
      enabled: canHide,
      label:
          '${datum.label}, ${datum.value.round()}${pct == null ? '' : ', $pct%'}',
      hint: hideHint,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: canHide ? onToggle : null,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Container(
            constraints: const BoxConstraints(minHeight: AppSize.tap),
            decoration: BoxDecoration(
              color: highlighted ? AppColors.surfaceMuted : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.xs),
            child: Row(
              children: [
                ChartSwatch(color: color, shape: shape, hollow: hidden),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Text(
                    datum.label,
                    style: AppText.body.copyWith(
                      color: hidden ? AppColors.textSecondary : AppColors.ink,
                      decoration: hidden ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                Text(
                  hidden ? '—' : '${datum.value.round()} · $pct%',
                  style: AppText.bodyStrong.copyWith(
                    color: hidden ? AppColors.textSecondary : AppColors.ink,
                  ),
                ),
                const SizedBox(width: AppSpace.sm),
                Icon(
                  hidden
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: AppIconSize.sm + 2,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PiePainter extends CustomPainter {
  final List<PieDatum> data;
  final List<(double, double)> ranges;
  final List<int> pcts;
  final double t;
  final int? active;
  const _PiePainter(this.data, this.ranges, this.pcts, this.t, this.active);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = math.min(size.width, size.height) / 2 - 12;
    for (var k = 0; k < data.length; k++) {
      final (start, sweep) = ranges[k];
      final s = sweep * t;
      final mid = start + sweep / 2;
      final pop = k == active ? 8.0 : 0.0;
      final center = c + Offset(math.cos(mid), math.sin(mid)) * pop;
      final color = AppChart.series[data[k].series % AppChart.series.length];
      final dim = active != null && k != active;
      final rect = Rect.fromCircle(center: center, radius: r);
      canvas.drawArc(
        rect,
        start,
        s,
        true,
        Paint()..color = dim ? color.withValues(alpha: 0.45) : color,
      );
      if (data.length > 1) {
        canvas.drawArc(
          rect,
          start,
          s,
          true,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = AppColors.surface,
        );
      }
      if (t > 0.9 && sweep > 0.42) {
        _label(
          canvas,
          '${pcts[k]}%',
          center + Offset(math.cos(mid), math.sin(mid)) * (r * 0.62),
          style: AppText.label.copyWith(fontSize: 14, color: AppColors.surface),
          anchorY: 0.5,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_PiePainter o) =>
      o.t != t || o.active != active || o.data != data || o.ranges != ranges;
}

// ───────────────────────── scatter plot ─────────────────────────

class ScatterPoint {
  final double x;
  final double y;
  final int group; // index into groups
  final String detail;
  const ScatterPoint(this.x, this.y, this.group, this.detail);
}

class ScatterGroup {
  final String label;
  final int series;
  const ScatterGroup(this.label, this.series);
}

/// Individual observations on two numeric axes (bid value vs profile
/// match). Group = colour + marker shape. Select a point for its details.
class AppScatterChart extends StatelessWidget {
  final List<ScatterPoint> points;
  final List<ScatterGroup> groups;
  final double yMin;
  final double yMax;
  final String Function(double) yFormat;
  final String xTitle;
  final String yTitle;
  final String semanticLabel;
  final String hint;
  const AppScatterChart({
    super.key,
    required this.points,
    required this.groups,
    required this.yMin,
    required this.yMax,
    required this.yFormat,
    required this.xTitle,
    required this.yTitle,
    required this.semanticLabel,
    required this.hint,
  });

  static const _insets = EdgeInsets.fromLTRB(60, 14, 14, 34);

  @override
  Widget build(BuildContext context) {
    final maxX = points.map((p) => p.x).fold<double>(0, math.max);
    final xTicks = niceTicks(maxX * 1.05, target: 4);
    final xMax = xTicks.last;
    final yTicks = <double>[
      for (var v = yMin; v <= yMax + 0.001; v += (yMax - yMin) / 4) v,
    ];
    Offset pos(ScatterPoint p, Size size) {
      final a = _plotArea(size, insets: _insets);
      return Offset(
        a.left + p.x / xMax * a.width,
        a.bottom - (p.y - yMin) / (yMax - yMin) * a.height,
      );
    }

    final order = List.generate(points.length, (i) => i)
      ..sort((a, b) => points[a].x.compareTo(points[b].x));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ChartSurface(
          key: ValueKey(Object.hashAll(points.map((p) => p.detail))),
          height: 300,
          count: points.length,
          order: order,
          horizontalScrub: false,
          semanticLabel:
              '$semanticLabel: ${points.map((p) => p.detail).join('; ')}',
          hint: hint,
          nearest: (p, size) {
            int? best;
            var bd = double.infinity;
            for (var i = 0; i < points.length; i++) {
              final d = (pos(points[i], size) - p).distance;
              if (d < bd) {
                bd = d;
                best = i;
              }
            }
            return bd <= AppChart.hitRadius ? best : null;
          },
          anchor: (i, size) => pos(points[i], size),
          tooltip: (i) => points[i].detail,
          readout: (i) => points[i].detail,
          painter: (t, active, size) => _ScatterPainter(
            points,
            groups,
            xTicks,
            xMax,
            yTicks,
            yMin,
            yMax,
            yFormat,
            xTitle,
            yTitle,
            t,
            active,
            _insets,
          ),
        ),
        const SizedBox(height: AppSpace.sm),
        Wrap(
          spacing: AppSpace.lg,
          runSpacing: AppSpace.xs,
          children: [
            for (final g in groups)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ChartSwatch(
                    color: AppChart.series[g.series % AppChart.series.length],
                    shape:
                        ChartShape.values[g.series % ChartShape.values.length],
                  ),
                  const SizedBox(width: AppSpace.xs + 2),
                  Flexible(child: Text(g.label, style: AppText.caption)),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class _ScatterPainter extends CustomPainter {
  final List<ScatterPoint> points;
  final List<ScatterGroup> groups;
  final List<double> xTicks;
  final double xMax;
  final List<double> yTicks;
  final double yMin;
  final double yMax;
  final String Function(double) yFormat;
  final String xTitle;
  final String yTitle;
  final double t;
  final int? active;
  final EdgeInsets insets;
  const _ScatterPainter(
    this.points,
    this.groups,
    this.xTicks,
    this.xMax,
    this.yTicks,
    this.yMin,
    this.yMax,
    this.yFormat,
    this.xTitle,
    this.yTitle,
    this.t,
    this.active,
    this.insets,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final a = _plotArea(size, insets: insets);
    _paintYGrid(canvas, a, yTicks, yMax, yMin, yFormat);
    final grid = Paint()
      ..color = AppChart.grid
      ..strokeWidth = AppChart.gridStroke;
    for (final v in xTicks) {
      final x = a.left + v / xMax * a.width;
      if (v > 0) canvas.drawLine(Offset(x, a.top), Offset(x, a.bottom), grid);
      _label(canvas, moneyCompact(v), Offset(x, a.bottom + 8));
    }
    canvas.drawLine(
      Offset(a.left, a.top),
      Offset(a.left, a.bottom),
      Paint()
        ..color = AppChart.axis
        ..strokeWidth = AppChart.axisStroke,
    );
    // axis titles
    _label(
      canvas,
      xTitle,
      Offset(a.center.dx, size.height - 2),
      style: AppText.tick.copyWith(fontWeight: FontWeight.w700),
      anchorY: 1,
    );
    canvas.save();
    canvas.translate(10, a.center.dy);
    canvas.rotate(-math.pi / 2);
    _label(
      canvas,
      yTitle,
      Offset.zero,
      style: AppText.tick.copyWith(fontWeight: FontWeight.w700),
      anchorY: 0.5,
    );
    canvas.restore();

    // points (selected last so it sits on top)
    final idx = List.generate(points.length, (i) => i)
      ..sort((x, y) => (x == active ? 1 : 0).compareTo(y == active ? 1 : 0));
    for (final i in idx) {
      final p = points[i];
      final g = groups[p.group];
      final color = AppChart.series[g.series % AppChart.series.length];
      final shape = ChartShape.values[g.series % ChartShape.values.length];
      final o = Offset(
        a.left + p.x / xMax * a.width,
        a.bottom - (p.y - yMin) / (yMax - yMin) * a.height,
      );
      final on = i == active;
      _paintMarker(
        canvas,
        o,
        (on ? AppChart.markerSelected : AppChart.markerSize) * t,
        shape,
        Paint()..color = color.withValues(alpha: on ? 1 : 0.85),
        outline: Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = on ? 2.5 : 1.5
          ..color = on ? AppColors.ink : AppColors.surface,
      );
    }
  }

  @override
  bool shouldRepaint(_ScatterPainter o) =>
      o.t != t || o.active != active || o.points != points;
}
