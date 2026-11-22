/// Declaration — Absence of Conflict of Interest.
///
/// Reference: GFR Rule 175(1)(i)(h) — Code of Integrity.
/// Format: Title + Ref | To: | Opening | 5 numbered clauses | Signature.
library;

import 'letter_model.dart';
import 'mii_certificate_text.dart' show formatLetterDate;

// ── Input model ───────────────────────────────────────────────────────────────

class NonRelationInput {
  final String tenderNo;
  final String buyerDesignation;
  final String buyerOrg;
  final String company;
  final String signatory;
  final String designation;
  final DateTime date;

  const NonRelationInput({
    required this.tenderNo,
    required this.buyerDesignation,
    required this.buyerOrg,
    required this.company,
    required this.signatory,
    required this.designation,
    required this.date,
  });
}

// ── Letter builder ────────────────────────────────────────────────────────────

List<LetterBlock> buildNonRelationUndertaking(NonRelationInput i) {
  return [
    // ── Title ───────────────────────────────────────────────────────────────
    LetterBlock.plain(
      LetterBlockKind.title,
      'DECLARATION — ABSENCE OF CONFLICT OF INTEREST',
    ),
    LetterBlock(LetterBlockKind.subtitle, [
      const LetterSpan(
        'GFR Rule 175(1)(i)(h) — Code of Integrity   |   GeM Bid No.: ',
      ),
      LetterSpan(i.tenderNo, bold: true),
      const LetterSpan('   |   Date: '),
      LetterSpan(formatLetterDate(i.date), bold: true),
    ]),

    const LetterBlock.spacer(),

    // ── To ───────────────────────────────────────────────────────────────────
    LetterBlock(LetterBlockKind.body, [
      const LetterSpan('To: The '),
      LetterSpan(i.buyerDesignation, bold: true),
      const LetterSpan(', '),
      LetterSpan(i.buyerOrg, bold: true),
    ]),

    const LetterBlock.spacer(),

    // ── Opening ──────────────────────────────────────────────────────────────
    LetterBlock(LetterBlockKind.body, [
      const LetterSpan('We, '),
      LetterSpan(i.company, bold: true),
      const LetterSpan(', represented by '),
      LetterSpan(i.signatory, bold: true),
      const LetterSpan(' ('),
      LetterSpan(i.designation, bold: true),
      const LetterSpan('), declare:'),
    ]),

    const LetterBlock.spacer(),

    // ── Clause 1 ─────────────────────────────────────────────────────────────
    LetterBlock(LetterBlockKind.body, [
      const LetterSpan('1.   Neither '),
      LetterSpan(i.company, bold: true),
      const LetterSpan(
        ' nor any of its Directors or Key Management Personnel has any family'
        ' relationship with any official of ',
      ),
      LetterSpan(i.buyerOrg, bold: true),
      const LetterSpan(
        ' involved in this Bid\'s preparation, evaluation, or award.',
      ),
    ]),

    const LetterBlock.spacer(),

    // ── Clause 2 ─────────────────────────────────────────────────────────────
    LetterBlock.plain(
      LetterBlockKind.body,
      '2.   We have no financial interest — by shareholding, loan, or guarantee —'
      ' in any competing bidder for this Bid.',
    ),

    const LetterBlock.spacer(),

    // ── Clause 3 ─────────────────────────────────────────────────────────────
    LetterBlock(LetterBlockKind.body, [
      const LetterSpan(
        '3.   No Director or KMP has been employed by or consulted for ',
      ),
      LetterSpan(i.buyerOrg, bold: true),
      const LetterSpan(
        ' in the last five (5) years in a capacity that creates a conflict of'
        ' interest in this procurement.',
      ),
    ]),

    const LetterBlock.spacer(),

    // ── Clause 4 ─────────────────────────────────────────────────────────────
    LetterBlock.plain(
      LetterBlockKind.body,
      '4.   We have not engaged any agent whose remuneration is contingent on the'
      ' success of this Bid in a manner that compromises procurement integrity.',
    ),

    const LetterBlock.spacer(),

    // ── Clause 5 ─────────────────────────────────────────────────────────────
    LetterBlock.plain(
      LetterBlockKind.body,
      '5.   Any conflict arising during the Bid process or Supply Order will be'
      ' disclosed promptly in writing.',
    ),

    const LetterBlock.spacer(),
    const LetterBlock.spacer(),

    // ── Signature block ───────────────────────────────────────────────────────
    LetterBlock(LetterBlockKind.signature, [
      LetterSpan(i.signatory, bold: true),
      const LetterSpan('   |   '),
      LetterSpan(i.designation, bold: true),
      const LetterSpan('   |   '),
      LetterSpan(i.company, bold: true),
    ]),
    LetterBlock.plain(LetterBlockKind.signature, 'Date:                              | Place:'),
  ];
}
