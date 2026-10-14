/// OEM Authorization Certificate — letter model and builder.
///
/// Authorizes a reseller/distributor to participate in a GeM bid on the
/// OEM's behalf. Has a named recipient block and tender number.
///
/// Pure Dart — no Flutter imports.
library;

import 'letter_model.dart';
import 'mii_certificate_text.dart' show formatLetterDate;

// ── Template selector ─────────────────────────────────────────────────────────

enum OemAuthorizationTemplate { template1 }

// ── Input model ───────────────────────────────────────────────────────────────

class OemAuthorizationInput {
  final OemAuthorizationTemplate template;
  final String recipientTitle;
  final String organization;
  final String organizationAddress;
  final String tenderNo;
  final String resellerName;
  final String resellerAddress;
  final String company;
  final String companyAddress;
  final String signatory;
  final String designation;
  final DateTime date;

  const OemAuthorizationInput({
    required this.template,
    required this.recipientTitle,
    required this.organization,
    required this.organizationAddress,
    required this.tenderNo,
    required this.resellerName,
    required this.resellerAddress,
    required this.company,
    required this.companyAddress,
    required this.signatory,
    required this.designation,
    required this.date,
  });
}

// ── Letter builder ────────────────────────────────────────────────────────────

List<LetterBlock> buildOemAuthorization(OemAuthorizationInput i) {
  switch (i.template) {
    case OemAuthorizationTemplate.template1:
      return _buildTemplate1(i);
  }
}

List<LetterBlock> _buildTemplate1(OemAuthorizationInput i) => [
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
    const LetterSpan('Authorization Letter'),
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

  // 13. Main authorization paragraph
  LetterBlock(LetterBlockKind.body, [
    const LetterSpan('We '),
    LetterSpan(i.company, bold: true),
    const LetterSpan(' situated at '),
    LetterSpan(i.companyAddress, bold: true),
    const LetterSpan(' would like to inform you that '),
    LetterSpan('M/s ${i.resellerName}', bold: true),
    const LetterSpan(' situated at '),
    LetterSpan(i.resellerAddress, bold: true),
    const LetterSpan(' is our authorized distributor for the above mentioned GeM Bid.'),
  ]),
  // 14. Scope of authorization
  LetterBlock.plain(
    LetterBlockKind.body,
    'They are authorized to quote rates, collect supply orders, make supplies, '
    'raise their own invoices and collect payments on our behalf.',
  ),
  // 15. Validity
  LetterBlock.plain(
    LetterBlockKind.body,
    'This authorization is valid till the validity of the above mentioned GeM Bid.',
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
