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
          if (kTools.any((t) => t.group == group))
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

  @override
  Widget build(BuildContext context) {
    final s = store;
    return DecoratedBox(
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
              color: AppColors.textSecondary,
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
          ],
        ),
      ),
    );
  }
}
