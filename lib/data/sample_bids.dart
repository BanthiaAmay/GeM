import 'dart:math' as math;

/// Illustrative sample opportunities that feed the Insights and Search screens.
///
/// The app has no live GeM bid feed. Every screen that shows these bids must
/// display the "Illustrative data" caption. Swap [SampleBidSource] (in
/// `search/bid_source.dart`) for a real feed and the UI stays the same.
class SampleBid {
  /// Stable pseudo-ID — never a real GeM bid number.
  final String id;

  /// Category key from `categories` in core/models.dart.
  final String category;
  final int postedDaysAgo;
  final int closesInDays;
  final int valueRs;
  final int matchPct;

  // ── Named-bid enrichment (null on procedurally generated bids) ──
  final String? titleEn;
  final String? titleHi;
  final String? department;

  /// ISO state code or plain name; illustrative.
  final String? state;
  final String? district;
  final String? items;

  /// Whether this bid's eligibility requires bank details (drives checklist).
  final bool needsBankDetails;

  /// Whether a bank guarantee is mentioned in illustrative tender terms.
  final bool needsBG;
  final bool mseRelaxation;
  final bool emdExemption;

  /// 0–100 opportunity score. Falls back to [matchPct] if null.
  final int? score;

  const SampleBid({
    required this.id,
    required this.category,
    required this.postedDaysAgo,
    required this.closesInDays,
    required this.valueRs,
    required this.matchPct,
    this.titleEn,
    this.titleHi,
    this.department,
    this.state,
    this.district,
    this.items,
    this.needsBankDetails = false,
    this.needsBG = false,
    this.mseRelaxation = false,
    this.emdExemption = false,
    this.score,
  });

  bool get open => closesInDays >= 0;

  /// Effective opportunity score (falls back to matchPct).
  int get effectiveScore => score ?? matchPct;

  String get displayTitle => titleEn ?? _categoryLabel[category] ?? 'Tender';

  static const _categoryLabel = {
    'office': 'Office supplies tender',
    'it': 'IT equipment tender',
    'furniture': 'Furniture tender',
    'cleaning': 'Cleaning supplies tender',
    'other': 'Miscellaneous tender',
  };
}

/// Fixed, curated list of named illustrative bids used by Search and the Home
/// "Recommended for you" card. Deterministic and always labelled illustrative.
const List<SampleBid> kNamedBids = [
  SampleBid(
    id: 'NAMED-001',
    category: 'office',
    postedDaysAgo: 3,
    closesInDays: 1,
    valueRs: 850000,
    matchPct: 92,
    score: 92,
    titleEn: 'Office stationery supplies',
    titleHi: 'कार्यालय स्टेशनरी आपूर्ति',
    department: 'Department of Education',
    state: 'Delhi',
    district: 'New Delhi',
    items: 'Notebooks, pens, files, paper, etc.',
    needsBankDetails: true,
    mseRelaxation: true,
    emdExemption: true,
  ),
  SampleBid(
    id: 'NAMED-002',
    category: 'it',
    postedDaysAgo: 5,
    closesInDays: 14,
    valueRs: 3200000,
    matchPct: 85,
    score: 85,
    titleEn: 'IT hardware procurement',
    titleHi: 'आईटी हार्डवेयर खरीद',
    department: 'Ministry of Electronics and Information Technology',
    state: 'Maharashtra',
    district: 'Mumbai',
    items: 'Laptops, desktops, printers',
    needsBankDetails: false,
    needsBG: true,
    mseRelaxation: true,
  ),
  SampleBid(
    id: 'NAMED-003',
    category: 'cleaning',
    postedDaysAgo: 8,
    closesInDays: 22,
    valueRs: 420000,
    matchPct: 79,
    score: 79,
    titleEn: 'Cleaning supplies',
    titleHi: 'सफाई सामग्री',
    department: 'Department of Health',
    state: 'Maharashtra',
    district: 'Pune',
    items: 'Disinfectants, mops, brooms',
    emdExemption: true,
  ),
  SampleBid(
    id: 'NAMED-004',
    category: 'furniture',
    postedDaysAgo: 2,
    closesInDays: 7,
    valueRs: 1500000,
    matchPct: 74,
    score: 74,
    titleEn: 'School furniture — desks and chairs',
    titleHi: 'विद्यालय फर्नीचर — डेस्क और कुर्सियाँ',
    department: 'Department of School Education',
    state: 'Maharashtra',
    district: 'Nagpur',
    items: 'Single-seater school desks, chairs',
    mseRelaxation: true,
    emdExemption: true,
  ),
  SampleBid(
    id: 'NAMED-005',
    category: 'it',
    postedDaysAgo: 10,
    closesInDays: 30,
    valueRs: 9500000,
    matchPct: 68,
    score: 68,
    titleEn: 'LED tube lights — pan India',
    titleHi: 'LED ट्यूब लाइट — सर्व भारत',
    department: 'Ministry of Power',
    state: 'Pan India',
    district: '',
    items: 'LED 20W tube lights, ISI marked',
    needsBG: true,
  ),
  SampleBid(
    id: 'NAMED-006',
    category: 'office',
    postedDaysAgo: 1,
    closesInDays: 3,
    valueRs: 280000,
    matchPct: 88,
    score: 88,
    titleEn: 'Printer cartridges and toner',
    titleHi: 'प्रिंटर कारतूस और टोनर',
    department: 'Central Secretariat',
    state: 'Delhi',
    district: 'New Delhi',
    items: 'HP, Canon, Brother compatible cartridges',
    emdExemption: true,
    mseRelaxation: true,
  ),
  SampleBid(
    id: 'NAMED-007',
    category: 'furniture',
    postedDaysAgo: 6,
    closesInDays: 18,
    valueRs: 620000,
    matchPct: 71,
    score: 71,
    titleEn: 'Office chairs — ergonomic',
    titleHi: 'कार्यालय कुर्सियाँ — एर्गोनोमिक',
    department: 'National Informatics Centre',
    state: 'Delhi',
    district: 'New Delhi',
    items: 'Mesh-back adjustable office chairs',
  ),
  SampleBid(
    id: 'NAMED-008',
    category: 'other',
    postedDaysAgo: 4,
    closesInDays: 10,
    valueRs: 750000,
    matchPct: 65,
    score: 65,
    titleEn: 'Hand sanitiser and PPE kits',
    titleHi: 'हैंड सैनिटाइज़र और PPE किट',
    department: 'Department of Health and Family Welfare',
    state: 'Maharashtra',
    district: 'Pune',
    items: '500 ml sanitiser bottles, 3-layer masks',
    emdExemption: true,
    needsBankDetails: true,
  ),
];

abstract final class SampleBids {
  /// 180 days of procedurally generated sample matches — for Insights charts.
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
