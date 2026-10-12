import 'package:flutter/material.dart';
import '../../core/tokens.dart';
import '../../data/sample_bids.dart';
import '../components.dart';
import 'search_models.dart';

// ─── Bid row ──────────────────────────────────────────────────────────────────

/// A single bid result row — list style with hairline divider. Matches the
/// concept: match pill (green), urgency date (red when ≤3 days).
class BidResultRow extends StatelessWidget {
  final SampleBid bid;
  final bool isHindi;
  final VoidCallback onTap;

  const BidResultRow({
    super.key,
    required this.bid,
    required this.isHindi,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = isHindi ? (bid.titleHi ?? bid.displayTitle) : bid.displayTitle;
    final urgent = bid.closesInDays <= 3;
    final closingLabel = isHindi
        ? '${bid.closesInDays} दिन शेष'
        : '${bid.closesInDays}d left';

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.xxl,
          vertical: AppSpace.lg,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.title, maxLines: 2),
                  if (bid.department != null) ...[
                    const SizedBox(height: AppSpace.xs),
                    Text(
                      bid.department!,
                      style: AppText.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: AppSpace.sm),
                  Row(
                    children: [
                      StatusChip(
                        '${bid.effectiveScore}%',
                        tone: StatusTone.success,
                      ),
                      if (bid.state != null && bid.state!.isNotEmpty) ...[
                        const SizedBox(width: AppSpace.sm),
                        Text(bid.state!, style: AppText.caption),
                      ],
                      const Spacer(),
                      Text(
                        closingLabel,
                        style: AppText.caption.copyWith(
                          color: urgent
                              ? AppColors.danger
                              : AppColors.textSecondary,
                          fontWeight:
                              urgent ? FontWeight.w700 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpace.md),
            const Icon(
              Icons.chevron_right,
              size: AppIconSize.md,
              color: AppColors.textHint,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Generic result row ───────────────────────────────────────────────────────

/// A non-bid result row (tool, lesson, finance item).
class SearchResultRow extends StatelessWidget {
  final SearchItem item;
  final bool isHindi;
  final VoidCallback onTap;

  static const _icons = <SearchType, IconData>{
    SearchType.tool: Icons.build_outlined,
    SearchType.lesson: Icons.school_outlined,
    SearchType.finance: Icons.account_balance_outlined,
    SearchType.calculator: Icons.calculate_outlined,
    SearchType.document: Icons.description_outlined,
    SearchType.faq: Icons.help_outline,
    SearchType.myData: Icons.person_outline,
    SearchType.bid: Icons.gavel_outlined,
  };

  const SearchResultRow({
    super.key,
    required this.item,
    required this.isHindi,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = isHindi ? item.titleHi : item.titleEn;
    final subtitle = isHindi ? item.subtitleHi : item.subtitleEn;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.xxl,
          vertical: AppSpace.lg,
        ),
        child: Row(
          children: [
            DecoratedBox(
              decoration: const BoxDecoration(
                color: AppColors.surfaceMuted,
                shape: BoxShape.circle,
              ),
              child: SizedBox(
                width: 40,
                height: 40,
                child: Icon(
                  _icons[item.type] ?? Icons.search,
                  size: AppIconSize.md - 4,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.body),
                  if (subtitle.isNotEmpty)
                    Text(subtitle, style: AppText.caption, maxLines: 2),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: AppIconSize.md,
              color: AppColors.textHint,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Illustrative data label ──────────────────────────────────────────────────

class IllustrativeLabel extends StatelessWidget {
  final bool isHindi;
  const IllustrativeLabel({super.key, this.isHindi = false});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpace.xxl,
      vertical: AppSpace.sm,
    ),
    child: Text(
      isHindi ? 'चित्रण डेटा — वास्तविक GeM बोलियाँ नहीं' : 'Illustrative data — not real GeM bids',
      style: AppText.caption.copyWith(color: AppColors.textHint),
    ),
  );
}
