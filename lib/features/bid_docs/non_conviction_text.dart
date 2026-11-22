/// Non-Conviction Certificate — letter model and builder.
///
/// Reference: GeM GTC Clause 3(A)(xiv).
/// Format: Title + Ref | To: | Opening | 4 numbered clauses | Signature.
library;

import 'letter_model.dart';
import 'mii_certificate_text.dart' show formatLetterDate;

// ── Input model ───────────────────────────────────────────────────────────────

class NonConvictionInput {
  final String tenderNo;
  final String buyerDesignation;
  final String buyerOrg;
  final String company;
  final String signatory;
  final String designation;
  final DateTime date;

  const NonConvictionInput({
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

List<LetterBlock> buildNonConvictionCertificate(NonConvictionInput i) {
  return [
    // ── Title ───────────────────────────────────────────────────────────────
    LetterBlock.plain(LetterBlockKind.title, 'NON-CONVICTION CERTIFICATE'),
    LetterBlock(LetterBlockKind.subtitle, [
      const LetterSpan('GeM GTC Clause 3(A)(xiv)   |   GeM Bid No.: '),
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
      const LetterSpan(
        ' has not been convicted by any court of law of any offence involving'
        ' corruption, fraud, bribery, or moral turpitude under the Prevention of'
        ' Corruption Act, 1988, the Indian Penal Code, 1860, or any other applicable statute.',
      ),
    ]),

    const LetterBlock.spacer(),

    // ── Clause 2 ─────────────────────────────────────────────────────────────
    LetterBlock.plain(
      LetterBlockKind.body,
      '2.   None of the present Directors, Promoters, or Key Management Personnel'
      ' have been individually convicted of any such offence.',
    ),

    const LetterBlock.spacer(),

    // ── Clause 3 ─────────────────────────────────────────────────────────────
    LetterBlock(LetterBlockKind.body, [
      const LetterSpan('3.   '),
      LetterSpan(i.company, bold: true),
      const LetterSpan(' is not '),
      const LetterSpan('"Debarred from Bidding"', bold: true),
      const LetterSpan(
        ' on the grounds mentioned in Rule 151 of the GFR, 2017, and does not'
        ' appear on the GeM Debarred/Suspended Sellers List as of this date.',
      ),
    ]),

    const LetterBlock.spacer(),

    // ── Clause 4 ─────────────────────────────────────────────────────────────
    LetterBlock(LetterBlockKind.body, [
      const LetterSpan('4.   We will notify '),
      LetterSpan(i.buyerOrg, bold: true),
      const LetterSpan(
        ' in writing within 7 days if any such conviction or prosecution is'
        ' initiated during the currency of a Supply Order.',
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
    LetterBlock.plain(LetterBlockKind.signature, 'Date:                              | Place:'),
  ];
}
