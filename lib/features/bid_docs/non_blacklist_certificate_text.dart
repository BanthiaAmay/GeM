/// Non-Blacklisting and Non-Debarment Certificate — letter model and builder.
///
/// Reference: GeM GTC Clause 3(A)(xiv) — Rule 151, GFR 2017.
/// Format: Title + Ref | To: | Opening | 3 numbered clauses | Signature + Seal.
library;

import 'letter_model.dart';
import 'mii_certificate_text.dart' show formatLetterDate;

// ── Input model ───────────────────────────────────────────────────────────────

class NonBlacklistCertificateInput {
  final String tenderNo;
  final String buyerDesignation;
  final String buyerOrg;
  final String company;
  final String signatory;
  final String designation;
  final DateTime date;

  const NonBlacklistCertificateInput({
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

List<LetterBlock> buildNonBlacklistCertificate(
  NonBlacklistCertificateInput i,
) {
  return [
    // ── Title ───────────────────────────────────────────────────────────────
    LetterBlock.plain(
      LetterBlockKind.title,
      'NON-BLACKLISTING AND NON-DEBARMENT CERTIFICATE',
    ),
    LetterBlock(LetterBlockKind.subtitle, [
      const LetterSpan(
        'GeM GTC Clause 3(A)(xiv) — Rule 151, GFR 2017   |   GeM Bid No.: ',
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
      const LetterSpan('), certify:'),
    ]),

    const LetterBlock.spacer(),

    // ── Clause 1 ─────────────────────────────────────────────────────────────
    LetterBlock(LetterBlockKind.body, [
      const LetterSpan('1.   '),
      LetterSpan(i.company, bold: true),
      const LetterSpan(' is not '),
      const LetterSpan('"Debarred from Bidding"', bold: true),
      const LetterSpan(' on the grounds mentioned in '),
      const LetterSpan('Rule 151 of the GFR, 2017', bold: true),
      const LetterSpan(
        ', and does not appear on the GeM Debarred/Suspended Sellers List as of this date.',
      ),
    ]),

    const LetterBlock.spacer(),

    // ── Clause 2 ─────────────────────────────────────────────────────────────
    LetterBlock(LetterBlockKind.body, [
      const LetterSpan('2.   '),
      LetterSpan(i.company, bold: true),
      const LetterSpan(
        ' has not been blacklisted or suspended by any Central/State Government'
        ' entity, PSU, or statutory authority on any ground.',
      ),
    ]),

    const LetterBlock.spacer(),

    // ── Clause 3 ─────────────────────────────────────────────────────────────
    LetterBlock(LetterBlockKind.body, [
      const LetterSpan(
        '3.   No debarment proceeding is pending against ',
      ),
      LetterSpan(i.company, bold: true),
      const LetterSpan(
        ' or any of its Directors or Key Management Personnel that remains unresolved.',
      ),
    ]),

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
    LetterBlock.plain(
      LetterBlockKind.signature,
      'Date:                    | Place:                    | Seal:',
    ),
  ];
}
