/// Acceptance of Terms and Conditions (ATC) Certificate — letter model and builder.
///
/// Accepts all additional terms and conditions associated with a GeM bid.
/// Company name appears bold in two places; no "Sincerely" line.
///
/// Pure Dart — no Flutter imports.
library;

import 'letter_model.dart';
import 'mii_certificate_text.dart' show formatLetterDate;

// ── Input model ───────────────────────────────────────────────────────────────

class AtcCertificateInput {
  final String recipientTitle;
  final String organization;
  final String organizationAddress;
  final String tenderNo;
  final String company;
  final String companyAddress;
  final String signatory;
  final String designation;
  final DateTime date;

  const AtcCertificateInput({
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

List<LetterBlock> buildAtcCertificate(AtcCertificateInput i) => [
  // 1. Date
  LetterBlock.plain(LetterBlockKind.date, 'Date: ${formatLetterDate(i.date)}'),
  // 2. Spacer
  const LetterBlock.spacer(),

  // 3-6. Recipient block
  LetterBlock.plain(LetterBlockKind.body, 'To'),
  LetterBlock(LetterBlockKind.body, [LetterSpan(i.recipientTitle, bold: true)]),
  LetterBlock.plain(LetterBlockKind.body, i.organization),
  LetterBlock.plain(LetterBlockKind.body, i.organizationAddress),
  // 7. Spacer
  const LetterBlock.spacer(),

  // 8. Subject line
  LetterBlock(LetterBlockKind.body, [
    const LetterSpan('Subject: ', bold: true),
    const LetterSpan('Acceptance of Terms and Conditions'),
  ]),
  // 9. GeM Bid No line
  LetterBlock(LetterBlockKind.body, [
    const LetterSpan('GeM Bid No: ', bold: true),
    LetterSpan(i.tenderNo),
  ]),
  // 10. Spacer
  const LetterBlock.spacer(),

  // 11. Salutation
  LetterBlock.plain(LetterBlockKind.body, 'Dear Sir/Ma\'am,'),
  // 12. Spacer
  const LetterBlock.spacer(),

  // 13. Para 1 — acceptance with bold company name
  LetterBlock(LetterBlockKind.body, [
    const LetterSpan('We, '),
    LetterSpan(i.company, bold: true),
    const LetterSpan(
      ', hereby acknowledge and accept all the additional terms and conditions '
      'associated with the above mentioned GeM Bid, as specified by the buyer '
      'in the bid documentation.',
    ),
  ]),
  // 14-16. Body paragraphs (no bold)
  LetterBlock.plain(
    LetterBlockKind.body,
    'We understand that these additional terms and conditions are an integral '
    'part of the bidding process and are essential for the successful execution '
    'of the contract.',
  ),
  LetterBlock.plain(
    LetterBlockKind.body,
    'By submitting our bid for the aforementioned GeM Bid, we affirm our '
    'commitment to comply with and abide by all the additional terms and '
    'conditions outlined by the buyer.',
  ),
  LetterBlock.plain(
    LetterBlockKind.body,
    'We fully understand that failure to adhere to these terms and conditions '
    'may result in disqualification or termination of the contract.',
  ),
  // 17. Spacer
  const LetterBlock.spacer(),

  // 18. Closing authorisation — bold company name (second occurrence)
  LetterBlock(LetterBlockKind.body, [
    const LetterSpan('Duly authorized to sign the bid for and on behalf of '),
    LetterSpan(i.company, bold: true),
    const LetterSpan('.'),
  ]),
  // 19-21. Three spacers before signature
  const LetterBlock.spacer(),
  const LetterBlock.spacer(),
  const LetterBlock.spacer(),

  // 22-23. Signature block
  LetterBlock.plain(LetterBlockKind.signature, i.signatory),
  LetterBlock.plain(LetterBlockKind.body, i.designation),
];
