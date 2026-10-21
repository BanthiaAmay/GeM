/// Financial Standing Undertaking — letter model and builder.
///
/// Declares the company is solvent, not under liquidation, court receivership,
/// or bankruptcy. Has a named recipient block unlike the generic "To Whom It
/// May Concern" pattern used by other bid-doc tools.
///
/// Pure Dart — no Flutter imports.
library;

import 'letter_model.dart';
import 'mii_certificate_text.dart' show formatLetterDate;

// ── Input model ───────────────────────────────────────────────────────────────

class FinancialStandingInput {
  final String recipientTitle;
  final String organization;
  final String organizationAddress;
  final String tenderNo;
  final String company;
  final String companyAddress;
  final String signatory;
  final String designation;
  final DateTime date;

  const FinancialStandingInput({
    required this.recipientTitle,
    required this.organization,
    required this.organizationAddress,
    required this.tenderNo,
    required this.company,
    required this.companyAddress,
    required this.signatory,
    required this.designation,
    required this.date,
  });
}

// ── Letter builder ────────────────────────────────────────────────────────────

List<LetterBlock> buildFinancialStandingUndertaking(FinancialStandingInput i) => [
  // Date
  LetterBlock.plain(LetterBlockKind.date, 'Date: ${formatLetterDate(i.date)}'),
  const LetterBlock.spacer(),

  // Recipient block — "To" header then named recipient
  LetterBlock.plain(LetterBlockKind.body, 'To'),
  LetterBlock(LetterBlockKind.body, [LetterSpan(i.recipientTitle, bold: true)]),
  LetterBlock.plain(LetterBlockKind.body, i.organization),
  LetterBlock.plain(LetterBlockKind.body, i.organizationAddress),
  const LetterBlock.spacer(),

  // Subject and reference lines
  LetterBlock(LetterBlockKind.body, [
    const LetterSpan('Subject: ', bold: true),
    const LetterSpan('Bidder Financial Standing Undertaking'),
  ]),
  LetterBlock(LetterBlockKind.body, [
    const LetterSpan('GeM Bid No: ', bold: true),
    LetterSpan(i.tenderNo),
  ]),
  const LetterBlock.spacer(),

  // Salutation
  LetterBlock.plain(LetterBlockKind.body, 'Dear Sir/Ma\'am,'),
  const LetterBlock.spacer(),

  // Paragraph 1 — solvency declaration
  LetterBlock(LetterBlockKind.body, [
    const LetterSpan('We, '),
    LetterSpan(i.company, bold: true),
    const LetterSpan(
      ', hereby declare that our organization is not currently undergoing '
      'liquidation, court receivership, or any similar legal proceedings. '
      'Furthermore, we affirm that we are not in a state of bankruptcy.',
    ),
  ]),
  const LetterBlock.spacer(),

  // Paragraph 2 — authorisation
  LetterBlock(LetterBlockKind.body, [
    const LetterSpan('Duly authorized to sign the bid for and on behalf of '),
    LetterSpan(i.company, bold: true),
    const LetterSpan('.'),
  ]),

  // Extra space before signature (blank × 3)
  const LetterBlock.spacer(),
  const LetterBlock.spacer(),

  // Signature block — no "Sincerely," per spec; signatory not bold per spec
  LetterBlock.plain(LetterBlockKind.signature, i.signatory),
  LetterBlock.plain(LetterBlockKind.signature, i.designation),
];
