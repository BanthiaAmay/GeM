/// Non-Relation Undertaking — letter model and builder.
///
/// Certifies no conflict of interest between the bidding company and any
/// member of the tender evaluation committee.
///
/// Pure Dart — no Flutter imports. Can be unit-tested without a widget tree.
library;

import 'letter_model.dart';
import 'mii_certificate_text.dart' show formatLetterDate;

export 'mii_certificate_text.dart' show formatLetterDate;

// ── Input model ───────────────────────────────────────────────────────────────

class NonRelationInput {
  final String tenderNo;
  final String company;
  final String companyAddress;
  final String signatory;
  final String designation;
  final DateTime date;

  const NonRelationInput({
    required this.tenderNo,
    required this.company,
    required this.companyAddress,
    required this.signatory,
    required this.designation,
    required this.date,
  });
}

// ── Letter builder ────────────────────────────────────────────────────────────

List<LetterBlock> buildNonRelationUndertaking(NonRelationInput i) => [
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
    const LetterSpan('Non-Relationship Certificate'),
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
      '), has no direct or indirect familial, financial, or business '
      'relationships with any members of the evaluation committee or any '
      'personnel associated with involved in the evaluation or '
      'decision-making process of GeM Bid No ',
    ),
    LetterSpan(i.tenderNo, bold: true),
    const LetterSpan('.'),
  ]),
  const LetterBlock.spacer(),

  // Paragraph 2 — affirmation
  LetterBlock.plain(
    LetterBlockKind.body,
    'Furthermore, we affirm that neither our company nor any of our directors, '
    'partners, or employees have any personal or financial interest in any '
    'company participating in the tender process for the project mentioned above.',
  ),
  const LetterBlock.spacer(),

  // Paragraph 3 — declaration
  LetterBlock.plain(
    LetterBlockKind.body,
    'We hereby declare that all information provided in this certificate is '
    'true and accurate to the best of our knowledge and belief.',
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

  // Extra space before signature (3 blank lines worth)
  const LetterBlock.spacer(),
  const LetterBlock.spacer(),

  // Signature block
  LetterBlock(LetterBlockKind.signature, [LetterSpan(i.signatory, bold: true)]),
  LetterBlock.plain(LetterBlockKind.signature, i.designation),
  LetterBlock.plain(LetterBlockKind.signature, i.company),
];
