/// OEM Authorization Certificate — letter model and builder.
///
/// Reference: GeM GTC Clause 28 — CMS 3.0.
/// Format: Title + Ref | To: | Authorization statement | Product + CMS Quadrant | Validity note | Signature.
library;

import 'letter_model.dart';
import 'mii_certificate_text.dart' show formatLetterDate;

// ── Input model ───────────────────────────────────────────────────────────────

class OemAuthorizationInput {
  final String tenderNo;
  final String buyerDesignation;
  final String buyerOrg;

  /// OEM / Brand Owner company name
  final String oemCompany;

  /// OEM signatory
  final String signatory;
  final String designation;

  /// Authorized dealer / reseller name
  final String resellerName;

  /// Complete address of authorized dealer
  final String resellerAddress;

  /// Product name as listed on GeM Portal
  final String productName;

  /// "Q3" or "Q4"
  final String cmsQuadrant;

  final DateTime date;

  const OemAuthorizationInput({
    required this.tenderNo,
    required this.buyerDesignation,
    required this.buyerOrg,
    required this.oemCompany,
    required this.signatory,
    required this.designation,
    required this.resellerName,
    required this.resellerAddress,
    required this.productName,
    required this.cmsQuadrant,
    required this.date,
  });
}

// ── Letter builder ────────────────────────────────────────────────────────────

List<LetterBlock> buildOemAuthorizationCertificate(OemAuthorizationInput i) {
  return [
    // ── Title ───────────────────────────────────────────────────────────────
    LetterBlock.plain(LetterBlockKind.title, 'OEM AUTHORIZATION CERTIFICATE'),
    LetterBlock(LetterBlockKind.subtitle, [
      const LetterSpan('GeM GTC Clause 28 — CMS 3.0   |   GeM Bid No.: '),
      LetterSpan(i.tenderNo, bold: true),
      const LetterSpan('   |   Date: '),
      LetterSpan(formatLetterDate(i.date), bold: true),
    ]),

    const LetterBlock.spacer(),

    // ── To ───────────────────────────────────────────────────────────────────
    LetterBlock(LetterBlockKind.body, [
      const LetterSpan('To: The '),
      LetterSpan(i.buyerDesignation, bold: true),
      const LetterSpan(', '),
      LetterSpan(i.buyerOrg, bold: true),
    ]),

    const LetterBlock.spacer(),

    // ── Authorization statement ───────────────────────────────────────────────
    LetterBlock(LetterBlockKind.body, [
      const LetterSpan('We, '),
      LetterSpan(i.oemCompany, bold: true),
      const LetterSpan(', represented by '),
      LetterSpan(i.signatory, bold: true),
      const LetterSpan(' ('),
      LetterSpan(i.designation, bold: true),
      const LetterSpan('), hereby authorize '),
      const LetterSpan('M/s ', bold: true),
      LetterSpan(i.resellerName, bold: true),
      const LetterSpan(', '),
      LetterSpan(i.resellerAddress, bold: true),
      const LetterSpan(
        ', to quote, bid, accept Supply Orders, supply, invoice, and collect payment'
        ' for the product listed below, in relation to GeM Bid No. ',
      ),
      LetterSpan(i.tenderNo, bold: true),
      const LetterSpan('.'),
    ]),

    const LetterBlock.spacer(),

    // ── Product + CMS ─────────────────────────────────────────────────────────
    LetterBlock(LetterBlockKind.body, [
      const LetterSpan('Product: ', bold: true),
      LetterSpan(i.productName, bold: true),
      const LetterSpan('   |   CMS Quadrant: ', bold: true),
      LetterSpan(i.cmsQuadrant, bold: true),
    ]),

    const LetterBlock.spacer(),

    // ── Validity note ─────────────────────────────────────────────────────────
    LetterBlock.plain(
      LetterBlockKind.body,
      'This authorization is sole and exclusive for this Bid, remains valid for the'
      ' full duration of any resulting Supply Order, and supersedes any conflicting'
      ' authorization for the same Bid.',
    ),

    const LetterBlock.spacer(),
    const LetterBlock.spacer(),

    // ── Signature block ───────────────────────────────────────────────────────
    LetterBlock(LetterBlockKind.signature, [
      LetterSpan(i.signatory, bold: true),
      const LetterSpan('   |   '),
      LetterSpan(i.designation, bold: true),
      const LetterSpan('   |   '),
      LetterSpan(i.oemCompany, bold: true),
    ]),
    LetterBlock.plain(LetterBlockKind.signature, 'Date:                              | Place:'),
  ];
}
