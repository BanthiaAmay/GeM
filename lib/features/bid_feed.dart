import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/models.dart' show money;
import '../core/theme.dart';
import '../data/app_store.dart';
import 'components.dart';
import 'widgets.dart' show openLink;

enum _FeedView { matching, latest }

/// Reads published server records. Bid collection never runs on the device.
class BidFeed extends StatefulWidget {
  final AppStore store;
  const BidFeed({super.key, required this.store});
  @override
  State<BidFeed> createState() => _BidFeedState();
}

class _BidFeedState extends State<BidFeed> {
  List<Map<String, dynamic>> bids = [];
  bool loading = true;
  String? error;
  late _FeedView view = widget.store.bidKeywords.isEmpty
      ? _FeedView.latest
      : _FeedView.matching;

  @override
  void initState() {
    super.initState();
    unawaited(refresh());
  }

  Future<void> refresh() async {
    final s = widget.store;
    if (s.client == null) {
      if (mounted) setState(() => loading = false);
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final List<dynamic> result = view == _FeedView.matching
          ? (s.signedIn && s.bidKeywords.isNotEmpty
                ? await s.client!.rpc(
                        'my_matching_bids',
                        params: {'p_limit': 50},
                      )
                      as List<dynamic>
                : const [])
          : await s.client!
                .from('gem_bids')
                .select()
                .eq('published', true)
                .gt('closes_at', DateTime.now().toUtc().toIso8601String())
                .order('starts_at', ascending: false, nullsFirst: false)
                .limit(50);
      if (mounted) {
        setState(
          () => bids = [
            for (final row in result) Map<String, dynamic>.from(row as Map),
          ],
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error = s.t(
            'The bid feed could not be loaded. Please retry.',
            'बोली सूची लोड नहीं हुई। फिर कोशिश करें।',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Widget empty(AppStore s) {
    if (view == _FeedView.latest) {
      return StateView(
        kind: StateKind.empty,
        title: s.t('No bids yet', 'अभी कोई बोली नहीं'),
        message: s.t(
          'No live bids are available here yet. Browse the official GeM bid list while the feed is being connected.',
          'यहाँ अभी लाइव बोलियाँ उपलब्ध नहीं हैं। स्रोत जुड़ने तक आधिकारिक GeM बोली सूची देखें।',
        ),
      );
    }
    if (s.bidKeywords.isEmpty) {
      return StateView(
        kind: StateKind.empty,
        title: s.t('Tell us what you sell', 'बताएँ आप क्या बेचते हैं'),
        message: s.t(
          'Add products or services to see bids that match your business.',
          'अपने व्यवसाय से मेल खाती बोलियाँ देखने के लिए उत्पाद या सेवाएँ जोड़ें।',
        ),
        actionLabel: s.t('Set my alerts', 'मेरे अलर्ट चुनें'),
        onAction: () => Navigator.pushNamed(context, '/alerts'),
      );
    }
    return StateView(
      kind: StateKind.empty,
      title: s.t(
        'No matching open bids yet',
        'अभी कोई मेल खाती खुली बोली नहीं',
      ),
      message: s.t(
        'New GeM bids are checked through the day. You’ll be notified when one matches.',
        'नई GeM बोलियाँ दिन भर देखी जाती हैं। मेल खाने पर आपको सूचना मिलेगी।',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.t('Find your next opportunity.', 'अपना अगला अवसर खोजें।'),
          style: AppText.h1,
        ),
        const SizedBox(height: AppSpace.md),
        Text(
          s.t(
            'Published GeM bids from the connected server feed. Confirm the latest details on GeM before bidding.',
            'जुड़े सर्वर स्रोत से प्रकाशित GeM बोलियाँ। बोली से पहले नवीनतम विवरण GeM पर जाँचें।',
          ),
          style: AppText.body,
        ),
        const SizedBox(height: AppSpace.lg),
        AppSegmentedControl<_FeedView>(
          options: [
            (_FeedView.matching, s.t('For you', 'आपके लिए'), null),
            (_FeedView.latest, s.t('Latest', 'नवीनतम'), null),
          ],
          value: view,
          semanticLabel: s.t('Bids to show', 'दिखाई जाने वाली बोलियाँ'),
          onChanged: (v) {
            setState(() => view = v);
            unawaited(refresh());
          },
        ),
        const SizedBox(height: AppSpace.sm),
        Wrap(
          spacing: AppSpace.md,
          children: [
            TextButton.icon(
              onPressed: loading ? null : refresh,
              icon: const Icon(Icons.refresh),
              label: Text(s.t('Refresh bids', 'बोलियाँ ताज़ा करें')),
            ),
            TextButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/alerts'),
              icon: const Icon(Icons.tune),
              label: Text(s.t('Set my alerts', 'मेरे अलर्ट चुनें')),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.lg),
        if (loading)
          StateView(
            kind: StateKind.loading,
            title: s.t('Loading bids', 'बोलियाँ लोड हो रही हैं'),
          )
        else if (error != null)
          StateView(
            kind: StateKind.error,
            title: error!,
            actionLabel: s.t('Retry', 'फिर कोशिश करें'),
            onAction: refresh,
          )
        else if (bids.isEmpty)
          empty(s),
        if (!loading && error == null)
          for (final bid in bids)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.lg),
              child: _BidCard(store: s, bid: bid),
            ),
        const SizedBox(height: AppSpace.xxl),
        AppButton(
          label: s.t('Browse official GeM bids', 'आधिकारिक GeM बोलियाँ देखें'),
          variant: AppButtonVariant.secondary,
          trailingIcon: Icons.open_in_new,
          onPressed: () =>
              openLink(context, s, 'https://bidplus.gem.gov.in/all-bids'),
        ),
      ],
    );
  }
}

/// One bid with the requirements read from its GeM bid document.
class _BidCard extends StatelessWidget {
  final AppStore store;
  final Map<String, dynamic> bid;
  const _BidCard({required this.store, required this.bid});

  static String _text(Object? value) => (value as String? ?? '').trim();

  @override
  Widget build(BuildContext context) {
    final s = store;
    final details = Map<String, dynamic>.from(bid['details'] as Map? ?? {});
    final buyer = [
      bid['organisation'],
      bid['buyer'],
      bid['ministry'],
    ].map(_text).firstWhere((v) => v.isNotEmpty, orElse: () => '');
    final where = [buyer, _text(bid['state'])].where((v) => v.isNotEmpty);
    final turnover = _text(
      details['bidder_turnover'] ?? details['oem_turnover'],
    );
    final emdAmount = num.tryParse(_text(details['emd_amount']));
    final emd = emdAmount != null
        ? money(emdAmount)
        : details['emd_required'] == 'No'
        ? s.t('Not required', 'आवश्यक नहीं')
        : '';
    final documents = List<String>.from(details['documents_required'] ?? []);
    final rows = [
      if (bid['quantity'] != null)
        KeyValueRow(s.t('Quantity', 'मात्रा'), '${bid['quantity']}'),
      if (_text(details['experience']).isNotEmpty)
        KeyValueRow(s.t('Experience', 'अनुभव'), _text(details['experience'])),
      if (turnover.isNotEmpty)
        KeyValueRow(s.t('Turnover', 'टर्नओवर'), turnover),
      if (emd.isNotEmpty) KeyValueRow('EMD', emd),
      if (documents.isNotEmpty)
        KeyValueRow(s.t('Documents', 'दस्तावेज़'), documents.join(', ')),
    ];
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(bid['source_id'] as String, style: AppText.caption),
          const SizedBox(height: AppSpace.sm),
          Text(bid['title'] as String, style: AppText.h3),
          if (where.isNotEmpty) ...[
            const SizedBox(height: AppSpace.sm),
            Text(where.join(' · '), style: AppText.bodySmall),
          ],
          const SizedBox(height: AppSpace.sm),
          Text(
            s.t('Closes: ', 'अंतिम समय: ') +
                DateFormat(
                  'd MMM yyyy, h:mm a',
                ).format(DateTime.parse(bid['closes_at'] as String).toLocal()),
            style: AppText.bodyStrong,
          ),
          Text(
            s.t('Last collected: ', 'अंतिम संग्रह: ') +
                DateFormat(
                  'd MMM, h:mm a',
                ).format(DateTime.parse(bid['fetched_at'] as String).toLocal()),
            style: AppText.caption,
          ),
          if (rows.isNotEmpty) ...[
            const SizedBox(height: AppSpace.sm),
            DividedList(children: rows),
          ],
          TextButton.icon(
            onPressed: () => openLink(context, s, bid['source_url'] as String),
            icon: const Icon(Icons.open_in_new),
            label: Text(s.t('View on GeM', 'GeM पर देखें')),
          ),
        ],
      ),
    );
  }
}

/// The live bid feed as its own screen (reached from Home and the menu).
class BidsPage extends StatelessWidget {
  final AppStore store;
  const BidsPage({super.key, required this.store});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.canvas,
    appBar: AppBar(title: Text(store.t('Live GeM bids', 'लाइव GeM बोलियाँ'))),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpace.gutter),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: BidFeed(store: store),
          ),
        ),
      ),
    ),
  );
}
