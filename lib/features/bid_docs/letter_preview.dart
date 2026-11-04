/// On-screen "paper" for a generated letter. Read-only and editable variants.
/// Uses only design tokens (AppColors / AppText / AppSpace / AppRadius).
library;

import 'package:flutter/material.dart';

import '../../core/tokens.dart';
import 'letter_model.dart';

TextStyle _styleFor(LetterBlock b, LetterSpan s) {
  final base = switch (b.kind) {
    LetterBlockKind.title => AppText.h3,
    LetterBlockKind.titleUnderlined => AppText.h3,
    LetterBlockKind.subtitle => AppText.bodyStrong,
    LetterBlockKind.heading => AppText.title,
    _ => AppText.body,
  };
  return base.copyWith(
    fontWeight: (s.bold || b.isBoldKind) ? FontWeight.w700 : null,
    decoration:
        (b.kind == LetterBlockKind.heading ||
            b.kind == LetterBlockKind.titleUnderlined)
        ? TextDecoration.underline
        : null,
    height: 1.45,
  );
}

bool _centered(LetterBlock b) =>
    b.kind == LetterBlockKind.title ||
    b.kind == LetterBlockKind.titleUnderlined ||
    b.kind == LetterBlockKind.subtitle ||
    b.kind == LetterBlockKind.heading;

/// The white sheet. [extraTopMargin] is the slider value (logical px) so the
/// user sees where the text will start when printing on letterhead.
class LetterPaper extends StatelessWidget {
  final List<LetterBlock> blocks;
  final double extraTopMargin;

  /// When non-null the paper shows one text box per non-spacer block, in
  /// order, instead of the styled letter.
  final List<TextEditingController>? editors;

  const LetterPaper({
    super.key,
    required this.blocks,
    this.extraTopMargin = 0,
    this.editors,
  });

  @override
  Widget build(BuildContext context) {
    var editorIndex = 0;
    final children = <Widget>[];
    for (final b in blocks) {
      if (b.isSpacer) {
        children.add(const SizedBox(height: AppSpace.huge));
        continue;
      }

      if (b.kind == LetterBlockKind.productTable) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.md),
            child: _buildTable(b),
          ),
        );
        continue;
      }

      if (b.kind == LetterBlockKind.productImage) {
        final bytes = b.imageBytes;
        if (bytes != null) {
          children.add(
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.md),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: Image.memory(bytes, fit: BoxFit.contain),
              ),
            ),
          );
        }
        continue;
      }

      final Widget w;
      if (editors != null) {
        w = TextField(
          controller: editors![editorIndex++],
          maxLines: null,
          textAlign: _centered(b) ? TextAlign.center : TextAlign.start,
          style: _styleFor(b, const LetterSpan('')),
        );
      } else {
        w = Text.rich(
          TextSpan(
            children: [
              for (final s in b.spans)
                TextSpan(text: s.text, style: _styleFor(b, s)),
            ],
          ),
          textAlign: _centered(b) ? TextAlign.center : TextAlign.start,
        );
      }
      children.add(
        Padding(
          padding: EdgeInsets.only(
            bottom: b.kind == LetterBlockKind.signature
                ? AppSpace.xs
                : AppSpace.md,
          ),
          child: w,
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.border),
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpace.xxl,
        AppSpace.xxl + extraTopMargin,
        AppSpace.xxl,
        AppSpace.xxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildTable(LetterBlock b) {
    final headers = b.tableHeaders!;
    final rows = b.tableRows!;
    return Table(
      border: TableBorder.all(color: AppColors.border),
      defaultColumnWidth: const FlexColumnWidth(),
      children: [
        TableRow(
          decoration: BoxDecoration(color: AppColors.surfaceMuted),
          children: [
            for (final h in headers)
              Padding(
                padding: const EdgeInsets.all(AppSpace.sm),
                child: Text(h, style: AppText.bodyStrong),
              ),
          ],
        ),
        for (final row in rows)
          TableRow(
            children: [
              for (final cell in row)
                Padding(
                  padding: const EdgeInsets.all(AppSpace.sm),
                  child: Text(cell, style: AppText.body),
                ),
            ],
          ),
      ],
    );
  }
}
