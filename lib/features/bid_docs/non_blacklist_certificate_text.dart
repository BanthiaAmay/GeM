/// Content + rules for the "Undertaking for Non-blacklisting" declaration
/// required in most government / GeM tenders.
///
/// All wording lives here (not in the widget) so it can be reviewed and
/// tested independently.
library;

import 'letter_model.dart';
import 'mii_certificate_text.dart' show formatLetterDate;

export 'mii_certificate_text.dart' show formatLetterDate;

/// Everything the certificate needs. Immutable; the page builds one on Generate.
class NbcInput {
  /// Recipient designation, e.g. "The Commandant".
  final String recipient;

  /// Organisation the tender belongs to, e.g. "Indian Army".
  final String organization;

  /// Recipient's address, e.g. "New Delhi".
  final String address;

  /// GeM bid number, e.g. "GEM/2026/B/7845020".
  final String tenderNo;

  final String company;

  /// Stored in the model (and profile) for future use; not placed in the
  /// document body by the current layout.
  final String companyAddress;

  final String signatory;
  final String designation;
  final DateTime date;

  const NbcInput({
    required this.recipient,
    required this.organization,
    required this.address,
    required this.tenderNo,
    required this.company,
    required this.companyAddress,
    required this.signatory,
    required this.designation,
    required this.date,
  });
}

/// Builds the certificate as styled blocks ready for [LetterPaper] and PDF.
List<LetterBlock> buildNbcCertificate(NbcInput i) => [
  LetterBlock.plain(LetterBlockKind.date, 'Date: ${formatLetterDate(i.date)}'),
  LetterBlock.plain(LetterBlockKind.body, ''),
  LetterBlock.plain(LetterBlockKind.body, 'To'),
  LetterBlock.plain(LetterBlockKind.body, ''),
  LetterBlock(LetterBlockKind.body, [LetterSpan(i.recipient, bold: true)]),
  LetterBlock(LetterBlockKind.body, [LetterSpan(i.organization, bold: true)]),
  LetterBlock(LetterBlockKind.body, [LetterSpan(i.address, bold: true)]),
  LetterBlock.plain(LetterBlockKind.body, ''),
  LetterBlock(LetterBlockKind.body, [
    const LetterSpan('Subject: '),
    const LetterSpan('Undertaking for Non-blacklisting', bold: true),
  ]),
  LetterBlock(LetterBlockKind.body, [
    const LetterSpan('GeM Bid No: '),
    LetterSpan(i.tenderNo, bold: true),
  ]),
  LetterBlock.plain(LetterBlockKind.body, ''),
  LetterBlock.plain(LetterBlockKind.body, 'Dear Sir/Ma\'am,'),
  LetterBlock.plain(
    LetterBlockKind.body,
    'We hereby certify that, we have not been ever blacklisted / debarred by '
    'any Central / State Government / Public Undertaking / Institute on any account.',
  ),
  LetterBlock(LetterBlockKind.body, [
    const LetterSpan('Duly authorized to sign the bid for and on behalf of '),
    LetterSpan(i.company, bold: true),
    const LetterSpan('.'),
  ]),
  const LetterBlock.spacer(),
  LetterBlock.plain(LetterBlockKind.signature, i.signatory),
  LetterBlock.plain(LetterBlockKind.signature, i.designation),
];
