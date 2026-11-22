/// Undertaking to Furnish Performance Bank Guarantee — letter model and builder.
///
/// Reference: GeM GTC Clause 4 — Security Deposit.
/// Format: Title + Ref | To: | Opening | 4 numbered clauses | Signature + Seal.
library;

import 'letter_model.dart';
import 'mii_certificate_text.dart' show formatLetterDate;

// ── Input model ───────────────────────────────────────────────────────────────

class PbgUndertakingInput {
  final String tenderNo;
  final String buyerDesignation;
  final String buyerOrg;
  final String company;

  /// PBG percentage of Supply Order value, e.g. "5"
  final String pbgPercent;

  /// Days within which PBG must be furnished: "15" or "30"
  final String pbgDays;

  final String signatory;
  final String designation;
  final DateTime date;

  const PbgUndertakingInput({
    required this.tenderNo,
    required this.buyerDesignation,
    required this.buyerOrg,
    required this.company,
    required this.pbgPercent,
    required this.pbgDays,
    required this.signatory,
    required this.designation,
    required this.date,
  });
}

// ── Letter builder ────────────────────────────────────────────────────────────

List<LetterBlock> buildPbgUndertaking(PbgUndertakingInput i) {
  return [
    // ── Title ───────────────────────────────────────────────────────────────
    LetterBlock.plain(
      LetterBlockKind.title,
      'UNDERTAKING TO FURNISH PERFORMANCE BANK GUARANTEE',
    ),
    LetterBlock(LetterBlockKind.subtitle, [
      const LetterSpan('GeM GTC Clause 4 — Security Deposit   |   GeM Bid No.: '),
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
      const LetterSpan('), hereby undertake:'),
    ]),

    const LetterBlock.spacer(),

    // ── Clause 1 ─────────────────────────────────────────────────────────────
    LetterBlock(LetterBlockKind.body, [
      const LetterSpan(
        '1.   In the event of being awarded a Supply Order, we will furnish a'
        ' Performance Bank Guarantee (PBG) of ',
      ),
      LetterSpan(i.pbgPercent, bold: true),
      const LetterSpan('% of the Supply Order value within '),
      LetterSpan(i.pbgDays, bold: true),
      const LetterSpan(
        ' days of issuance of the Supply Order, as stipulated in the ATC and'
        ' GeM GTC Clause 4.',
      ),
    ]),

    const LetterBlock.spacer(),

    // ── Clause 2 ─────────────────────────────────────────────────────────────
    LetterBlock(LetterBlockKind.body, [
      const LetterSpan(
        '2.   The PBG will be issued by a scheduled commercial bank in India, in a'
        ' form acceptable to the Buyer Organisation, and will remain valid for the'
        ' full period of the Supply Order plus ',
      ),
      const LetterSpan('60 days', bold: true),
      const LetterSpan(' beyond the warranty/defect liability period.'),
    ]),

    const LetterBlock.spacer(),

    // ── Clause 3 ─────────────────────────────────────────────────────────────
    LetterBlock.plain(
      LetterBlockKind.body,
      '3.   We acknowledge that failure to furnish the PBG within the stipulated time'
      ' shall entitle the Buyer Organisation to cancel the Supply Order and forfeit the'
      ' Bid Security/EMD.',
    ),

    const LetterBlock.spacer(),

    // ── Clause 4 ─────────────────────────────────────────────────────────────
    LetterBlock.plain(
      LetterBlockKind.body,
      '4.   We confirm that our banking arrangements are in place and there is no'
      ' impediment to furnishing the PBG as committed above.',
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
