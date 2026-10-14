/// Non-Conviction Certificate — letter model and builder.
///
/// Certifies that the company and its associates have no criminal convictions.
/// No tender number — this letter is company-level, not bid-specific.
///
/// Pure Dart — no Flutter imports.
library;

import 'letter_model.dart';
import 'mii_certificate_text.dart' show formatLetterDate;

export 'mii_certificate_text.dart' show formatLetterDate;

// ── Input model ───────────────────────────────────────────────────────────────

class NonConvictionInput {
  final String company;
  final String companyAddress;
  final String signatory;
  final String designation;
  final DateTime date;

  const NonConvictionInput({
    required this.company,
    required this.companyAddress,
    required this.signatory,
    required this.designation,
    required this.date,
  });
}

// ── Letter builder ────────────────────────────────────────────────────────────

List<LetterBlock> buildNonConvictionCertificate(NonConvictionInput i) => [
  // Date
  LetterBlock.plain(LetterBlockKind.date, 'Date: ${formatLetterDate(i.date)}'),
  const LetterBlock.spacer(),

  // Centred title
  LetterBlock(LetterBlockKind.title, [
    const LetterSpan('To Whom It May Concern'),
  ]),
  const LetterBlock.spacer(),

  // Subject line: "Subject:" bold, rest normal
  LetterBlock(LetterBlockKind.body, [
    const LetterSpan('Subject: ', bold: true),
    const LetterSpan('Non-Conviction Certificate'),
  ]),
  const LetterBlock.spacer(),

  // Paragraph 1 — main certification
  LetterBlock(LetterBlockKind.body, [
    const LetterSpan('This is to certify that '),
    LetterSpan(i.company, bold: true),
    const LetterSpan(' represented by '),
    LetterSpan(i.signatory, bold: true),
    const LetterSpan(' ('),
    LetterSpan(i.designation, bold: true),
    const LetterSpan(
      '), has not been convicted of any criminal offense under the laws '
      'of India or any other jurisdiction. Neither our company nor any of '
      'our directors, partners, or employees have been found guilty of any '
      'criminal offense punishable by imprisonment, fine, or any other '
      'penal action.',
    ),
  ]),
  const LetterBlock.spacer(),

  // Paragraph 2 — affirmation
  LetterBlock.plain(
    LetterBlockKind.body,
    'We affirm that all individuals associated with our company have '
    'maintained a clean legal record and have not been involved in any '
    'criminal activities that would affect our eligibility to participate '
    'in tenders or projects in India.',
  ),
  const LetterBlock.spacer(),

  // Paragraph 3 — declaration
  LetterBlock.plain(
    LetterBlockKind.body,
    'We hereby declare that all information provided in this certificate '
    'is true and accurate to the best of our knowledge and belief.',
  ),
  const LetterBlock.spacer(),

  // Paragraph 4 — closing
  LetterBlock.plain(
    LetterBlockKind.body,
    'Thank you for considering our bid. Should you require any further '
    'clarification or documentation, please feel free to contact us.',
  ),
  const LetterBlock.spacer(),

  // Sign-off
  LetterBlock.plain(LetterBlockKind.body, 'Sincerely,'),

  // Extra space before signature (blank × 3)
  const LetterBlock.spacer(),
  const LetterBlock.spacer(),

  // Signature block
  LetterBlock(LetterBlockKind.signature, [LetterSpan(i.signatory, bold: true)]),
  LetterBlock.plain(LetterBlockKind.signature, i.designation),
  LetterBlock.plain(LetterBlockKind.signature, i.company),
];
