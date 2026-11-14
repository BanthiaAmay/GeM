import 'package:flutter/material.dart';
import '../core/models.dart' show money;
import '../core/tokens.dart';
import '../data/app_store.dart';
import 'components.dart';
import 'widgets.dart' show openLink;

/// One matched bid's estimated value: confidence, how it was reached, each
/// item's price and the offers behind it, and what could not be valued.
Future<void> showBidValuation(
  BuildContext context,
  AppStore store,
  String bidId,
  String title,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: false,
  backgroundColor: AppColors.surface,
  builder: (context) => DraggableScrollableSheet(
    expand: false,
    initialChildSize: 0.75,
    maxChildSize: 0.95,
    builder: (context, controller) => BidValuationView(
      store: store,
      bidId: bidId,
      title: title,
      controller: controller,
    ),
  ),
);

class BidValuationView extends StatefulWidget {
  final AppStore store;
  final String bidId;
  final String title;
  final ScrollController? controller;

  /// Injected in tests; defaults to [AppStore.bidValuationDetail].
  final Future<Map<String, dynamic>?> Function(String bidId)? load;
  const BidValuationView({
    super.key,
    required this.store,
    required this.bidId,
    required this.title,
    this.controller,
    this.load,
  });

  @override
  State<BidValuationView> createState() => _BidValuationViewState();
}

class _BidValuationViewState extends State<BidValuationView> {
  late Future<Map<String, dynamic>?> _future = _fetch();

  Future<Map<String, dynamic>?> _fetch() =>
      (widget.load ?? widget.store.bidValuationDetail)(widget.bidId);

  AppStore get s => widget.store;

  String _date(Object? iso) {
    final when = DateTime.tryParse('${iso ?? ''}')?.toLocal();
    if (when == null) return '—';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${when.day} ${months[when.month - 1]} ${when.year}';
  }

  String _pct(Object? value) =>
      value is num ? '${(value * 100).round()}%' : '—';

  String _reliabilityText(Object? value) {
    if (value is! num) return '—';
    if (value >= 0.9) {
      return s.t('3 or more offers per item', 'हर वस्तु के लिए 3 या अधिक ऑफ़र');
    }
    if (value >= 0.6) {
      return s.t('Mostly 2 offers per item', 'अधिकतर वस्तुओं के लिए 2 ऑफ़र');
    }
    return s.t('Mostly 1 offer per item', 'अधिकतर वस्तुओं के लिए 1 ऑफ़र');
  }

  (String, StatusTone) _band(Object? confidence) => switch (confidence) {
    'high' => (s.t('High confidence', 'उच्च विश्वसनीयता'), StatusTone.success),
    'medium' => (
      s.t('Medium confidence', 'मध्यम विश्वसनीयता'),
      StatusTone.warning,
    ),
    _ => (s.t('Low confidence', 'कम विश्वसनीयता'), StatusTone.neutral),
  };

  String _offerTier(Object? tier) => switch (tier) {
    'normal' => s.t('3+ offers', '3+ ऑफ़र'),
    'reduced' => s.t('2 offers', '2 ऑफ़र'),
    'provisional' => s.t('1 offer · provisional', '1 ऑफ़र · अस्थायी'),
    _ => s.t('Not priced', 'मूल्य नहीं मिला'),
  };

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _future,
      builder: (context, snap) {
        final children = <Widget>[
          const SheetHandle(),
          Text(
            s.t('Estimated value', 'अनुमानित मूल्य'),
            style: AppText.overline,
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            widget.title,
            style: AppText.title,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpace.lg),
        ];
        if (snap.connectionState != ConnectionState.done) {
          children.add(
            StateView(
              kind: StateKind.loading,
              title: s.t('Loading estimate…', 'अनुमान लोड हो रहा है…'),
            ),
          );
        } else if (snap.hasError) {
          children.add(
            StateView(
              kind: StateKind.error,
              title: s.t('Could not load the estimate', 'अनुमान लोड नहीं हुआ'),
              actionLabel: s.t('Retry', 'फिर कोशिश करें'),
              onAction: () => setState(() => _future = _fetch()),
            ),
          );
        } else if (snap.data?['status'] == 'failed') {
          children.add(
            StateView(
              kind: StateKind.empty,
              title: s.t('Valuation failed', 'मूल्यांकन विफल'),
              message: s.t(
                'Valuation failed on {date}. It will be retried.',
                '{date} को मूल्यांकन विफल हुआ। फिर से कोशिश की जाएगी।',
                vars: {
                  'date': _date(
                    (snap.data!['attempt'] as Map?)?['last_attempt_at'],
                  ),
                },
              ),
            ),
          );
        } else if (snap.data == null || snap.data!['status'] != 'valued') {
          children.add(
            StateView(
              kind: StateKind.empty,
              title: s.t('Not valued yet', 'अभी मूल्यांकन नहीं हुआ'),
              message: s.t(
                'Open bids closing in the next 10 days are valued once a day.',
                'अगले 10 दिनों में बंद होने वाली बोलियों का मूल्यांकन दिन में एक बार होता है।',
              ),
            ),
          );
        } else {
          children.addAll(_details(snap.data!));
        }
        children.addAll([
          const SizedBox(height: AppSpace.xl),
          Text(
            s.t(
              'This is an estimate based on available market prices. It is not an official GeM valuation or a guaranteed contract price.',
              'यह उपलब्ध बाज़ार कीमतों पर आधारित अनुमान है। यह GeM का आधिकारिक मूल्यांकन या गारंटीशुदा अनुबंध मूल्य नहीं है।',
            ),
            style: AppText.caption,
          ),
          const SizedBox(height: AppSpace.xl),
        ]);
        return ListView(
          controller: widget.controller,
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl),
          children: children,
        );
      },
    );
  }

  List<Widget> _details(Map<String, dynamic> data) {
    final v = Map<String, dynamic>.from(data['valuation'] as Map? ?? {});
    final items = [
      for (final i in data['items'] as List? ?? const [])
        Map<String, dynamic>.from(i as Map),
    ];
    final complete = v['complete'] == true;
    final (bandLabel, bandTone) = _band(v['confidence']);
    final total = (v['priced_value_inr'] as num?)?.toDouble() ?? 0;
    final unpriced = items.where((i) => i['priced'] != true).toList();
    final nothingPriced = (v['priced_count'] as num? ?? 0) == 0;
    return [
      if (nothingPriced)
        Text(
          s.t(
            'No market price was found for any item. ₹0 here is not an estimate.',
            'किसी भी वस्तु का बाज़ार मूल्य नहीं मिला। यहाँ ₹0 कोई अनुमान नहीं है।',
          ),
          style: AppText.bodyStrong,
        )
      else
        Text(money(total), style: AppText.h1),
      Text(
        complete
            ? s.t('Complete contract value', 'पूर्ण अनुबंध मूल्य')
            : s.t(
                'Partial estimate: not all items could be valued',
                'आंशिक अनुमान: सभी वस्तुओं का मूल्य नहीं मिला',
              ),
        style: AppText.caption,
      ),
      const SizedBox(height: AppSpace.sm),
      Align(
        alignment: Alignment.centerLeft,
        child: StatusChip(bandLabel, tone: bandTone),
      ),
      const SizedBox(height: AppSpace.md),
      KeyValueRow(
        s.t('Pricing coverage', 'मूल्य कवरेज'),
        _pct(v['pricing_coverage']),
      ),
      KeyValueRow(
        s.t('Match confidence', 'मिलान विश्वसनीयता'),
        _pct(v['match_confidence']),
      ),
      KeyValueRow(
        s.t(
          'Price sources: based on number of independent offers',
          'मूल्य स्रोत: स्वतंत्र ऑफ़र की संख्या पर आधारित',
        ),
        _reliabilityText(v['price_reliability']),
      ),
      Text(
        s.t(
          'Price sources counts independent offers. It is not a statistical measure of price accuracy.',
          'मूल्य स्रोत केवल स्वतंत्र ऑफ़र गिनता है। यह कीमत की सटीकता का सांख्यिकीय माप नहीं है।',
        ),
        style: AppText.caption,
      ),
      const SizedBox(height: AppSpace.xl),
      Text(s.t('Items', 'वस्तुएँ'), style: AppText.h3),
      const SizedBox(height: AppSpace.sm),
      for (final item in items) _itemCard(item),
      if (unpriced.isNotEmpty) ...[
        const SizedBox(height: AppSpace.md),
        Text(
          s.t(
            'Not valued ({n}): excluded from the total',
            'मूल्यांकन नहीं ({n}): कुल में शामिल नहीं',
            vars: {'n': '${unpriced.length}'},
          ),
          style: AppText.bodyStrong,
        ),
        for (final item in unpriced)
          Text('• ${item['name']}', style: AppText.bodySmall),
      ],
    ];
  }

  Widget _itemCard(Map<String, dynamic> item) {
    final priced = item['priced'] == true;
    final qty = (item['qty'] as num?)?.toDouble();
    final unit = (item['unit'] as String?) ?? '';
    final offers = [
      for (final o in item['offers'] as List? ?? const [])
        Map<String, dynamic>.from(o as Map),
    ];
    final qtyText = qty == null
        ? '—'
        : qty.toStringAsFixed(qty % 1 == 0 ? 0 : 2);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.sm),
      child: AppCard(
        tone: AppCardTone.outlined,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${item['name']}', style: AppText.bodyStrong),
            const SizedBox(height: AppSpace.xs),
            Text(
              priced
                  ? '$qtyText $unit × ${money((item['unit_price'] as num).toDouble())} = '
                        '${money((item['line_value'] as num).toDouble())}'
                  : '$qtyText $unit · ${s.t('Not priced', 'मूल्य नहीं मिला')}',
              style: AppText.bodySmall,
            ),
            const SizedBox(height: AppSpace.xs),
            Wrap(
              spacing: AppSpace.sm,
              runSpacing: AppSpace.xs,
              children: [
                StatusChip(
                  _offerTier(item['price_reliability']),
                  tone: priced ? StatusTone.info : StatusTone.neutral,
                ),
                if (priced && item['match_score'] is num)
                  StatusChip(
                    s.t(
                      'Match {p}',
                      'मिलान {p}',
                      vars: {'p': _pct(item['match_score'])},
                    ),
                  ),
              ],
            ),
            for (final o in offers)
              InkWell(
                onTap: () => openLink(context, s, '${o['source_url']}'),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: AppSize.tap),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.open_in_new,
                        size: AppIconSize.sm,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: AppSpace.sm),
                      Expanded(
                        child: Text(
                          '${(o['seller_name'] as String?)?.isNotEmpty == true ? o['seller_name'] : o['source_name']}'
                          ' · ${o['unit_price'] is num ? money((o['unit_price'] as num).toDouble()) : '—'}',
                          style: AppText.caption.copyWith(
                            decoration: TextDecoration.underline,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
