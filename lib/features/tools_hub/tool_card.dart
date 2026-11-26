/// The "box" for one tool on the Tools tab, and the grid + hub that lays them
/// out with search, category filters and a results count.
///
/// Design: white bordered card, outlined icon in a green-tint circle, bold
/// title, quiet caption, category chip + PDF badge. Hub adds a compact search
/// bar, horizontally scrollable filter chips, and a live document count.
library;

import 'package:flutter/material.dart';

import '../../core/tokens.dart';
import '../../data/app_store.dart';
import '../components.dart';
import 'tool_registry.dart';

// ─────────────────────────── ToolCard ───────────────────────────

class ToolCard extends StatelessWidget {
  final AppStore store;
  final ToolEntry tool;
  const ToolCard({super.key, required this.store, required this.tool});

  @override
  Widget build(BuildContext context) {
    final s = store;
    final title = s.t(tool.titleEn, tool.titleHi);
    final description = s.t(tool.descriptionEn, tool.descriptionHi);
    final catLabel = s.t(tool.docCategory.labelEn, tool.docCategory.labelHi);

    return AppCard(
      padding: const EdgeInsets.all(AppSpace.lg),
      semanticLabel: '$title. $description',
      onTap: () {
        s.event('tool_opened', page: tool.id);
        Navigator.of(context).pushNamed(tool.route);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon row
          Row(
            children: [
              DecoratedBox(
                decoration: const BoxDecoration(
                  color: AppColors.brandTint,
                  shape: BoxShape.circle,
                ),
                child: SizedBox(
                  width: AppSize.buttonSm,
                  height: AppSize.buttonSm,
                  child: Icon(
                    tool.icon,
                    size: AppIconSize.md - 4,
                    color: AppColors.brand,
                  ),
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.chevron_right,
                size: AppIconSize.md,
                color: AppColors.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          // Title
          Text(title, style: AppText.title),
          const SizedBox(height: AppSpace.xs),
          // Description — clamp to 3 lines
          Text(
            description,
            style: AppText.caption,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpace.md),
          // Metadata row: PDF badge + category chip
          Wrap(
            spacing: AppSpace.xs,
            runSpacing: AppSpace.xs,
            children: [
              if (tool.badge != null)
                StatusChip(s.t(tool.badge!.$1, tool.badge!.$2)),
              StatusChip(catLabel),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── ToolGrid ───────────────────────────

/// Lays [children] out in equal-width columns (1 / 2 / 3 by available width),
/// each row as tall as its tallest card. Never fixes a card height, so large
/// text scales safely.
class ToolGrid extends StatelessWidget {
  final List<Widget> children;
  const ToolGrid({super.key, required this.children});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final columns = c.maxWidth >= AppSize.wide
          ? 3
          : (c.maxWidth >= 300 &&
                    MediaQuery.textScalerOf(context).scale(16) <= 24
                ? 2
                : 1);
      final rows = <Widget>[];
      for (var i = 0; i < children.length; i += columns) {
        final slice = children.skip(i).take(columns).toList();
        rows.add(
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.md),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var j = 0; j < columns; j++) ...[
                    if (j > 0) const SizedBox(width: AppSpace.md),
                    Expanded(
                      child: j < slice.length ? slice[j] : const SizedBox(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      }
      return Column(children: rows);
    },
  );
}

// ─────────────────────────── ToolsHub ───────────────────────────

/// Full body of the Tools tab: section heading, search bar, category filter
/// chips, a live document count, the filtered card grid, and a contextual
/// note for MSME users.
class ToolsHub extends StatefulWidget {
  final AppStore store;
  const ToolsHub({super.key, required this.store});

  @override
  State<ToolsHub> createState() => _ToolsHubState();
}

class _ToolsHubState extends State<ToolsHub> {
  DocCategory? _category; // null = All

  AppStore get s => widget.store;

  List<ToolEntry> get _filtered => kTools
      .where((t) => _category == null || t.docCategory == _category)
      .toList();

  void _clearAll() => setState(() => _category = null);

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final count = filtered.length;
    final total = kTools.length;
    final hasFilter = _category != null;

    // ── Count label ──────────────────────────────────────────────
    final countText = count == total
        ? s.t('$total documents', '$total दस्तावेज़')
        : s.t('$count of $total documents', '$total में से $count दस्तावेज़');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Section heading ──────────────────────────────────────
        for (final group in ToolGroup.values)
          if (group != ToolGroup.analysis && kTools.any((t) => t.group == group))
            SectionHeader(s.t(group.titleEn, group.titleHi)),

        // ── Filter chips (horizontal scroll) ─────────────────────
        _FilterChips(
          store: s,
          selected: _category,
          onSelect: (cat) => setState(() => _category = cat),
        ),
        const SizedBox(height: AppSpace.md),

        // ── Results count ────────────────────────────────────────
        Text(countText, style: AppText.secondary(AppText.caption)),
        const SizedBox(height: AppSpace.md),

        // ── Grid or empty state ───────────────────────────────────
        if (count == 0)
          StateView(
            kind: StateKind.empty,
            title: s.t('No documents found', 'कोई दस्तावेज़ नहीं मिला'),
            message: s.t(
              'Try a different search or clear the filters.',
              'अलग खोज करें या फ़िल्टर हटाएँ।',
            ),
            actionLabel: s.t('Clear filters', 'फ़िल्टर हटाएँ'),
            onAction: _clearAll,
          )
        else
          ToolGrid(
            children: [for (final t in filtered) ToolCard(store: s, tool: t)],
          ),

        // ── Contextual note ───────────────────────────────────────
        if (count > 0) ...[
          const SizedBox(height: AppSpace.xl),
          _TenderNote(store: s, onClear: hasFilter ? _clearAll : null),
        ],
      ],
    );
  }
}

// ─────────────────────────── Private widgets ─────────────────────────────────

class _FilterChips extends StatelessWidget {
  final AppStore store;
  final DocCategory? selected;
  final ValueChanged<DocCategory?> onSelect;

  const _FilterChips({
    required this.store,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final s = store;
    final chips = <(String label, DocCategory? value)>[
      (s.t('All', 'सभी'), null),
      ...DocCategory.values.map((c) => (s.t(c.labelEn, c.labelHi), c)),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          for (var i = 0; i < chips.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpace.xs),
            _FilterChip(
              label: chips[i].$1,
              isSelected: selected == chips[i].$2,
              onTap: () => onSelect(chips[i].$2),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.md,
          vertical: AppSpace.sm,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.brandTint : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: isSelected ? AppColors.brand : AppColors.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: AppText.label.copyWith(
            color: isSelected ? AppColors.brand : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _TenderNote extends StatelessWidget {
  final AppStore store;
  final VoidCallback? onClear;

  const _TenderNote({required this.store, this.onClear});

  static const _disclaimerTitle = 'Disclaimer — Documentation Formats';

  static const _disclaimerBody =
      'The document templates provided in this section are for reference and '
      'facilitation purposes only. Bid2Scale does not provide legal advice, and '
      'nothing in these templates constitutes a legal opinion or professional '
      'counsel.\n\nBefore using any template, please note:\n\n'
      '1. Accuracy is your responsibility. All blanks, placeholders, and '
      'variable fields must be completed with accurate, verifiable information. '
      'Bid2Scale does not verify, validate, or review any content you enter into '
      'a template. Errors in filled details — including percentages, amounts, '
      'registration numbers, dates, or names — are entirely the user\'s '
      'responsibility.\n\n'
      '2. Eligibility is your responsibility. Bid2Scale does not determine, '
      'assess, or confirm whether you qualify for any declaration, exemption, or '
      'certificate available in this tool — including but not limited to MSME '
      'status, EMD exemption, local content percentage, or Class I Local '
      'Supplier classification. It is your sole responsibility to verify your '
      'eligibility before making any declaration.\n\n'
      '3. Document selection is your responsibility. Bid2Scale does not advise '
      'which documents are required for any specific bid. The requirement for '
      'each document is determined by the GeM GTC, the buyer\'s ATC, and the '
      'specific bid conditions. You must independently identify which documents '
      'apply to your bid before using this tool.\n\n'
      '4. No guarantee of bid acceptance. Generating a document through '
      'Bid2Scale does not guarantee that the document will be accepted by the '
      'Buyer Organisation, that your bid will qualify, or that any declaration '
      'will be considered valid under the applicable regulatory framework. '
      'Bid2Scale makes no representation as to the suitability or adequacy of '
      'any generated document for any specific bid.\n\n'
      '5. False declarations carry legal consequences. Several documents in this '
      'library constitute statutory declarations under the Government Financial '
      'Rules (GFR), 2017, the Prevention of Corruption Act, 1988, and other '
      'applicable Indian law. A false or misleading declaration — regardless of '
      'how it was prepared — may result in forfeiture of EMD, disqualification '
      'from the bid, debarment from GeM for a minimum of 3 months or longer, '
      'and potential civil or criminal liability. The legal consequences attach '
      'to the declarant, not to the tool used to prepare the document.\n\n'
      '6. Templates may not reflect the latest regulatory position. GeM GTC, '
      'DPIIT orders, and related rules are updated periodically. Bid2Scale does '
      'not guarantee that the formats are current at the time of your use. '
      'Always cross-check each document against the current GeM GTC version and '
      'the ATC for your specific bid before submission. The date on which you '
      'generate a document is not a representation that the format is current as '
      'of that date.\n\n'
      '7. Buyer-specific and bid-specific requirements prevail. The ATC for a '
      'specific bid takes precedence over GeM GTC to the extent permitted by law '
      '(GTC Clause 1). A template generated through this tool may not capture '
      'buyer-specific modifications. You are responsible for reviewing the ATC '
      'and adjusting documents accordingly.\n\n'
      '8. Generating a document is not submission. Bid2Scale does not submit any '
      'document to GeM or any Buyer Organisation on your behalf. The act of '
      'submission is entirely yours. Any error in submission — including '
      'submitting the wrong document, submitting to the wrong bid, or submitting '
      'an incomplete document — is the user\'s responsibility.\n\n'
      '9. Post-generation edits are your responsibility. If you modify a '
      'document after it is generated by this tool, Bid2Scale bears no '
      'responsibility for the content of the modified version. The user is '
      'responsible for the final document as submitted, regardless of what was '
      'originally generated.\n\n'
      '10. No implied approval or endorsement. Generating a document through '
      'Bid2Scale does not constitute any form of certification, validation, '
      'legal review, or endorsement of the content, the user\'s eligibility, or '
      'the user\'s compliance with applicable law. The tool does not perform any '
      'background check, data verification, or regulatory review.\n\n'
      '11. Document formats are sourced from public regulatory frameworks. The '
      'formats in this section are not proprietary to Bid2Scale. They are '
      'derived from publicly available GeM GTC clauses, DPIIT orders, GFR '
      'provisions, and other Government of India regulatory instruments. '
      'Bid2Scale does not claim ownership of these formats and has not '
      'independently created or modified the underlying legal language.\n\n'
      '12. AI-assisted generation. These document formats were structured and '
      'compiled with the assistance of Artificial Intelligence (AI) tools. While '
      'care has been taken to align the formats with applicable regulatory '
      'requirements, AI-generated content may contain errors, omissions, or '
      'outdated references. Users must independently verify all formats against '
      'the current applicable regulatory text before use. Use of AI in '
      'preparation does not transfer any responsibility from the user to '
      'Bid2Scale.\n\n'
      '13. Consult a qualified professional. For bids of material value, or '
      'where any declaration involves complex facts — including local content '
      'calculation, NPA status, land border compliance, or OEM authorisation — '
      'seek advice from a chartered accountant, legal counsel, or compliance '
      'professional before submission.\n\n'
      '14. Bid2Scale accepts no liability. Bid2Scale is an application. The '
      'Documentation tool within Bid2Scale is provided solely to assist with '
      'format generation. Bid2Scale is not liable — under any theory including '
      'negligence, misrepresentation, or breach of duty — for any loss, bid '
      'disqualification, debarment, regulatory penalty, financial damage, or '
      'legal proceeding arising from: the use or misuse of documents generated '
      'through this tool; errors in content entered by the user; the user\'s '
      'reliance on these formats without independent verification; modifications '
      'made by the user after generation; submission of an incorrect or '
      'inapplicable document; or any AI-related error in the structure or '
      'language of the format.';

  void _showDisclaimer(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        backgroundColor: AppColors.surface,
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_disclaimerTitle, style: AppText.bodyStrong),
              const SizedBox(height: AppSpace.lg),
              Flexible(
                child: SingleChildScrollView(
                  child: Text(
                    _disclaimerBody,
                    style: AppText.caption.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.6,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.xl),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(
                    'Close',
                    style: AppText.bodyStrong.copyWith(color: AppColors.brand),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = store;
    return GestureDetector(
      onTap: () => _showDisclaimer(context),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.info_outline,
                size: AppIconSize.sm + 2,
                color: AppColors.info,
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Text(
                  s.t(
                    'Requirements vary by tender. Always check the bid document before submitting.',
                    'आवश्यकताएँ निविदा के अनुसार बदलती हैं। जमा करने से पहले बोली दस्तावेज़ जाँचें।',
                  ),
                  style: AppText.caption,
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              const Icon(
                Icons.chevron_right,
                size: AppIconSize.sm + 2,
                color: AppColors.textHint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
