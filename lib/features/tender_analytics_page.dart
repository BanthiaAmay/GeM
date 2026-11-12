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

num _emd(Map<String, dynamic> bid) {
  final d = Map<String, dynamic>.from(bid['details'] as Map? ?? {});
  final raw = (d['emd_amount'] ?? '').toString().replaceAll(',', '');
  return num.tryParse(raw) ?? 0;
}

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
    'manufacturing_cost',
    'labour_cost',
    'packaging_cost',
    'logistics_cost',
    'other_cost',
  ]) {
    sum += (ad[k] as num?) ?? 0;
  }
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

// Status cycle
const _statuses = [
  'saved',
  'shortlisted',
  'participating',
  'submitted',
  'awarded',
  'closed',
];

String _statusLabel(AppStore s, String status) => switch (status) {
  'saved' => s.t('Saved', 'सहेजा'),
  'shortlisted' => s.t('Shortlisted', 'शॉर्टलिस्टेड'),
  'participating' => s.t('Participating', 'भागीदारी'),
  'submitted' => s.t('Submitted', 'जमा किया'),
  'awarded' => s.t('Awarded', 'पुरस्कृत'),
  'closed' => s.t('Closed', 'बंद'),
  _ => status,
};

Color _statusColor(String status) => switch (status) {
  'awarded' => AppColors.brand,
  'submitted' => AppColors.info,
  'participating' => AppColors.warning,
  'shortlisted' => AppColors.violet,
  'closed' => AppColors.textHint,
  _ => AppColors.textSecondary,
};

// ── Entry point ─────────────────────────────────────────────────────────────

class TenderAnalyticsPage extends StatefulWidget {
  final AppStore store;
  const TenderAnalyticsPage({super.key, required this.store});
  @override
  State<TenderAnalyticsPage> createState() => _TenderAnalyticsPageState();
}

class _TenderAnalyticsPageState extends State<TenderAnalyticsPage> {
  int _tab = 0;
  final _tabs = ['Overview', 'Financial', 'Lifecycle', 'Simulator', 'Payments'];

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
            // Tab bar
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
                        color: active ? AppColors.brand : AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        _tabs[i],
                        style: AppText.label.copyWith(
                          color:
                              active ? AppColors.surface : AppColors.textSecondary,
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
                    0 => _OverviewTab(store: s, onTabChange: (t) => setState(() => _tab = t)),
                    1 => _FinancialTab(store: s),
                    2 => _LifecycleTab(store: s),
                    3 => _SimulatorTab(store: s),
                    4 => _PaymentsTab(store: s),
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
      'Save bids from Find Bids to understand their financial requirements, estimated costs, potential returns and payment timelines.',
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

  const _MetricCard({
    required this.label,
    required this.value,
    this.color = AppColors.ink,
    this.tooltip,
    this.sub,
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
            Text(sub!, style: AppText.caption.copyWith(color: AppColors.textHint)),
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

    final totalEmd = active.fold<num>(0, (a, r) => a + _emd(_bid(r)));
    final totalValue = active.fold<num>(0, (a, r) => a + _tenderValue(_bid(r)));

    num? execCost;
    num? revenue;
    for (final d in adActive) {
      final c = _totalCost(d);
      final sp = (d['selling_price'] as num?) ?? 0;
      if (c > 0) execCost = (execCost ?? 0) + c;
      if (sp > 0) revenue = (revenue ?? 0) + sp;
    }
    final netProfit = (revenue != null && execCost != null)
        ? revenue - execCost
        : null;

    // Upcoming deadlines
    final now = DateTime.now();
    final urgent = <Map<String, dynamic>>[];
    final upcoming = <Map<String, dynamic>>[];
    for (final r in bids) {
      final b = _bid(r);
      final ca = DateTime.tryParse(b['closes_at'] as String? ?? '');
      if (ca == null) continue;
      final days = ca.difference(now).inDays;
      if (days >= 0 && days <= 7) {
        urgent.add(r);
      } else if (days > 7 && days <= 30) {
        upcoming.add(r);
      }
    }

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
              'Financial intelligence for your saved tenders',
              'सहेजी बोलियों की वित्तीय समझ',
            ),
            style: AppText.caption.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpace.lg),
          Wrap(
            spacing: AppSpace.sm,
            runSpacing: AppSpace.sm,
            children: [
              SizedBox(
                width: (MediaQuery.of(context).size.width - AppSpace.gutter * 2 - AppSpace.sm) / 2,
                child: _MetricCard(
                  label: s.t('Active Saved Bids', 'सक्रिय सहेजी बोलियाँ'),
                  value: '${active.length}',
                  color: AppColors.brand,
                  tooltip: s.t(
                    'Saved bids whose submission deadline has not yet passed.',
                    'सहेजी बोलियाँ जिनकी समय-सीमा नहीं गुज़री।',
                  ),
                ),
              ),
              SizedBox(
                width: (MediaQuery.of(context).size.width - AppSpace.gutter * 2 - AppSpace.sm) / 2,
                child: _MetricCard(
                  label: s.t('Combined Tender Value', 'संयुक्त टेंडर मूल्य'),
                  value: totalValue > 0 ? _money(totalValue) : '—',
                  tooltip: s.t(
                    'Sum of estimated values of all active saved tenders.',
                    'सभी सक्रिय सहेजी बोलियों का अनुमानित मूल्य।',
                  ),
                ),
              ),
              SizedBox(
                width: (MediaQuery.of(context).size.width - AppSpace.gutter * 2 - AppSpace.sm) / 2,
                child: _MetricCard(
                  label: s.t('Total EMD Requirement', 'कुल EMD आवश्यकता'),
                  value: totalEmd > 0 ? _money(totalEmd) : '—',
                  color: AppColors.warning,
                  sub: s.t('May be nil for MSME', 'MSME के लिए शून्य हो सकता है'),
                  tooltip: s.t(
                    'Combined EMD across active saved bids. MSME-registered sellers may be exempt.',
                    'सक्रिय बोलियों पर कुल EMD। MSME विक्रेता छूट के पात्र हो सकते हैं।',
                  ),
                ),
              ),
              SizedBox(
                width: (MediaQuery.of(context).size.width - AppSpace.gutter * 2 - AppSpace.sm) / 2,
                child: _MetricCard(
                  label: s.t('Est. Execution Cost', 'अनु. निष्पादन लागत'),
                  value: execCost != null ? _money(execCost) : '—',
                  tooltip: s.t(
                    'Sum of costs entered in Financial tab. Enter costs to see this.',
                    'Financial टैब में दर्ज लागत का योग।',
                  ),
                ),
              ),
              SizedBox(
                width: (MediaQuery.of(context).size.width - AppSpace.gutter * 2 - AppSpace.sm) / 2,
                child: _MetricCard(
                  label: s.t('Potential Revenue', 'संभावित राजस्व'),
                  value: revenue != null ? _money(revenue) : '—',
                  color: AppColors.brand,
                  tooltip: s.t(
                    'Sum of selling prices entered in Financial tab. Not guaranteed revenue.',
                    'Financial टैब में दर्ज बिक्री मूल्यों का योग। गारंटीड राजस्व नहीं।',
                  ),
                ),
              ),
              SizedBox(
                width: (MediaQuery.of(context).size.width - AppSpace.gutter * 2 - AppSpace.sm) / 2,
                child: _MetricCard(
                  label: s.t('Est. Net Profit', 'अनु. शुद्ध लाभ'),
                  value: netProfit != null ? _money(netProfit) : '—',
                  color: netProfit != null
                      ? (netProfit >= 0 ? AppColors.brand : AppColors.danger)
                      : AppColors.ink,
                  tooltip: s.t(
                    'Estimated revenue minus estimated execution costs. Enter costs to see this.',
                    'अनुमानित राजस्व घटाएं अनुमानित लागत।',
                  ),
                ),
              ),
            ],
          ),

          // Upcoming deadlines
          if (urgent.isNotEmpty || upcoming.isNotEmpty) ...[
            const SizedBox(height: AppSpace.xxl),
            Text(
              s.t('Upcoming Deadlines', 'आने वाली समय-सीमाएँ'),
              style: AppText.h3,
            ),
            const SizedBox(height: AppSpace.md),
            AppCard(
              padding: EdgeInsets.zero,
              child: DividedList(
                children: [
                  for (final r in [...urgent, ...upcoming])
                    _DeadlineRow(
                      row: r,
                      urgent: urgent.contains(r),
                      onTap: () => onTabChange(1),
                    ),
                ],
              ),
            ),
          ],

          // Financial highlights
          const SizedBox(height: AppSpace.xxl),
          Text(s.t('Financial Highlights', 'वित्तीय मुख्य बातें'), style: AppText.h3),
          const SizedBox(height: AppSpace.md),
          AppCard(
            tone: AppCardTone.muted,
            padding: const EdgeInsets.all(AppSpace.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (totalEmd > 0)
                  _HighlightBullet(
                    s.t(
                      'Your combined EMD requirement is ${_money(totalEmd)} across ${active.length} active bid(s).',
                      'आपकी कुल EMD आवश्यकता ${active.length} सक्रिय बोली(यों) में ${_money(totalEmd)} है।',
                    ),
                    icon: Icons.lock_outline,
                    color: AppColors.warning,
                  ),
                if (urgent.isNotEmpty)
                  _HighlightBullet(
                    s.t(
                      '${urgent.length} saved bid(s) closing within the next 7 days.',
                      '${urgent.length} सहेजी बोली(याँ) अगले 7 दिनों में बंद होती हैं।',
                    ),
                    icon: Icons.timer_outlined,
                    color: AppColors.danger,
                  ),
                if (execCost != null)
                  _HighlightBullet(
                    s.t(
                      'Your estimated execution cost across selected bids is ${_money(execCost)}.',
                      'चुनी बोलियों की अनुमानित निष्पादन लागत ${_money(execCost)} है।',
                    ),
                    icon: Icons.payments_outlined,
                    color: AppColors.info,
                  ),
                if (totalEmd == 0 && urgent.isEmpty && execCost == null)
                  Text(
                    s.t(
                      'Enter costs in the Financial tab to see personalised insights.',
                      'व्यक्तिगत अंतर्दृष्टि देखने के लिए Financial टैब में लागत दर्ज करें।',
                    ),
                    style: AppText.body.copyWith(color: AppColors.textSecondary),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeadlineRow extends StatelessWidget {
  final Map<String, dynamic> row;
  final bool urgent;
  final VoidCallback onTap;
  const _DeadlineRow({required this.row, required this.urgent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final b = _bid(row);
    final ca = DateTime.tryParse(b['closes_at'] as String? ?? '');
    final days = ca?.difference(DateTime.now()).inDays;
    return AppListTile(
      icon: Icons.calendar_today_outlined,
      title: _title(row),
      subtitle: ca != null ? _fmt(ca) : '',
      trailing: days != null
          ? StatusChip(
              '$days d',
              tone: urgent ? StatusTone.danger : StatusTone.warning,
            )
          : null,
      onTap: onTap,
    );
  }
}

class _HighlightBullet extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color;
  const _HighlightBullet(this.text, {required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpace.md),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: AppSpace.sm),
        Expanded(child: Text(text, style: AppText.body)),
      ],
    ),
  );
}

// ── Tab 1 — Financial ────────────────────────────────────────────────────────

class _FinancialTab extends StatefulWidget {
  final AppStore store;
  const _FinancialTab({required this.store});
  @override
  State<_FinancialTab> createState() => _FinancialTabState();
}

class _FinancialTabState extends State<_FinancialTab> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    final bids = s.savedBids.where((r) {
      if (_filter == 'all') return true;
      if (_filter == 'active') return _isActive(r);
      final ad = s.getAnalyticsDatum(_sourceId(r));
      if (_filter == 'awarded') return (ad['status'] ?? 'saved') == 'awarded';
      return true;
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.gutter,
            vertical: AppSpace.sm,
          ),
          child: Row(
            children: [
              for (final (k, label) in [
                ('all', s.t('All', 'सभी')),
                ('active', s.t('Active', 'सक्रिय')),
                ('awarded', s.t('Awarded', 'पुरस्कृत')),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: AppSpace.sm),
                  child: GestureDetector(
                    onTap: () => setState(() => _filter = k),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.md,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _filter == k
                            ? AppColors.brand
                            : AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        label,
                        style: AppText.label.copyWith(
                          color: _filter == k
                              ? AppColors.surface
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.gutter,
              AppSpace.xs,
              AppSpace.gutter,
              80,
            ),
            itemCount: bids.length,
            separatorBuilder: (_, i) => const SizedBox(height: AppSpace.md),
            itemBuilder: (context, i) =>
                _BidFinancialCard(store: s, row: bids[i]),
          ),
        ),
      ],
    );
  }
}

class _BidFinancialCard extends StatefulWidget {
  final AppStore store;
  final Map<String, dynamic> row;
  const _BidFinancialCard({required this.store, required this.row});
  @override
  State<_BidFinancialCard> createState() => _BidFinancialCardState();
}

class _BidFinancialCardState extends State<_BidFinancialCard> {
  bool _expanded = false;

  static const _costFields = [
    ('procurement_cost', 'Procurement', 'खरीद लागत'),
    ('manufacturing_cost', 'Manufacturing', 'निर्माण लागत'),
    ('labour_cost', 'Labour', 'श्रम लागत'),
    ('packaging_cost', 'Packaging', 'पैकेजिंग'),
    ('logistics_cost', 'Logistics', 'रसद लागत'),
    ('other_cost', 'Other', 'अन्य लागत'),
  ];

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    final sourceId = _sourceId(widget.row);
    final ad = s.getAnalyticsDatum(sourceId);
    final status = (ad['status'] as String?) ?? 'saved';
    final cost = _totalCost(ad);
    final sp = (ad['selling_price'] as num?) ?? 0;
    final profit = sp > 0 || cost > 0 ? sp - cost : null;
    final margin =
        sp > 0 ? ((profit! / sp) * 100).toStringAsFixed(1) : null;
    final tv = _tenderValue(_bid(widget.row));
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
              const SizedBox(width: AppSpace.sm),
              GestureDetector(
                onTap: () {
                  final idx = _statuses.indexOf(status);
                  final next = _statuses[(idx + 1) % _statuses.length];
                  s.saveAnalyticsDatum(sourceId, {'status': next});
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.sm,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(color: _statusColor(status).withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    _statusLabel(s, status),
                    style: AppText.label.copyWith(color: _statusColor(status)),
                  ),
                ),
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
          // Summary row
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
                  s.t('Profit', 'लाभ'),
                  profit != null ? _money(profit) : '—',
                  color: profit != null
                      ? (profit >= 0 ? AppColors.brand : AppColors.danger)
                      : null,
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: _SummaryChip(
                  s.t('Margin', 'मार्जिन'),
                  margin != null ? '$margin%' : '—',
                  color: margin != null
                      ? (double.parse(margin) >= 0
                          ? AppColors.brand
                          : AppColors.danger)
                      : null,
                ),
              ),
            ],
          ),
          // Expand/collapse
          const SizedBox(height: AppSpace.sm),
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              children: [
                Text(
                  _expanded
                      ? s.t('Hide cost details', 'लागत विवरण छुपाएँ')
                      : s.t('Enter / edit costs', 'लागत दर्ज करें'),
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
            const SizedBox(height: AppSpace.md),
            for (final (key, en, hi) in _costFields)
              _CostField(
                label: s.t(en, hi),
                initialValue: (ad[key] as num?)?.toString() ?? '',
                onChanged: (v) {
                  final parsed = num.tryParse(v);
                  s.saveAnalyticsDatum(sourceId, {key: parsed});
                },
              ),
            _CostField(
              label: s.t('Selling Price', 'बिक्री मूल्य'),
              initialValue: (ad['selling_price'] as num?)?.toString() ?? '',
              onChanged: (v) {
                final parsed = num.tryParse(v);
                s.saveAnalyticsDatum(sourceId, {'selling_price': parsed});
              },
            ),
            _CostField(
              label: s.t('GST Rate %', 'GST दर %'),
              initialValue: (ad['gst_rate'] as num?)?.toString() ?? '18',
              onChanged: (v) {
                final parsed = num.tryParse(v);
                s.saveAnalyticsDatum(sourceId, {'gst_rate': parsed ?? 18});
              },
            ),
            if (tv > 0) ...[
              const SizedBox(height: AppSpace.sm),
              GestureDetector(
                onTap: () {
                  final est = tv * 0.72;
                  s.saveAnalyticsDatum(sourceId, {'procurement_cost': est});
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.md,
                    vertical: AppSpace.sm,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.infoTint,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.auto_fix_high, size: 15, color: AppColors.info),
                      const SizedBox(width: AppSpace.sm),
                      Expanded(
                        child: Text(
                          s.t(
                            'Est. Execution Cost (72% of tender value = ${_money(tv * 0.72)}) — assumption',
                            'अनु. निष्पादन लागत (टेंडर मूल्य का 72% = ${_money(tv * 0.72)}) — अनुमान',
                          ),
                          style: AppText.caption.copyWith(color: AppColors.info),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
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

class _CostField extends StatefulWidget {
  final String label;
  final String initialValue;
  final void Function(String) onChanged;
  const _CostField({
    required this.label,
    required this.initialValue,
    required this.onChanged,
  });
  @override
  State<_CostField> createState() => _CostFieldState();
}

class _CostFieldState extends State<_CostField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpace.sm),
    child: Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(
            widget.label,
            style: AppText.caption,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: AppSpace.sm),
        Expanded(
          child: TextField(
            controller: _ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
            onSubmitted: widget.onChanged,
            onEditingComplete: () => widget.onChanged(_ctrl.text),
          ),
        ),
      ],
    ),
  );
}

// ── Tab 2 — Lifecycle ────────────────────────────────────────────────────────

class _LifecycleTab extends StatelessWidget {
  final AppStore store;
  const _LifecycleTab({required this.store});

  @override
  Widget build(BuildContext context) {
    final s = store;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.gutter,
        AppSpace.md,
        AppSpace.gutter,
        80,
      ),
      itemCount: s.savedBids.length,
      separatorBuilder: (_, i) => const SizedBox(height: AppSpace.md),
      itemBuilder: (context, i) =>
          _BidLifecycleCard(store: s, row: s.savedBids[i]),
    );
  }
}

class _BidLifecycleCard extends StatefulWidget {
  final AppStore store;
  final Map<String, dynamic> row;
  const _BidLifecycleCard({required this.store, required this.row});
  @override
  State<_BidLifecycleCard> createState() => _BidLifecycleCardState();
}

class _BidLifecycleCardState extends State<_BidLifecycleCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    final sourceId = _sourceId(widget.row);
    final ad = s.getAnalyticsDatum(sourceId);
    final b = _bid(widget.row);
    final savedAt = DateTime.tryParse(widget.row['saved_at'] as String? ?? '');
    final submissionAt = DateTime.tryParse(b['closes_at'] as String? ?? '');
    final awardAt = DateTime.tryParse(ad['award_date'] as String? ?? '');
    final deliveryAt = DateTime.tryParse(ad['delivery_date'] as String? ?? '');
    final invoiceAt = DateTime.tryParse(ad['invoice_date'] as String? ?? '');
    final payAt = DateTime.tryParse(ad['payment_received_date'] as String? ?? '');

    // Estimate result date ~21 days after submission
    final resultAt = submissionAt?.add(const Duration(days: 21));

    final stages = [
      (s.t('Bid Saved', 'बोली सहेजी'), savedAt, false),
      (s.t('Submission Deadline', 'जमा करने की अंतिम तिथि'), submissionAt, false),
      (s.t('Evaluation / Result', 'मूल्यांकन / परिणाम'), resultAt, true),
      (s.t('Award', 'पुरस्कार'), awardAt, ad['award_date'] == null),
      (s.t('Delivery', 'डिलीवरी'), deliveryAt, ad['delivery_date'] == null),
      (s.t('Invoice', 'चालान'), invoiceAt, ad['invoice_date'] == null),
      (s.t('Payment', 'भुगतान'), payAt, ad['payment_received_date'] == null),
    ];

    return AppCard(
      padding: const EdgeInsets.all(AppSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _title(widget.row),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.bodyStrong,
                  ),
                ),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  color: AppColors.textHint,
                ),
              ],
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: AppSpace.lg),
            for (var i = 0; i < stages.length; i++)
              _StageRow(
                label: stages[i].$1,
                date: stages[i].$2,
                isEstimated: stages[i].$3,
                isLast: i == stages.length - 1,
              ),
          ],
        ],
      ),
    );
  }
}

class _StageRow extends StatelessWidget {
  final String label;
  final DateTime? date;
  final bool isEstimated;
  final bool isLast;
  const _StageRow({
    required this.label,
    required this.date,
    required this.isEstimated,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final past = date != null && date!.isBefore(now);
    final dotColor = date == null
        ? AppColors.border
        : past
            ? AppColors.brand
            : AppColors.borderStrong;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dotColor,
                border: Border.all(
                  color: past ? AppColors.brand : AppColors.borderStrong,
                  width: 2,
                ),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 32,
                color: AppColors.border,
              ),
          ],
        ),
        const SizedBox(width: AppSpace.md),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpace.md),
            child: Row(
              children: [
                Expanded(child: Text(label, style: AppText.body)),
                if (date != null)
                  Text(
                    isEstimated
                        ? '${_fmt(date!)} (Est.)'
                        : _fmt(date!),
                    style: AppText.caption.copyWith(
                      color: isEstimated ? AppColors.textHint : AppColors.textSecondary,
                    ),
                  )
                else
                  Text(
                    '—',
                    style: AppText.caption.copyWith(color: AppColors.textHint),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Tab 3 — Simulator ────────────────────────────────────────────────────────

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
      totalEmdSel += _emd(_bid(r));
      final ad = s.getAnalyticsDatum(sid);
      final sp = (ad['selling_price'] as num?) ?? (_tenderValue(_bid(r)) * 0.95);
      totalRevSel += sp;
      totalCostSel += _totalCost(ad) > 0
          ? _totalCost(ad)
          : _tenderValue(_bid(r)) * 0.72;
    }

    final expWins = (selCount * _winRate).ceil();
    final expRev = totalRevSel * _winRate;
    final expCost = totalCostSel * (1 + _costOverrun);
    final expProfit = expRev - expCost;
    final workingCap = (totalEmdSel + expCost - expRev).clamp(0, double.infinity);

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
          Text(s.t('Select Bids to Simulate', 'अनुकरण के लिए बोलियाँ चुनें'), style: AppText.h3),
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
          Text(s.t('Simulation Results', 'अनुकरण परिणाम'), style: AppText.h3),
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
                width: (MediaQuery.of(context).size.width - AppSpace.gutter * 2 - AppSpace.sm) / 2,
                child: _MetricCard(
                  label: s.t('Expected Wins', 'अपेक्षित जीत'),
                  value: '$expWins of $selCount',
                  color: AppColors.brand,
                ),
              ),
              SizedBox(
                width: (MediaQuery.of(context).size.width - AppSpace.gutter * 2 - AppSpace.sm) / 2,
                child: _MetricCard(
                  label: s.t('Expected Revenue', 'अपेक्षित राजस्व'),
                  value: expRev > 0 ? _money(expRev) : '—',
                  color: AppColors.brand,
                ),
              ),
              SizedBox(
                width: (MediaQuery.of(context).size.width - AppSpace.gutter * 2 - AppSpace.sm) / 2,
                child: _MetricCard(
                  label: s.t('Expected Cost', 'अपेक्षित लागत'),
                  value: expCost > 0 ? _money(expCost) : '—',
                ),
              ),
              SizedBox(
                width: (MediaQuery.of(context).size.width - AppSpace.gutter * 2 - AppSpace.sm) / 2,
                child: _MetricCard(
                  label: s.t('Expected Net Profit', 'अपेक्षित शुद्ध लाभ'),
                  value: expRev > 0 ? _money(expProfit) : '—',
                  color: expProfit >= 0 ? AppColors.brand : AppColors.danger,
                ),
              ),
              SizedBox(
                width: MediaQuery.of(context).size.width - AppSpace.gutter * 2,
                child: _MetricCard(
                  label: s.t('Required Working Capital', 'आवश्यक कार्यशील पूंजी'),
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
          Text(display, style: AppText.bodyStrong.copyWith(color: AppColors.brand)),
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

// ── Tab 4 — Payments ─────────────────────────────────────────────────────────

class _PaymentsTab extends StatelessWidget {
  final AppStore store;
  const _PaymentsTab({required this.store});

  @override
  Widget build(BuildContext context) {
    final s = store;
    final awarded = s.savedBids.where((r) {
      final ad = s.getAnalyticsDatum(_sourceId(r));
      final st = (ad['status'] as String?) ?? 'saved';
      return st == 'awarded' || st == 'closed';
    }).toList();

    num totalExpected = 0;
    num totalReceived = 0;
    for (final r in awarded) {
      final ad = s.getAnalyticsDatum(_sourceId(r));
      totalExpected += (ad['po_value'] as num?) ?? 0;
      totalReceived += (ad['amount_received'] as num?) ?? 0;
    }
    final totalPending = totalExpected - totalReceived;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.gutter,
            AppSpace.md,
            AppSpace.gutter,
            AppSpace.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: _MetricCard(
                  label: s.t('Total Expected', 'कुल अपेक्षित'),
                  value: totalExpected > 0 ? _money(totalExpected) : '—',
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: _MetricCard(
                  label: s.t('Received', 'प्राप्त'),
                  value: totalReceived > 0 ? _money(totalReceived) : '—',
                  color: AppColors.brand,
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: _MetricCard(
                  label: s.t('Pending', 'लंबित'),
                  value: totalPending > 0 ? _money(totalPending) : '—',
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: awarded.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpace.gutter),
                    child: Text(
                      s.t(
                        "No awarded orders yet. Mark bids as 'Awarded' in Financial to track payments.",
                        "अभी कोई पुरस्कृत ऑर्डर नहीं। भुगतान ट्रैक करने के लिए Financial में 'Awarded' चुनें।",
                      ),
                      textAlign: TextAlign.center,
                      style: AppText.body.copyWith(color: AppColors.textSecondary),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.gutter,
                    AppSpace.xs,
                    AppSpace.gutter,
                    80,
                  ),
                  itemCount: awarded.length,
                  separatorBuilder: (_, i) => const SizedBox(height: AppSpace.md),
                  itemBuilder: (context, i) =>
                      _PaymentCard(store: s, row: awarded[i]),
                ),
        ),
      ],
    );
  }
}

class _PaymentCard extends StatelessWidget {
  final AppStore store;
  final Map<String, dynamic> row;
  const _PaymentCard({required this.store, required this.row});

  @override
  Widget build(BuildContext context) {
    final s = store;
    final sourceId = _sourceId(row);
    final ad = s.getAnalyticsDatum(sourceId);
    final poValue = (ad['po_value'] as num?) ?? 0;
    final received = (ad['amount_received'] as num?) ?? 0;
    final outstanding = poValue - received;

    final deliveryAt = DateTime.tryParse(ad['delivery_date'] as String? ?? '');
    final expectedPayment = deliveryAt?.add(const Duration(days: 15));
    final invoiceAt = DateTime.tryParse(ad['invoice_date'] as String? ?? '');
    final payAt = DateTime.tryParse(ad['payment_received_date'] as String? ?? '');

    // Status
    String payStatus = 'pending';
    if (poValue > 0 && received >= poValue) {
      payStatus = 'paid';
    } else if (received > 0) {
      payStatus = 'partial';
    } else if (expectedPayment != null &&
        expectedPayment.isBefore(DateTime.now()) &&
        received == 0) {
      payStatus = 'overdue';
    }

    final statusColor = switch (payStatus) {
      'paid' => AppColors.brand,
      'partial' => AppColors.warning,
      'overdue' => AppColors.danger,
      _ => AppColors.textSecondary,
    };
    final statusLabel = switch (payStatus) {
      'paid' => s.t('Paid', 'भुगतान हो गया'),
      'partial' => s.t('Partial', 'आंशिक'),
      'overdue' => s.t('Overdue', 'अतिदेय'),
      _ => s.t('Pending', 'लंबित'),
    };

    return AppCard(
      padding: const EdgeInsets.all(AppSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _title(row),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.bodyStrong,
                ),
              ),
              StatusChip(
                statusLabel,
                tone: switch (payStatus) {
                  'paid' => StatusTone.success,
                  'overdue' => StatusTone.danger,
                  'partial' => StatusTone.warning,
                  _ => StatusTone.neutral,
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          _CostField(
            label: s.t('PO Value', 'PO मूल्य'),
            initialValue: poValue > 0 ? poValue.toString() : '',
            onChanged: (v) {
              s.saveAnalyticsDatum(sourceId, {'po_value': num.tryParse(v)});
            },
          ),
          _CostField(
            label: s.t('Received', 'प्राप्त'),
            initialValue: received > 0 ? received.toString() : '',
            onChanged: (v) {
              s.saveAnalyticsDatum(sourceId, {'amount_received': num.tryParse(v)});
            },
          ),
          if (outstanding > 0) ...[
            const SizedBox(height: AppSpace.sm),
            Row(
              children: [
                Text(
                  s.t('Outstanding: ', 'बकाया: '),
                  style: AppText.caption,
                ),
                Text(
                  _money(outstanding),
                  style: AppText.bodyStrong.copyWith(color: statusColor),
                ),
              ],
            ),
          ],
          if (expectedPayment != null) ...[
            const SizedBox(height: AppSpace.xs),
            Text(
              '${s.t('Est. Payment Date', 'अनु. भुगतान तिथि')}: ${_fmt(expectedPayment)} (Est.)',
              style: AppText.caption.copyWith(color: AppColors.textHint),
            ),
          ],
          if (invoiceAt != null) ...[
            const SizedBox(height: AppSpace.xs),
            Text(
              '${s.t('Invoice', 'चालान')}: ${_fmt(invoiceAt)}',
              style: AppText.caption,
            ),
          ],
          if (payAt != null) ...[
            const SizedBox(height: AppSpace.xs),
            Text(
              '${s.t('Payment Received', 'भुगतान प्राप्त')}: ${_fmt(payAt)}',
              style: AppText.caption.copyWith(color: AppColors.brand),
            ),
          ],
        ],
      ),
    );
  }
}
