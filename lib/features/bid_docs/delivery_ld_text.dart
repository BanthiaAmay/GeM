/// Acknowledgment of Delivery Obligations and Liquidated Damages — letter model and builder.
///
/// Reference: GeM GTC — Delivery and Liquidated Damages Provisions.
/// Format: Title + Ref | To: | Opening | Delivery table | LD section | Force Majeure | Acceptance | Signature + Seal.
library;

import 'letter_model.dart';
import 'mii_certificate_text.dart' show formatLetterDate;

// ── Row model ─────────────────────────────────────────────────────────────────

class DeliveryRow {
  final String itemDescription;
  final String quantity;
  final String deliveryLocation;
  final String committedDeliveryDate;

  const DeliveryRow({
    required this.itemDescription,
    required this.quantity,
    required this.deliveryLocation,
    required this.committedDeliveryDate,
  });
}

// ── Input model ───────────────────────────────────────────────────────────────

class DeliveryLdInput {
  final String tenderNo;
  final String buyerDesignation;
  final String buyerOrg;
  final String company;
  final List<DeliveryRow> deliveryRows;
  final String signatory;
  final String designation;
  final DateTime date;

  const DeliveryLdInput({
    required this.tenderNo,
    required this.buyerDesignation,
    required this.buyerOrg,
    required this.company,
    required this.deliveryRows,
    required this.signatory,
    required this.designation,
    required this.date,
  });
}

// ── Letter builder ────────────────────────────────────────────────────────────

List<LetterBlock> buildDeliveryLdAcknowledgment(DeliveryLdInput i) {
  final rows = i.deliveryRows.asMap().entries.map((e) {
    final idx = e.key + 1;
    final r = e.value;
    return [
      '$idx',
      r.itemDescription,
      r.quantity,
      r.deliveryLocation,
      r.committedDeliveryDate,
    ];
  }).toList();

  return [
    // ── Title ───────────────────────────────────────────────────────────────
    LetterBlock.plain(
      LetterBlockKind.title,
      'ACKNOWLEDGMENT OF DELIVERY OBLIGATIONS AND LIQUIDATED DAMAGES',
    ),
    LetterBlock(LetterBlockKind.subtitle, [
      const LetterSpan(
        'GeM GTC — Delivery and Liquidated Damages Provisions   |   GeM Bid No.: ',
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
      const LetterSpan('), acknowledge and accept:'),
    ]),

    const LetterBlock.spacer(),

    // ── Section 1: Delivery table ─────────────────────────────────────────────
    LetterBlock.plain(LetterBlockKind.heading, '1. Committed Delivery Schedule'),

    LetterBlock.table(
      tableHeaders: const [
        'S.No',
        'Item Description',
        'Quantity',
        'Delivery Location',
        'Committed Delivery Date',
      ],
      tableRows: rows,
    ),

    const LetterBlock.spacer(),

    // ── Section 2: Liquidated Damages ─────────────────────────────────────────
    LetterBlock.plain(LetterBlockKind.heading, '2. Liquidated Damages'),
    LetterBlock(LetterBlockKind.body, [
      const LetterSpan(
        'In the event of delay beyond the committed date, Liquidated Damages (LD)'
        ' shall be levied at ',
      ),
      const LetterSpan('0.5% of the value of delayed goods per week', bold: true),
      const LetterSpan(' (or part thereof), subject to a maximum of '),
      const LetterSpan('10% of the total Supply Order value', bold: true),
      const LetterSpan(
        ', as per the GeM GTC and ATC. LD will be recovered through deduction'
        ' from pending payments or the PBG.',
      ),
    ]),

    const LetterBlock.spacer(),

    // ── Section 3: Force Majeure ──────────────────────────────────────────────
    LetterBlock.plain(LetterBlockKind.heading, '3. Force Majeure'),
    LetterBlock.plain(
      LetterBlockKind.body,
      'LD shall not apply in the event of a Force Majeure delay, subject to written'
      ' notification to the Buyer Organisation within 7 days of occurrence.',
    ),

    const LetterBlock.spacer(),

    // ── Section 4: Acceptance ─────────────────────────────────────────────────
    LetterBlock.plain(LetterBlockKind.heading, '4. Acceptance'),
    LetterBlock.plain(
      LetterBlockKind.body,
      'We accept the above delivery schedule and LD terms unconditionally and will'
      ' not raise any dispute against LD levied in accordance with the above provisions.',
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
