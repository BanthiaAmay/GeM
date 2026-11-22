/// Escalation Matrix — letter model and builder.
///
/// Reference: GeM Bid documents format.
/// Format: Title + Ref | Table (Tier/Contact/Email) | Footer | Signature.
library;

import 'letter_model.dart';
import 'mii_certificate_text.dart' show formatLetterDate;

// ── Contact model ─────────────────────────────────────────────────────────────

class EscalationContact {
  final String name;
  final String designation;
  final String email;

  const EscalationContact({
    required this.name,
    required this.designation,
    required this.email,
  });

  bool get isComplete =>
      name.trim().isNotEmpty &&
      designation.trim().isNotEmpty &&
      email.trim().isNotEmpty;
}

// ── Input model ───────────────────────────────────────────────────────────────

class EscalationMatrixInput {
  final String tenderNo;
  final String company;
  final EscalationContact primary;
  final EscalationContact? secondary;
  final EscalationContact? tertiary;
  final String signatory;
  final String designation;
  final DateTime date;

  const EscalationMatrixInput({
    required this.tenderNo,
    required this.company,
    required this.primary,
    this.secondary,
    this.tertiary,
    required this.signatory,
    required this.designation,
    required this.date,
  });
}

// ── Validation ────────────────────────────────────────────────────────────────

String? validateEmail(String? v) {
  if (v == null || v.trim().isEmpty) return 'Required';
  if (!v.trim().contains('@')) return 'Enter a valid email address';
  return null;
}

// ── Letter builder ────────────────────────────────────────────────────────────

List<LetterBlock> buildEscalationMatrix(EscalationMatrixInput i) {
  final tierLabels = ['1 — Operational', '2 — Management', '3 — Senior/Legal'];
  final contacts = [
    i.primary,
    if (i.secondary != null && i.secondary!.isComplete) i.secondary!,
    if (i.tertiary != null && i.tertiary!.isComplete) i.tertiary!,
  ];

  final tableRows = <List<String>>[];
  for (int idx = 0; idx < contacts.length; idx++) {
    final c = contacts[idx];
    tableRows.add([
      tierLabels[idx],
      '${c.name}\n${c.designation}',
      c.email,
    ]);
  }

  return [
    // ── Title ───────────────────────────────────────────────────────────────
    LetterBlock(LetterBlockKind.title, [
      const LetterSpan('ESCALATION MATRIX — '),
      LetterSpan(i.company, bold: true),
    ]),
    LetterBlock(LetterBlockKind.subtitle, [
      const LetterSpan('GeM Bid No.: '),
      LetterSpan(i.tenderNo, bold: true),
      const LetterSpan('   |   Date: '),
      LetterSpan(formatLetterDate(i.date), bold: true),
    ]),

    const LetterBlock.spacer(),

    // ── Table ────────────────────────────────────────────────────────────────
    LetterBlock.table(
      tableHeaders: const ['Tier', 'Contact', 'Email'],
      tableRows: tableRows,
    ),

    const LetterBlock.spacer(),

    // ── Footer ───────────────────────────────────────────────────────────────
    LetterBlock.plain(
      LetterBlockKind.body,
      'Unresolved matters may be escalated via GeM Grievance Portal (gem.gov.in)'
      ' or GeM Helpdesk: 1800-419-3436 / helpdesk-gem@gov.in.',
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

String? validatePhone(String? v) {
  if (v == null || v.trim().isEmpty) return 'Required';
  final digits = v.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 7 || digits.length > 15) return 'Enter a valid phone number';
  return null;
}
