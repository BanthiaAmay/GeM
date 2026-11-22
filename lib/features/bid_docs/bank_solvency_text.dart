/// Bank Solvency Certificate — Covering Letter — letter model and builder.
///
/// A covering letter from the company to their bank requesting a Solvency Certificate.
/// Format: Title | Date | To (Branch Manager) | Subject | Body | Signature + Seal.
library;

import 'letter_model.dart';
import 'mii_certificate_text.dart' show formatLetterDate;

// ── Input model ───────────────────────────────────────────────────────────────

class BankSolvencyInput {
  final String tenderNo;
  final String bankName;
  final String bankAddress;
  final String company;
  final String accountNo;
  final String buyerOrg;

  /// e.g. "2019"
  final String accountHolderSince;

  /// e.g. "₹50,00,000"
  final String contractAmount;

  /// "3" or "6"
  final String validityMonths;

  final String signatory;
  final String designation;
  final DateTime date;

  const BankSolvencyInput({
    required this.tenderNo,
    required this.bankName,
    required this.bankAddress,
    required this.company,
    required this.accountNo,
    required this.buyerOrg,
    required this.accountHolderSince,
    required this.contractAmount,
    required this.validityMonths,
    required this.signatory,
    required this.designation,
    required this.date,
  });
}

// ── Letter builder ────────────────────────────────────────────────────────────

List<LetterBlock> buildBankSolvencyCoverLetter(BankSolvencyInput i) {
  return [
    // ── Title ───────────────────────────────────────────────────────────────
    LetterBlock.plain(
      LetterBlockKind.title,
      'REQUEST FOR BANK SOLVENCY CERTIFICATE',
    ),
    LetterBlock(LetterBlockKind.subtitle, [
      const LetterSpan('Date: '),
      LetterSpan(formatLetterDate(i.date), bold: true),
    ]),

    const LetterBlock.spacer(),

    // ── To ───────────────────────────────────────────────────────────────────
    LetterBlock(LetterBlockKind.body, [
      const LetterSpan('To: The Branch Manager, '),
      LetterSpan(i.bankName, bold: true),
      const LetterSpan(', '),
      LetterSpan(i.bankAddress, bold: true),
    ]),

    const LetterBlock.spacer(),

    // ── Subject ───────────────────────────────────────────────────────────────
    LetterBlock(LetterBlockKind.body, [
      const LetterSpan('Subject: ', bold: true),
      const LetterSpan('Solvency Certificate for GeM Bid No. '),
      LetterSpan(i.tenderNo, bold: true),
    ]),

    const LetterBlock.spacer(),

    LetterBlock.plain(LetterBlockKind.body, 'Dear Sir/Ma\'am,'),

    const LetterBlock.spacer(),

    // ── Body ─────────────────────────────────────────────────────────────────
    LetterBlock(LetterBlockKind.body, [
      LetterSpan(i.company, bold: true),
      const LetterSpan(' (Account No. '),
      LetterSpan(i.accountNo, bold: true),
      const LetterSpan(') is participating in GeM Bid No. '),
      LetterSpan(i.tenderNo, bold: true),
      const LetterSpan(' issued by '),
      LetterSpan(i.buyerOrg, bold: true),
      const LetterSpan(', which requires a Bank Solvency Certificate.'),
    ]),

    const LetterBlock.spacer(),

    LetterBlock.plain(
      LetterBlockKind.body,
      'Please issue a certificate on your letterhead, duly signed and stamped by an'
      ' authorised official, confirming:',
    ),

    const LetterBlock.spacer(),

    // ── Items (a), (b), (c) ───────────────────────────────────────────────────
    LetterBlock(LetterBlockKind.body, [
      const LetterSpan(' (a) '),
      LetterSpan(i.company, bold: true),
      const LetterSpan(' is a bonafide account holder of your bank since '),
      LetterSpan(i.accountHolderSince, bold: true),
      const LetterSpan(';'),
    ]),

    LetterBlock(LetterBlockKind.body, [
      const LetterSpan(
        ' (b) Our financial position/credit facilities are adequate to execute contracts up to ₹',
      ),
      LetterSpan(i.contractAmount, bold: true),
      const LetterSpan('; and'),
    ]),

    LetterBlock(LetterBlockKind.body, [
      const LetterSpan(' (c) '),
      LetterSpan(i.company, bold: true),
      const LetterSpan(' is not in default of any financial obligation to your bank.'),
    ]),

    const LetterBlock.spacer(),

    // ── Validity note ─────────────────────────────────────────────────────────
    LetterBlock(LetterBlockKind.body, [
      const LetterSpan('The certificate should be valid for a minimum of '),
      LetterSpan(i.validityMonths, bold: true),
      const LetterSpan(
        ' months from the date of issue. We consent to verification of this'
        ' certificate by the Buyer Organisation or GeM Secretariat if required.',
      ),
    ]),

    const LetterBlock.spacer(),
    const LetterBlock.spacer(),

    // ── Signature block ───────────────────────────────────────────────────────
    LetterBlock(LetterBlockKind.signature, [
      LetterSpan(i.signatory, bold: true),
      const LetterSpan('   |   '),
      LetterSpan(i.designation, bold: true),
      const LetterSpan('   |   '),
      LetterSpan(i.company, bold: true),
    ]),
    LetterBlock.plain(
      LetterBlockKind.signature,
      'Date:                    | Place:                    | Seal:',
    ),
  ];
}
