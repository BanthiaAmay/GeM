/// Warranty Declaration — letter model and builder.
///
/// Certifies warranty terms for products/services being tendered.
/// No recipient block, no tender number.
///
/// Pure Dart — no Flutter imports.
library;

import 'letter_model.dart';
import 'mii_certificate_text.dart' show formatLetterDate;

// ── Input model ───────────────────────────────────────────────────────────────

class WarrantyDeclarationInput {
  final String signatoryName;
  final String designation;
  final String warrantyPeriod;
  final String contactName;
  final String contactPosition;
  final String contactEmail;
  final String contactPhone;
  final DateTime date;

  const WarrantyDeclarationInput({
    required this.signatoryName,
    required this.designation,
    required this.warrantyPeriod,
    required this.contactName,
    required this.contactPosition,
    required this.contactEmail,
    required this.contactPhone,
    required this.date,
  });
}

// ── Letter builder ────────────────────────────────────────────────────────────

List<LetterBlock> buildWarrantyDeclaration(WarrantyDeclarationInput i) => [
  // 1. Date
  LetterBlock.plain(LetterBlockKind.date, 'Date: ${formatLetterDate(i.date)}'),
  // 2. Spacer
  const LetterBlock.spacer(),

  // 3. Title — "To Whom It May Concern" (centered bold)
  LetterBlock.plain(LetterBlockKind.title, 'To Whom It May Concern'),
  // 4. Spacer
  const LetterBlock.spacer(),

  // 5. Subject
  LetterBlock.plain(LetterBlockKind.body, 'Subject: Warranty Declaration'),
  // 6. Spacer
  const LetterBlock.spacer(),

  // 7. Intro paragraph with bold signatory + designation
  LetterBlock(LetterBlockKind.body, [
    const LetterSpan('This is to certify that represented by '),
    LetterSpan('${i.signatoryName} (${i.designation})', bold: true),
    const LetterSpan(
      ', hereby declares the following warranty terms for the '
      'products/services being tendered:',
    ),
  ]),

  // 8. Warranty period paragraph with bold period
  LetterBlock(LetterBlockKind.body, [
    const LetterSpan(
      'Warranty Period: We hereby commit to providing a warranty period of ',
    ),
    LetterSpan(i.warrantyPeriod, bold: true),
    const LetterSpan(
      ' from the date of delivery/installation/commissioning, '
      'whichever is applicable.',
    ),
  ]),
  // 9. Spacer
  const LetterBlock.spacer(),

  // 10. Contact header
  LetterBlock.plain(
    LetterBlockKind.body,
    'Contact Information: In case of any warranty claims or service '
    'requests, please contact:',
  ),
  // 11. Spacer
  const LetterBlock.spacer(),

  // 12-15. Contact details
  LetterBlock.plain(LetterBlockKind.body, 'Name: ${i.contactName}'),
  LetterBlock.plain(LetterBlockKind.body, 'Position: ${i.contactPosition}'),
  LetterBlock.plain(LetterBlockKind.body, 'Email: ${i.contactEmail}'),
  LetterBlock.plain(LetterBlockKind.body, 'Phone No: ${i.contactPhone}'),
  // 16. Spacer
  const LetterBlock.spacer(),

  // 17-18. Closing declarations
  LetterBlock.plain(
    LetterBlockKind.body,
    'We hereby declare that all information provided in this warranty '
    'declaration is true and accurate to the best of our knowledge and belief.',
  ),
  LetterBlock.plain(
    LetterBlockKind.body,
    'Thank you for considering our bid. Should you require any further '
    'clarification or documentation regarding the warranty terms, please '
    'feel free to contact us.',
  ),
  // 19. Spacer
  const LetterBlock.spacer(),

  // 20. Sincerely
  LetterBlock.plain(LetterBlockKind.body, 'Sincerely'),
  // 21-23. Three spacers before signature
  const LetterBlock.spacer(),
  const LetterBlock.spacer(),
  const LetterBlock.spacer(),

  // 24-25. Signature block
  LetterBlock.plain(LetterBlockKind.signature, i.signatoryName),
  LetterBlock.plain(LetterBlockKind.body, i.designation),
];
