/// Land Border Declaration — letter model and builder.
///
/// Certifies compliance with land border restrictions under Rule 144 (xi)
/// of GFR 2017. No recipient block, no tender number.
///
/// Pure Dart — no Flutter imports.
library;

import 'letter_model.dart';
import 'mii_certificate_text.dart' show formatLetterDate;

// ── Template selector ─────────────────────────────────────────────────────────

enum LandBorderTemplate { template1 }

// ── Input model ───────────────────────────────────────────────────────────────

class LandBorderDeclarationInput {
  final LandBorderTemplate template;
  final String company;
  final String companyAddress;
  final String signatory;
  final String designation;
  final DateTime date;

  const LandBorderDeclarationInput({
    required this.template,
    required this.company,
    required this.companyAddress,
    required this.signatory,
    required this.designation,
    required this.date,
  });
}

// ── Letter builder ────────────────────────────────────────────────────────────

List<LetterBlock> buildLandBorderDeclaration(LandBorderDeclarationInput i) {
  switch (i.template) {
    case LandBorderTemplate.template1:
      return _buildTemplate1(i);
  }
}

List<LetterBlock> _buildTemplate1(LandBorderDeclarationInput i) => [
  // 1. Date
  LetterBlock.plain(LetterBlockKind.date, 'Date: ${formatLetterDate(i.date)}'),
  // 2. Spacer
  const LetterBlock.spacer(),

  // 3. Title — "To Whom It May Concern" (centered bold)
  LetterBlock.plain(LetterBlockKind.title, 'To Whom It May Concern'),
  // 4. Spacer
  const LetterBlock.spacer(),

  // 5. Subject
  LetterBlock(LetterBlockKind.body, [
    const LetterSpan('Subject: ', bold: true),
    const LetterSpan(
      'Declaration of Compliance with Restrictions under Rule 144 (xi) of GFR 2017',
    ),
  ]),
  // 6. Spacer
  const LetterBlock.spacer(),

  // 7. Para 1 — company bold
  LetterBlock(LetterBlockKind.body, [
    const LetterSpan('We, '),
    LetterSpan(i.company, bold: true),
    const LetterSpan(
      ', hereby declare that we are in full compliance with the restrictions '
      'outlined under Rule 144 (xi) of the General Financial Rules (GFR) 2017, '
      'as per the Department of Expenditure (DOE) Order (Public Procurement No.4) '
      'dated 23.02.2023, and subsequent amendments.',
    ),
  ]),
  // 8. Spacer
  const LetterBlock.spacer(),

  // 9. Preamble
  LetterBlock.plain(
    LetterBlockKind.body,
    'As a bidder participating in procurement processes, we confirm the following:',
  ),
  // 10. Spacer
  const LetterBlock.spacer(),

  // 11–14. Numbered list items (separate body blocks)
  LetterBlock.plain(
    LetterBlockKind.body,
    '1. We do not share a land border with India.',
  ),
  LetterBlock.plain(
    LetterBlockKind.body,
    '2. We do not have any Specified Transfer of Technology (ToT) arrangement '
    'with any entity from a country that shares a land border with India.',
  ),
  LetterBlock.plain(
    LetterBlockKind.body,
    '3. Our beneficial ownership structure complies with the definitions outlined '
    'in the General Terms and Conditions on GeM 4.0 (Version 1.11), dated 21st June 2023.',
  ),
  LetterBlock.plain(
    LetterBlockKind.body,
    '4. We understand that any false declaration or non-compliance with the '
    'aforementioned regulations may result in debarment and further legal action '
    'in accordance with the law.',
  ),
  // 15. Spacer
  const LetterBlock.spacer(),

  // 16. Certifying statement
  LetterBlock.plain(
    LetterBlockKind.body,
    'We hereby certify that the information provided in this declaration is true '
    'and accurate to the best of our knowledge.',
  ),
  // 17. Spacer
  const LetterBlock.spacer(),

  // 18. Sincerely
  LetterBlock.plain(LetterBlockKind.body, 'Sincerely,'),
  // 19–21. Three spacers before signature
  const LetterBlock.spacer(),
  const LetterBlock.spacer(),
  const LetterBlock.spacer(),

  // 22–23. Signature block
  LetterBlock.plain(LetterBlockKind.signature, i.signatory),
  LetterBlock.plain(LetterBlockKind.body, i.designation),
];
