/// Warranty Declaration — letter model and builder.
///
/// Reference: GeM GTC Clause 10(i).
/// Format: Title + Ref | Opening | 2 numbered clauses | Warranty Claims Contact | Truth declaration | Signature + Seal.
library;

import 'letter_model.dart';
import 'mii_certificate_text.dart' show formatLetterDate;

// ── Input model ───────────────────────────────────────────────────────────────

class WarrantyDeclarationInput {
  final String tenderNo;
  final String company;
  final String signatory;
  final String designation;

  /// e.g. "24 months" or "2 years"
  final String warrantyPeriod;

  /// Working days for defect response/resolution.
  final String warrantyResponseDays;

  final String contactName;
  final String contactDesignation;
  final String contactEmail;
  final String contactPhone;
  final DateTime date;

  const WarrantyDeclarationInput({
    required this.tenderNo,
    required this.company,
    required this.signatory,
    required this.designation,
    required this.warrantyPeriod,
    required this.warrantyResponseDays,
    required this.contactName,
    required this.contactDesignation,
    required this.contactEmail,
    required this.contactPhone,
    required this.date,
  });
}

// ── Letter builder ────────────────────────────────────────────────────────────

List<LetterBlock> buildWarrantyDeclaration(WarrantyDeclarationInput i) {
  return [
    // ── Title ───────────────────────────────────────────────────────────────
    LetterBlock.plain(LetterBlockKind.title, 'WARRANTY DECLARATION'),
    LetterBlock(LetterBlockKind.subtitle, [
      const LetterSpan('GeM GTC Clause 10(i)   |   GeM Bid No.: '),
      LetterSpan(i.tenderNo, bold: true),
      const LetterSpan('   |   Date: '),
      LetterSpan(formatLetterDate(i.date), bold: true),
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
      const LetterSpan('1.   We commit to a warranty period of '),
      LetterSpan(i.warrantyPeriod, bold: true),
      const LetterSpan(
        ' from the date of delivery/acceptance, as prescribed in the ATC for this'
        ' Bid. Where the ATC expressly overrides the GTC Clause 10(i) standard of'
        ' one (1) year, the ATC period applies. Should the ATC not prescribe a'
        ' different period, we will provide the GTC-standard 1-year warranty.',
      ),
    ]),

    const LetterBlock.spacer(),

    // ── Clause 2 ─────────────────────────────────────────────────────────────
    LetterBlock(LetterBlockKind.body, [
      const LetterSpan(
        '2.   The warranty covers defects in materials, workmanship, and performance'
        ' under normal use. We will repair or replace defective goods within ',
      ),
      LetterSpan(i.warrantyResponseDays, bold: true),
      const LetterSpan(' working days of notification, at no cost to the Buyer.'),
    ]),

    const LetterBlock.spacer(),

    // ── Warranty Claims Contact ───────────────────────────────────────────────
    LetterBlock(LetterBlockKind.body, [
      const LetterSpan('Warranty Claims Contact: ', bold: true),
      LetterSpan(i.contactName, bold: true),
      const LetterSpan(' | '),
      LetterSpan(i.contactDesignation, bold: true),
      const LetterSpan(' | '),
      LetterSpan(i.contactEmail, bold: true),
      const LetterSpan(' | '),
      LetterSpan(i.contactPhone, bold: true),
    ]),

    const LetterBlock.spacer(),

    // ── Truth declaration ─────────────────────────────────────────────────────
    LetterBlock.plain(
      LetterBlockKind.body,
      'We hereby declare that all information provided in this warranty declaration'
      ' is true and accurate to the best of our knowledge and belief.',
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
