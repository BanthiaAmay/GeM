/// Power of Attorney for Authorised Signatory — letter model and builder.
///
/// Reference: GeM Bid No. — to be executed on stamp paper of appropriate value and notarized.
/// Format: Title + Ref | KNOW ALL PERSONS clause | Principal + Attorney details | 5 purposes | Binding clause | Executed by | Witnesses.
library;

import 'letter_model.dart';
import 'mii_certificate_text.dart' show formatLetterDate;

// ── Input model ───────────────────────────────────────────────────────────────

class PowerOfAttorneyInput {
  final String tenderNo;
  final String company;

  /// e.g. "the Companies Act, 2013" or "the Indian Partnership Act, 1932"
  final String legalBasis;

  /// CIN / Registration No.
  final String cinRegNo;

  /// Registered office address
  final String registeredAddress;

  /// Buyer Organisation name (for clause 3)
  final String buyerOrg;

  /// Attorney (Authorised Person) name
  final String attorneyName;
  final String attorneyDesignation;
  final String attorneyAddress;
  final String attorneyPan;

  /// Executor (Director/Partner/Proprietor) name
  final String executorName;
  final String executorDesignation;

  final DateTime date;

  const PowerOfAttorneyInput({
    required this.tenderNo,
    required this.company,
    required this.legalBasis,
    required this.cinRegNo,
    required this.registeredAddress,
    required this.buyerOrg,
    required this.attorneyName,
    required this.attorneyDesignation,
    required this.attorneyAddress,
    required this.attorneyPan,
    required this.executorName,
    required this.executorDesignation,
    required this.date,
  });
}

// ── Letter builder ────────────────────────────────────────────────────────────

List<LetterBlock> buildPowerOfAttorney(PowerOfAttorneyInput i) {
  return [
    // ── Title ───────────────────────────────────────────────────────────────
    LetterBlock.plain(LetterBlockKind.title, 'POWER OF ATTORNEY'),
    LetterBlock(LetterBlockKind.subtitle, [
      const LetterSpan('GeM Bid No.: '),
      LetterSpan(i.tenderNo, bold: true),
      const LetterSpan('   |   Date: '),
      LetterSpan(formatLetterDate(i.date), bold: true),
    ]),

    const LetterBlock.spacer(),

    // ── KNOW ALL PERSONS ──────────────────────────────────────────────────────
    LetterBlock.plain(LetterBlockKind.heading, 'KNOW ALL PERSONS BY THESE PRESENTS THAT:'),

    const LetterBlock.spacer(),

    // ── Principal ─────────────────────────────────────────────────────────────
    LetterBlock(LetterBlockKind.body, [
      const LetterSpan('We, '),
      LetterSpan(i.company, bold: true),
      const LetterSpan(', incorporated/registered under '),
      LetterSpan(i.legalBasis, bold: true),
      const LetterSpan(' bearing '),
      LetterSpan(i.cinRegNo, bold: true),
      const LetterSpan(', having its registered office at '),
      LetterSpan(i.registeredAddress, bold: true),
      const LetterSpan(
        ' (hereinafter "the Principal"), hereby appoint and authorise:',
      ),
    ]),

    const LetterBlock.spacer(),

    // ── Attorney details ──────────────────────────────────────────────────────
    LetterBlock(LetterBlockKind.body, [
      const LetterSpan('Name: ', bold: true),
      LetterSpan(i.attorneyName, bold: true),
      const LetterSpan('   |   '),
      const LetterSpan('Designation: ', bold: true),
      LetterSpan(i.attorneyDesignation, bold: true),
    ]),
    LetterBlock(LetterBlockKind.body, [
      const LetterSpan('Address: ', bold: true),
      LetterSpan(i.attorneyAddress, bold: true),
      const LetterSpan('   |   '),
      const LetterSpan('PAN: ', bold: true),
      LetterSpan(i.attorneyPan, bold: true),
    ]),

    const LetterBlock.spacer(),

    LetterBlock(LetterBlockKind.body, [
      const LetterSpan(
        '(hereinafter "the Attorney") to act on behalf of the Principal for the'
        ' following purposes in relation to GeM Bid No. ',
      ),
      LetterSpan(i.tenderNo, bold: true),
      const LetterSpan(':'),
    ]),

    const LetterBlock.spacer(),

    // ── 5 Purposes ───────────────────────────────────────────────────────────
    LetterBlock.plain(
      LetterBlockKind.body,
      '1.   To sign, submit, and execute all Bid documents, declarations,'
      ' undertakings, and certificates;',
    ),

    LetterBlock.plain(
      LetterBlockKind.body,
      '2.   To accept or negotiate any Supply Order issued pursuant to the above Bid;',
    ),

    LetterBlock(LetterBlockKind.body, [
      const LetterSpan(
        '3.   To sign contracts, agreements, and correspondence with ',
      ),
      LetterSpan(i.buyerOrg, bold: true),
      const LetterSpan(' and the GeM Secretariat;'),
    ]),

    LetterBlock.plain(
      LetterBlockKind.body,
      '4.   To receive and acknowledge notices, orders, and communications; and',
    ),

    LetterBlock.plain(
      LetterBlockKind.body,
      '5.   To do all such acts and things as may be required or incidental to the above.',
    ),

    const LetterBlock.spacer(),

    // ── Binding clause ────────────────────────────────────────────────────────
    LetterBlock.plain(
      LetterBlockKind.body,
      'All acts done by the Attorney in pursuance of this Power of Attorney shall'
      ' be binding on the Principal. This Power of Attorney shall remain valid until'
      ' revoked in writing.',
    ),

    const LetterBlock.spacer(),
    const LetterBlock.spacer(),

    // ── Executed by ───────────────────────────────────────────────────────────
    LetterBlock.plain(LetterBlockKind.heading, 'Executed by:'),
    LetterBlock(LetterBlockKind.signature, [
      LetterSpan(i.executorName, bold: true),
      const LetterSpan('   |   '),
      LetterSpan(i.executorDesignation, bold: true),
      const LetterSpan('   |   '),
      LetterSpan(i.company, bold: true),
    ]),
    LetterBlock.plain(LetterBlockKind.signature, 'Date:                              | Place:'),

    const LetterBlock.spacer(),

    // ── Witnesses ─────────────────────────────────────────────────────────────
    LetterBlock.plain(
      LetterBlockKind.body,
      'Witness 1: Name: ____________  Signature: ____________',
    ),
    LetterBlock.plain(
      LetterBlockKind.body,
      'Witness 2: Name: ____________  Signature: ____________',
    ),

    const LetterBlock.spacer(),

    LetterBlock.plain(
      LetterBlockKind.body,
      '(To be executed on stamp paper of appropriate value and notarized)',
    ),
  ];
}
