/// Content + rules for the "Self-Certification of Local Content" declaration
/// (Make in India) for GeM bids.
///
/// Reference: DPIIT Order No. P-45021/2/2017-PP (BE-II)-Part (4) Vol. II
/// dated 19th July, 2024 | GeM GTC Clause 3(A)(xix).
///
/// All wording lives here (not in the widget) so it can be reviewed and
/// tested in one place.
library;

import 'letter_model.dart';

/// PPP-MII classification of a bidder by percentage of local content.
/// Class I  : local content >= 50%
/// Class II : local content >= 20% and < 50%
/// Not local: below 20% — the certificate must NOT be generated.
enum LocalSupplierClass { classI, classII, notLocal }

LocalSupplierClass classifyLocalContent(num percent) {
  if (percent >= 50) return LocalSupplierClass.classI;
  if (percent >= 20) return LocalSupplierClass.classII;
  return LocalSupplierClass.notLocal;
}

/// The minimum-local-content figure quoted in the letter's first paragraph.
int minimumLocalContentFor(LocalSupplierClass c) =>
    c == LocalSupplierClass.classI ? 50 : 20;

/// Everything the letter needs. Immutable; the page builds one on "Generate".
class MiiCertificateInput {
  final String tenderNo;
  final double localContentPercent;
  final String company;

  /// Place of business / manufacturing premises where local value addition
  /// is carried out. Prefilled from the company-address profile key.
  final String placeOfBusiness;
  final String signatory;
  final String designation;
  final DateTime date;

  const MiiCertificateInput({
    required this.tenderNo,
    required this.localContentPercent,
    required this.company,
    required this.placeOfBusiness,
    required this.signatory,
    required this.designation,
    required this.date,
  });
}

const _monthAbbr = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// "Oct 04 2026" — same format as the reference letter.
String formatLetterDate(DateTime d) =>
    '${_monthAbbr[d.month - 1]} ${d.day.toString().padLeft(2, '0')} ${d.year}';

/// 100 -> "100", 62.5 -> "62.5", 62.504 -> "62.5" (max two decimals).
String formatPercent(double v) {
  final s = v.toStringAsFixed(2);
  return s.replaceFirst(RegExp(r'\.?0+$'), '');
}

// ---------------------------------------------------------------- validation

final RegExp _tenderNoPattern = RegExp(
  r'^GEM/\d{4}/[A-Z]/\d{5,10}$',
  caseSensitive: false,
);

/// True when [v] looks like a standard GeM bid number.
bool looksLikeGemTenderNo(String v) => _tenderNoPattern.hasMatch(v.trim());

String? validateLocalContent(String? raw) {
  final v = double.tryParse((raw ?? '').trim());
  if (v == null || !v.isFinite) return 'Enter a number between 0 and 100';
  if (v < 0 || v > 100) return 'Enter a number between 0 and 100';
  if (classifyLocalContent(v) == LocalSupplierClass.notLocal) {
    return 'Below 20% you do not qualify as a local supplier';
  }
  return null;
}

// ----------------------------------------------------------------- the letter

/// Builds the letter as styled blocks matching the DPIIT 2024 format.
/// Bold spans = user-supplied values.
List<LetterBlock> buildMiiCertificate(MiiCertificateInput i) {
  final cls = classifyLocalContent(i.localContentPercent);
  assert(
    cls != LocalSupplierClass.notLocal,
    'Caller must block generation below 20% local content',
  );
  final classLabel = cls == LocalSupplierClass.classI ? 'Class I' : 'Class II';

  return [
    // ── Header ──────────────────────────────────────────────────────────────
    LetterBlock.plain(
      LetterBlockKind.title,
      'SELF-CERTIFICATION OF LOCAL CONTENT',
    ),
    LetterBlock.plain(
      LetterBlockKind.subtitle,
      'DPIIT Order No. P-45021/2/2017-PP (BE-II)-Part (4) Vol. II'
      ' dated 19th July, 2024 | GeM GTC Clause 3(A)(xix)',
    ),

    // ── Bid reference line ───────────────────────────────────────────────────
    LetterBlock(LetterBlockKind.body, [
      const LetterSpan('GeM Bid No.: '),
      LetterSpan(i.tenderNo, bold: true),
      const LetterSpan('   |   Date: '),
      LetterSpan(formatLetterDate(i.date), bold: true),
    ]),

    const LetterBlock.spacer(),

    // ── Opening declaration ──────────────────────────────────────────────────
    LetterBlock(LetterBlockKind.body, [
      const LetterSpan('We, '),
      LetterSpan(i.company, bold: true),
      const LetterSpan(', represented by '),
      LetterSpan(i.signatory, bold: true),
      const LetterSpan(' ('),
      LetterSpan(i.designation, bold: true),
      const LetterSpan('), hereby declare:'),
    ]),

    const LetterBlock.spacer(),

    // ── Clause 1 ─────────────────────────────────────────────────────────────
    LetterBlock(LetterBlockKind.body, [
      const LetterSpan('1.   We are a '),
      LetterSpan(classLabel, bold: true),
      const LetterSpan(' Local Supplier with Local Content (LC) of '),
      LetterSpan('${formatPercent(i.localContentPercent)}%', bold: true),
      const LetterSpan(
        ', calculated as: {(Value of item − Value of imported content)'
        ' ÷ Value of item} × 100, at our manufacturing premises in ',
      ),
      LetterSpan(i.placeOfBusiness, bold: true),
      const LetterSpan('.'),
    ]),

    const LetterBlock.spacer(),

    // ── Clause 2 ─────────────────────────────────────────────────────────────
    LetterBlock.plain(
      LetterBlockKind.body,
      '2.   All supporting records are maintained and available within'
      ' 5 working days of a request. For Supply Orders exceeding'
      ' ₹10 crore, we will furnish a CA/Statutory Auditor certificate'
      ' confirming the LC percentage.',
    ),

    const LetterBlock.spacer(),

    // ── Clause 3 ─────────────────────────────────────────────────────────────
    LetterBlock.plain(
      LetterBlockKind.body,
      '3.   We understand that a false declaration constitutes a breach of'
      ' the Code of Integrity under GFR Rule 175(1)(i)(h) and may result'
      ' in debarment under Rule 151(iii).',
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
