/// Financial Standing Undertaking — letter model and builder.
///
/// Reference: GeM Bid No. | Date.
/// Format: Title + Ref | To: | Opening | 4 numbered clauses | Signature + Seal.
library;

import 'letter_model.dart';
import 'mii_certificate_text.dart' show formatLetterDate;

// ── Input model ───────────────────────────────────────────────────────────────

class FinancialStandingInput {
  final String tenderNo;
  final String buyerDesignation;
  final String buyerOrg;
  final String company;

  /// Annual turnovers for FY 2022–23, 2023–24, 2024–25 (₹ amounts as strings).
  final String turnover2223;
  final String turnover2324;
  final String turnover2425;

  /// Year for the net worth statement, e.g. "2024".
  final String netWorthYear;

  final String signatory;
  final String designation;
  final DateTime date;

  const FinancialStandingInput({
    required this.tenderNo,
    required this.buyerDesignation,
    required this.buyerOrg,
    required this.company,
    required this.turnover2223,
    required this.turnover2324,
    required this.turnover2425,
    required this.netWorthYear,
    required this.signatory,
    required this.designation,
    required this.date,
  });
}

// ── Letter builder ────────────────────────────────────────────────────────────

List<LetterBlock> buildFinancialStandingUndertaking(FinancialStandingInput i) {
  return [
    // ── Title ───────────────────────────────────────────────────────────────
    LetterBlock.plain(LetterBlockKind.title, 'UNDERTAKING OF FINANCIAL STANDING'),
    LetterBlock(LetterBlockKind.subtitle, [
      const LetterSpan('GeM Bid No.: '),
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
      const LetterSpan(
        '1.   Our annual turnover for FY 2022–23 to 2024–25 is ₹',
      ),
      LetterSpan(i.turnover2223, bold: true),
      const LetterSpan(', ₹'),
      LetterSpan(i.turnover2324, bold: true),
      const LetterSpan(', ₹'),
      LetterSpan(i.turnover2425, bold: true),
      const LetterSpan(', respectively, meeting the ATC criterion for this Bid.'),
    ]),

    const LetterBlock.spacer(),

    // ── Clause 2 ─────────────────────────────────────────────────────────────
    LetterBlock(LetterBlockKind.body, [
      const LetterSpan('2.   Our net worth as of 31st March '),
      LetterSpan(i.netWorthYear, bold: true),
      const LetterSpan(
        ' is positive. We are not subject to insolvency or winding-up proceedings'
        ' under the Insolvency and Bankruptcy Code, 2016.',
      ),
    ]),

    const LetterBlock.spacer(),

    // ── Clause 3 ─────────────────────────────────────────────────────────────
    LetterBlock.plain(
      LetterBlockKind.body,
      '3.   We are not classified as an NPA by any bank or financial institution.',
    ),

    const LetterBlock.spacer(),

    // ── Clause 4 ─────────────────────────────────────────────────────────────
    LetterBlock.plain(
      LetterBlockKind.body,
      '4.   We will furnish audited financial statements, CA-certified turnover certificate,'
      ' and ITR acknowledgements within 48 hours of a written request.',
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
