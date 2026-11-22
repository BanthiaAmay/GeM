/// Declaration of Maximum Retail Price (MRP) — letter model and builder.
///
/// Reference: GeM GTC Clauses 3(A)(xi) and 23.5(iv).
/// Format: Title + Ref | Opening | Product table | 4 numbered clauses | Signature.
library;

import 'letter_model.dart';
import 'mii_certificate_text.dart' show formatLetterDate;

// ── Row model ─────────────────────────────────────────────────────────────────

class MrpProductRow {
  final String productName;
  final String makeBrand;
  final String modelNo;

  /// ₹ amount incl. all taxes, as printed on product/packaging
  final String mrp;

  /// ₹ GeM Bid Price
  final String gemBidPrice;

  /// e.g. "10%"
  final String discountPercent;

  const MrpProductRow({
    required this.productName,
    required this.makeBrand,
    required this.modelNo,
    required this.mrp,
    required this.gemBidPrice,
    required this.discountPercent,
  });
}

// ── Input model ───────────────────────────────────────────────────────────────

class MrpDeclarationInput {
  final String tenderNo;
  final String company;
  final String signatory;
  final String designation;
  final List<MrpProductRow> products;
  final DateTime date;

  const MrpDeclarationInput({
    required this.tenderNo,
    required this.company,
    required this.signatory,
    required this.designation,
    required this.products,
    required this.date,
  });
}

// ── Letter builder ────────────────────────────────────────────────────────────

List<LetterBlock> buildMrpDeclaration(MrpDeclarationInput i) {
  // Build table rows
  final rows = i.products.asMap().entries.map((e) {
    final idx = e.key + 1;
    final p = e.value;
    return [
      '$idx',
      p.productName,
      p.makeBrand,
      p.modelNo,
      p.mrp,
      p.gemBidPrice,
      p.discountPercent,
    ];
  }).toList();

  return [
    // ── Title ───────────────────────────────────────────────────────────────
    LetterBlock.plain(
      LetterBlockKind.title,
      'DECLARATION OF MAXIMUM RETAIL PRICE (MRP)',
    ),
    LetterBlock(LetterBlockKind.subtitle, [
      const LetterSpan('GeM GTC Clauses 3(A)(xi) and 23.5(iv)   |   GeM Bid No.: '),
      LetterSpan(i.tenderNo, bold: true),
      const LetterSpan('   |   Date: '),
      LetterSpan(formatLetterDate(i.date), bold: true),
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
      const LetterSpan('), declare:'),
    ]),

    const LetterBlock.spacer(),

    // ── Product table ─────────────────────────────────────────────────────────
    LetterBlock.table(
      tableHeaders: const [
        'S.No',
        'Product Name',
        'Make/Brand',
        'Model No.',
        'Declared MRP (₹, incl. all taxes)',
        'GeM Bid Price (₹)',
        'Discount %',
      ],
      tableRows: rows,
    ),

    const LetterBlock.spacer(),

    // ── Clause 1 ─────────────────────────────────────────────────────────────
    LetterBlock.plain(
      LetterBlockKind.body,
      '1.   The MRP above is as printed on the product/packaging in compliance with'
      ' the Legal Metrology Act, 2009 and Legal Metrology (Packaged Commodities) Rules, 2011.',
    ),

    const LetterBlock.spacer(),

    // ── Clause 2 ─────────────────────────────────────────────────────────────
    LetterBlock(LetterBlockKind.body, [
      const LetterSpan('2.   Our GeM Bid price reflects a '),
      const LetterSpan('minimum 10% discount', bold: true),
      const LetterSpan(
        ' on the above MRP and is not higher than our price on any other channel,'
        ' per GTC Clause 3(A)(xi).',
      ),
    ]),

    const LetterBlock.spacer(),

    // ── Clause 3 ─────────────────────────────────────────────────────────────
    LetterBlock.plain(
      LetterBlockKind.body,
      '3.   We have not and will not misrepresent MRP or sell above MRP on GeM,'
      ' in compliance with GTC Clause 23.5(iv).',
    ),

    const LetterBlock.spacer(),

    // ── Clause 4 ─────────────────────────────────────────────────────────────
    LetterBlock.plain(
      LetterBlockKind.body,
      '4.   We undertake full responsibility for the accuracy of the above declaration'
      ' and confirm compliance with the applicable provisions of law and GeM portal guidelines.',
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
    LetterBlock.plain(LetterBlockKind.signature, 'Date:                              | Place:'),
  ];
}
