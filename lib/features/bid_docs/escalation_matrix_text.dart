/// Escalation Matrix Certificate — letter model and builder.
///
/// Matches the format:
///   - Date (left-aligned date block)
///   - "To Whom It May Concern," title
///   - "Escalation Matrix for [TenderNo]" sub-title
///   - Introductory sentence
///   - Numbered contact sections (Level 1, Level 2, Level 3 optional)
///   - Closing paragraph
///   - "Sincerely," / signature block
library;

import 'letter_model.dart';

// ── Contact model ─────────────────────────────────────────────────────────────

class EscalationContact {
  final String name;
  final String position;
  final String email;
  final String phone;

  const EscalationContact({
    required this.name,
    required this.position,
    required this.email,
    required this.phone,
  });

  bool get isComplete =>
      name.trim().isNotEmpty &&
      position.trim().isNotEmpty &&
      email.trim().isNotEmpty &&
      phone.trim().isNotEmpty;
}

// ── Input model ───────────────────────────────────────────────────────────────

class EscalationMatrixInput {
  final String tenderNo;
  final EscalationContact primary;
  final EscalationContact? secondary;
  final EscalationContact? tertiary;
  final String signatory;
  final String designation;
  final String company;
  final DateTime date;

  const EscalationMatrixInput({
    required this.tenderNo,
    required this.primary,
    this.secondary,
    this.tertiary,
    required this.signatory,
    required this.designation,
    required this.company,
    required this.date,
  });
}

// ── Validation ────────────────────────────────────────────────────────────────

/// Returns null on success or an error message on failure.
String? validateEmail(String? v) {
  if (v == null || v.trim().isEmpty) return 'Required';
  if (!v.trim().contains('@')) return 'Enter a valid email address';
  return null;
}

String? validatePhone(String? v) {
  if (v == null || v.trim().isEmpty) return 'Required';
  final digits = v.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 7) return 'Enter a valid phone number';
  return null;
}

// ── Date helper ───────────────────────────────────────────────────────────────

const _months = [
  '',
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

String formatDateLong(DateTime d) => '${_months[d.month]} ${d.day}, ${d.year}';

// ── Letter builder ────────────────────────────────────────────────────────────

List<LetterBlock> buildEscalationMatrix(EscalationMatrixInput i) {
  final blocks = <LetterBlock>[];

  // Date
  blocks.add(LetterBlock(LetterBlockKind.date, [LetterSpan(formatDateLong(i.date))]));
  blocks.add(const LetterBlock.spacer());

  // Title / sub-title
  blocks.add(LetterBlock(LetterBlockKind.title, [
    const LetterSpan('To Whom It May Concern,'),
  ]));
  blocks.add(LetterBlock(LetterBlockKind.subtitle, [
    const LetterSpan('Escalation Matrix for '),
    LetterSpan(i.tenderNo, bold: true),
  ]));
  blocks.add(const LetterBlock.spacer());

  // Intro
  blocks.add(LetterBlock(LetterBlockKind.body, [
    const LetterSpan('We, '),
    LetterSpan(i.company, bold: true),
    const LetterSpan(
      ', hereby provide the following escalation matrix for the above-mentioned tender. '
      'Should any issue arise, please contact the designated personnel in the order listed below:',
    ),
  ]));
  blocks.add(const LetterBlock.spacer());

  // Level 1 — Primary (always present)
  blocks.addAll(_contactBlock(1, 'Primary Contact', i.primary));

  // Level 2 — Secondary (optional)
  if (i.secondary != null && i.secondary!.isComplete) {
    blocks.add(const LetterBlock.spacer());
    blocks.addAll(_contactBlock(2, 'Secondary Contact', i.secondary!));
  }

  // Level 3 — Additional (optional)
  if (i.tertiary != null && i.tertiary!.isComplete) {
    blocks.add(const LetterBlock.spacer());
    blocks.addAll(_contactBlock(3, 'Additional Contact', i.tertiary!));
  }

  blocks.add(const LetterBlock.spacer());

  // Closing paragraph
  blocks.add(LetterBlock(LetterBlockKind.body, [
    const LetterSpan(
      'We are committed to providing prompt and efficient service. '
      'Please do not hesitate to contact us if you require any further information or clarification.',
    ),
  ]));
  blocks.add(const LetterBlock.spacer());

  // Sign-off
  blocks.add(LetterBlock.plain(LetterBlockKind.body, 'Sincerely,'));
  blocks.add(const LetterBlock.spacer());

  // Signature block — one line each, matching existing cert style
  blocks.add(LetterBlock(LetterBlockKind.signature, [LetterSpan(i.signatory, bold: true)]));
  blocks.add(LetterBlock.plain(LetterBlockKind.signature, i.designation));
  blocks.add(LetterBlock.plain(LetterBlockKind.signature, i.company));

  return blocks;
}

/// Builds 5 [LetterBlock]s for one numbered contact section.
List<LetterBlock> _contactBlock(int level, String label, EscalationContact c) {
  return [
    LetterBlock(LetterBlockKind.heading, [
      LetterSpan('$level. $label Information:', bold: true),
    ]),
    LetterBlock(LetterBlockKind.body, [
      const LetterSpan('Name: ', bold: true),
      LetterSpan(c.name),
    ]),
    LetterBlock(LetterBlockKind.body, [
      const LetterSpan('Position: ', bold: true),
      LetterSpan(c.position),
    ]),
    LetterBlock(LetterBlockKind.body, [
      const LetterSpan('Email: ', bold: true),
      LetterSpan(c.email),
    ]),
    LetterBlock(LetterBlockKind.body, [
      const LetterSpan('Phone No: ', bold: true),
      LetterSpan(c.phone),
    ]),
  ];
}
