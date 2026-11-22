/// ATC Acknowledgment and Acceptance Certificate — letter model and builder.
///
/// Reference: GeM GTC Clause 1 (Document Hierarchy).
/// Format: Title + Ref | To: | Opening | 2 numbered clauses | Disclaimer | Signature + Seal.
library;

import 'letter_model.dart';
import 'mii_certificate_text.dart' show formatLetterDate;

// ── Input model ───────────────────────────────────────────────────────────────

class AtcCertificateInput {
  final String tenderNo;
  final String buyerDesignation;
  final String buyerOrg;
  final String company;
  final String signatory;
  final String designation;
  final DateTime date;

  const AtcCertificateInput({
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

List<LetterBlock> buildAtcCertificate(AtcCertificateInput i) {
  return [
    // ── Title ───────────────────────────────────────────────────────────────
    LetterBlock.plain(
      LetterBlockKind.title,
      'ACKNOWLEDGMENT AND ACCEPTANCE OF ADDITIONAL TERMS AND CONDITIONS (ATC)',
    ),
    LetterBlock(LetterBlockKind.subtitle, [
      const LetterSpan('GeM GTC Clause 1 (Document Hierarchy)   |   GeM Bid No.: '),
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
      const LetterSpan('), confirm:'),
    ]),

    const LetterBlock.spacer(),

    // ── Clause 1 ─────────────────────────────────────────────────────────────
    LetterBlock(LetterBlockKind.body, [
      const LetterSpan('1.   We have reviewed the ATC uploaded by '),
      LetterSpan(i.buyerOrg, bold: true),
      const LetterSpan(
        ' for this Bid. Per Clause 1 of the GeM GTC (Version 1.29, 25th March 2026),'
        ' the ATC takes precedence over the GTC and STC to the extent permitted by law.',
      ),
    ]),

    const LetterBlock.spacer(),

    // ── Clause 2 ─────────────────────────────────────────────────────────────
    LetterBlock.plain(
      LetterBlockKind.body,
      '2.   Our Bid price fully accounts for all obligations, specifications, timelines,'
      ' and conditions in the ATC. We accept all ATC provisions unconditionally and will'
      ' not raise any objection to them after Bid submission.',
    ),

    const LetterBlock.spacer(),

    // ── Disclaimer ───────────────────────────────────────────────────────────
    LetterBlock.plain(
      LetterBlockKind.body,
      'We fully understand that failure to adhere to these terms and conditions may'
      ' result in disqualification or termination of the contract.',
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
    LetterBlock.plain(
      LetterBlockKind.signature,
      'Date:                    | Place:                    | Seal:',
    ),
  ];
}
