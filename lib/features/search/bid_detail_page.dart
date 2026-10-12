import 'package:flutter/material.dart';
import '../../core/tokens.dart';
import '../../data/app_store.dart';
import '../../data/sample_bids.dart';
import '../components.dart';
import 'search_result_card.dart';

/// Full detail page for a single illustrative bid. Route: `/bid-detail`.
/// Arguments: the bid id string.
class BidDetailPage extends StatelessWidget {
  final AppStore store;
  final String? bidId;

  const BidDetailPage({super.key, required this.store, this.bidId});

  SampleBid? get _bid {
    if (bidId == null) return null;
    try {
      return kNamedBids.firstWhere((b) => b.id == bidId);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = store;
    final bid = _bid;
    final isHi = s.language == 'hi';

    if (bid == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(isHi ? 'बोली विवरण' : 'Bid detail'),
          backgroundColor: AppColors.surface,
        ),
        body: StateView(
          kind: StateKind.error,
          title: isHi ? 'बोली नहीं मिली' : 'Bid not found',
        ),
      );
    }

    final title = isHi ? (bid.titleHi ?? bid.displayTitle) : bid.displayTitle;
    final urgent = bid.closesInDays <= 3;

    final checklist = <(String label, bool met)>[
      (isHi ? 'बैंक विवरण' : 'Bank details', bid.needsBankDetails),
      (isHi ? 'बैंक गारंटी' : 'Bank guarantee', bid.needsBG),
      (isHi ? 'MSE शिथिलता लागू' : 'MSE relaxation', bid.mseRelaxation),
      (isHi ? 'EMD छूट' : 'EMD exemption', bid.emdExemption),
    ];

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(isHi ? 'बोली विवरण' : 'Bid detail'),
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.xxl,
          vertical: AppSpace.xxl,
        ),
        children: [
          // Title
          Text(title, style: AppText.h2),
          const SizedBox(height: AppSpace.sm),
          if (bid.department != null)
            Text(bid.department!, style: AppText.secondary(AppText.body)),
          const SizedBox(height: AppSpace.lg),

          // Match score + closing
          Row(
            children: [
              StatusChip(
                '${bid.effectiveScore}% ${isHi ? "मिलान" : "match"}',
                tone: StatusTone.success,
              ),
              const SizedBox(width: AppSpace.sm),
              Text(
                isHi
                    ? '${bid.closesInDays} दिन शेष'
                    : '${bid.closesInDays} days left',
                style: AppText.caption.copyWith(
                  color: urgent ? AppColors.danger : AppColors.textSecondary,
                  fontWeight: urgent ? FontWeight.w700 : FontWeight.normal,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.xxl),

          // Key details
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                if (bid.state != null && bid.state!.isNotEmpty)
                  _row(
                    isHi ? 'राज्य' : 'State',
                    bid.state!,
                    icon: Icons.location_on_outlined,
                  ),
                if (bid.district != null && bid.district!.isNotEmpty)
                  _divRow(
                    isHi ? 'जिला' : 'District',
                    bid.district!,
                    icon: Icons.pin_drop_outlined,
                  ),
                _divRow(
                  isHi ? 'मूल्य' : 'Value',
                  '₹${_fmt(bid.valueRs)}',
                  icon: Icons.currency_rupee_outlined,
                ),
                _divRow(
                  isHi ? 'पोस्ट किया गया' : 'Posted',
                  isHi
                      ? '${bid.postedDaysAgo} दिन पहले'
                      : '${bid.postedDaysAgo} days ago',
                  icon: Icons.calendar_today_outlined,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.xxl),

          // Items
          if (bid.items != null) ...[
            Text(
              isHi ? 'सामग्री' : 'Items',
              style: AppText.h3,
            ),
            const SizedBox(height: AppSpace.sm),
            Text(bid.items!, style: AppText.body),
            const SizedBox(height: AppSpace.xxl),
          ],

          // Eligibility flags
          Text(
            isHi ? 'पात्रता' : 'Eligibility',
            style: AppText.h3,
          ),
          const SizedBox(height: AppSpace.sm),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < checklist.length; i++)
                  Column(
                    children: [
                      if (i > 0) const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpace.xl,
                          vertical: AppSpace.md,
                        ),
                        child: StatusItem(
                          label: checklist[i].$1,
                          state: checklist[i].$2
                              ? ItemState.done
                              : ItemState.pending,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.xxl),

          // Illustrative disclaimer
          IllustrativeLabel(isHindi: isHi),
          const SizedBox(height: AppSpace.xxl),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {required IconData icon}) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpace.xl,
      vertical: AppSpace.md,
    ),
    child: Row(
      children: [
        Icon(icon, size: AppIconSize.sm, color: AppColors.textSecondary),
        const SizedBox(width: AppSpace.sm),
        Expanded(child: Text(label, style: AppText.caption)),
        Text(
          value,
          style: AppText.bodySmall.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );

  Widget _divRow(String label, String value, {required IconData icon}) => Column(
    children: [
      const Divider(height: 1),
      _row(label, value, icon: icon),
    ],
  );

  static String _fmt(int v) {
    if (v >= 10000000) return '${(v / 10000000).toStringAsFixed(1)} Cr';
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)} L';
    return '${(v / 1000).toStringAsFixed(0)}K';
  }
}
