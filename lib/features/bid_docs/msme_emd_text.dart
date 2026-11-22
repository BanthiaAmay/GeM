/// MSME EMD Exemption Declaration — letter model and builder.
///
/// Reference: GeM GTC Clause 4(xiii)(m)(i).
/// Format: Title + Ref | To: | Opening + exemption claim | Manufacturer declaration | Udyam details | Closing | Signature + Seal.
library;

import 'letter_model.dart';
import 'mii_certificate_text.dart' show formatLetterDate;

// ── Input model ───────────────────────────────────────────────────────────────

class MsmeEmdInput {
  final String tenderNo;
  final String buyerDesignation;
  final String buyerOrg;
  final String company;
  final String productServiceName;
  final String placeOfBusiness;
  final String udyamRegistrationNo;

  /// "Micro" or "Small"
  final String msmeCategory;

  final String signatory;
  final String designation;
  final DateTime date;

  const MsmeEmdInput({
    required this.tenderNo,
    required this.buyerDesignation,
    required this.buyerOrg,
    required this.company,
    required this.productServiceName,
    required this.placeOfBusiness,
    required this.udyamRegistrationNo,
    required this.msmeCategory,
    required this.signatory,
    required this.designation,
    required this.date,
  });
}

// ── Letter builder ────────────────────────────────────────────────────────────

List<LetterBlock> buildMsmeEmdDeclaration(MsmeEmdInput i) {
  return [
    // ── Title ───────────────────────────────────────────────────────────────
    LetterBlock.plain(
      LetterBlockKind.title,
      'DECLARATION — EXEMPTION FROM EARNEST MONEY DEPOSIT (EMD)',
    ),
    LetterBlock(LetterBlockKind.subtitle, [
      const LetterSpan('GeM GTC Clause 4(xiii)(m)(i)   |   GeM Bid No.: '),
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
        '), claim EMD exemption under Clause 4(xiii)(m)(i) of the GeM GTC,'
        ' which exempts MSE manufacturers holding valid Udyam Registration.',
      ),
    ]),

    const LetterBlock.spacer(),

    // ── Manufacturer declaration ──────────────────────────────────────────────
    LetterBlock(LetterBlockKind.body, [
      const LetterSpan('We expressly declare that '),
      LetterSpan(i.company, bold: true),
      const LetterSpan(' is the manufacturer', bold: true),
      const LetterSpan(' of '),
      LetterSpan(i.productServiceName, bold: true),
      const LetterSpan(
        ' offered under this Bid — not a trader or reseller. Our manufacturing'
        ' premises are located at ',
      ),
      LetterSpan(i.placeOfBusiness, bold: true),
      const LetterSpan('.'),
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

    // ── Closing ───────────────────────────────────────────────────────────────
    LetterBlock.plain(
      LetterBlockKind.body,
      'We kindly request your prompt attention to this matter and the necessary'
      ' actions to process our exemption Request.',
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
