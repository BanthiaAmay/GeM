/// MSME Turnover / Experience Exemption — letter model and builder.
///
/// Reference: Public Procurement Policy for MSEs Order, 2012 — Para 11(a) | GeM GTC Clause 4(xiii)(t).
/// Format: Title + Ref | To: | Opening + exemption claim | Udyam details | Documents note | Signature + Seal.
library;

import 'letter_model.dart';
import 'mii_certificate_text.dart' show formatLetterDate;

// ── Input model ───────────────────────────────────────────────────────────────

class MsmeTurnoverInput {
  final String tenderNo;
  final String buyerDesignation;
  final String buyerOrg;
  final String company;
  final String udyamRegistrationNo;

  /// "Micro" or "Small"
  final String msmeCategory;

  final String signatory;
  final String designation;
  final DateTime date;

  const MsmeTurnoverInput({
    required this.tenderNo,
    required this.buyerDesignation,
    required this.buyerOrg,
    required this.company,
    required this.udyamRegistrationNo,
    required this.msmeCategory,
    required this.signatory,
    required this.designation,
    required this.date,
  });
}

// ── Letter builder ────────────────────────────────────────────────────────────

List<LetterBlock> buildMsmeTurnoverDeclaration(MsmeTurnoverInput i) {
  return [
    // ── Title ───────────────────────────────────────────────────────────────
    LetterBlock.plain(
      LetterBlockKind.title,
      'DECLARATION — EXEMPTION FROM PRIOR TURNOVER AND EXPERIENCE CRITERIA',
    ),
    LetterBlock(LetterBlockKind.subtitle, [
      const LetterSpan(
        'Public Procurement Policy for MSEs Order, 2012 — Para 11(a)   |'
        '   GeM GTC Clause 4(xiii)(t)   |   GeM Bid No.: ',
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
      const LetterSpan(
        '), claim exemption from the Prior Turnover and Prior Experience criteria'
        ' for this Bid under ',
      ),
      const LetterSpan(
        'Para 11(a) of the Public Procurement Policy for MSEs Order, 2012',
        bold: true,
      ),
      const LetterSpan(', as referenced in Clause 4(xiii)(t) of the GeM GTC.'),
    ]),

    const LetterBlock.spacer(),

    // ── Udyam details ─────────────────────────────────────────────────────────
    LetterBlock(LetterBlockKind.body, [
      const LetterSpan('Udyam Registration No.: ', bold: true),
      LetterSpan(i.udyamRegistrationNo, bold: true),
      const LetterSpan('   |   Category: ', bold: true),
      LetterSpan(i.msmeCategory, bold: true),
      const LetterSpan('   |   Status: ', bold: true),
      const LetterSpan('Valid'),
    ]),

    const LetterBlock.spacer(),

    // ── Documents note ────────────────────────────────────────────────────────
    LetterBlock.plain(
      LetterBlockKind.body,
      'A copy of our Udyam Registration Certificate is enclosed. Any additional'
      ' documentation to verify MSME status will be provided within 48 hours of a'
      ' written request.',
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
