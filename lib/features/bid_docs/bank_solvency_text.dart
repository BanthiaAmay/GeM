/// Bank Solvency Certificate — letter models and builders.
///
/// Mode 1: Request Letter — formal application to the branch manager.
/// Mode 2: Reference Format — structured template for the bank to complete
///         and issue on official letterhead.
///
/// Pure Dart — no Flutter imports.
library;

import 'letter_model.dart';
import 'mii_certificate_text.dart' show formatLetterDate;

// ── Indian amount → words ─────────────────────────────────────────────────────

const _ones = [
  '',
  'One',
  'Two',
  'Three',
  'Four',
  'Five',
  'Six',
  'Seven',
  'Eight',
  'Nine',
  'Ten',
  'Eleven',
  'Twelve',
  'Thirteen',
  'Fourteen',
  'Fifteen',
  'Sixteen',
  'Seventeen',
  'Eighteen',
  'Nineteen',
];
const _tens = [
  '',
  '',
  'Twenty',
  'Thirty',
  'Forty',
  'Fifty',
  'Sixty',
  'Seventy',
  'Eighty',
  'Ninety',
];

String _twoDigits(int n) {
  if (n <= 0) return '';
  if (n < 20) return _ones[n];
  final t = _tens[n ~/ 10];
  final o = n % 10 > 0 ? ' ${_ones[n % 10]}' : '';
  return '$t$o';
}

String _threeDigits(int n) {
  if (n <= 0) return '';
  if (n < 100) return _twoDigits(n);
  final h = '${_ones[n ~/ 100]} Hundred';
  final rem = n % 100;
  return rem > 0 ? '$h ${_twoDigits(rem)}' : h;
}

/// Converts a positive integer to Indian-style words (up to 99,99,99,999).
/// Returns empty string for zero or negative.
String amountToWords(int n) {
  if (n <= 0) return '';
  final parts = <String>[];
  if (n >= 10000000) {
    parts.add('${_twoDigits(n ~/ 10000000)} Crore');
    n %= 10000000;
  }
  if (n >= 100000) {
    parts.add('${_twoDigits(n ~/ 100000)} Lakh');
    n %= 100000;
  }
  if (n >= 1000) {
    parts.add('${_twoDigits(n ~/ 1000)} Thousand');
    n %= 1000;
  }
  if (n > 0) parts.add(_threeDigits(n));
  return parts.join(' ');
}

String _fmt(int n) =>
    n.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d\d)+\d$)'),
      (m) => '${m[1]},',
    );

// ── Input model ───────────────────────────────────────────────────────────────

class BankSolvencyInput {
  final String company;
  final String constitutionType;
  final String companyAddress;
  final String panNumber;
  final String accountHolderName;
  final String bankName;
  final String branchName;
  final String ifscCode;
  final String accountNumber; // optional
  final int solventAmount;
  final String bidReferenceNo; // optional
  final String signatory;
  final String designation;
  final DateTime date;

  const BankSolvencyInput({
    required this.company,
    required this.constitutionType,
    required this.companyAddress,
    required this.panNumber,
    required this.accountHolderName,
    required this.bankName,
    required this.branchName,
    required this.ifscCode,
    required this.accountNumber,
    required this.solventAmount,
    required this.bidReferenceNo,
    required this.signatory,
    required this.designation,
    required this.date,
  });

  String get amountWords => amountToWords(solventAmount);
  String get amountFmt => '₹${_fmt(solventAmount)}';
}

// ── Mode 1: Request Letter ────────────────────────────────────────────────────

List<LetterBlock> buildBankSolvencyRequestLetter(BankSolvencyInput i) {
  final purpose =
      i.bidReferenceNo.isNotEmpty
          ? 'GeM / Government Tender Participation (Bid Reference No. ${i.bidReferenceNo})'
          : 'GeM / Government Tender Participation';

  return [
    LetterBlock.plain(
      LetterBlockKind.date,
      'Date: ${formatLetterDate(i.date)}',
    ),
    const LetterBlock.spacer(),

    // Recipient — Branch Manager
    LetterBlock.plain(LetterBlockKind.body, 'To'),
    LetterBlock(
      LetterBlockKind.body,
      [const LetterSpan('The Branch Manager', bold: true)],
    ),
    LetterBlock(
      LetterBlockKind.body,
      [LetterSpan(i.bankName, bold: true)],
    ),
    LetterBlock.plain(LetterBlockKind.body, i.branchName),
    const LetterBlock.spacer(),

    // Subject
    LetterBlock(LetterBlockKind.body, [
      const LetterSpan('Subject: ', bold: true),
      const LetterSpan(
        'Request for Issuance of Bank Solvency Certificate for '
        'GeM / Government Tender Participation',
      ),
    ]),
    const LetterBlock.spacer(),

    // Salutation
    LetterBlock.plain(LetterBlockKind.body, 'Dear Sir/Ma\'am,'),
    const LetterBlock.spacer(),

    // Para 1 — applicant details
    LetterBlock(LetterBlockKind.body, [
      const LetterSpan('I/We, '),
      LetterSpan(i.company, bold: true),
      LetterSpan(
        ', a ${i.constitutionType} having PAN ${i.panNumber}, '
        'registered at ${i.companyAddress}, '
        'hereby request you to kindly issue a Bank Solvency Certificate in '
        'favour of our organisation for the following purpose:',
      ),
    ]),
    const LetterBlock.spacer(),

    // Purpose
    LetterBlock(LetterBlockKind.body, [
      const LetterSpan('Purpose: ', bold: true),
      LetterSpan(purpose),
    ]),
    const LetterBlock.spacer(),

    // Account details block
    LetterBlock(
      LetterBlockKind.body,
      [const LetterSpan('Details of our bank account:', bold: true)],
    ),
    LetterBlock(LetterBlockKind.body, [
      const LetterSpan('Name of Account Holder: '),
      LetterSpan(i.accountHolderName, bold: true),
    ]),
    LetterBlock(LetterBlockKind.body, [
      const LetterSpan('Bank Name: '),
      LetterSpan(i.bankName, bold: true),
    ]),
    LetterBlock(LetterBlockKind.body, [
      const LetterSpan('Branch: '),
      LetterSpan(i.branchName, bold: true),
    ]),
    LetterBlock(LetterBlockKind.body, [
      const LetterSpan('IFSC Code: '),
      LetterSpan(i.ifscCode, bold: true),
    ]),
    if (i.accountNumber.isNotEmpty)
      LetterBlock(LetterBlockKind.body, [
        const LetterSpan('Account Number: '),
        LetterSpan(i.accountNumber, bold: true),
      ]),
    const LetterBlock.spacer(),

    // Requested amount
    LetterBlock(LetterBlockKind.body, [
      const LetterSpan('Requested Solvency Amount: '),
      LetterSpan(
        '${i.amountFmt} (Rupees ${i.amountWords} Only)',
        bold: true,
      ),
    ]),
    const LetterBlock.spacer(),

    // Para 3 — certificate requirements
    LetterBlock.plain(
      LetterBlockKind.body,
      'We understand that the Bank Solvency Certificate is required to be '
      'issued on the official letterhead of your bank, duly signed and '
      'stamped by the authorised bank official.',
    ),
    const LetterBlock.spacer(),

    // Para 4 — closing request
    LetterBlock.plain(
      LetterBlockKind.body,
      'We shall be grateful if you could arrange to issue the said '
      'certificate at the earliest. Please let us know if any supporting '
      'documents or bank charges are required.',
    ),
    const LetterBlock.spacer(),

    // Sign-off
    LetterBlock.plain(LetterBlockKind.body, 'Thanking you,'),
    const LetterBlock.spacer(),
    LetterBlock.plain(LetterBlockKind.body, 'Yours faithfully,'),
    const LetterBlock.spacer(),
    const LetterBlock.spacer(),
    const LetterBlock.spacer(),

    // Signature block
    LetterBlock.plain(LetterBlockKind.signature, i.signatory),
    LetterBlock.plain(LetterBlockKind.body, i.designation),
    LetterBlock.plain(LetterBlockKind.body, i.company),
  ];
}

// ── Mode 2: Reference Format ──────────────────────────────────────────────────

List<LetterBlock> buildBankSolvencyReferenceFormat(BankSolvencyInput i) {
  final purpose =
      i.bidReferenceNo.isNotEmpty
          ? 'GeM / Government Tender Participation in relation to '
              'Bid Reference No. ${i.bidReferenceNo}'
          : 'GeM / Government Tender Participation';

  return [
    // Disclaimer header — always first and prominent
    LetterBlock(LetterBlockKind.title, [
      const LetterSpan(
        'REFERENCE FORMAT – TO BE COMPLETED, VERIFIED AND ISSUED BY THE BANK. '
        'NOT A VALID BANK CERTIFICATE.',
      ),
    ]),
    const LetterBlock.spacer(),

    // Certificate title
    LetterBlock(
      LetterBlockKind.titleUnderlined,
      [const LetterSpan('BANK SOLVENCY CERTIFICATE')],
    ),
    const LetterBlock.spacer(),

    // Bank details
    LetterBlock(
      LetterBlockKind.body,
      [LetterSpan(i.bankName, bold: true)],
    ),
    LetterBlock.plain(LetterBlockKind.body, i.branchName),
    const LetterBlock.spacer(),

    // Certificate metadata
    LetterBlock(LetterBlockKind.body, [
      const LetterSpan('Certificate No.: '),
      const LetterSpan('___________________________'),
    ]),
    LetterBlock(LetterBlockKind.body, [
      const LetterSpan('Date: '),
      const LetterSpan('___________________________'),
    ]),
    const LetterBlock.spacer(),

    // Addressee
    LetterBlock(
      LetterBlockKind.body,
      [const LetterSpan('TO WHOMSOEVER IT MAY CONCERN', bold: true)],
    ),
    const LetterBlock.spacer(),

    // Paragraph 1 — certification
    LetterBlock(LetterBlockKind.body, [
      const LetterSpan('This is to certify that '),
      LetterSpan(i.company, bold: true),
      LetterSpan(
        ', a ${i.constitutionType} having PAN ${i.panNumber}, '
        'registered at ${i.companyAddress}, '
        'is a customer of this bank and maintains account(s) with our branch.',
      ),
    ]),
    const LetterBlock.spacer(),

    // Paragraph 2 — solvency declaration
    LetterBlock(LetterBlockKind.body, [
      const LetterSpan(
        'Based on the records available with our branch, we certify that '
        'the financial standing of the above-mentioned customer is '
        'satisfactory and they are solvent for a sum of ',
      ),
      LetterSpan(
        '${i.amountFmt} (Rupees ${i.amountWords} Only)',
        bold: true,
      ),
      const LetterSpan(' as on the date of this certificate.'),
    ]),
    const LetterBlock.spacer(),

    // Purpose
    LetterBlock(LetterBlockKind.body, [
      const LetterSpan(
        'This certificate is issued solely for the purpose of ',
      ),
      LetterSpan(purpose, bold: true),
      const LetterSpan('.'),
    ]),
    const LetterBlock.spacer(),

    // Validity
    LetterBlock.plain(
      LetterBlockKind.body,
      'This certificate is valid for a period of ___ days from the date of '
      'issuance, unless specified otherwise.',
    ),
    const LetterBlock.spacer(),
    const LetterBlock.spacer(),

    // Bank official signature block
    LetterBlock(
      LetterBlockKind.body,
      [const LetterSpan('For', bold: true)],
    ),
    LetterBlock(
      LetterBlockKind.body,
      [LetterSpan(i.bankName, bold: true)],
    ),
    LetterBlock.plain(LetterBlockKind.body, i.branchName),
    const LetterBlock.spacer(),
    const LetterBlock.spacer(),
    const LetterBlock.spacer(),

    LetterBlock.plain(
      LetterBlockKind.body,
      'Authorised Signatory\'s Signature: ___________________________',
    ),
    LetterBlock.plain(
      LetterBlockKind.body,
      'Name: ___________________________',
    ),
    LetterBlock.plain(
      LetterBlockKind.body,
      'Designation: ___________________________',
    ),
    LetterBlock.plain(
      LetterBlockKind.body,
      'Bank Stamp / Seal: ___________________________',
    ),
    const LetterBlock.spacer(),

    // Footer note
    LetterBlock(LetterBlockKind.body, [
      const LetterSpan('NOTE: ', bold: true),
      LetterSpan(
        'This certificate must be issued on the official letterhead of '
        '${i.bankName}, ${i.branchName}, duly signed and stamped by an '
        'authorised bank official. This reference format is provided by '
        'Bid2Scale as a guide only and does not constitute a valid bank '
        'certificate.',
      ),
    ]),
  ];
}
