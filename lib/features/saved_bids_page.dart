import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/theme.dart';
import '../core/models.dart' show money;
import '../data/app_store.dart';
import 'components.dart';
import 'widgets.dart' show openLink;

class SavedBidsPage extends StatelessWidget {
  final AppStore store;
  const SavedBidsPage({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final s = store;
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: Text(s.t('Saved Bids', 'सहेजी गई बोलियाँ')),
      ),
      body: ListenableBuilder(
        listenable: s,
        builder: (context, _) {
          final bids = s.savedBids;
          if (bids.isEmpty) {
            return StateView(
              kind: StateKind.empty,
              title: s.t(
                'Your shortlist is waiting.',
                'आपकी शॉर्टलिस्ट खाली है।',
              ),
              message: s.t(
                'Save interesting bids to keep track of opportunities you may want to explore later.',
                'दिलचस्प बोलियाँ सहेजें ताकि बाद में उन्हें देख सकें।',
              ),
              actionLabel: s.t('Find Bids', 'बोलियाँ खोजें'),
              onAction: () => Navigator.pushReplacementNamed(context, '/bids'),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpace.gutter),
            itemCount: bids.length,
            separatorBuilder: (_, i) => const SizedBox(height: AppSpace.md),
            itemBuilder: (context, i) {
              final row = bids[i];
              final bid = Map<String, dynamic>.from(
                row['bid_data'] as Map? ?? row,
              );
              return _SavedBidCard(store: s, row: row, bid: bid);
            },
          );
        },
      ),
    );
  }
}

class _SavedBidCard extends StatelessWidget {
  final AppStore store;
  final Map<String, dynamic> row;
  final Map<String, dynamic> bid;
  const _SavedBidCard({
    required this.store,
    required this.row,
    required this.bid,
  });

  static String _text(Object? v) => (v as String? ?? '').trim();

  @override
  Widget build(BuildContext context) {
    final s = store;
    final details = Map<String, dynamic>.from(bid['details'] as Map? ?? {});

    final buyer = [bid['organisation'], bid['buyer'], bid['ministry']]
        .map(_text)
        .firstWhere((v) => v.isNotEmpty, orElse: () => '');
    final state = _text(bid['state']);
    final whereStr =
        [buyer, state].where((v) => v.isNotEmpty).join(' · ');

    final closesAt = DateTime.tryParse(bid['closes_at'] as String? ?? '');
    final daysLeft = closesAt?.toLocal().difference(DateTime.now()).inDays;
    final isClosed = daysLeft != null && daysLeft < 0;
    final closesDisplay = closesAt != null
        ? DateFormat('d MMM yyyy').format(closesAt.toLocal())
        : '—';

    final emdAmount = num.tryParse(_text(details['emd_amount']));
    final emd = emdAmount != null
        ? money(emdAmount)
        : details['emd_required'] == 'No'
        ? s.t('Not required', 'आवश्यक नहीं')
        : null;

    final savedAt = DateTime.tryParse(row['saved_at'] as String? ?? '');
    final savedDisplay = savedAt != null
        ? s.t(
            'Saved ${DateFormat('d MMM').format(savedAt.toLocal())}',
            '${DateFormat('d MMM').format(savedAt.toLocal())} को सहेजा',
          )
        : null;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
        boxShadow: AppShadow.card,
        border: isClosed
            ? Border.all(color: AppColors.danger.withValues(alpha: 0.3))
            : null,
      ),
      child: ClipRRect(
        borderRadius: AppRadius.card,
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
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
                  if (isClosed)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.sm,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.dangerTint,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        s.t('Closed', 'बंद'),
                        style: AppText.label.copyWith(color: AppColors.danger),
                      ),
                    )
                  else if (daysLeft != null && daysLeft <= 7)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.sm,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: daysLeft <= 3
                            ? AppColors.dangerTint
                            : AppColors.warningTint,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        s.t('$daysLeft days left', '$daysLeft दिन शेष'),
                        style: AppText.label.copyWith(
                          color: daysLeft <= 3
                              ? AppColors.danger
                              : AppColors.warning,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpace.md),
              Text(
                bid['title'] as String? ?? '',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: AppText.title,
              ),
              if (whereStr.isNotEmpty) ...[
                const SizedBox(height: AppSpace.sm),
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
              ],
              const SizedBox(height: AppSpace.md),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 13,
                    color: AppColors.textHint,
                  ),
                  const SizedBox(width: AppSpace.xs),
                  Text(
                    s.t('Closes $closesDisplay', '$closesDisplay को बंद'),
                    style: AppText.caption,
                  ),
                  if (emd != null) ...[
                    const SizedBox(width: AppSpace.md),
                    Text('·', style: AppText.caption),
                    const SizedBox(width: AppSpace.xs),
                    Text(
                      s.t('EMD: $emd', 'EMD: $emd'),
                      style: AppText.caption,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpace.lg),
              Row(
                children: [
                  if (savedDisplay != null)
                    Text(
                      savedDisplay,
                      style: AppText.caption.copyWith(
                        color: AppColors.textHint,
                      ),
                    ),
                  const Spacer(),
                  // Remove bookmark
                  InkWell(
                    onTap: () => s.toggleSavedBid(bid),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpace.xs),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.bookmark,
                            size: 16,
                            color: AppColors.brand,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            s.t('Remove', 'हटाएँ'),
                            style: AppText.label.copyWith(
                              color: AppColors.brand,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpace.sm),
                  AppButton(
                    label: s.t('View on GeM', 'GeM पर देखें'),
                    variant: AppButtonVariant.secondary,
                    size: AppButtonSize.sm,
                    expand: false,
                    trailingIcon: Icons.open_in_new,
                    onPressed: () => openLink(
                      context,
                      s,
                      bid['source_url'] as String? ?? '',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
