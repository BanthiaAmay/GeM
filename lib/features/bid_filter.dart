import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../core/tokens.dart';
import '../data/app_store.dart';

// ── Sort order ────────────────────────────────────────────────────────────────

enum BidSortOrder {
  closingSoonest,
  recentlyPublished,
  lowestEmd,
  highestEmd,
}

// ── Quick preset keys ────────────────────────────────────────────────────────

const kPresetMsme = 'msme_friendly';
const kPresetLowEmd = 'low_emd';
const kPresetNoEmd = 'no_emd';
const kPresetFirstTime = 'first_time';
const kPresetClosingSoon = 'closing_soon';
const kPresetMinimalDocs = 'minimal_docs';

// Map doc-filter key → [full label, short label]
const kDocFilters = <String, List<String>>{
  'iso': ['ISO Certificate', 'ISO'],
  'gst': ['GST Certificate', 'GST'],
  'msme': ['MSME / Udyam', 'MSME'],
  'nsic': ['NSIC Certificate', 'NSIC'],
  'oem': ['OEM Certificate', 'OEM'],
  'bis': ['BIS / BEE', 'BIS'],
  'fssai': ['FSSAI License', 'FSSAI'],
  'pan': ['PAN Card', 'PAN'],
  'experience': ['Experience Certificate', 'Exp.Cert'],
};

// ── Immutable filter state ────────────────────────────────────────────────────

class BidFilterState {
  final int? closingWithinDays;
  final DateTime? closingFrom;
  final DateTime? closingTo;
  final double? minEmd;
  final double? maxEmd;
  final bool noEmdOnly;
  final Set<String> docTypes;
  final Set<String> states;
  final Set<String> ministries;
  final Set<String> quickPresets;
  final BidSortOrder sortOrder;
  final String searchQuery;

  const BidFilterState({
    this.closingWithinDays,
    this.closingFrom,
    this.closingTo,
    this.minEmd,
    this.maxEmd,
    this.noEmdOnly = false,
    this.docTypes = const {},
    this.states = const {},
    this.ministries = const {},
    this.quickPresets = const {},
    this.sortOrder = BidSortOrder.closingSoonest,
    this.searchQuery = '',
  });

  static const empty = BidFilterState();

  int get activeCount {
    int n = quickPresets.length;
    if (closingWithinDays != null || closingFrom != null || closingTo != null) n++;
    if (noEmdOnly || minEmd != null || maxEmd != null) n++;
    if (docTypes.isNotEmpty) n++;
    if (states.isNotEmpty) n++;
    if (ministries.isNotEmpty) n++;
    return n;
  }

  bool get hasAny => activeCount > 0 || searchQuery.isNotEmpty;

  BidFilterState copyWith({
    int? closingWithinDays,
    bool clearClosingWithinDays = false,
    DateTime? closingFrom,
    bool clearClosingFrom = false,
    DateTime? closingTo,
    bool clearClosingTo = false,
    double? minEmd,
    bool clearMinEmd = false,
    double? maxEmd,
    bool clearMaxEmd = false,
    bool? noEmdOnly,
    Set<String>? docTypes,
    Set<String>? states,
    Set<String>? ministries,
    Set<String>? quickPresets,
    BidSortOrder? sortOrder,
    String? searchQuery,
  }) =>
      BidFilterState(
        closingWithinDays: clearClosingWithinDays
            ? null
            : (closingWithinDays ?? this.closingWithinDays),
        closingFrom:
            clearClosingFrom ? null : (closingFrom ?? this.closingFrom),
        closingTo: clearClosingTo ? null : (closingTo ?? this.closingTo),
        minEmd: clearMinEmd ? null : (minEmd ?? this.minEmd),
        maxEmd: clearMaxEmd ? null : (maxEmd ?? this.maxEmd),
        noEmdOnly: noEmdOnly ?? this.noEmdOnly,
        docTypes: docTypes ?? this.docTypes,
        states: states ?? this.states,
        ministries: ministries ?? this.ministries,
        quickPresets: quickPresets ?? this.quickPresets,
        sortOrder: sortOrder ?? this.sortOrder,
        searchQuery: searchQuery ?? this.searchQuery,
      );
}

// ── Pure filter + sort logic ──────────────────────────────────────────────────

class BidFilterLogic {
  static List<Map<String, dynamic>> apply(
    List<Map<String, dynamic>> bids,
    BidFilterState filter,
  ) {
    var result = bids.where((b) => _matches(b, filter)).toList();
    _sort(result, filter.sortOrder);
    return result;
  }

  static bool _matches(Map<String, dynamic> bid, BidFilterState f) {
    // Quick presets
    for (final preset in f.quickPresets) {
      if (!_matchesPreset(bid, preset)) return false;
    }

    // Closing date filters
    final closesAt = DateTime.tryParse(bid['closes_at'] as String? ?? '');
    if (closesAt != null) {
      final now = DateTime.now();
      if (f.closingWithinDays != null) {
        if (closesAt.isBefore(now)) return false;
        if (closesAt.isAfter(now.add(Duration(days: f.closingWithinDays!)))) {
          return false;
        }
      }
      if (f.closingFrom != null && closesAt.isBefore(f.closingFrom!)) return false;
      if (f.closingTo != null) {
        final to = f.closingTo!.add(const Duration(days: 1));
        if (closesAt.isAfter(to)) return false;
      }
    } else if (f.closingWithinDays != null || f.closingFrom != null) {
      return false;
    }

    // EMD filters
    final details = Map<String, dynamic>.from(bid['details'] as Map? ?? {});
    final emdStr = details['emd_amount'] as String? ?? '';
    final emdAmt = num.tryParse(emdStr);
    final noEmd = details['emd_required'] == 'No';

    if (f.noEmdOnly && !noEmd) return false;
    if (f.minEmd != null && emdAmt != null && emdAmt < f.minEmd!) return false;
    if (f.maxEmd != null && emdAmt != null && emdAmt > f.maxEmd!) return false;

    // Document-type filters (bid must require ALL selected doc types)
    if (f.docTypes.isNotEmpty) {
      final docs = List<String>.from(details['documents_required'] ?? [])
          .map((d) => d.toLowerCase())
          .toList();
      for (final key in f.docTypes) {
        if (!docs.any((d) => d.contains(key.toLowerCase()))) return false;
      }
    }

    // State filter
    if (f.states.isNotEmpty) {
      final state = (bid['state'] as String? ?? '').trim().toLowerCase();
      if (!f.states.any((s) => state.contains(s.toLowerCase()))) return false;
    }

    // Ministry filter
    if (f.ministries.isNotEmpty) {
      final ministry = (bid['ministry'] as String? ?? '').trim().toLowerCase();
      if (!f.ministries.any((m) => ministry.contains(m.toLowerCase()))) {
        return false;
      }
    }

    // Text search
    if (f.searchQuery.isNotEmpty) {
      final q = f.searchQuery.toLowerCase();
      final title = (bid['title'] as String? ?? '').toLowerCase();
      final id = (bid['source_id'] as String? ?? '').toLowerCase();
      final org = (bid['organisation'] as String? ?? '').toLowerCase();
      final buyer = (bid['buyer'] as String? ?? '').toLowerCase();
      if (!title.contains(q) &&
          !id.contains(q) &&
          !org.contains(q) &&
          !buyer.contains(q)) {
        return false;
      }
    }

    return true;
  }

  static bool _matchesPreset(Map<String, dynamic> bid, String preset) {
    final details = Map<String, dynamic>.from(bid['details'] as Map? ?? {});
    final emdStr = details['emd_amount'] as String? ?? '';
    final emdAmt = num.tryParse(emdStr);
    final noEmd = details['emd_required'] == 'No';
    final docs = List<String>.from(details['documents_required'] ?? []);
    final experience = (details['experience'] as String? ?? '').trim();
    final closesAt = DateTime.tryParse(bid['closes_at'] as String? ?? '');

    switch (preset) {
      case kPresetMsme:
        final lowEmd = noEmd || (emdAmt != null && emdAmt <= 100000);
        return lowEmd && docs.length <= 3 && experience.isEmpty;
      case kPresetLowEmd:
        return noEmd || (emdAmt != null && emdAmt <= 100000);
      case kPresetNoEmd:
        return noEmd;
      case kPresetFirstTime:
        return experience.isEmpty && docs.length <= 3;
      case kPresetClosingSoon:
        if (closesAt == null) return false;
        final now = DateTime.now();
        return closesAt.isAfter(now) &&
            closesAt.isBefore(now.add(const Duration(days: 7)));
      case kPresetMinimalDocs:
        return docs.length <= 2;
      default:
        return true;
    }
  }

  static void _sort(
      List<Map<String, dynamic>> bids, BidSortOrder order) {
    switch (order) {
      case BidSortOrder.closingSoonest:
        bids.sort((a, b) {
          final ad = DateTime.tryParse(a['closes_at'] as String? ?? '');
          final bd = DateTime.tryParse(b['closes_at'] as String? ?? '');
          if (ad == null && bd == null) return 0;
          if (ad == null) return 1;
          if (bd == null) return -1;
          return ad.compareTo(bd);
        });
      case BidSortOrder.recentlyPublished:
        bids.sort((a, b) {
          final ad = DateTime.tryParse(a['starts_at'] as String? ?? '');
          final bd = DateTime.tryParse(b['starts_at'] as String? ?? '');
          if (ad == null && bd == null) return 0;
          if (ad == null) return 1;
          if (bd == null) return -1;
          return bd.compareTo(ad);
        });
      case BidSortOrder.lowestEmd:
        bids.sort((a, b) => _emdVal(a).compareTo(_emdVal(b)));
      case BidSortOrder.highestEmd:
        bids.sort((a, b) => _emdVal(b).compareTo(_emdVal(a)));
    }
  }

  static double _emdVal(Map<String, dynamic> bid) {
    final d = Map<String, dynamic>.from(bid['details'] as Map? ?? {});
    if (d['emd_required'] == 'No') return -1;
    return num.tryParse(d['emd_amount'] as String? ?? '')?.toDouble() ??
        double.maxFinite;
  }

  static List<String> uniqueStates(List<Map<String, dynamic>> bids) {
    final set = <String>{};
    for (final b in bids) {
      final s = (b['state'] as String? ?? '').trim();
      if (s.isNotEmpty) set.add(s);
    }
    return set.toList()..sort();
  }

  static List<String> uniqueMinistries(List<Map<String, dynamic>> bids) {
    final set = <String>{};
    for (final b in bids) {
      final m = (b['ministry'] as String? ?? '').trim();
      if (m.isNotEmpty) set.add(m);
    }
    return set.toList()..sort();
  }
}

// ── Opportunity indicator chips on bid cards ──────────────────────────────────

class BidOpportunityIndicators extends StatelessWidget {
  final Map<String, dynamic> bid;
  final AppStore store;
  const BidOpportunityIndicators({
    super.key,
    required this.bid,
    required this.store,
  });

  @override
  Widget build(BuildContext context) {
    final s = store;
    final details = Map<String, dynamic>.from(bid['details'] as Map? ?? {});
    final emdStr = details['emd_amount'] as String? ?? '';
    final emdAmt = num.tryParse(emdStr);
    final noEmd = details['emd_required'] == 'No';
    final docs = List<String>.from(details['documents_required'] ?? []);
    final experience = (details['experience'] as String? ?? '').trim();

    final chips = <(String, Color, Color)>[];

    if (noEmd) {
      chips.add((
        s.t('No EMD', 'EMD नहीं'),
        AppColors.brandTint,
        AppColors.brand,
      ));
    } else if (emdAmt != null && emdAmt <= 100000) {
      chips.add((
        s.t('Low EMD', 'कम EMD'),
        AppColors.brandTint,
        AppColors.brand,
      ));
    }

    if (experience.isEmpty && docs.length <= 3) {
      chips.add((
        s.t('MSME Friendly', 'MSME अनुकूल'),
        AppColors.infoTint,
        AppColors.info,
      ));
    }

    if (docs.length <= 2) {
      chips.add((
        s.t('Minimal Docs', 'कम दस्तावेज़'),
        AppColors.warningTint,
        AppColors.warning,
      ));
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: AppSpace.xs,
      runSpacing: AppSpace.xs,
      children: [
        for (final chip in chips)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.sm,
              vertical: 3,
            ),
            decoration: BoxDecoration(
              color: chip.$2,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              chip.$1,
              style: AppText.label.copyWith(color: chip.$3, fontSize: 10),
            ),
          ),
      ],
    );
  }
}

// ── Active filter chip bar ────────────────────────────────────────────────────

class ActiveFilterChips extends StatelessWidget {
  final BidFilterState filter;
  final AppStore store;
  final ValueChanged<BidFilterState> onChanged;

  const ActiveFilterChips({
    super.key,
    required this.filter,
    required this.store,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final s = store;
    final chips = <(String, VoidCallback)>[];

    // Quick presets
    final presetLabels = <String, String>{
      kPresetMsme: s.t('MSME Friendly', 'MSME अनुकूल'),
      kPresetLowEmd: s.t('Low EMD', 'कम EMD'),
      kPresetNoEmd: s.t('No EMD', 'EMD नहीं'),
      kPresetFirstTime: s.t('First-Time', 'नए विक्रेता'),
      kPresetClosingSoon: s.t('Closing Soon', 'जल्द बंद'),
      kPresetMinimalDocs: s.t('Minimal Docs', 'कम दस्तावेज़'),
    };
    for (final p in filter.quickPresets) {
      final label = presetLabels[p] ?? p;
      chips.add((
        label,
        () {
          final presets = Set<String>.from(filter.quickPresets)..remove(p);
          onChanged(filter.copyWith(quickPresets: presets));
        },
      ));
    }

    // Date
    if (filter.closingWithinDays != null) {
      chips.add((
        s.t('Within ${filter.closingWithinDays}d', '${filter.closingWithinDays} दिन में'),
        () => onChanged(filter.copyWith(clearClosingWithinDays: true)),
      ));
    } else if (filter.closingFrom != null || filter.closingTo != null) {
      final from = filter.closingFrom != null
          ? DateFormat('d MMM').format(filter.closingFrom!)
          : '…';
      final to = filter.closingTo != null
          ? DateFormat('d MMM').format(filter.closingTo!)
          : '…';
      chips.add((
        '$from → $to',
        () => onChanged(filter.copyWith(
          clearClosingFrom: true,
          clearClosingTo: true,
        )),
      ));
    }

    // EMD
    if (filter.noEmdOnly) {
      chips.add((
        s.t('No EMD', 'EMD नहीं'),
        () => onChanged(filter.copyWith(noEmdOnly: false)),
      ));
    } else if (filter.minEmd != null || filter.maxEmd != null) {
      final min = filter.minEmd != null
          ? '₹${_shortNum(filter.minEmd!)}'
          : '';
      final max = filter.maxEmd != null
          ? '₹${_shortNum(filter.maxEmd!)}'
          : '';
      final label = [
        if (min.isNotEmpty) 'EMD ≥$min',
        if (max.isNotEmpty) 'EMD ≤$max',
      ].join(', ');
      chips.add((
        label,
        () => onChanged(filter.copyWith(clearMinEmd: true, clearMaxEmd: true)),
      ));
    }

    // Documents
    if (filter.docTypes.isNotEmpty) {
      final labels =
          filter.docTypes.map((k) => kDocFilters[k]?[1] ?? k).join(', ');
      chips.add((
        labels,
        () => onChanged(filter.copyWith(docTypes: const {})),
      ));
    }

    // States
    for (final st in filter.states) {
      chips.add((
        st,
        () {
          final states = Set<String>.from(filter.states)..remove(st);
          onChanged(filter.copyWith(states: states));
        },
      ));
    }

    // Ministries
    if (filter.ministries.isNotEmpty) {
      final label = filter.ministries.length == 1
          ? filter.ministries.first.length > 20
              ? '${filter.ministries.first.substring(0, 18)}…'
              : filter.ministries.first
          : s.t(
              '${filter.ministries.length} ministries',
              '${filter.ministries.length} मंत्रालय',
            );
      chips.add((
        label,
        () => onChanged(filter.copyWith(ministries: const {})),
      ));
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (_, idx) => const SizedBox(width: AppSpace.xs),
        itemBuilder: (_, i) {
          final chip = chips[i];
          return GestureDetector(
            onTap: chip.$2,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.sm,
                vertical: AppSpace.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.brandTint,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    chip.$1,
                    style: AppText.label.copyWith(color: AppColors.brand),
                  ),
                  const SizedBox(width: AppSpace.xs),
                  Icon(Icons.close, size: 12, color: AppColors.brand),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  static String _shortNum(double v) {
    if (v >= 10000000) return '${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toInt().toString();
  }
}

// ── Filter bottom sheet ───────────────────────────────────────────────────────

Future<BidFilterState?> showBidFilterSheet({
  required BuildContext context,
  required AppStore store,
  required BidFilterState current,
  required List<Map<String, dynamic>> allBids,
}) =>
    showModalBottomSheet<BidFilterState>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BidFilterSheet(
        store: store,
        initial: current,
        allBids: allBids,
      ),
    );

class _BidFilterSheet extends StatefulWidget {
  final AppStore store;
  final BidFilterState initial;
  final List<Map<String, dynamic>> allBids;
  const _BidFilterSheet({
    required this.store,
    required this.initial,
    required this.allBids,
  });

  @override
  State<_BidFilterSheet> createState() => _BidFilterSheetState();
}

class _BidFilterSheetState extends State<_BidFilterSheet> {
  late BidFilterState _f;
  late List<String> _availStates;
  late List<String> _availMinistries;
  final _minEmdCtrl = TextEditingController();
  final _maxEmdCtrl = TextEditingController();
  final _stateSearchCtrl = TextEditingController();
  final _minSearchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _f = widget.initial;
    _availStates = BidFilterLogic.uniqueStates(widget.allBids);
    _availMinistries = BidFilterLogic.uniqueMinistries(widget.allBids);
    if (_f.minEmd != null) _minEmdCtrl.text = _f.minEmd!.toInt().toString();
    if (_f.maxEmd != null) _maxEmdCtrl.text = _f.maxEmd!.toInt().toString();
  }

  @override
  void dispose() {
    _minEmdCtrl.dispose();
    _maxEmdCtrl.dispose();
    _stateSearchCtrl.dispose();
    _minSearchCtrl.dispose();
    super.dispose();
  }

  int get _matchCount => BidFilterLogic.apply(widget.allBids, _f).length;

  void _togglePreset(String key) {
    final p = Set<String>.from(_f.quickPresets);
    if (!p.remove(key)) p.add(key);
    setState(() => _f = _f.copyWith(quickPresets: p));
  }

  void _toggleDoc(String key) {
    final d = Set<String>.from(_f.docTypes);
    if (!d.remove(key)) d.add(key);
    setState(() => _f = _f.copyWith(docTypes: d));
  }

  void _toggleState(String st) {
    final s = Set<String>.from(_f.states);
    if (!s.remove(st)) s.add(st);
    setState(() => _f = _f.copyWith(states: s));
  }

  void _toggleMinistry(String m) {
    final ms = Set<String>.from(_f.ministries);
    if (!ms.remove(m)) ms.add(m);
    setState(() => _f = _f.copyWith(ministries: ms));
  }

  void _clearAll() {
    _minEmdCtrl.clear();
    _maxEmdCtrl.clear();
    setState(() => _f = BidFilterState.empty);
  }

  AppStore get _s => widget.store;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.92;
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.sheet,
      ),
      child: Column(
        children: [
          const SizedBox(height: AppSpace.sm),
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.borderStrong,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          // Header row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.xxl),
            child: Row(
              children: [
                const Icon(
                  Icons.filter_list,
                  size: AppIconSize.md,
                  color: AppColors.ink,
                ),
                const SizedBox(width: AppSpace.sm),
                Expanded(
                  child: Text(
                    _s.t('Filter Bids', 'बोलियाँ फ़िल्टर करें'),
                    style: AppText.h3,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const SizedBox(
                    width: AppSize.tap,
                    height: AppSize.tap,
                    child: Icon(Icons.close, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          const Divider(height: 1),
          // Scrollable body
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpace.xxl),
              children: [
                _buildQuickPresets(),
                _divider(),
                _buildDateSection(),
                _divider(),
                _buildEmdSection(),
                _divider(),
                _buildDocsSection(),
                if (_availStates.isNotEmpty) ...[
                  _divider(),
                  _buildStatesSection(),
                ],
                if (_availMinistries.isNotEmpty) ...[
                  _divider(),
                  _buildMinistriesSection(),
                ],
                _divider(),
                _buildSortSection(),
                const SizedBox(height: AppSpace.huge),
              ],
            ),
          ),
          // Fixed bottom bar
          const Divider(height: 1),
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpace.xxl,
              AppSpace.md,
              AppSpace.xxl,
              AppSpace.md + bottomPad,
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: _clearAll,
                    child: Container(
                      height: AppSize.buttonMd,
                      alignment: Alignment.center,
                      child: Text(
                        _s.t('Clear All', 'सब हटाएँ'),
                        style: AppText.button.copyWith(color: AppColors.brand),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpace.sm),
                Expanded(
                  flex: 3,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context, _f),
                    child: Container(
                      height: AppSize.buttonMd,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.ink,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        _matchCount > 0
                            ? _s.t(
                                'Show $_matchCount bids',
                                '$_matchCount बोलियाँ दिखाएँ',
                              )
                            : _s.t('Apply Filters', 'फ़िल्टर लागू करें'),
                        style: AppText.button.copyWith(
                          color: AppColors.surface,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Sections ─────────────────────────────────────────────────────────────

  Widget _buildQuickPresets() {
    final presets = [
      (kPresetMsme, _s.t('MSME Friendly', 'MSME अनुकूल'),
          Icons.thumb_up_outlined),
      (kPresetLowEmd, _s.t('Low EMD', 'कम EMD'),
          Icons.currency_rupee),
      (kPresetNoEmd, _s.t('No EMD', 'EMD नहीं'),
          Icons.money_off_outlined),
      (kPresetFirstTime, _s.t('First-Time Sellers', 'नए विक्रेता'),
          Icons.star_border),
      (kPresetClosingSoon, _s.t('Closing Soon', 'जल्द बंद'),
          Icons.timer_outlined),
      (kPresetMinimalDocs, _s.t('Minimal Docs', 'कम दस्तावेज़'),
          Icons.description_outlined),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(_s.t('Quick Filters', 'त्वरित फ़िल्टर')),
        const SizedBox(height: AppSpace.sm),
        Text(
          _s.t(
            'Tap to find bids matching these criteria',
            'इन मानदंडों की बोलियाँ ढूँढें',
          ),
          style: AppText.caption,
        ),
        const SizedBox(height: AppSpace.md),
        Wrap(
          spacing: AppSpace.sm,
          runSpacing: AppSpace.sm,
          children: [
            for (final p in presets)
              _PresetChip(
                label: p.$2,
                icon: p.$3,
                selected: _f.quickPresets.contains(p.$1),
                onTap: () => _togglePreset(p.$1),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildDateSection() {
    final opts = [
      (1, _s.t('24h', '24 घंटे')),
      (3, _s.t('3d', '3 दिन')),
      (7, _s.t('7d', '7 दिन')),
      (15, _s.t('15d', '15 दिन')),
      (30, _s.t('30d', '30 दिन')),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(_s.t('Date of Close', 'बंद होने की तारीख')),
        const SizedBox(height: AppSpace.xs),
        Text(
          _s.t('Closing within', 'इतने दिनों में बंद होने वाली'),
          style: AppText.caption,
        ),
        const SizedBox(height: AppSpace.sm),
        Wrap(
          spacing: AppSpace.sm,
          runSpacing: AppSpace.sm,
          children: [
            for (final opt in opts)
              _ToggleChip(
                label: opt.$2,
                selected: _f.closingWithinDays == opt.$1,
                onTap: () => setState(() {
                  final same = _f.closingWithinDays == opt.$1;
                  _f = _f.copyWith(
                    closingWithinDays: same ? null : opt.$1,
                    clearClosingWithinDays: same,
                    clearClosingFrom: true,
                    clearClosingTo: true,
                  );
                }),
              ),
          ],
        ),
        const SizedBox(height: AppSpace.md),
        Text(
          _s.t('Or select a custom range', 'या तारीख की सीमा चुनें'),
          style: AppText.caption,
        ),
        const SizedBox(height: AppSpace.sm),
        Row(
          children: [
            Expanded(
              child: _DateField(
                label: _s.t('From', 'से'),
                value: _f.closingFrom,
                onChanged: (d) => setState(() => _f = _f.copyWith(
                  closingFrom: d,
                  clearClosingWithinDays: true,
                )),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
              child: Text(
                '→',
                style: AppText.caption.copyWith(color: AppColors.textHint),
              ),
            ),
            Expanded(
              child: _DateField(
                label: _s.t('To', 'तक'),
                value: _f.closingTo,
                onChanged: (d) => setState(() => _f = _f.copyWith(
                  closingTo: d,
                  clearClosingWithinDays: true,
                )),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmdSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(_s.t('Minimum EMD', 'न्यूनतम EMD')),
        const SizedBox(height: AppSpace.sm),
        Row(
          children: [
            Expanded(
              child: _NumField(
                controller: _minEmdCtrl,
                hint: _s.t('Min EMD (₹)', 'न्यूनतम (₹)'),
                onChanged: (v) {
                  final d = double.tryParse(v.replaceAll(',', ''));
                  setState(() => _f = d != null
                      ? _f.copyWith(minEmd: d)
                      : _f.copyWith(clearMinEmd: true));
                },
              ),
            ),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: _NumField(
                controller: _maxEmdCtrl,
                hint: _s.t('Max EMD (₹)', 'अधिकतम (₹)'),
                onChanged: (v) {
                  final d = double.tryParse(v.replaceAll(',', ''));
                  setState(() => _f = d != null
                      ? _f.copyWith(maxEmd: d)
                      : _f.copyWith(clearMaxEmd: true));
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.sm),
        _CheckRow(
          label: _s.t('No EMD Required', 'EMD आवश्यक नहीं'),
          checked: _f.noEmdOnly,
          onChanged: (v) =>
              setState(() => _f = _f.copyWith(noEmdOnly: v)),
        ),
      ],
    );
  }

  Widget _buildDocsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          _s.t('Certificates / Documentation', 'प्रमाणपत्र / दस्तावेज़'),
        ),
        const SizedBox(height: AppSpace.xs),
        Text(
          _s.t(
            'Show bids that require all selected certificates',
            'चुने गए सभी प्रमाणपत्र माँगने वाली बोलियाँ दिखाएँ',
          ),
          style: AppText.caption,
        ),
        const SizedBox(height: AppSpace.sm),
        Wrap(
          spacing: AppSpace.sm,
          runSpacing: AppSpace.sm,
          children: [
            for (final e in kDocFilters.entries)
              _ToggleChip(
                label: e.value[1],
                selected: _f.docTypes.contains(e.key),
                onTap: () => _toggleDoc(e.key),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatesSection() {
    final query = _stateSearchCtrl.text.toLowerCase();
    final filtered = query.isEmpty
        ? _availStates
        : _availStates
            .where((s) => s.toLowerCase().contains(query))
            .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(_s.t('Location / State', 'स्थान / राज्य')),
        const SizedBox(height: AppSpace.sm),
        _SearchField(
          controller: _stateSearchCtrl,
          hint: _s.t('Search states…', 'राज्य खोजें…'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSpace.sm),
        Wrap(
          spacing: AppSpace.sm,
          runSpacing: AppSpace.sm,
          children: [
            for (final st in filtered)
              _ToggleChip(
                label: st,
                selected: _f.states.contains(st),
                onTap: () => _toggleState(st),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildMinistriesSection() {
    final query = _minSearchCtrl.text.toLowerCase();
    final filtered = query.isEmpty
        ? _availMinistries
        : _availMinistries
            .where((m) => m.toLowerCase().contains(query))
            .toList();
    final shown = filtered.take(12).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(_s.t('Department / Ministry', 'विभाग / मंत्रालय')),
        const SizedBox(height: AppSpace.sm),
        _SearchField(
          controller: _minSearchCtrl,
          hint: _s.t('Search ministries…', 'मंत्रालय खोजें…'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSpace.sm),
        Wrap(
          spacing: AppSpace.sm,
          runSpacing: AppSpace.sm,
          children: [
            for (final m in shown)
              _ToggleChip(
                label: m.length > 32 ? '${m.substring(0, 30)}…' : m,
                selected: _f.ministries.contains(m),
                onTap: () => _toggleMinistry(m),
              ),
          ],
        ),
        if (filtered.length > 12)
          Padding(
            padding: const EdgeInsets.only(top: AppSpace.xs),
            child: Text(
              _s.t(
                '+${filtered.length - 12} more — search to narrow',
                '+${filtered.length - 12} और — खोज कर कम करें',
              ),
              style: AppText.caption.copyWith(color: AppColors.textHint),
            ),
          ),
      ],
    );
  }

  Widget _buildSortSection() {
    final opts = [
      (BidSortOrder.closingSoonest, _s.t('Closing Soonest', 'सबसे पहले बंद')),
      (BidSortOrder.recentlyPublished,
          _s.t('Recently Published', 'हाल में प्रकाशित')),
      (BidSortOrder.lowestEmd, _s.t('Lowest EMD First', 'सबसे कम EMD पहले')),
      (BidSortOrder.highestEmd,
          _s.t('Highest EMD First', 'सबसे अधिक EMD पहले')),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(_s.t('Sort By', 'क्रम से')),
        const SizedBox(height: AppSpace.sm),
        for (final opt in opts)
          _RadioRow(
            label: opt.$2,
            selected: _f.sortOrder == opt.$1,
            onTap: () => setState(() => _f = _f.copyWith(sortOrder: opt.$1)),
          ),
      ],
    );
  }

  Widget _sectionTitle(String text) =>
      Text(text, style: AppText.title.copyWith(fontSize: 16));

  Widget _divider() => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpace.xl),
    child: Container(height: 1, color: AppColors.border),
  );
}

// ── Shared micro-widgets for the sheet ───────────────────────────────────────

class _PresetChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _PresetChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.md,
        vertical: AppSpace.sm,
      ),
      decoration: BoxDecoration(
        color: selected ? AppColors.brand : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: selected ? AppColors.brand : AppColors.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: selected ? AppColors.surface : AppColors.textSecondary,
          ),
          const SizedBox(width: AppSpace.xs),
          Text(
            label,
            style: AppText.label.copyWith(
              color: selected ? AppColors.surface : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    ),
  );
}

class _ToggleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ToggleChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.md,
        vertical: AppSpace.sm,
      ),
      decoration: BoxDecoration(
        color: selected ? AppColors.brandTint : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: selected ? AppColors.brand : AppColors.borderStrong,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Text(
        label,
        style: AppText.label.copyWith(
          color: selected ? AppColors.brand : AppColors.textSecondary,
        ),
      ),
    ),
  );
}

class _CheckRow extends StatelessWidget {
  final String label;
  final bool checked;
  final ValueChanged<bool> onChanged;
  const _CheckRow({
    required this.label,
    required this.checked,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => onChanged(!checked),
    child: Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: checked ? AppColors.brand : AppColors.surface,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: checked ? AppColors.brand : AppColors.borderStrong,
            ),
          ),
          child: checked
              ? const Icon(Icons.check, size: 14, color: AppColors.surface)
              : null,
        ),
        const SizedBox(width: AppSpace.sm),
        Text(label, style: AppText.body),
      ],
    ),
  );
}

class _RadioRow extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _RadioRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color:
                    selected ? AppColors.brand : AppColors.borderStrong,
                width: selected ? 2 : 1,
              ),
            ),
            child: selected
                ? Center(
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.brand,
                      ),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: AppSpace.sm),
          Text(label, style: AppText.body),
        ],
      ),
    ),
  );
}

class _NumField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  const _NumField({
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: TextInputType.number,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    onChanged: onChanged,
    style: AppText.bodyStrong,
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: AppText.caption.copyWith(color: AppColors.textHint),
      filled: true,
      fillColor: AppColors.surfaceMuted,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpace.md,
        vertical: AppSpace.md,
      ),
      border: OutlineInputBorder(
        borderRadius: AppRadius.input,
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.input,
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.input,
        borderSide: const BorderSide(color: AppColors.brand, width: 1.5),
      ),
      prefixText: '₹ ',
      prefixStyle: AppText.bodyStrong.copyWith(
        color: AppColors.textSecondary,
      ),
    ),
  );
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  const _SearchField({
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    onChanged: onChanged,
    style: AppText.body,
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: AppText.caption.copyWith(color: AppColors.textHint),
      prefixIcon: const Icon(
        Icons.search,
        size: AppIconSize.sm,
        color: AppColors.textHint,
      ),
      filled: true,
      fillColor: AppColors.surfaceMuted,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpace.md,
        vertical: AppSpace.sm,
      ),
      border: OutlineInputBorder(
        borderRadius: AppRadius.input,
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.input,
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.input,
        borderSide: const BorderSide(color: AppColors.brand, width: 1.5),
      ),
    ),
  );
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  const _DateField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () async {
      final d = await showDatePicker(
        context: context,
        initialDate: value ?? DateTime.now(),
        firstDate: DateTime.now().subtract(const Duration(days: 1)),
        lastDate: DateTime.now().add(const Duration(days: 365)),
        builder: (ctx, child) => Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.brand,
            ),
          ),
          child: child!,
        ),
      );
      if (d != null) onChanged(d);
    },
    child: Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.sm,
        vertical: AppSpace.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: AppRadius.input,
      ),
      child: Row(
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 13,
            color: AppColors.textHint,
          ),
          const SizedBox(width: AppSpace.xs),
          Expanded(
            child: Text(
              value != null
                  ? DateFormat('d MMM yyyy').format(value!)
                  : label,
              style: value != null
                  ? AppText.bodyStrong
                  : AppText.caption
                      .copyWith(color: AppColors.textHint),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (value != null)
            GestureDetector(
              onTap: () => onChanged(null),
              child: const Icon(Icons.close, size: 13, color: AppColors.textHint),
            ),
        ],
      ),
    ),
  );
}
