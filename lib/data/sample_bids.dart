import 'dart:math' as math;

/// Illustrative sample opportunities that feed the Insights screens.
///
/// The app has no live GeM bid feed yet (the Bids tab is a preview too), so
/// Insights runs on this deterministic sample and every screen labels it
/// "Illustrative data". Swap [SampleBids.build] for a real source and the
/// charts keep working — they only depend on [SampleBid].
class SampleBid {
  /// Stable pseudo-ID shown in tooltips (never a real GeM bid number).
  final String id;

  /// A key of `categories` in core/models.dart.
  final String category;
  final int postedDaysAgo;
  final int closesInDays;
  final int valueRs;
  final int matchPct;
  const SampleBid({
    required this.id,
    required this.category,
    required this.postedDaysAgo,
    required this.closesInDays,
    required this.valueRs,
    required this.matchPct,
  });

  bool get open => closesInDays >= 0;
}

abstract final class SampleBids {
  /// 180 days of sample matches — enough for a 90-day window plus its
  /// previous 90 days for comparison. Deterministic (fixed seed) so charts
  /// don't reshuffle between visits.
  static List<SampleBid> build() {
    var seed = 20260927;
    double rnd() {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      return seed / 0x7fffffff;
    }

    const weights = <String, double>{
      'office': 0.30,
      'it': 0.22,
      'furniture': 0.18,
      'cleaning': 0.15,
      'other': 0.15,
    };
    String pick() {
      var r = rnd(), acc = 0.0;
      for (final e in weights.entries) {
        acc += e.value;
        if (r <= acc) return e.key;
      }
      return 'other';
    }

    final bids = <SampleBid>[];
    var n = 0;
    for (var d = 179; d >= 0; d--) {
      // Rising trend: recent days match more often.
      final p = 0.22 + 0.30 * (1 - d / 180);
      final count = (rnd() < p ? 1 : 0) + (rnd() < p * 0.35 ? 1 : 0);
      for (var i = 0; i < count; i++) {
        n++;
        final logV = rnd();
        final value = (40000 * math.pow(30, logV)).round() ~/ 1000 * 1000;
        final match = (60 + 30 * (0.45 * logV + 0.55 * rnd())).round();
        final duration = 5 + (rnd() * 26).round();
        bids.add(
          SampleBid(
            id: 'SAMPLE-${n.toString().padLeft(3, '0')}',
            category: pick(),
            postedDaysAgo: d,
            closesInDays: duration - d,
            valueRs: value,
            matchPct: match.clamp(58, 98),
          ),
        );
      }
    }
    return bids;
  }
}
