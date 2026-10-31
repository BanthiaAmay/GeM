/// MSME EMD Exemption Request Declaration — letter model and builder.
///
/// Requests exemption from Earnest Money Deposit as a registered MSME.
/// Includes named recipient block and specific legal boilerplate.
///
/// Pure Dart — no Flutter imports.
library;

import 'letter_model.dart';
import 'mii_certificate_text.dart' show formatLetterDate;

// ── Input model ───────────────────────────────────────────────────────────────

class MsmeEmdInput {
  final String recipientTitle;
  final String organization;
  final String organizationAddress;
  final String tenderNo;
  final String company;
  final String companyAddress;
  final String signatory;
  final String designation;
  final String udyamRegistrationNo;
  final DateTime date;

  const MsmeEmdInput({
    required this.recipientTitle,
    required this.organization,
    required this.organizationAddress,
    required this.tenderNo,
    required this.company,
    required this.companyAddress,
    required this.signatory,
    required this.designation,
    required this.udyamRegistrationNo,
    required this.date,
  });
}

// ── Letter builder ────────────────────────────────────────────────────────────

List<LetterBlock> buildMsmeEmdDeclaration(MsmeEmdInput i) => [
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
    LetterSpan('Exemption Request for EMD for Tender No. ${i.tenderNo}'),
  ]),
  // 9. Spacer
  const LetterBlock.spacer(),

  // 10. Salutation
  LetterBlock.plain(LetterBlockKind.body, 'Dear Sir/Ma\'am,'),
  // 11. Spacer
  const LetterBlock.spacer(),

  // 12. Para 1 — introduction
  LetterBlock.plain(
    LetterBlockKind.body,
    'I am writing on behalf of ${i.company}, a registered Micro, Small, and '
    'Medium Enterprise (MSME), in reference to Tender No. ${i.tenderNo} issued '
    'by ${i.organization}. We appreciate the opportunity presented by the tender '
    'and wish to participate actively.',
  ),
  // 13. Spacer
  const LetterBlock.spacer(),

  // 14. Para 2 — legal basis
  LetterBlock.plain(
    LetterBlockKind.body,
    'As per the Government of India\'s Micro, Small, and Medium Enterprises '
    'Development Act, 2006, and the subsequent amendments, MSMEs are eligible '
    'for certain exemptions and benefits to facilitate their participation in '
    'procurement processes. One such benefit pertains to the waiver or exemption '
    'of Earnest Money Deposit (EMD) for MSMEs.',
  ),
  // 15. Spacer
  const LetterBlock.spacer(),

  // 16. Para 3 — claim exemption
  LetterBlock.plain(
    LetterBlockKind.body,
    'We hereby claim exemption from the requirement of submitting EMD for the '
    'aforementioned tender based on our MSME status. Our MSME registration '
    'details are as follows:',
  ),
  // 17. Udyam registration number (bold)
  LetterBlock(LetterBlockKind.body, [
    const LetterSpan('1. MSME Registration Number: '),
    LetterSpan(i.udyamRegistrationNo, bold: true),
  ]),
  // 18. Spacer
  const LetterBlock.spacer(),

  // 19. Validity confirmation
  LetterBlock.plain(
    LetterBlockKind.body,
    'Furthermore, we confirm that our MSME registration is valid and up-to-date '
    'as per the records of the appropriate authority.',
  ),
  // 20. Spacer
  const LetterBlock.spacer(),

  // 21-23. Documents list
  LetterBlock.plain(
    LetterBlockKind.body,
    'In compliance with the provisions outlined in the tender documents and '
    'relevant government regulations, we have enclosed the following documents '
    'for your verification:',
  ),
  LetterBlock.plain(
    LetterBlockKind.body,
    '1. Copy of our valid MSME registration certificate',
  ),
  LetterBlock.plain(
    LetterBlockKind.body,
    '2. Any other documents or information deemed necessary for the verification '
    'process',
  ),
  // 24. Spacer
  const LetterBlock.spacer(),

  // 25. Closing request
  LetterBlock.plain(
    LetterBlockKind.body,
    'We kindly request your prompt attention to this matter and the necessary '
    'actions to process our exemption Request.',
  ),
  // 26. Spacer
  const LetterBlock.spacer(),

  // 27. Sign-off
  LetterBlock.plain(LetterBlockKind.body, 'Yours Sincerely'),
  // 28-30. Three spacers before signature
  const LetterBlock.spacer(),
  const LetterBlock.spacer(),
  const LetterBlock.spacer(),

  // 31-32. Signature block
  LetterBlock.plain(LetterBlockKind.signature, i.signatory),
  LetterBlock.plain(LetterBlockKind.body, i.designation),
];
