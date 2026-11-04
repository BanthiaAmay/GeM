import 'package:flutter/material.dart';
import '../core/models.dart' show categories;
import '../core/theme.dart';
import '../data/app_store.dart';
import '../data/sample_bids.dart';
import 'analytics_charts.dart';
import 'charts.dart' show moneyCompact;
import 'components.dart';
import 'glass.dart';
import 'scroll_hint.dart';

/// Insights & analytics: an overview that leads to bid trends, category mix
/// and bid fit. Runs on [SampleBids] (labelled "Illustrative data" on every
/// screen) until a live bid feed exists; the calculator-progress figure on
/// the overview is real, read from the user's saved results.
///
/// Routes: /insights, /insights-trends, /insights-categories, /insights-fit.
/// The date range lives in [AppStore.insightsDays] so it carries across
/// all four screens.

final _allBids = SampleBids.build();
const _categoryOrder = ['office', 'it', 'furniture', 'cleaning', 'other'];

DateTime get _today {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

String _dm(DateTime d) => '${d.day}/${d.month}';

/// One time bucket of the chosen range.
class _Bucket {
  final DateTime start;
  final DateTime end;
  final int count;
  final int previous;
  const _Bucket(this.start, this.end, this.count, this.previous);
}

int _bucketDays(int days) => switch (days) {
  7 => 1,
  30 => 6,
  _ => 15,
};

List<_Bucket> _buckets(int days) {
  final b = _bucketDays(days);
  final n = days ~/ b;
  int inRange(int fromAgo, int toAgo) => _allBids
      .where((x) => x.postedDaysAgo >= toAgo && x.postedDaysAgo <= fromAgo)
      .length;
  return [
    for (var i = 0; i < n; i++)
      () {
        final oldest = days - 1 - i * b;
        final newest = days - (i + 1) * b;
        return _Bucket(
          _today.subtract(Duration(days: oldest)),
          _today.subtract(Duration(days: newest)),
          inRange(oldest, newest),
          inRange(oldest + days, newest + days),
        );
      }(),
  ];
}

List<SampleBid> _inRange(int days, {String? category}) => [
  for (final b in _allBids)
    if (b.postedDaysAgo < days && (category == null || b.category == category))
      b,
];

int _closingSoon() =>
    _allBids.where((b) => b.closesInDays >= 0 && b.closesInDays <= 7).length;

String _categoryName(AppStore s, String key) {
  final c = categories[key]!;
  return s.t(c[0], c[1]);
}

List<(int, String)> _rangeOptions(AppStore s) => [
  (7, s.t('Last 7 days', 'पिछले 7 दिन')),
  (30, s.t('Last 30 days', 'पिछले 30 दिन')),
  (90, s.t('Last 90 days', 'पिछले 90 दिन')),
];

String _bidsText(AppStore s, int n) => n == 1
    ? s.t('1 bid', '1 बोली')
    : s.t('{n} bids', '{n} बोलियाँ', vars: {'n': '$n'});

String _rangeText(_Bucket b) =>
    b.start == b.end ? _dm(b.start) : '${_dm(b.start)}–${_dm(b.end)}';

// ───────────────────────── shared scaffold ─────────────────────────

class _InsightsScaffold extends StatelessWidget {
  final AppStore store;
  final String title;
  final List<Widget> children;
  const _InsightsScaffold({
    required this.store,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final s = store;
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            GlassBar.top(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.sm,
                AppSpace.sm,
                AppSpace.sm,
                AppSpace.sm,
              ),
              child: Row(
                children: [
                  AppIconButton(
                    icon: Icons.arrow_back_ios_new,
                    tooltip: s.t('Back', 'वापस'),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: AppText.title,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSize.tap),
                ],
              ),
            ),
            Expanded(
              child: ScrollMoreHint(
                builder: (context, controller) => SingleChildScrollView(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.gutter,
                    AppSpace.lg,
                    AppSpace.gutter,
                    80,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: children,
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
}

class _SampleNotice extends StatelessWidget {
  final AppStore store;
  final bool detailed;
  const _SampleNotice({required this.store, this.detailed = false});

  @override
  Widget build(BuildContext context) {
    final s = store;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StatusChip(
          s.t('Illustrative data', 'उदाहरण डेटा'),
          tone: StatusTone.info,
          icon: Icons.info_outline,
        ),
        if (detailed) ...[
          const SizedBox(height: AppSpace.sm),
          Text(
            s.t(
              'These charts use sample opportunities, not live GeM bids.',
              'ये चार्ट नमूना अवसरों का उपयोग करते हैं, GeM की लाइव बोलियों का नहीं।',
            ),
            style: AppText.caption,
          ),
        ],
      ],
    );
  }
}

Widget _sectionTitle(String title, [String? caption]) => Padding(
  padding: const EdgeInsets.only(bottom: AppSpace.lg),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Semantics(header: true, child: Text(title, style: AppText.h3)),
      if (caption != null) ...[
        const SizedBox(height: AppSpace.xs),
        Text(caption, style: AppText.caption),
      ],
    ],
  ),
);

Widget _emptyState(AppStore s) => StateView(
  kind: StateKind.empty,
  title: s.t('No opportunities in this range', 'इस सीमा में कोई अवसर नहीं'),
  message: s.t(
    'Try a longer date range or another category.',
    'लंबी तारीख सीमा या दूसरी श्रेणी आज़माएँ।',
  ),
);

// ───────────────────────── overview ─────────────────────────

class InsightsPage extends StatelessWidget {
  final AppStore store;
  const InsightsPage({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final s = store;
    final days = s.insightsDays;
    final buckets = _buckets(days);
    final matched = _inRange(days).length;
    final closing = _closingSoon();
    final b = _bucketDays(days);
    final tools = ['eligibility', 'revenue', 'pricing', 'roi'];
    final done = tools.where(s.completed.contains).length;

    return _InsightsScaffold(
      store: s,
      title: s.t('Insights', 'इनसाइट्स'),
      children: [
        Wrap(
          spacing: AppSpace.md,
          runSpacing: AppSpace.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            AppDropdownChip<int>(
              options: _rangeOptions(s),
              value: days,
              onChanged: s.setInsightsDays,
              semanticLabel: s.t('Date range', 'तारीख सीमा'),
            ),
            _SampleNotice(store: s),
          ],
        ),
        const SizedBox(height: AppSpace.xl),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _Metric(
                label: s.t('Matched bids', 'मेल खाती बोलियाँ'),
                value: '$matched',
              ),
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: _Metric(
                label: s.t('Closing soon', 'जल्द बंद होने वाली'),
                value: '$closing',
                color: AppColors.danger,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.xxxl),
        _sectionTitle(
          s.t('Matched bids by period', 'अवधि के अनुसार मेल खाती बोलियाँ'),
          b == 1
              ? s.t('Each bar is one day', 'हर बार एक दिन है')
              : s.t(
                  'Each bar covers {n} days',
                  'हर बार {n} दिन दर्शाता है',
                  vars: {'n': '$b'},
                ),
        ),
        AppBarChart(
          semanticLabel: s.t(
            'Bar chart of matched bids by period',
            'अवधि के अनुसार मेल खाती बोलियों का बार चार्ट',
          ),
          hint: s.t('Tap a bar for details', 'विवरण के लिए बार दबाएँ'),
          data: [
            for (final k in buckets)
              BarDatum(
                _dm(k.start),
                k.count.toDouble(),
                k.count == 1
                    ? s.t(
                        '{range} · 1 bid',
                        '{range} · 1 बोली',
                        vars: {'range': _rangeText(k)},
                      )
                    : s.t(
                        '{range} · {n} bids',
                        '{range} · {n} बोलियाँ',
                        vars: {'range': _rangeText(k), 'n': '${k.count}'},
                      ),
              ),
          ],
        ),
        const SizedBox(height: AppSpace.xl),
        AppCard(
          tone: AppCardTone.muted,
          padding: const EdgeInsets.all(AppSpace.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      s.t('Calculators completed', 'पूरे किए गए कैलकुलेटर'),
                      style: AppText.title,
                    ),
                  ),
                  Text(
                    '$done ${s.t('of', 'में से')} ${tools.length}',
                    style: AppText.bodyStrong.copyWith(color: AppColors.brand),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.md),
              AppProgressBar(
                value: done / tools.length,
                color: AppColors.brand,
                semanticLabel: s.t(
                  'Calculators completed',
                  'पूरे किए गए कैलकुलेटर',
                ),
              ),
              const SizedBox(height: AppSpace.sm),
              Text(
                s.t('From your saved results', 'आपके सहेजे परिणामों से'),
                style: AppText.caption,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.xxxl),
        _sectionTitle(s.t('Explore', 'खोजें')),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
          child: DividedList(
            children: [
              AppListTile(
                icon: Icons.show_chart,
                title: s.t('Bid trends', 'बोली रुझान'),
                subtitle: s.t('New matches over time', 'समय के साथ नए मेल'),
                onTap: () =>
                    Navigator.of(context).pushNamed('/insights-trends'),
              ),
              AppListTile(
                icon: Icons.pie_chart_outline,
                title: s.t('Category mix', 'श्रेणी मिश्रण'),
                subtitle: s.t(
                  'Which categories your matches fall in',
                  'आपके मेल किन श्रेणियों में हैं',
                ),
                onTap: () =>
                    Navigator.of(context).pushNamed('/insights-categories'),
              ),
              AppListTile(
                icon: Icons.scatter_plot_outlined,
                title: s.t('Bid fit', 'बोली उपयुक्तता'),
                subtitle: s.t(
                  'Bid value against profile match',
                  'बोली मूल्य बनाम प्रोफ़ाइल मेल',
                ),
                onTap: () => Navigator.of(context).pushNamed('/insights-fit'),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.xl),
        _SampleNotice(store: s, detailed: true),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Metric({
    required this.label,
    required this.value,
    this.color = AppColors.ink,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: '$label $value',
    child: ExcludeSemantics(
      child: AppCard(
        padding: const EdgeInsets.all(AppSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppText.caption),
            const SizedBox(height: AppSpace.xs),
            Text(value, style: AppText.h1.copyWith(color: color)),
          ],
        ),
      ),
    ),
  );
}

// ───────────────────────── trends ─────────────────────────

class InsightsTrendsPage extends StatelessWidget {
  final AppStore store;
  const InsightsTrendsPage({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final s = store;
    final days = s.insightsDays;
    final buckets = _buckets(days);
    final b = _bucketDays(days);
    final now = buckets.fold<int>(0, (a, k) => a + k.count);
    final before = buckets.fold<int>(0, (a, k) => a + k.previous);
    final delta = now - before;
    final closing = _closingSoon();

    String detail(_Bucket k) => k.count == 1
        ? s.t(
            '{range} · 1 bid',
            '{range} · 1 बोली',
            vars: {'range': _rangeText(k)},
          )
        : s.t(
            '{range} · {n} bids',
            '{range} · {n} बोलियाँ',
            vars: {'range': _rangeText(k), 'n': '${k.count}'},
          );

    return _InsightsScaffold(
      store: s,
      title: s.t('Bid trends', 'बोली रुझान'),
      children: [
        AppSegmentedControl<int>(
          semanticLabel: s.t('Date range', 'तारीख सीमा'),
          value: days,
          onChanged: s.setInsightsDays,
          options: [
            for (final (v, label) in _rangeOptions(s)) (v, '${v}D', label),
          ],
        ),
        const SizedBox(height: AppSpace.md),
        _SampleNotice(store: s),
        const SizedBox(height: AppSpace.xxl),
        _sectionTitle(
          s.t('New matched bids', 'नई मेल खाती बोलियाँ'),
          b == 1
              ? s.t('Each point is one day', 'हर बिंदु एक दिन है')
              : s.t(
                  'Each point covers {n} days',
                  'हर बिंदु {n} दिन दर्शाता है',
                  vars: {'n': '$b'},
                ),
        ),
        AppLineChart(
          semanticLabel: s.t(
            'Line chart of new matched bids over time',
            'समय के साथ नई मेल खाती बोलियों का लाइन चार्ट',
          ),
          hint: s.t(
            'Tap or hover a point for details',
            'विवरण के लिए बिंदु दबाएँ',
          ),
          data: [
            for (final k in buckets)
              LineDatum(
                _dm(k.start),
                k.count.toDouble(),
                detail(k),
                previous: k.previous.toDouble(),
              ),
          ],
        ),
        const SizedBox(height: AppSpace.sm),
        LineLegend(
          current: s.t('This period', 'यह अवधि'),
          previous: s.t('Previous period', 'पिछली अवधि'),
        ),
        const SizedBox(height: AppSpace.xxl),
        AppCard(
          tone: AppCardTone.muted,
          padding: const EdgeInsets.all(AppSpace.lg),
          child: Semantics(
            container: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.t(
                    'Compared with the previous {days} days',
                    'पिछले {days} दिनों की तुलना में',
                    vars: {'days': '$days'},
                  ),
                  style: AppText.caption,
                ),
                const SizedBox(height: AppSpace.xs),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      delta > 0
                          ? Icons.trending_up
                          : delta < 0
                          ? Icons.trending_down
                          : Icons.trending_flat,
                      color: delta > 0
                          ? AppColors.brand
                          : delta < 0
                          ? AppColors.danger
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: AppSpace.sm),
                    Text(
                      delta == 0
                          ? s.t('No change', 'कोई बदलाव नहीं')
                          : '${delta > 0 ? '+' : '−'}${delta.abs()}',
                      style: AppText.h2.copyWith(
                        color: delta > 0
                            ? AppColors.brand
                            : delta < 0
                            ? AppColors.danger
                            : AppColors.ink,
                      ),
                    ),
                    if (delta != 0) ...[
                      const SizedBox(width: AppSpace.sm),
                      Flexible(
                        child: Text(
                          s.t('matched bids', 'मेल खाती बोलियाँ'),
                          style: AppText.body,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpace.lg),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
          child: DividedList(
            children: [
              KeyValueRow(
                s.t('Closing soon', 'जल्द बंद होने वाली'),
                _bidsText(s, closing),
              ),
              AppListTile(
                icon: Icons.pie_chart_outline,
                title: s.t('Category mix', 'श्रेणी मिश्रण'),
                onTap: () =>
                    Navigator.of(context).pushNamed('/insights-categories'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ───────────────────────── category mix ─────────────────────────

class InsightsCategoriesPage extends StatelessWidget {
  final AppStore store;
  const InsightsCategoriesPage({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final s = store;
    final days = s.insightsDays;
    final bids = _inRange(days);
    final data = [
      for (var i = 0; i < _categoryOrder.length; i++)
        PieDatum(
          _categoryName(s, _categoryOrder[i]),
          bids.where((b) => b.category == _categoryOrder[i]).length.toDouble(),
          i,
        ),
    ];
    return _InsightsScaffold(
      store: s,
      title: s.t('Category mix', 'श्रेणी मिश्रण'),
      children: [
        Wrap(
          spacing: AppSpace.md,
          runSpacing: AppSpace.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            AppDropdownChip<int>(
              options: _rangeOptions(s),
              value: days,
              onChanged: s.setInsightsDays,
              semanticLabel: s.t('Date range', 'तारीख सीमा'),
            ),
            _SampleNotice(store: s),
          ],
        ),
        const SizedBox(height: AppSpace.xl),
        _sectionTitle(
          s.t('Matched bids by category', 'श्रेणी के अनुसार मेल खाती बोलियाँ'),
        ),
        if (bids.isEmpty)
          _emptyState(s)
        else
          AppPieChart(
            data: data,
            totalLabel: s.t('Total', 'कुल'),
            totalWord: s.t('matched bids', 'मेल खाती बोलियाँ'),
            semanticLabel: s.t(
              'Pie chart of matched bids by category',
              'श्रेणी के अनुसार मेल खाती बोलियों का पाई चार्ट',
            ),
            hint: s.t(
              'Tap or hover a slice for details',
              'विवरण के लिए हिस्सा दबाएँ',
            ),
            hideHint: s.t(
              'Tap to hide or show this category',
              'इस श्रेणी को छिपाने या दिखाने के लिए दबाएँ',
            ),
            detail: (d, pct) => d.value.round() == 1
                ? s.t(
                    '{category}: 1 bid ({pct}%)',
                    '{category}: 1 बोली ({pct}%)',
                    vars: {'category': d.label, 'pct': '$pct'},
                  )
                : s.t(
                    '{category}: {n} bids ({pct}%)',
                    '{category}: {n} बोलियाँ ({pct}%)',
                    vars: {
                      'category': d.label,
                      'n': '${d.value.round()}',
                      'pct': '$pct',
                    },
                  ),
          ),
        const SizedBox(height: AppSpace.xl),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
          child: AppListTile(
            icon: Icons.scatter_plot_outlined,
            title: s.t('Bid fit', 'बोली उपयुक्तता'),
            onTap: () => Navigator.of(context).pushNamed('/insights-fit'),
          ),
        ),
      ],
    );
  }
}

// ───────────────────────── bid fit ─────────────────────────

class InsightsFitPage extends StatefulWidget {
  final AppStore store;
  const InsightsFitPage({super.key, required this.store});

  @override
  State<InsightsFitPage> createState() => _InsightsFitPageState();
}

class _InsightsFitPageState extends State<InsightsFitPage> {
  String? _category; // null = all

  String _closes(SampleBid b) {
    final s = widget.store;
    if (b.closesInDays < 0) return s.t('closed', 'बंद');
    if (b.closesInDays == 0) return s.t('closes today', 'आज बंद होती है');
    if (b.closesInDays == 1) return s.t('closes in 1 day', '1 दिन में बंद');
    return s.t(
      'closes in {n} days',
      '{n} दिन में बंद',
      vars: {'n': '${b.closesInDays}'},
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    final days = s.insightsDays;
    final bids = _inRange(days, category: _category);
    final avg = bids.isEmpty
        ? 0
        : (bids.fold<int>(0, (a, b) => a + b.matchPct) / bids.length).round();
    final groups = [
      for (var i = 0; i < _categoryOrder.length; i++)
        ScatterGroup(_categoryName(s, _categoryOrder[i]), i),
    ];
    return _InsightsScaffold(
      store: s,
      title: s.t('Bid fit', 'बोली उपयुक्तता'),
      children: [
        Wrap(
          spacing: AppSpace.md,
          runSpacing: AppSpace.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            AppDropdownChip<int>(
              options: _rangeOptions(s),
              value: days,
              onChanged: s.setInsightsDays,
              semanticLabel: s.t('Date range', 'तारीख सीमा'),
            ),
            _SampleNotice(store: s),
          ],
        ),
        const SizedBox(height: AppSpace.md),
        AppChoiceChips<String?>(
          semanticLabel: s.t('Category', 'श्रेणी'),
          value: _category,
          onChanged: (v) => setState(() => _category = v),
          options: [
            (null, s.t('All categories', 'सभी श्रेणियाँ')),
            for (final k in _categoryOrder) (k, _categoryName(s, k)),
          ],
        ),
        const SizedBox(height: AppSpace.lg),
        _sectionTitle(
          s.t('Bid value and profile match', 'बोली मूल्य और प्रोफ़ाइल मेल'),
          s.t('Each point is one opportunity', 'हर बिंदु एक अवसर है'),
        ),
        if (bids.isEmpty)
          _emptyState(s)
        else ...[
          AppScatterChart(
            points: [
              for (final b in bids)
                ScatterPoint(
                  b.valueRs.toDouble(),
                  b.matchPct.toDouble(),
                  _categoryOrder.indexOf(b.category),
                  '${_categoryName(s, b.category)} · ${b.id}\n'
                  '${moneyCompact(b.valueRs.toDouble())} · '
                  '${b.matchPct}% ${s.t('match', 'मेल')} · ${_closes(b)}',
                ),
            ],
            groups: groups,
            yMin: 50,
            yMax: 100,
            yFormat: (v) => '${v.round()}%',
            xTitle: s.t('Estimated bid value', 'अनुमानित बोली मूल्य'),
            yTitle: s.t('Profile match', 'प्रोफ़ाइल मेल'),
            semanticLabel: s.t(
              'Scatter plot of bid value against profile match',
              'प्रोफ़ाइल मेल के मुकाबले बोली मूल्य का स्कैटर प्लॉट',
            ),
            hint: s.t(
              'Tap, hover or use arrow keys to select a point',
              'बिंदु चुनने के लिए दबाएँ या तीर कुंजियाँ उपयोग करें',
            ),
          ),
          const SizedBox(height: AppSpace.md),
          AppCard(
            tone: AppCardTone.muted,
            padding: const EdgeInsets.all(AppSpace.lg),
            child: Text(
              s.t(
                '{n} opportunities · average match {pct}%',
                '{n} अवसर · औसत मेल {pct}%',
                vars: {'n': '${bids.length}', 'pct': '$avg'},
              ),
              style: AppText.bodyStrong,
            ),
          ),
        ],
      ],
    );
  }
}
