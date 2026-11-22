/// Bid Security Declaration — letter model and builder.
///
/// Reference: GeM GTC Clause 4(xiii)(o).
/// Format: Title + Ref | To: | Opening + EMD confirmation | Forfeiture clauses (a–d) | Debarment para | Signature.
library;

import 'letter_model.dart';
import 'mii_certificate_text.dart' show formatLetterDate;

// ── Input model ───────────────────────────────────────────────────────────────

class BidSecurityInput {
  final String tenderNo;
  final String buyerDesignation;
  final String buyerOrg;
  final String company;
  final String emdAmount;
  final String modeOfPayment;
  final String signatory;
  final String designation;
  final DateTime date;

  const BidSecurityInput({
    required this.tenderNo,
    required this.buyerDesignation,
    required this.buyerOrg,
    required this.company,
    required this.emdAmount,
    required this.modeOfPayment,
    required this.signatory,
    required this.designation,
    required this.date,
  });
}

// ── Letter builder ────────────────────────────────────────────────────────────

List<LetterBlock> buildBidSecurityDeclaration(BidSecurityInput i) {
  return [
    // ── Title ───────────────────────────────────────────────────────────────
    LetterBlock.plain(LetterBlockKind.title, 'BID SECURITY DECLARATION'),
    LetterBlock(LetterBlockKind.subtitle, [
      const LetterSpan('GeM GTC Clause 4(xiii)(o)   |   GeM Bid No.: '),
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
      const LetterSpan('), confirm that EMD of ₹'),
      LetterSpan(i.emdAmount, bold: true),
      const LetterSpan(' has been submitted by '),
      LetterSpan(i.modeOfPayment, bold: true),
      const LetterSpan(' for the above Bid.'),
    ]),

    const LetterBlock.spacer(),

    // ── Forfeiture ───────────────────────────────────────────────────────────
    LetterBlock.plain(
      LetterBlockKind.body,
      'We acknowledge that the EMD shall be forfeited if we:',
    ),
    LetterBlock.plain(
      LetterBlockKind.body,
      ' (a) withdraw or modify our Bid before expiry of the validity period;',
    ),
    LetterBlock.plain(LetterBlockKind.body, ' (b) make any false declaration;'),
    LetterBlock.plain(
      LetterBlockKind.body,
      ' (c) fail to execute the Contract or accept the Supply Order after selection; or',
    ),
    LetterBlock.plain(
      LetterBlockKind.body,
      ' (d) fail to submit the required Performance Bank Guarantee within the stipulated time.',
    ),

    const LetterBlock.spacer(),

    // ── Debarment ────────────────────────────────────────────────────────────
    LetterBlock.plain(
      LetterBlockKind.body,
      'We understand that forfeiture may also result in debarment from GeM for a minimum of 3 months on the first offence.',
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
