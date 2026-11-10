import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/models.dart' show money;
import '../core/theme.dart';
import '../data/app_store.dart';
import 'components.dart';

// ── Toggle chip on each bid card ─────────────────────────────────────────────

class CompareToggleButton extends StatelessWidget {
  final AppStore store;
  final Map<String, dynamic> bid;
  const CompareToggleButton({super.key, required this.store, required this.bid});

  @override
  Widget build(BuildContext context) {
    final s = store;
    final selected = s.inCompare(bid);
    final full = !selected && s.compareSelection.length >= 3;
    final bg = selected ? AppColors.brand : AppColors.brandTint;
    final fg = selected ? AppColors.surface : AppColors.brand;
    return GestureDetector(
      onTap: full
          ? () => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    s.t(
                      'You can compare up to 3 bids at a time.',
                      'आप एक साथ 3 बोलियाँ ही तुलना में जोड़ सकते हैं।',
                    ),
                  ),
                  duration: const Duration(seconds: 2),
                ),
              )
          : () => s.toggleCompare(bid),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.md,
          vertical: AppSpace.sm,
        ),
        decoration: BoxDecoration(
          color: full ? AppColors.surfaceMuted : bg,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: selected
              ? null
              : Border.all(color: AppColors.brand.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? Icons.check_circle_outline : Icons.compare_arrows,
              size: 14,
              color: full ? AppColors.textHint : fg,
            ),
            const SizedBox(width: AppSpace.xs),
            Text(
              selected
                  ? s.t('Remove', 'हटाएँ')
                  : s.t('+ Compare', '+ तुलना'),
              style: AppText.label.copyWith(
                color: full ? AppColors.textHint : fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Floating bar shown at the bottom of BidFeed ──────────────────────────────

class CompareBar extends StatelessWidget {
  final AppStore store;
  const CompareBar({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final s = store;
    final count = s.compareSelection.length;
    if (count == 0) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final n = s.compareSelection.length;
        if (n == 0) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.symmetric(vertical: AppSpace.md),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.lg,
            vertical: AppSpace.md,
          ),
          decoration: BoxDecoration(
            color: AppColors.ink,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: AppShadow.floating,
          ),
          child: Row(
            children: [
              Icon(Icons.compare_arrows, size: 18, color: AppColors.surface),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Text(
                  s.t('$n bid${n > 1 ? 's' : ''} to compare', '$n बोली${n > 1 ? 'याँ' : ''} तुलना के लिए'),
                  style: AppText.bodySmall.copyWith(color: AppColors.surface),
                ),
              ),
              TextButton(
                onPressed: s.clearCompare,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.surface.withValues(alpha: 0.6),
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  s.t('Clear', 'हटाएँ'),
                  style: AppText.label.copyWith(
                    color: AppColors.surface.withValues(alpha: 0.6),
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.xs),
              AppButton(
                label: s.t('Compare', 'तुलना करें'),
                size: AppButtonSize.sm,
                expand: false,
                onPressed: n < 2
                    ? null
                    : () => Navigator.pushNamed(context, '/compare'),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Full-screen compare page ─────────────────────────────────────────────────

class BidComparePage extends StatelessWidget {
  final AppStore store;
  const BidComparePage({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final s = store;
    final bids = s.compareSelection;
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: Text(s.t('Compare bids', 'बोलियाँ तुलना करें')),
        actions: [
          TextButton(
            onPressed: () {
              s.clearCompare();
              Navigator.pop(context);
            },
            child: Text(
              s.t('Clear all', 'सब हटाएँ'),
              style: AppText.bodySmall.copyWith(color: AppColors.brand),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: bids.length < 2
            ? StateView(
                kind: StateKind.empty,
                title: s.t(
                  'Select at least 2 bids to compare',
                  'तुलना के लिए कम से कम 2 बोलियाँ चुनें',
                ),
                message: s.t(
                  'Tap "+ Compare" on any bid card to add it here.',
                  'किसी भी बोली कार्ड पर "+ तुलना" दबाएँ।',
                ),
                actionLabel: s.t('Back to bids', 'बोलियों पर जाएँ'),
                onAction: () => Navigator.pop(context),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpace.gutter),
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: _CompareTable(bids: bids, store: s),
                ),
              ),
      ),
    );
  }
}

class _CompareTable extends StatelessWidget {
  final List<Map<String, dynamic>> bids;
  final AppStore store;
  const _CompareTable({required this.bids, required this.store});

  @override
  Widget build(BuildContext context) {
    final s = store;
    final colWidth = 220.0;

    // Precompute values for each bid
    List<Map<String, dynamic>> rows = bids.map((bid) {
      final details = Map<String, dynamic>.from(bid['details'] as Map? ?? {});
      final buyer = [
        bid['organisation'],
        bid['buyer'],
        bid['ministry'],
      ].map((v) => (v as String? ?? '').trim()).firstWhere(
        (v) => v.isNotEmpty,
        orElse: () => '',
      );
      final closesAt = DateTime.tryParse(bid['closes_at'] as String? ?? '');
      final daysLeft = closesAt?.toLocal().difference(DateTime.now()).inDays;
      final closesDisplay = closesAt != null
          ? DateFormat('d MMM yyyy').format(closesAt.toLocal())
          : '—';
      final emdAmount = num.tryParse(
        (details['emd_amount'] as String? ?? '').trim(),
      );
      final emd = emdAmount != null
          ? money(emdAmount)
          : details['emd_required'] == 'No'
          ? s.t('Not required', 'आवश्यक नहीं')
          : '—';
      final docs = List<String>.from(details['documents_required'] ?? []);
      final experience = (details['experience'] as String? ?? '').trim();
      final quantity = bid['quantity']?.toString() ?? '—';
      final mse = details['mse_relaxation'] == true ||
          details['mse_exemption'] == true;
      final emdExempt = details['emd_required'] == 'No' ||
          details['emd_exemption'] == true;

      return {
        'title': bid['title'] as String? ?? '—',
        'source_id': bid['source_id'] as String? ?? '—',
        'buyer': buyer.isNotEmpty ? buyer : '—',
        'state': (bid['state'] as String? ?? '').trim().isNotEmpty
            ? bid['state']
            : '—',
        'closes': closesDisplay,
        'days_left': daysLeft,
        'quantity': quantity,
        'emd': emd,
        'experience': experience.isNotEmpty ? experience : '—',
        'docs': docs,
        'mse': mse,
        'emd_exempt': emdExempt,
        'source_url': bid['source_url'] as String? ?? '',
      };
    }).toList();

    // Determine best values (for highlighting)
    // Fewer days left = more urgent (highlight if urgent)
    int? minDays;
    for (final r in rows) {
      final d = r['days_left'] as int?;
      if (d != null && (minDays == null || d < minDays)) minDays = d;
    }

    final rowDefs = [
      _RowDef(label: s.t('Bid ID', 'बोली ID'), key: 'source_id'),
      _RowDef(
        label: s.t('Closes', 'अंतिम तिथि'),
        key: 'closes',
        highlight: (v, _, r) {
          final d = r['days_left'] as int?;
          return d != null && d <= 7;
        },
        highlightColor: AppColors.warningTint,
      ),
      _RowDef(label: s.t('Buyer', 'खरीदार'), key: 'buyer'),
      _RowDef(label: s.t('State', 'राज्य'), key: 'state'),
      _RowDef(label: s.t('Quantity', 'मात्रा'), key: 'quantity'),
      _RowDef(label: s.t('EMD', 'EMD'), key: 'emd'),
      _RowDef(label: s.t('Experience', 'अनुभव'), key: 'experience'),
      _RowDef(
        label: s.t('MSE relaxation', 'MSE छूट'),
        key: 'mse',
        isBool: true,
        highlight: (v, _, a) => v == true,
        highlightColor: AppColors.brandTint,
      ),
      _RowDef(
        label: s.t('EMD exempt', 'EMD मुक्त'),
        key: 'emd_exempt',
        isBool: true,
        highlight: (v, _, a) => v == true,
        highlightColor: AppColors.brandTint,
      ),
      _RowDef(label: s.t('Documents', 'दस्तावेज़'), key: 'docs', isList: true),
    ];

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label column
          SizedBox(
            width: 130,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeaderCell(
                  text: s.t('Attribute', 'विशेषता'),
                  width: 130,
                  isLabel: true,
                ),
                for (final row in rowDefs)
                  _LabelCell(label: row.label, width: 130),
              ],
            ),
          ),
          // Bid columns
          for (final r in rows)
            SizedBox(
              width: colWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HeaderCell(
                    text: r['title'] as String,
                    width: colWidth,
                    isLabel: false,
                  ),
                  for (final row in rowDefs)
                    _ValueCell(
                      row: row,
                      data: r,
                      width: colWidth,
                      store: s,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _RowDef {
  final String label;
  final String key;
  final bool isBool;
  final bool isList;
  final bool Function(dynamic value, List<dynamic> allValues, Map data)?
  highlight;
  final Color highlightColor;
  const _RowDef({
    required this.label,
    required this.key,
    this.isBool = false,
    this.isList = false,
    this.highlight,
    this.highlightColor = AppColors.brandTint,
  });
}

class _HeaderCell extends StatelessWidget {
  final String text;
  final double width;
  final bool isLabel;
  const _HeaderCell({
    required this.text,
    required this.width,
    required this.isLabel,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: 56,
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpace.md,
      vertical: AppSpace.sm,
    ),
    decoration: BoxDecoration(
      color: isLabel ? AppColors.surfaceMuted : AppColors.brandTint,
      border: Border(
        bottom: BorderSide(color: AppColors.border),
        right: BorderSide(color: AppColors.border),
      ),
    ),
    child: Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: AppText.label.copyWith(
        color: isLabel ? AppColors.textHint : AppColors.brand,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _LabelCell extends StatelessWidget {
  final String label;
  final double width;
  const _LabelCell({required this.label, required this.width});

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpace.md,
      vertical: AppSpace.md,
    ),
    decoration: BoxDecoration(
      color: AppColors.surfaceMuted,
      border: Border(
        bottom: BorderSide(color: AppColors.border),
        right: BorderSide(color: AppColors.border),
      ),
    ),
    child: Text(
      label,
      style: AppText.label.copyWith(color: AppColors.textSecondary),
    ),
  );
}

class _ValueCell extends StatelessWidget {
  final _RowDef row;
  final Map<String, dynamic> data;
  final double width;
  final AppStore store;
  const _ValueCell({
    required this.row,
    required this.data,
    required this.width,
    required this.store,
  });

  @override
  Widget build(BuildContext context) {
    final s = store;
    final value = data[row.key];
    final highlighted =
        row.highlight?.call(value, [], data) ?? false;
    final bg = highlighted ? row.highlightColor : AppColors.surface;

    Widget content;
    if (row.isBool) {
      final yes = value == true;
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            yes ? Icons.check_circle_outline : Icons.remove_circle_outline,
            size: 15,
            color: yes ? AppColors.brand : AppColors.textHint,
          ),
          const SizedBox(width: AppSpace.xs),
          Text(
            yes ? s.t('Yes', 'हाँ') : s.t('No', 'नहीं'),
            style: AppText.bodySmall.copyWith(
              color: yes ? AppColors.brand : AppColors.textHint,
              fontWeight: yes ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      );
    } else if (row.isList) {
      final list = value as List? ?? [];
      content = list.isEmpty
          ? Text('—', style: AppText.caption.copyWith(color: AppColors.textHint))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final d in list.take(3))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      '• ${(d as String).length > 28 ? '${(d).substring(0, 26)}…' : d}',
                      style: AppText.caption,
                    ),
                  ),
                if (list.length > 3)
                  Text(
                    '+${list.length - 3} ${s.t('more', 'और')}',
                    style: AppText.caption.copyWith(color: AppColors.textHint),
                  ),
              ],
            );
    } else {
      content = Text(
        value?.toString() ?? '—',
        style: AppText.bodySmall,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      );
    }

    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.md,
        vertical: AppSpace.md,
      ),
      decoration: BoxDecoration(
        color: bg,
        border: Border(
          bottom: BorderSide(color: AppColors.border),
          right: BorderSide(color: AppColors.border),
        ),
      ),
      child: content,
    );
  }
}
