/// Certificate of Compliance with Technical Specifications — letter model and builder.
///
/// Reference: GeM GTC Clause 3(A) — Bidder Obligations.
/// Format: Title + Ref | To: | Opening | Full Compliance para | Spec-wise table | Signature + Seal.
library;

import 'letter_model.dart';
import 'mii_certificate_text.dart' show formatLetterDate;

// ── Row model ─────────────────────────────────────────────────────────────────

class SpecRow {
  final String specParameter;
  final String requiredValue;
  final String offeredValue;

  /// "Yes" or "No"
  final String compliant;

  const SpecRow({
    required this.specParameter,
    required this.requiredValue,
    required this.offeredValue,
    required this.compliant,
  });
}

// ── Input model ───────────────────────────────────────────────────────────────

class TechSpecsInput {
  final String tenderNo;
  final String buyerDesignation;
  final String buyerOrg;
  final String company;
  final List<SpecRow> specRows;
  final String signatory;
  final String designation;
  final DateTime date;

  const TechSpecsInput({
    required this.tenderNo,
    required this.buyerDesignation,
    required this.buyerOrg,
    required this.company,
    required this.specRows,
    required this.signatory,
    required this.designation,
    required this.date,
  });
}

// ── Letter builder ────────────────────────────────────────────────────────────

List<LetterBlock> buildTechSpecsCertificate(TechSpecsInput i) {
  final rows = i.specRows.asMap().entries.map((e) {
    final idx = e.key + 1;
    final s = e.value;
    return [
      '$idx',
      s.specParameter,
      s.requiredValue,
      s.offeredValue,
      s.compliant,
    ];
  }).toList();

  return [
    // ── Title ───────────────────────────────────────────────────────────────
    LetterBlock.plain(
      LetterBlockKind.title,
      'CERTIFICATE OF COMPLIANCE WITH TECHNICAL SPECIFICATIONS',
    ),
    LetterBlock(LetterBlockKind.subtitle, [
      const LetterSpan(
        'GeM GTC Clause 3(A) — Bidder Obligations   |   GeM Bid No.: ',
      ),
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

    // ── Opening ──────────────────────────────────────────────────────────────
    LetterBlock(LetterBlockKind.body, [
      const LetterSpan('We, '),
      LetterSpan(i.company, bold: true),
      const LetterSpan(', represented by '),
      LetterSpan(i.signatory, bold: true),
      const LetterSpan(' ('),
      LetterSpan(i.designation, bold: true),
      const LetterSpan('), certify:'),
    ]),

    const LetterBlock.spacer(),

    // ── Section 1: Full Compliance Declaration ────────────────────────────────
    LetterBlock.plain(LetterBlockKind.heading, '1. Full Compliance Declaration'),
    LetterBlock.plain(
      LetterBlockKind.body,
      'The product/service offered under this Bid fully complies with all technical'
      ' specifications, quality standards, and performance parameters stipulated in the'
      ' ATC, GeM catalogue listing, and applicable BIS/mandatory standards.',
    ),

    const LetterBlock.spacer(),

    // ── Section 2: Spec-wise Compliance ──────────────────────────────────────
    LetterBlock.plain(LetterBlockKind.heading, '2. Specification-wise Compliance'),

    LetterBlock.table(
      tableHeaders: const [
        'S.No',
        'Specification Parameter',
        'Required Value / Standard',
        'Offered Value / Standard',
        'Compliant (Yes/No)',
      ],
      tableRows: rows,
    ),

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
