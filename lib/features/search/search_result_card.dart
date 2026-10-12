import 'package:flutter/material.dart';
import '../../core/tokens.dart';
import '../../data/app_store.dart';
import '../../data/sample_bids.dart';
import 'search_engine.dart';
import 'search_models.dart';

// ─── Bid row ──────────────────────────────────────────────────────────────────

/// A single bid result row — list style with hairline divider. Matches the
/// concept: match pill (green), urgency date (red when ≤3 days).
class BidResultRow extends StatelessWidget {
  final SampleBid bid;
  final bool isHindi;
  final VoidCallback onTap;
  final AppStore store;

  /// Raw query string for match highlighting (empty = no highlight).
  final String query;

  const BidResultRow({
    super.key,
    required this.bid,
    required this.isHindi,
    required this.onTap,
    required this.store,
    this.query = '',
  });

  String _scoreReason() {
    final s = bid.effectiveScore;
    if (s >= 85) return store.t('Product fit: Excellent', 'उत्पाद मिलान: उत्कृष्ट');
    if (s >= 70) return store.t('Product fit: Good', 'उत्पाद मिलान: अच्छा');
    if (s >= 55) return store.t('Product fit: Fair', 'उत्पाद मिलान: ठीक');
    return store.t('Partial match', 'आंशिक मिलान');
  }

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
                  HighlightText(
                    text: title,
                    query: query,
                    baseStyle: AppText.title,
                    maxLines: 2,
                  ),
                  if (bid.department != null) ...[
                    const SizedBox(height: AppSpace.xs),
                    HighlightText(
                      text: bid.department!,
                      query: query,
                      baseStyle: AppText.caption,
                      maxLines: 1,
                    ),
                  ],
                  const SizedBox(height: AppSpace.sm),
                  Row(
                    children: [
                      Text(
                        '${bid.effectiveScore} · ${_scoreReason()}',
                        style: AppText.caption.copyWith(
                          color: AppColors.brand,
                          fontWeight: FontWeight.w600,
                        ),
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

  /// Raw query string for match highlighting (empty = no highlight).
  final String query;

  static const _icons = <SearchType, IconData>{
    SearchType.tool: Icons.build_outlined,
    SearchType.lesson: Icons.school_outlined,
    SearchType.finance: Icons.account_balance_outlined,
    SearchType.calculator: Icons.calculate_outlined,
    SearchType.document: Icons.description_outlined,
    SearchType.faq: Icons.help_outline,
    SearchType.myData: Icons.person_outline,
    SearchType.bid: Icons.gavel_outlined,
    SearchType.category: Icons.category_outlined,
  };

  const SearchResultRow({
    super.key,
    required this.item,
    required this.isHindi,
    required this.onTap,
    this.query = '',
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
                  HighlightText(
                    text: title,
                    query: query,
                    baseStyle: AppText.body,
                  ),
                  if (subtitle.isNotEmpty)
                    HighlightText(
                      text: subtitle,
                      query: query,
                      baseStyle: AppText.caption,
                      maxLines: 2,
                    ),
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
      isHindi
          ? 'चित्रण डेटा — वास्तविक GeM बोलियाँ नहीं'
          : 'Illustrative data — not real GeM bids',
      style: AppText.caption.copyWith(color: AppColors.textHint),
    ),
  );
}

// ─── Highlight text ───────────────────────────────────────────────────────────

/// Renders [text] with any fragments matching [query] tokens shown in bold.
/// Falls back to a plain [Text] when [query] is empty or no ranges match.
class HighlightText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle baseStyle;
  final int? maxLines;

  const HighlightText({
    super.key,
    required this.text,
    required this.query,
    required this.baseStyle,
    this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) {
      return Text(text, style: baseStyle, maxLines: maxLines, overflow: maxLines != null ? TextOverflow.ellipsis : null);
    }
    final tokens = SearchEngine.normalise(query)
        .split(' ')
        .where((t) => t.length >= 2)
        .toList();
    if (tokens.isEmpty) {
      return Text(text, style: baseStyle, maxLines: maxLines, overflow: maxLines != null ? TextOverflow.ellipsis : null);
    }
    final ranges = SearchEngine.highlightRanges(text, tokens);
    if (ranges.isEmpty) {
      return Text(text, style: baseStyle, maxLines: maxLines, overflow: maxLines != null ? TextOverflow.ellipsis : null);
    }

    final spans = <TextSpan>[];
    var pos = 0;
    for (final (start, end) in ranges) {
      if (start > pos) {
        spans.add(TextSpan(text: text.substring(pos, start)));
      }
      spans.add(TextSpan(
        text: text.substring(start, end),
        style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink),
      ));
      pos = end;
    }
    if (pos < text.length) {
      spans.add(TextSpan(text: text.substring(pos)));
    }
    return RichText(
      maxLines: maxLines,
      overflow: maxLines != null ? TextOverflow.ellipsis : TextOverflow.clip,
      text: TextSpan(style: baseStyle, children: spans),
    );
  }
}
