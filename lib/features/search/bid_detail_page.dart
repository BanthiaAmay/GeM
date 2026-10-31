import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
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

    // Eligibility checklist from the user's real profile/onboarding answers.
    final elig = s.section('eligibility');
    final List<(String, bool)> checklist = [
      (s.t('GST registered', 'GST पंजीकृत'), elig['gst'] == 'yes'),
      (s.t('PAN registered', 'PAN पंजीकृत'), elig['pan'] == true),
      (s.t('Bank account linked', 'बैंक खाता लिंक'), elig['bank'] == true),
      (s.t('Udyam registered', 'Udyam पंजीकृत'), elig['udyam'] == true),
      (
        s.t('Product category set', 'उत्पाद श्रेणी सेट'),
        elig['category'] != null && elig['category'] != 'other',
      ),
    ];
    final readyCount = checklist.where((c) => c.$2).length;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(isHi ? 'बोली विवरण' : 'Bid detail'),
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: isHi ? 'साझा करें' : 'Share',
            onPressed: () async {
              await SharePlus.instance.share(ShareParams(text: title));
            },
          ),
          IconButton(
            icon: const Icon(Icons.bookmark_border),
            tooltip: isHi ? 'सहेजें' : 'Bookmark',
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(isHi ? 'सहेजा गया' : 'Saved'),
                duration: const Duration(seconds: 2),
              ),
            ),
          ),
        ],
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

          // Match pill + closing pill
          Row(
            children: [
              StatusChip(
                '${bid.effectiveScore}% ${isHi ? "मिलान" : "match"}',
                tone: StatusTone.success,
              ),
              const SizedBox(width: AppSpace.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.md,
                  vertical: AppSpace.xs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  isHi
                      ? '${bid.closesInDays} दिन शेष'
                      : '${bid.closesInDays} days left',
                  style: AppText.caption.copyWith(
                    color: urgent ? AppColors.danger : AppColors.textSecondary,
                    fontWeight: urgent ? FontWeight.w700 : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.xxl),

          // Key details card — Bid ID is marked Illustrative
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _row(
                  s.t('Bid ID', 'बोली ID'),
                  '${bid.id} (${isHi ? "चित्रण" : "Illustrative"})',
                  icon: Icons.tag_outlined,
                ),
                if (bid.state != null && bid.state!.isNotEmpty)
                  _divRow(
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
            Text(isHi ? 'सामग्री' : 'Items', style: AppText.h3),
            const SizedBox(height: AppSpace.sm),
            Text(bid.items!, style: AppText.body),
            const SizedBox(height: AppSpace.xxl),
          ],

          // Eligibility checklist — computed from real profile answers
          Text(
            '${s.t("Eligibility checklist", "पात्रता जांचसूची")} · '
            '${s.t("{n} of 5 ready", "{n} में से 5 तैयार", vars: {"n": "$readyCount"})}',
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
          const SizedBox(height: AppSpace.lg),

          // Estimate working capital — navigates to Financial Hub
          InkWell(
            onTap: () => Navigator.of(context).pushNamed('/home'),
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
              child: Row(
                children: [
                  const Icon(
                    Icons.calculate_outlined,
                    size: AppIconSize.md,
                    color: AppColors.brand,
                  ),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: Text(
                      s.t(
                        'Estimate working capital',
                        'कार्यशील पूँजी का अनुमान',
                      ),
                      style: AppText.body.copyWith(color: AppColors.brand),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    size: AppIconSize.sm,
                    color: AppColors.textHint,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpace.xxl),

          // Illustrative disclaimer
          IllustrativeLabel(isHindi: isHi),
          const SizedBox(height: AppSpace.lg),

          // Primary action: open on GeM portal
          AppButton(
            label: s.t('Open bid on GeM', 'GeM पर बोली खोलें'),
            onPressed: () async {
              final uri = Uri.parse('https://bidplus.gem.gov.in/');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),
          const SizedBox(height: AppSpace.md),

          // Secondary action: set reminder
          AppButton(
            label: s.t('Set reminder', 'अनुस्मारक सेट करें'),
            variant: AppButtonVariant.secondary,
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(isHi ? 'अनुस्मारक सेट किया गया' : 'Reminder set'),
                duration: const Duration(seconds: 2),
              ),
            ),
          ),
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
        Flexible(
          child: Text(
            value,
            style: AppText.bodySmall.copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    ),
  );

  Widget _divRow(String label, String value, {required IconData icon}) =>
      Column(
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
