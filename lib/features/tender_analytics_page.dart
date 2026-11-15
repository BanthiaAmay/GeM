import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../core/models.dart' show money;
import '../core/theme.dart';
import '../data/app_store.dart';
import 'components.dart';
import 'glass.dart';

// ── File-level helpers ──────────────────────────────────────────────────────

String _money(num v) => money(v);

num _tenderValue(Map<String, dynamic> bid) {
  final d = Map<String, dynamic>.from(bid['details'] as Map? ?? {});
  for (final k in ['tender_value', 'estimated_value', 'contract_value']) {
    final raw = (d[k] ?? bid[k])?.toString().replaceAll(',', '') ?? '';
    final v = num.tryParse(raw);
    if (v != null && v > 0) return v;
  }
  return 0;
}

bool _isActive(Map<String, dynamic> row) {
  final bid = Map<String, dynamic>.from(row['bid_data'] as Map? ?? row);
  final closesAt = DateTime.tryParse(bid['closes_at'] as String? ?? '');
  if (closesAt == null) return true;
  return closesAt.isAfter(DateTime.now());
}

num _totalCost(Map<String, dynamic> ad) {
  num sum = 0;
  for (final k in [
    'procurement_cost',
    'labour_cost',
    'manufacturing_cost', // backward compat with older data
    'packaging_cost',
    'logistics_cost',
    'installation_cost',
    'taxes_cost',
    'compliance_cost',
    'warranty_cost',
    'financing_cost',
    'other_cost',
  ]) {
    sum += (ad[k] as num?) ?? 0;
  }
  final extraJson = ad['extra_costs_json'] as String? ?? '[]';
  try {
    final extras = jsonDecode(extraJson) as List;
    for (final e in extras) {
      sum += (e['amount'] as num?) ?? 0;
    }
  } catch (_) {}
  return sum;
}

String _fmt(DateTime d) => DateFormat('d MMM').format(d.toLocal());

Map<String, dynamic> _bid(Map<String, dynamic> row) =>
    Map<String, dynamic>.from(row['bid_data'] as Map? ?? row);

String _title(Map<String, dynamic> row) {
  final b = _bid(row);
  return (b['title'] as String? ?? '').trim();
}

String _sourceId(Map<String, dynamic> row) =>
    (row['source_id'] as String? ?? '').trim();

// ── Entry point ─────────────────────────────────────────────────────────────

class TenderAnalyticsPage extends StatefulWidget {
  final AppStore store;
  const TenderAnalyticsPage({super.key, required this.store});
  @override
  State<TenderAnalyticsPage> createState() => _TenderAnalyticsPageState();
}

class _TenderAnalyticsPageState extends State<TenderAnalyticsPage> {
  int _tab = 0;
  final _tabs = ['Overview', 'Financial', 'Simulator'];

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            GlassBar.top(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.sm,
                vertical: AppSpace.sm,
              ),
              child: Row(
                children: [
                  AppIconButton(
                    icon: Icons.arrow_back_ios_new,
                    tooltip: s.t('Back', 'वापस'),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Text(
                      s.t('Tender Analytics', 'टेंडर एनालिटिक्स'),
                      textAlign: TextAlign.center,
                      style: AppText.title,
                    ),
                  ),
                  const SizedBox(width: AppSize.tap),
                ],
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.gutter,
                  vertical: AppSpace.xs,
                ),
                itemCount: _tabs.length,
                separatorBuilder: (_, i) => const SizedBox(width: AppSpace.sm),
                itemBuilder: (context, i) {
                  final active = _tab == i;
                  return GestureDetector(
                    onTap: () => setState(() => _tab = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.md,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: active
                            ? AppColors.brand
                            : AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        _tabs[i],
                        style: AppText.label.copyWith(
                          color: active
                              ? AppColors.surface
                              : AppColors.textSecondary,
                          fontWeight:
                              active ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 2),
            Expanded(
              child: ListenableBuilder(
                listenable: s,
                builder: (context, _) {
                  if (s.savedBids.isEmpty) return _emptyState(context, s);
                  return switch (_tab) {
                    0 => _OverviewTab(
                        store: s,
                        onTabChange: (t) => setState(() => _tab = t),
                      ),
                    1 => _FinancialTab(store: s),
                    2 => _SimulatorTab(store: s),
                    _ => const SizedBox(),
                  };
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(BuildContext context, AppStore s) => StateView(
    kind: StateKind.empty,
    title: s.t(
      'Start analysing your opportunities',
      'अपने अवसरों का विश्लेषण शुरू करें',
    ),
    message: s.t(
      'Save bids from Find Bids to understand their financial requirements, estimated costs and potential returns.',
      'Find Bids से बोलियाँ सहेजें ताकि उनकी वित्तीय आवश्यकताओं को समझ सकें।',
    ),
    actionLabel: s.t('Explore Find Bids', 'बोलियाँ खोजें'),
    onAction: () => Navigator.of(context).pushReplacementNamed('/bids'),
  );
}

// ── Shared _MetricCard ───────────────────────────────────────────────────────

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final String? tooltip;
  final String? sub;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _MetricCard({
    required this.label,
    required this.value,
    this.color = AppColors.ink,
    this.tooltip,
    this.sub,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: AppText.caption)),
              if (tooltip != null)
                GestureDetector(
                  onTap: () => showModalBottomSheet<void>(
                    context: context,
                    backgroundColor: AppColors.surface,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                    ),
                    builder: (_) => Padding(
                      padding: const EdgeInsets.all(AppSpace.gutter),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label, style: AppText.h3),
                          const SizedBox(height: AppSpace.md),
                          Text(tooltip!, style: AppText.body),
                          const SizedBox(height: AppSpace.gutter),
                        ],
                      ),
                    ),
                  ),
                  child: Icon(
                    Icons.info_outline,
                    size: 15,
                    color: AppColors.textHint,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpace.xs),
          Text(value, style: AppText.h2.copyWith(color: color)),
          if (sub != null) ...[
            const SizedBox(height: 2),
            Text(
              sub!,
              style: AppText.caption.copyWith(color: AppColors.textHint),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpace.sm),
            GestureDetector(
              onTap: onAction,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    actionLabel!,
                    style: AppText.label.copyWith(color: AppColors.brand),
                  ),
                  const SizedBox(width: 2),
                  Icon(Icons.arrow_forward, size: 14, color: AppColors.brand),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Tab 0 — Overview ─────────────────────────────────────────────────────────

class _OverviewTab extends StatelessWidget {
  final AppStore store;
  final void Function(int) onTabChange;
  const _OverviewTab({required this.store, required this.onTabChange});

  @override
  Widget build(BuildContext context) {
    final s = store;
    final bids = s.savedBids;
    final active = bids.where(_isActive).toList();

    final activeBidIds = {for (final r in active) _sourceId(r)};
    final adActive = s.analyticsData.where(
      (d) => activeBidIds.contains(d['source_id'] as String? ?? ''),
    );

    // EMD: sum across active bids, respecting nil/unavailable per-bid
    num emdTotal = 0;
    bool emdInfoFound = false;
    for (final r in active) {
      final d =
          Map<String, dynamic>.from(_bid(r)['details'] as Map? ?? {});
      final req = (d['emd_required'] ?? '').toString().toLowerCase();
      if (req.isEmpty) continue;
      emdInfoFound = true;
      if (req != 'no' && req != 'nil' && req != 'none' && req != '0') {
        final raw =
            (d['emd_amount'] ?? '').toString().replaceAll(',', '');
        emdTotal += num.tryParse(raw) ?? 0;
      }
    }
    final emdDisplay = !emdInfoFound && active.isNotEmpty
        ? s.t('Not Available', 'उपलब्ध नहीं')
        : emdTotal == 0
            ? '₹0'
            : _money(emdTotal);
    final emdColor = !emdInfoFound && active.isNotEmpty
        ? AppColors.textHint
        : emdTotal > 0
            ? AppColors.warning
            : AppColors.ink;

    // Financial metrics — require user input in Financial tab
    num? execCost;
    num? revenue;
    for (final d in adActive) {
      final c = _totalCost(d);
      final sp = (d['selling_price'] as num?) ?? 0;
      if (c > 0) execCost = (execCost ?? 0) + c;
      if (sp > 0) revenue = (revenue ?? 0) + sp;
    }
    final netProfit =
        (revenue != null && execCost != null) ? revenue - execCost : null;

    final halfWidth =
        (MediaQuery.of(context).size.width -
            AppSpace.gutter * 2 -
            AppSpace.sm) /
        2;
    final fullWidth =
        MediaQuery.of(context).size.width - AppSpace.gutter * 2;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.gutter,
        AppSpace.md,
        AppSpace.gutter,
        80,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.t(
              'Financial overview of your saved bids',
              'सहेजी बोलियों का वित्तीय अवलोकन',
            ),
            style: AppText.caption.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpace.lg),
          Wrap(
            spacing: AppSpace.sm,
            runSpacing: AppSpace.sm,
            children: [
              SizedBox(
                width: halfWidth,
                child: _MetricCard(
                  label: s.t('Active Saved Bids', 'सक्रिय सहेजी बोलियाँ'),
                  value: '${active.length}',
                  color: AppColors.brand,
                  actionLabel: s.t('View Saved Bids', 'सहेजी बोलियाँ देखें'),
                  onAction: () =>
                      Navigator.pushNamed(context, '/saved-bids'),
                  tooltip: s.t(
                    'Saved bids whose submission deadline has not yet passed.',
                    'सहेजी बोलियाँ जिनकी समय-सीमा नहीं गुज़री।',
                  ),
                ),
              ),
              SizedBox(
                width: halfWidth,
                child: _MetricCard(
                  label: s.t('Total EMD Requirement', 'कुल EMD आवश्यकता'),
                  value: emdDisplay,
                  color: emdColor,
                  sub: s.t(
                    'May be nil for MSME',
                    'MSME के लिए शून्य हो सकता है',
                  ),
                  tooltip: s.t(
                    'Combined EMD across active saved bids. MSME-registered sellers may be exempt.',
                    'सक्रिय बोलियों पर कुल EMD। MSME विक्रेता छूट के पात्र हो सकते हैं।',
                  ),
                ),
              ),
              SizedBox(
                width: halfWidth,
                child: _MetricCard(
                  label: s.t('Est. Execution Cost', 'अनु. निष्पादन लागत'),
                  value: execCost != null
                      ? _money(execCost)
                      : s.t('Not entered', 'दर्ज नहीं'),
                  color: execCost != null
                      ? AppColors.ink
                      : AppColors.textHint,
                  actionLabel: s.t('Calculate Costs', 'लागत दर्ज करें'),
                  onAction: () => onTabChange(1),
                  tooltip: s.t(
                    'Sum of costs entered in the Financial tab for active bids.',
                    'Financial टैब में दर्ज लागत का योग।',
                  ),
                ),
              ),
              SizedBox(
                width: halfWidth,
                child: _MetricCard(
                  label: s.t('Potential Revenue', 'संभावित राजस्व'),
                  value: revenue != null
                      ? _money(revenue)
                      : s.t('Not entered', 'दर्ज नहीं'),
                  color: revenue != null
                      ? AppColors.brand
                      : AppColors.textHint,
                  tooltip: s.t(
                    'Sum of expected bid amounts entered in the Financial tab. Not guaranteed revenue.',
                    'Financial टैब में दर्ज अपेक्षित बिक्री मूल्यों का योग।',
                  ),
                ),
              ),
              SizedBox(
                width: fullWidth,
                child: _MetricCard(
                  label: s.t('Est. Net Profit', 'अनु. शुद्ध लाभ'),
                  value: netProfit != null
                      ? _money(netProfit)
                      : s.t(
                          'Enter costs and revenue in Financial tab',
                          'Financial टैब में लागत और राजस्व दर्ज करें',
                        ),
                  color: netProfit != null
                      ? (netProfit >= 0
                          ? AppColors.brand
                          : AppColors.danger)
                      : AppColors.textHint,
                  tooltip: s.t(
                    'Potential revenue minus estimated execution costs. Enter data in Financial tab.',
                    'संभावित राजस्व घटाएं अनुमानित निष्पादन लागत।',
                  ),
                ),
              ),
            ],
          ),
          if (execCost == null || revenue == null) ...[
            const SizedBox(height: AppSpace.xl),
            AppCard(
              tone: AppCardTone.muted,
              padding: const EdgeInsets.all(AppSpace.lg),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    size: 16,
                    color: AppColors.info,
                  ),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: Text(
                      s.t(
                        'Open the Financial tab to enter costs and expected revenue for each bid. This will show your execution cost, potential revenue and estimated net profit here.',
                        'प्रत्येक बोली के लिए लागत और अपेक्षित राजस्व दर्ज करने के लिए Financial टैब खोलें। इससे यहाँ निष्पादन लागत, संभावित राजस्व और अनुमानित शुद्ध लाभ दिखेगा।',
                      ),
                      style: AppText.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Tab 1 — Financial ────────────────────────────────────────────────────────

class _FinancialTab extends StatelessWidget {
  final AppStore store;
  const _FinancialTab({required this.store});

  @override
  Widget build(BuildContext context) {
    final s = store;
    final bids = s.savedBids;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.gutter,
        AppSpace.md,
        AppSpace.gutter,
        80,
      ),
      itemCount: bids.length,
      separatorBuilder: (_, i) => const SizedBox(height: AppSpace.md),
      itemBuilder: (context, i) =>
          _BidFinancialCard(store: s, row: bids[i], startExpanded: true),
    );
  }
}

class _BidFinancialCard extends StatefulWidget {
  final AppStore store;
  final Map<String, dynamic> row;
  final bool startExpanded;
  const _BidFinancialCard({
    required this.store,
    required this.row,
    this.startExpanded = false,
  });
  @override
  State<_BidFinancialCard> createState() => _BidFinancialCardState();
}

class _BidFinancialCardState extends State<_BidFinancialCard>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late bool _expanded;
  bool _saved = false; // true once explicitly saved this session

  // All cost field controllers owned by this state
  final Map<String, TextEditingController> _costCtrls = {};
  late TextEditingController _sellingCtrl;
  final List<TextEditingController> _extraLabels = [];
  final List<TextEditingController> _extraAmounts = [];

  static const _costFields = [
    ('procurement_cost', 'Procurement Costs', 'खरीद लागत'),
    ('labour_cost', 'Labour & Manufacturing Costs', 'श्रम एवं निर्माण लागत'),
    ('packaging_cost', 'Packaging Costs', 'पैकेजिंग लागत'),
    ('logistics_cost', 'Logistics Costs', 'रसद लागत'),
    ('installation_cost', 'Installation Costs', 'स्थापना लागत'),
    ('taxes_cost', 'Taxes (non-recoverable)', 'कर (अपूरणीय)'),
    ('compliance_cost', 'Compliance Costs', 'अनुपालन लागत'),
    ('warranty_cost', 'Warranty Costs', 'वारंटी लागत'),
    ('financing_cost', 'Financing Costs', 'वित्तपोषण लागत'),
    ('other_cost', 'Other Costs', 'अन्य लागत'),
  ];

  @override
  void initState() {
    super.initState();
    _expanded = widget.startExpanded;
    final ad = widget.store.getAnalyticsDatum(_sourceId(widget.row));
    for (final (key, _, _) in _costFields) {
      _costCtrls[key] =
          TextEditingController(text: (ad[key] as num?)?.toString() ?? '');
    }
    _sellingCtrl = TextEditingController(
      text: (ad['selling_price'] as num?)?.toString() ?? '',
    );
    _loadExtraControllers(ad);
    // If store already has data for this bid, mark as saved
    _saved = _totalCost(ad) > 0 || (ad['selling_price'] as num? ?? 0) > 0;
  }

  void _loadExtraControllers(Map<String, dynamic> ad) {
    final raw = ad['extra_costs_json'] as String? ?? '[]';
    try {
      final list = jsonDecode(raw) as List;
      for (final item in list) {
        _extraLabels.add(
          TextEditingController(text: item['label'] as String? ?? ''),
        );
        _extraAmounts.add(
          TextEditingController(
            text: (item['amount'] as num?)?.toString() ?? '',
          ),
        );
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    for (final c in _costCtrls.values) c.dispose();
    _sellingCtrl.dispose();
    for (final c in _extraLabels) c.dispose();
    for (final c in _extraAmounts) c.dispose();
    super.dispose();
  }

  void _saveAll() {
    final sourceId = _sourceId(widget.row);
    final data = <String, dynamic>{};
    for (final (key, _, _) in _costFields) {
      data[key] = num.tryParse(_costCtrls[key]!.text);
    }
    data['selling_price'] = num.tryParse(_sellingCtrl.text);
    final extras = <Map<String, dynamic>>[];
    for (var i = 0; i < _extraLabels.length; i++) {
      final label = _extraLabels[i].text.trim();
      final amount = num.tryParse(_extraAmounts[i].text);
      if (label.isNotEmpty || (amount != null && amount > 0)) {
        extras.add({'label': label, 'amount': amount});
      }
    }
    data['extra_costs_json'] = jsonEncode(extras);
    widget.store.saveAnalyticsDatum(sourceId, data);
    setState(() => _saved = true);
  }

  void _confirmDelete(BuildContext context) {
    final s = widget.store;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(AppSpace.gutter),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.t('Delete financial data?', 'वित्तीय डेटा हटाएँ?'),
              style: AppText.h3,
            ),
            const SizedBox(height: AppSpace.sm),
            Text(
              s.t(
                'All costs and revenue data for this bid will be cleared. This cannot be undone.',
                'इस बोली की सभी लागत और राजस्व जानकारी हट जाएगी। यह क्रिया वापस नहीं की जा सकती।',
              ),
              style: AppText.body.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpace.xl),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(s.t('Cancel', 'रद्द करें')),
                  ),
                ),
                const SizedBox(width: AppSpace.sm),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      foregroundColor: AppColors.surface,
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      _deleteAll();
                    },
                    child: Text(s.t('Delete', 'हटाएँ')),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.md),
          ],
        ),
      ),
    );
  }

  void _deleteAll() {
    final sourceId = _sourceId(widget.row);
    final empty = <String, dynamic>{};
    for (final (key, _, _) in _costFields) {
      empty[key] = null;
    }
    empty['selling_price'] = null;
    empty['extra_costs_json'] = '[]';
    widget.store.saveAnalyticsDatum(sourceId, empty);
    // Reset all controllers
    for (final (key, _, _) in _costFields) {
      _costCtrls[key]!.text = '';
    }
    _sellingCtrl.text = '';
    for (final c in _extraLabels) c.dispose();
    for (final c in _extraAmounts) c.dispose();
    _extraLabels.clear();
    _extraAmounts.clear();
    setState(() => _saved = false);
  }

  void _addExtraCost() {
    setState(() {
      _extraLabels.add(TextEditingController());
      _extraAmounts.add(TextEditingController());
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // required by AutomaticKeepAliveClientMixin
    final s = widget.store;
    final sourceId = _sourceId(widget.row);
    final ad = s.getAnalyticsDatum(sourceId);

    // Live totals from store (reflects last save)
    final cost = _totalCost(ad);
    final sp = (ad['selling_price'] as num?) ?? 0;
    final profit = sp > 0 || cost > 0 ? sp - cost : null;
    final margin =
        sp > 0 ? ((profit! / sp) * 100).toStringAsFixed(1) : null;
    final b = _bid(widget.row);
    final ca = DateTime.tryParse(b['closes_at'] as String? ?? '');

    return AppCard(
      padding: const EdgeInsets.all(AppSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _title(widget.row),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.bodyStrong,
                ),
              ),
              if (_saved)
                Padding(
                  padding: const EdgeInsets.only(left: AppSpace.sm),
                  child: Icon(Icons.check_circle, size: 16, color: AppColors.brand),
                ),
            ],
          ),
          if (ca != null) ...[
            const SizedBox(height: AppSpace.xs),
            Text(
              '${s.t('Closes', 'बंद होता है')}: ${_fmt(ca)}',
              style: AppText.caption.copyWith(color: AppColors.textHint),
            ),
          ],
          const SizedBox(height: AppSpace.md),
          Row(
            children: [
              Expanded(
                child: _SummaryChip(
                  s.t('Cost', 'लागत'),
                  cost > 0 ? _money(cost) : '—',
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: _SummaryChip(
                  s.t('Revenue', 'राजस्व'),
                  sp > 0 ? _money(sp) : '—',
                  color: sp > 0 ? AppColors.brand : null,
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: _SummaryChip(
                  s.t('Profit', 'लाभ'),
                  profit != null ? _money(profit) : '—',
                  color: profit != null
                      ? (profit >= 0 ? AppColors.brand : AppColors.danger)
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.sm),
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              children: [
                Text(
                  _expanded
                      ? s.t('Hide details', 'विवरण छुपाएँ')
                      : s.t('Enter / Edit Costs', 'लागत दर्ज / संपादित करें'),
                  style: AppText.label.copyWith(color: AppColors.brand),
                ),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: AppColors.brand,
                ),
              ],
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: AppSpace.lg),
            Text(
              s.t('Execution Costs', 'निष्पादन लागत'),
              style: AppText.caption.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            for (final (key, en, hi) in _costFields)
              _CostField(
                label: s.t(en, hi),
                controller: _costCtrls[key]!,
              ),
            for (var i = 0; i < _extraLabels.length; i++)
              _ExtraCostRow(
                labelCtrl: _extraLabels[i],
                amountCtrl: _extraAmounts[i],
                index: i + 1,
                onChanged: () {},
              ),
            GestureDetector(
              onTap: _addExtraCost,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_circle_outline, size: 16, color: AppColors.brand),
                    const SizedBox(width: AppSpace.xs),
                    Text(
                      s.t('Add Other Cost', 'अन्य लागत जोड़ें'),
                      style: AppText.label.copyWith(color: AppColors.brand),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: AppSpace.xl),
            Text(
              s.t('Expected Revenue', 'अपेक्षित राजस्व'),
              style: AppText.caption.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            _CostField(
              label: s.t(
                'Expected Bid / Selling Amount',
                'अपेक्षित बोली / बिक्री राशि',
              ),
              controller: _sellingCtrl,
            ),
            if (margin != null) ...[
              const SizedBox(height: AppSpace.sm),
              Row(
                children: [
                  Icon(
                    double.parse(margin) >= 0
                        ? Icons.trending_up
                        : Icons.trending_down,
                    size: 15,
                    color: double.parse(margin) >= 0
                        ? AppColors.brand
                        : AppColors.danger,
                  ),
                  const SizedBox(width: AppSpace.xs),
                  Text(
                    s.t('Profit Margin: $margin%', 'लाभ मार्जिन: $margin%'),
                    style: AppText.bodyStrong.copyWith(
                      color: double.parse(margin) >= 0
                          ? AppColors.brand
                          : AppColors.danger,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppSpace.md),
            ReassuranceNote(
              s.t(
                'Enter only non-recoverable costs. Recoverable GST (input tax credit) should not be included as an expense.',
                'केवल अप्रतिदेय लागत दर्ज करें। वसूली योग्य GST (इनपुट टैक्स क्रेडिट) को खर्च में शामिल न करें।',
              ),
            ),
            const SizedBox(height: AppSpace.lg),
            // ── Save / Delete action row ──────────────────────────────
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.save_outlined, size: 16),
                    label: Text(s.t('Save', 'सहेजें')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      foregroundColor: AppColors.surface,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    onPressed: _saveAll,
                  ),
                ),
                const SizedBox(width: AppSpace.sm),
                OutlinedButton.icon(
                  icon: Icon(Icons.delete_outline, size: 16, color: AppColors.danger),
                  label: Text(
                    s.t('Delete', 'हटाएँ'),
                    style: TextStyle(color: AppColors.danger),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.danger),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.md,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  onPressed: () => _confirmDelete(context),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ExtraCostRow extends StatelessWidget {
  final TextEditingController labelCtrl;
  final TextEditingController amountCtrl;
  final int index;
  final VoidCallback onChanged;
  const _ExtraCostRow({
    required this.labelCtrl,
    required this.amountCtrl,
    required this.index,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: labelCtrl,
              decoration: InputDecoration(
                hintText: 'Cost $index name',
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.sm,
                  vertical: AppSpace.sm,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                isDense: true,
              ),
              onSubmitted: (_) => onChanged(),
              onEditingComplete: onChanged,
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            flex: 3,
            child: TextField(
              controller: amountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
              ],
              decoration: InputDecoration(
                prefixText: '₹ ',
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.sm,
                  vertical: AppSpace.sm,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                isDense: true,
              ),
              onSubmitted: (_) => onChanged(),
              onEditingComplete: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _SummaryChip(this.label, this.value, {this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpace.sm,
      vertical: AppSpace.sm,
    ),
    decoration: BoxDecoration(
      color: AppColors.surfaceMuted,
      borderRadius: BorderRadius.circular(AppRadius.sm),
    ),
    child: Column(
      children: [
        Text(label, style: AppText.caption),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppText.label.copyWith(
            color: color ?? AppColors.ink,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _CostField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  const _CostField({required this.label, required this.controller});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpace.sm),
    child: Row(
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: AppText.caption,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: AppSpace.sm),
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
            ],
            decoration: InputDecoration(
              prefixText: '₹ ',
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpace.sm,
                vertical: AppSpace.sm,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              isDense: true,
            ),
          ),
        ),
      ],
    ),
  );
}

// ── Tab 2 — Simulator ────────────────────────────────────────────────────────

class _SimulatorTab extends StatefulWidget {
  final AppStore store;
  const _SimulatorTab({required this.store});
  @override
  State<_SimulatorTab> createState() => _SimulatorTabState();
}

class _SimulatorTabState extends State<_SimulatorTab> {
  double _winRate = 0.5;
  double _costOverrun = 0.0;
  double _paymentDelay = 30;
  final Set<String> _selected = {};
  bool _selectionInit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_selectionInit) {
      _selectionInit = true;
      for (final r in widget.store.savedBids) {
        if (_isActive(r)) _selected.add(_sourceId(r));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    final bids = s.savedBids;

    num totalEmdSel = 0;
    num totalRevSel = 0;
    num totalCostSel = 0;
    int selCount = 0;
    for (final r in bids) {
      final sid = _sourceId(r);
      if (!_selected.contains(sid)) continue;
      selCount++;
      final b = _bid(r);
      final d = Map<String, dynamic>.from(b['details'] as Map? ?? {});
      final req = (d['emd_required'] ?? '').toString().toLowerCase();
      if (req.isNotEmpty &&
          req != 'no' &&
          req != 'nil' &&
          req != 'none' &&
          req != '0') {
        final raw =
            (d['emd_amount'] ?? '').toString().replaceAll(',', '');
        totalEmdSel += num.tryParse(raw) ?? 0;
      }
      final ad = s.getAnalyticsDatum(sid);
      // Use user-entered data as baseline; fall back to tender value estimates
      final sp = (ad['selling_price'] as num?) ?? 0;
      totalRevSel += sp;
      totalCostSel += _totalCost(ad);
    }

    final expWins = (selCount * _winRate).ceil();
    final expRev = totalRevSel * _winRate;
    final expCost = totalCostSel * (1 + _costOverrun);
    final expProfit = expRev - expCost;
    final workingCap =
        (totalEmdSel + expCost - expRev).clamp(0, double.infinity);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.gutter,
        AppSpace.md,
        AppSpace.gutter,
        80,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.t('Select Bids to Simulate', 'अनुकरण के लिए बोलियाँ चुनें'),
            style: AppText.h3,
          ),
          const SizedBox(height: AppSpace.sm),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final r in bids)
                  CheckboxListTile(
                    value: _selected.contains(_sourceId(r)),
                    onChanged: (v) => setState(() {
                      if (v == true) {
                        _selected.add(_sourceId(r));
                      } else {
                        _selected.remove(_sourceId(r));
                      }
                    }),
                    title: Text(
                      _title(r),
                      style: AppText.body,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    activeColor: AppColors.brand,
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.xl),
          Text(s.t('Assumptions', 'मान्यताएँ'), style: AppText.h3),
          const SizedBox(height: AppSpace.md),
          AppCard(
            padding: const EdgeInsets.all(AppSpace.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SliderRow(
                  label: s.t('Win Rate', 'जीत दर'),
                  value: _winRate,
                  min: 0,
                  max: 1,
                  display: '${(_winRate * 100).round()}%',
                  onChanged: (v) => setState(() => _winRate = v),
                ),
                const SizedBox(height: AppSpace.md),
                _SliderRow(
                  label: s.t('Cost Overrun', 'लागत वृद्धि'),
                  value: _costOverrun,
                  min: 0,
                  max: 0.3,
                  display: '+${(_costOverrun * 100).round()}%',
                  onChanged: (v) => setState(() => _costOverrun = v),
                ),
                const SizedBox(height: AppSpace.md),
                _SliderRow(
                  label: s.t('Payment Delay', 'भुगतान विलंब'),
                  value: _paymentDelay,
                  min: 0,
                  max: 90,
                  display: '${_paymentDelay.round()} days',
                  onChanged: (v) => setState(() => _paymentDelay = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.xl),
          Text(
            s.t('Simulation Results', 'अनुकरण परिणाम'),
            style: AppText.h3,
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            s.t(
              'Simulated estimate — not a guarantee.',
              'अनुमानित परिणाम — गारंटी नहीं।',
            ),
            style: AppText.caption.copyWith(color: AppColors.textHint),
          ),
          const SizedBox(height: AppSpace.md),
          Wrap(
            spacing: AppSpace.sm,
            runSpacing: AppSpace.sm,
            children: [
              SizedBox(
                width: (MediaQuery.of(context).size.width -
                        AppSpace.gutter * 2 -
                        AppSpace.sm) /
                    2,
                child: _MetricCard(
                  label: s.t('Expected Wins', 'अपेक्षित जीत'),
                  value: '$expWins of $selCount',
                  color: AppColors.brand,
                ),
              ),
              SizedBox(
                width: (MediaQuery.of(context).size.width -
                        AppSpace.gutter * 2 -
                        AppSpace.sm) /
                    2,
                child: _MetricCard(
                  label: s.t('Expected Revenue', 'अपेक्षित राजस्व'),
                  value: expRev > 0 ? _money(expRev) : '—',
                  color: AppColors.brand,
                ),
              ),
              SizedBox(
                width: (MediaQuery.of(context).size.width -
                        AppSpace.gutter * 2 -
                        AppSpace.sm) /
                    2,
                child: _MetricCard(
                  label: s.t('Expected Cost', 'अपेक्षित लागत'),
                  value: expCost > 0 ? _money(expCost) : '—',
                ),
              ),
              SizedBox(
                width: (MediaQuery.of(context).size.width -
                        AppSpace.gutter * 2 -
                        AppSpace.sm) /
                    2,
                child: _MetricCard(
                  label: s.t('Expected Net Profit', 'अपेक्षित शुद्ध लाभ'),
                  value: expRev > 0 ? _money(expProfit) : '—',
                  color: expProfit >= 0 ? AppColors.brand : AppColors.danger,
                ),
              ),
              SizedBox(
                width: MediaQuery.of(context).size.width -
                    AppSpace.gutter * 2,
                child: _MetricCard(
                  label: s.t(
                    'Required Working Capital',
                    'आवश्यक कार्यशील पूंजी',
                  ),
                  value: workingCap > 0 ? _money(workingCap) : _money(0),
                  color: AppColors.warning,
                  tooltip: s.t(
                    'Estimated capital needed before receiving payments (EMD + costs − expected revenue).',
                    'भुगतान प्राप्त होने से पहले आवश्यक पूंजी (EMD + लागत − राजस्व)।',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final String display;
  final void Function(double) onChanged;
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.display,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppText.body),
          Text(
            display,
            style: AppText.bodyStrong.copyWith(color: AppColors.brand),
          ),
        ],
      ),
      SliderTheme(
        data: SliderTheme.of(context).copyWith(
          activeTrackColor: AppColors.brand,
          thumbColor: AppColors.brand,
          inactiveTrackColor: AppColors.border,
          overlayColor: AppColors.brandTint,
          trackHeight: 3,
        ),
        child: Slider(value: value, min: min, max: max, onChanged: onChanged),
      ),
    ],
  );
}
