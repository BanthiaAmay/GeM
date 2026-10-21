/// Content + rules for the "Self Certification under Preference to MAKE IN
/// INDIA Policy" declaration that GeM / CPPP tenders ask for.
///
/// All wording lives here (not in the widget) so it can be reviewed and
/// tested in one place. The wording mirrors the reference letter produced by
/// tools.bidz365.com/mii-certificate.
library;

import 'letter_model.dart';

/// PPP-MII classification of a bidder by percentage of local content.
/// Class-I  : local content >= 50%
/// Class-II : local content >= 20% and < 50%
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

  /// "Details of location at which local value addition will be made".
  /// Prefilled from the company address, but editable — a company can have
  /// its factory somewhere other than its registered office.
  final String valueAdditionLocation;
  final String signatory;
  final String designation;
  final DateTime date;

  const MiiCertificateInput({
    required this.tenderNo,
    required this.localContentPercent,
    required this.company,
    required this.valueAdditionLocation,
    required this.signatory,
    required this.designation,
    required this.date,
  });
}

const _monthAbbr = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
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
// Validators return an *English key* (or null when valid) so the page can run
// it through `store.t()`. Tender-number format is a soft warning only: GeM
// also has custom-bid / RA / PBP numbers, and a wrong guess here must never
// block a real user.

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

/// Builds the letter as styled blocks. Bold spans = user-supplied values.
List<LetterBlock> buildMiiCertificate(MiiCertificateInput i) {
  final cls = classifyLocalContent(i.localContentPercent);
  assert(
    cls != LocalSupplierClass.notLocal,
    'Caller must block generation below 20% local content',
  );
  final minPct = minimumLocalContentFor(cls);

  return [
    LetterBlock.plain(LetterBlockKind.date, 'Date: ${formatLetterDate(i.date)}'),
    LetterBlock.plain(
      LetterBlockKind.title,
      'Self Certification under Preference to “MAKE IN INDIA” Policy',
    ),
    LetterBlock.plain(
      LetterBlockKind.subtitle,
      '(Refer Clause No. 2.8 & 3.4.4 of ITT)',
    ),
    LetterBlock.plain(LetterBlockKind.heading, 'CERTIFICATE'),
    LetterBlock(LetterBlockKind.body, [
      const LetterSpan(
        'In line with Government Public Procurement Order No. '
        'P-45021/2/2017-BE-II dt. 15.06.2017, as amended from time to time '
        'and as applicable on the date of submission of tender, we hereby '
        'certify that we ',
      ),
      LetterSpan(i.company, bold: true),
      LetterSpan(
        ' are local supplier meeting the requirement of minimum Local '
        'content ($minPct%) as defined in above orders for the material '
        'against tender no ',
      ),
      LetterSpan(i.tenderNo, bold: true),
    ]),
    LetterBlock(LetterBlockKind.body, [
      LetterSpan(
        'Local Content : ${formatPercent(i.localContentPercent)}%',
        bold: true,
      ),
    ]),
    LetterBlock.plain(
      LetterBlockKind.body,
      'Details of location at which local value addition will be made is as '
      'follows:',
    ),
    LetterBlock(LetterBlockKind.body, [
      LetterSpan(i.valueAdditionLocation, bold: true),
    ]),
    // The reference letter says "up two years" (typo). Corrected to
    // "up to two years" — see CLAUDE_CODE_PROMPT.md, "Wording to confirm".
    LetterBlock.plain(
      LetterBlockKind.body,
      'We also understand, false declarations will be in breach of the Code '
      'of Integrity under Rule 175(1)(i)(h) of the General Financial Rule '
      'for which a bidder or its successors can be debarred for up to two '
      'years as per Rule 151 (iii) of the General Financial Rules along with '
      'such other actions as may be permissible under law.',
    ),
    LetterBlock(LetterBlockKind.body, [
      const LetterSpan('Duly authorized to sign the bid for and on behalf of '),
      LetterSpan(i.company, bold: true),
      const LetterSpan('.'),
    ]),
    const LetterBlock.spacer(),
    LetterBlock.plain(LetterBlockKind.signature, i.signatory),
    LetterBlock.plain(LetterBlockKind.signature, i.designation),
  ];
}
