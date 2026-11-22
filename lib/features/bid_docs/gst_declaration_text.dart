/// Declaration of GST Registration and Compliance — letter model and builder.
///
/// Reference: GeM GTC — Invoicing and Payment Provisions.
/// Format: Title + Ref | To: | Opening | 5 numbered clauses | Signature + Seal.
library;

import 'letter_model.dart';
import 'mii_certificate_text.dart' show formatLetterDate;

// ── Input model ───────────────────────────────────────────────────────────────

class GstDeclarationInput {
  final String tenderNo;
  final String buyerDesignation;
  final String buyerOrg;
  final String company;
  final String gstin;
  final String gstState;
  final String signatory;
  final String designation;
  final DateTime date;

  const GstDeclarationInput({
    required this.tenderNo,
    required this.buyerDesignation,
    required this.buyerOrg,
    required this.company,
    required this.gstin,
    required this.gstState,
    required this.signatory,
    required this.designation,
    required this.date,
  });
}

// ── Letter builder ────────────────────────────────────────────────────────────

List<LetterBlock> buildGstDeclaration(GstDeclarationInput i) {
  return [
    // ── Title ───────────────────────────────────────────────────────────────
    LetterBlock.plain(
      LetterBlockKind.title,
      'DECLARATION OF GST REGISTRATION AND COMPLIANCE',
    ),
    LetterBlock(LetterBlockKind.subtitle, [
      const LetterSpan('GeM GTC — Invoicing and Payment Provisions   |   GeM Bid No.: '),
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
      const LetterSpan('1.   '),
      LetterSpan(i.company, bold: true),
      const LetterSpan(' is duly registered under the Goods and Services Tax Act, 2017.'),
    ]),
    LetterBlock(LetterBlockKind.body, [
      const LetterSpan('     GSTIN: ', bold: true),
      LetterSpan(i.gstin, bold: true),
      const LetterSpan('   |   '),
      const LetterSpan('State of Registration: ', bold: true),
      LetterSpan(i.gstState, bold: true),
      const LetterSpan('   |   '),
      const LetterSpan('Status: ', bold: true),
      const LetterSpan('Active'),
    ]),

    const LetterBlock.spacer(),

    // ── Clause 2 ─────────────────────────────────────────────────────────────
    LetterBlock.plain(
      LetterBlockKind.body,
      '2.   The GSTIN registered on the GeM portal matches the GSTIN above and is'
      ' linked to our active PAN. There is no discrepancy between our GeM registration'
      ' and GST records.',
    ),

    const LetterBlock.spacer(),

    // ── Clause 3 ─────────────────────────────────────────────────────────────
    LetterBlock.plain(
      LetterBlockKind.body,
      '3.   All applicable GST returns (GSTR-1, GSTR-3B) are filed and up to date'
      ' as of this date. We are not in default of any GST obligation that would affect'
      ' the Buyer Organisation\'s Input Tax Credit (ITC) entitlement.',
    ),

    const LetterBlock.spacer(),

    // ── Clause 4 ─────────────────────────────────────────────────────────────
    LetterBlock.plain(
      LetterBlockKind.body,
      '4.   We will issue GST-compliant tax invoices for all supplies, clearly mentioning'
      ' the Buyer\'s GSTIN, HSN/SAC codes, applicable GST rates, and all mandatory fields'
      ' under the GST Act.',
    ),

    const LetterBlock.spacer(),

    // ── Clause 5 ─────────────────────────────────────────────────────────────
    LetterBlock.plain(
      LetterBlockKind.body,
      '5.   Any GST-related discrepancy flagged by the Buyer Organisation or the GST'
      ' portal will be resolved within 15 days of notice.',
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
