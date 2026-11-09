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

  Widget _empty(AppStore s) {
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
        'New GeM bids are checked through the day. You'll be notified when one matches.',
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
        // ── Page intro ─────────────────────────────────────────────────────
        Text(
          s.t('Find your next opportunity.', 'अपना अगला अवसर खोजें।'),
          style: AppText.h1,
        ),
        const SizedBox(height: AppSpace.xs),
        Text(
          s.t(
            'Live bids from GeM. Confirm details on GeM before bidding.',
            'GeM से लाइव बोलियाँ। बोली देने से पहले GeM पर जाँचें।',
          ),
          style: AppText.caption,
        ),
        const SizedBox(height: AppSpace.lg),

        // ── Tab + controls row ──────────────────────────────────────────────
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
        Row(
          children: [
            _ActionChip(
              icon: Icons.refresh,
              label: s.t('Refresh', 'ताज़ा करें'),
              onTap: loading ? null : refresh,
            ),
            const SizedBox(width: AppSpace.sm),
            _ActionChip(
              icon: Icons.tune_outlined,
              label: s.t('Set alerts', 'अलर्ट चुनें'),
              onTap: () => Navigator.pushNamed(context, '/alerts'),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.lg),

        // ── Content ─────────────────────────────────────────────────────────
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
          _empty(s),
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

// ── Small action chip for the top controls row ──────────────────────────────
class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _ActionChip({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.md,
        vertical: AppSpace.sm,
      ),
      decoration: BoxDecoration(
        color: onTap == null ? AppColors.surfaceMuted : AppColors.brandTint,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: onTap == null ? AppColors.textHint : AppColors.brand,
          ),
          const SizedBox(width: AppSpace.xs),
          Text(
            label,
            style: AppText.label.copyWith(
              color: onTap == null ? AppColors.textHint : AppColors.brand,
            ),
          ),
        ],
      ),
    ),
  );
}

// ── Individual bid card ─────────────────────────────────────────────────────
class _BidCard extends StatelessWidget {
  final AppStore store;
  final Map<String, dynamic> bid;
  const _BidCard({required this.store, required this.bid});

  static String _text(Object? value) => (value as String? ?? '').trim();

  @override
  Widget build(BuildContext context) {
    final s = store;
    final details = Map<String, dynamic>.from(bid['details'] as Map? ?? {});

    // Buyer + location
    final buyer = [
      bid['organisation'],
      bid['buyer'],
      bid['ministry'],
    ].map(_text).firstWhere((v) => v.isNotEmpty, orElse: () => '');
    final state = _text(bid['state']);
    final whereStr =
        [buyer, state].where((v) => v.isNotEmpty).join(' · ');

    // Close date + urgency
    final closesAt = DateTime.tryParse(bid['closes_at'] as String? ?? '');
    final daysLeft = closesAt != null
        ? closesAt.toLocal().difference(DateTime.now()).inDays
        : null;
    final closesDisplay = closesAt != null
        ? DateFormat('d MMM yyyy, h:mm a').format(closesAt.toLocal())
        : '—';

    Color badgeBg = AppColors.brandTint;
    Color badgeFg = AppColors.brand;
    if (daysLeft != null) {
      if (daysLeft <= 3) {
        badgeBg = AppColors.dangerTint;
        badgeFg = AppColors.danger;
      } else if (daysLeft <= 7) {
        badgeBg = AppColors.warningTint;
        badgeFg = AppColors.warning;
      }
    }

    // Metrics
    final emdAmount = num.tryParse(_text(details['emd_amount']));
    final emd = emdAmount != null
        ? money(emdAmount)
        : details['emd_required'] == 'No'
        ? s.t('Not required', 'आवश्यक नहीं')
        : null;
    final quantity = bid['quantity'];
    final experience = _text(details['experience']);
    final documents = List<String>.from(details['documents_required'] ?? []);

    // "Last collected" timestamp
    String? updatedStr;
    final fetchedRaw = bid['fetched_at'] as String?;
    if (fetchedRaw != null) {
      final dt = DateTime.tryParse(fetchedRaw);
      if (dt != null) {
        updatedStr = '${s.t('Updated', 'अपडेट')} '
            '${DateFormat('d MMM, h:mm a').format(dt.toLocal())}';
      }
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
        boxShadow: AppShadow.card,
      ),
      child: ClipRRect(
        borderRadius: AppRadius.card,
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header: GEM ID pill + days-left badge ──────────────────
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.sm,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      bid['source_id'] as String? ?? '',
                      style: AppText.overline.copyWith(
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (daysLeft != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.sm,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        daysLeft <= 0
                            ? s.t('Closing today', 'आज बंद')
                            : s.t('$daysLeft days left', '$daysLeft दिन शेष'),
                        style: AppText.label.copyWith(color: badgeFg),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpace.md),

              // ── Title (3 lines max) ─────────────────────────────────────
              Text(
                bid['title'] as String? ?? '',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: AppText.title,
              ),
              const SizedBox(height: AppSpace.sm),

              // ── Buyer + State ───────────────────────────────────────────
              if (whereStr.isNotEmpty)
                Row(
                  children: [
                    Icon(
                      Icons.business_outlined,
                      size: 13,
                      color: AppColors.textHint,
                    ),
                    const SizedBox(width: AppSpace.xs),
                    Flexible(
                      child: Text(
                        whereStr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: AppSpace.lg),

              // ── Close date block ────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.md,
                  vertical: AppSpace.md,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.event_outlined,
                          size: 18,
                          color: badgeFg,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpace.md),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.t('CLOSES', 'अंतिम समय'),
                          style: AppText.overline,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          closesDisplay,
                          style: AppText.bodyStrong.copyWith(fontSize: 15),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.sm),

              // ── Metrics: Quantity + EMD ─────────────────────────────────
              if (quantity != null || emd != null)
                Row(
                  children: [
                    if (quantity != null)
                      Expanded(
                        child: _MetricCell(
                          label: s.t('Quantity', 'मात्रा'),
                          value: '$quantity',
                        ),
                      ),
                    if (quantity != null && emd != null)
                      const SizedBox(width: AppSpace.sm),
                    if (emd != null)
                      Expanded(child: _MetricCell(label: 'EMD', value: emd)),
                  ],
                ),

              // ── Experience (if present) ─────────────────────────────────
              if (experience.isNotEmpty) ...[
                const SizedBox(height: AppSpace.sm),
                _MetricCell(
                  label: s.t('Experience', 'अनुभव'),
                  value: experience,
                  fullWidth: true,
                ),
              ],

              // ── Documents chips ─────────────────────────────────────────
              if (documents.isNotEmpty) ...[
                const SizedBox(height: AppSpace.sm),
                _DocChips(documents: documents, store: s),
              ],

              // ── Timestamp ───────────────────────────────────────────────
              if (updatedStr != null) ...[
                const SizedBox(height: AppSpace.md),
                Text(
                  updatedStr,
                  style: AppText.caption.copyWith(color: AppColors.textHint),
                ),
              ],
              const SizedBox(height: AppSpace.md),

              // ── CTA ─────────────────────────────────────────────────────
              AppButton(
                label: s.t('View on GeM', 'GeM पर देखें'),
                variant: AppButtonVariant.secondary,
                trailingIcon: Icons.open_in_new,
                onPressed: () =>
                    openLink(context, s, bid['source_url'] as String),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Metric cell: label + value in a surfaceMuted box ────────────────────────
class _MetricCell extends StatelessWidget {
  final String label;
  final String value;
  final bool fullWidth;
  const _MetricCell({
    required this.label,
    required this.value,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: fullWidth ? double.infinity : null,
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpace.md,
      vertical: AppSpace.sm,
    ),
    decoration: BoxDecoration(
      color: AppColors.surfaceMuted,
      borderRadius: BorderRadius.circular(AppRadius.sm),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.overline),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.bodyStrong,
        ),
      ],
    ),
  );
}

// ── Document chips with "+N more" overflow ───────────────────────────────────
class _DocChips extends StatelessWidget {
  final List<String> documents;
  final AppStore store;
  const _DocChips({required this.documents, required this.store});

  static const _maxShow = 2;

  String _shorten(String doc) {
    // Strip " (Requested in ATC)" suffix
    final clean = doc
        .replaceAll(RegExp(r'\s*\(Requested in ATC\)', caseSensitive: false), '')
        .trim();
    return clean.length > 24 ? '${clean.substring(0, 22)}…' : clean;
  }

  @override
  Widget build(BuildContext context) {
    final shown = documents.take(_maxShow).toList();
    final extra = documents.length - _maxShow;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          store.t('Documents', 'दस्तावेज़'),
          style: AppText.overline,
        ),
        const SizedBox(height: AppSpace.xs),
        Wrap(
          spacing: AppSpace.xs,
          runSpacing: AppSpace.xs,
          children: [
            for (final doc in shown)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.sm,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  _shorten(doc),
                  style: AppText.label.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            if (extra > 0)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.sm,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.infoTint,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  '+$extra',
                  style: AppText.label.copyWith(color: AppColors.info),
                ),
              ),
          ],
        ),
      ],
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
