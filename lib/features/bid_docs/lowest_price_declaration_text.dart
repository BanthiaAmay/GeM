/// Lowest Price Declaration Certificate — letter model and builder.
///
/// Declares that prices quoted in a GeM bid are the lowest offered
/// to any buyer. Has a named recipient block and tender number.
///
/// Pure Dart — no Flutter imports.
library;

import 'letter_model.dart';
import 'mii_certificate_text.dart' show formatLetterDate;

// ── Template selector ─────────────────────────────────────────────────────────

enum LowestPriceTemplate { template1 }

// ── Input model ───────────────────────────────────────────────────────────────

class LowestPriceDeclarationInput {
  final LowestPriceTemplate template;
  final String recipientTitle;
  final String organization;
  final String organizationAddress;
  final String tenderNo;
  final String company;
  final String companyAddress;
  final String signatory;
  final String designation;
  final DateTime date;

  const LowestPriceDeclarationInput({
    required this.template,
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

List<LetterBlock> buildLowestPriceDeclaration(LowestPriceDeclarationInput i) {
  switch (i.template) {
    case LowestPriceTemplate.template1:
      return _buildTemplate1(i);
  }
}

List<LetterBlock> _buildTemplate1(LowestPriceDeclarationInput i) => [
  // 1. Date
  LetterBlock.plain(LetterBlockKind.date, 'Date: ${formatLetterDate(i.date)}'),
  // 2. Spacer
  const LetterBlock.spacer(),

  // 3–6. Named recipient block
  LetterBlock.plain(LetterBlockKind.body, 'To'),
  LetterBlock(LetterBlockKind.body, [LetterSpan(i.recipientTitle, bold: true)]),
  LetterBlock.plain(LetterBlockKind.body, i.organization),
  LetterBlock.plain(LetterBlockKind.body, i.organizationAddress),
  // 7. Spacer
  const LetterBlock.spacer(),

  // 8. Subject
  LetterBlock(LetterBlockKind.body, [
    const LetterSpan('Subject: ', bold: true),
    const LetterSpan('Declaration of Lowest Price Quoted'),
  ]),
  // 9. GeM Bid No (separate line)
  LetterBlock(LetterBlockKind.body, [
    const LetterSpan('GeM Bid No: ', bold: true),
    LetterSpan(i.tenderNo),
  ]),
  // 10. Spacer
  const LetterBlock.spacer(),

  // 11. Salutation
  LetterBlock.plain(LetterBlockKind.body, "Dear Sir/Ma'am,"),
  // 12. Spacer
  const LetterBlock.spacer(),

  // 13–15. Consecutive body blocks (no spacers between them)
  LetterBlock(LetterBlockKind.body, [
    const LetterSpan('We '),
    LetterSpan(i.company, bold: true),
    const LetterSpan(' having our registered office at '),
    LetterSpan(i.companyAddress, bold: true),
    const LetterSpan(
      ', hereby declare that the prices quoted by us in response to the '
      'above-mentioned bid are the lowest.',
    ),
  ]),
  LetterBlock.plain(
    LetterBlockKind.body,
    'We affirm that we have never quoted or supplied the product/service at '
    'rates lower than those quoted in this bid to any government organization, '
    'public sector undertaking (PSU), institution, or any other buyer.',
  ),
  LetterBlock.plain(
    LetterBlockKind.body,
    'We understand and accept that any deviation or false declaration regarding '
    'this matter may result in disqualification from the tendering process and '
    'potential legal consequences as per applicable laws.',
  ),
  // 16. Spacer
  const LetterBlock.spacer(),

  // 17. Closing authorization line
  LetterBlock(LetterBlockKind.body, [
    const LetterSpan('Duly authorized to sign the bid for and on behalf of '),
    LetterSpan(i.company, bold: true),
    const LetterSpan('.'),
  ]),
  // 18–20. Three spacers before signature
  const LetterBlock.spacer(),
  const LetterBlock.spacer(),
  const LetterBlock.spacer(),

  // 21–22. Signature block
  LetterBlock.plain(LetterBlockKind.signature, i.signatory),
  LetterBlock.plain(LetterBlockKind.body, i.designation),
];
