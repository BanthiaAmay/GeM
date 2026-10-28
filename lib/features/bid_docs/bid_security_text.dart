/// Bid Security Declaration — letter model and builder.
///
/// Declares the bidder's compliance with bid security conditions
/// in lieu of a physical deposit. Includes named recipient block
/// and specific legal boilerplate.
///
/// Pure Dart — no Flutter imports.
library;

import 'letter_model.dart';
import 'mii_certificate_text.dart' show formatLetterDate;

// ── Input model ───────────────────────────────────────────────────────────────

class BidSecurityInput {
  final String recipientTitle;
  final String organization;
  final String organizationAddress;
  final String tenderNo;
  final String company;
  final String companyAddress;
  final String signatory;
  final String designation;
  final DateTime date;

  const BidSecurityInput({
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

List<LetterBlock> buildBidSecurityDeclaration(BidSecurityInput i) => [
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
    LetterSpan('Bids Securing Declaration against GeM bid no. ${i.tenderNo}'),
  ]),
  // 9. Spacer
  const LetterBlock.spacer(),

  // 10. Salutation
  LetterBlock.plain(LetterBlockKind.body, 'Dear Sir/Ma\'am,'),
  // 11. Spacer
  const LetterBlock.spacer(),

  // 12. Para 1 — bid security acknowledgement
  LetterBlock.plain(
    LetterBlockKind.body,
    'We, understand that, according to your conditions, bids must be '
    'supported by a Bid Securing Declaration.',
  ),
  // 13. Spacer
  const LetterBlock.spacer(),

  // 14. Para 2 — disqualification notice
  LetterBlock.plain(
    LetterBlockKind.body,
    'We, accept that I/ We may be disqualified from bidding for any '
    'contract with you for a period of six months from the date of '
    'notification if am/ We are in a breach of any obligation under the '
    'bid conditions, because we',
  ),
  // 15. Spacer
  const LetterBlock.spacer(),

  // 16-19. Numbered clauses
  LetterBlock.plain(
    LetterBlockKind.body,
    '1. have fail to sign the contract, withdrawn/ modified/ amended, '
    'impairs or derogates from the tender, my/ our bid during the period '
    'of bid validity specified in the form of Bid; or',
  ),
  LetterBlock.plain(
    LetterBlockKind.body,
    '2. having been notified of the acceptance of our Bid by the '
    'purchaser during the period of bid validity',
  ),
  LetterBlock.plain(
    LetterBlockKind.body,
    '    • Fail or refuse to execute the contract, i.e. failed to '
    'supply items against Supply Order, or',
  ),
  LetterBlock.plain(
    LetterBlockKind.body,
    '    • fail or refuse to furnish the performance security, in '
    'accordance with the instructions to Bidders.',
  ),
  // 20. Spacer
  const LetterBlock.spacer(),

  // 21-23. Expiry clauses
  LetterBlock.plain(
    LetterBlockKind.body,
    'We, undersigned this Bid Securing Declaration shall cease to be '
    'valid if we are not the successful Bidder (L1), upon the earlier of',
  ),
  LetterBlock.plain(
    LetterBlockKind.body,
    '1. the receipt of your notification of the name of the successful '
    'bidder; or',
  ),
  LetterBlock.plain(
    LetterBlockKind.body,
    '2. thirty days after the expiration of the validity of my/ our Bid.',
  ),
  // 24. Spacer
  const LetterBlock.spacer(),

  // 25. Closing authorisation — company bold ONLY here
  LetterBlock(LetterBlockKind.body, [
    const LetterSpan('Duly authorized to sign the bid for and on behalf of '),
    LetterSpan(i.company, bold: true),
    const LetterSpan('.'),
  ]),

  // 26-28. Three spacers before signature
  const LetterBlock.spacer(),
  const LetterBlock.spacer(),
  const LetterBlock.spacer(),

  // 29-30. Signature block (designation uses body kind per spec)
  LetterBlock.plain(LetterBlockKind.signature, i.signatory),
  LetterBlock.plain(LetterBlockKind.body, i.designation),
];
