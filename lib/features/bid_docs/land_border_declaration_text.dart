/// Declaration — Compliance with Land Border Restriction — letter model and builder.
///
/// Reference: GFR Rule 144(xi) | GeM GTC Clause 26 | DOE Order (PP No. 4) dated 23.02.2023.
/// Format: Title + Ref | Opening | 5 numbered clauses | Signature.
library;

import 'letter_model.dart';
import 'mii_certificate_text.dart' show formatLetterDate;

// ── Input model ───────────────────────────────────────────────────────────────

class LandBorderDeclarationInput {
  final String tenderNo;
  final String company;
  final String signatory;
  final String designation;
  final DateTime date;

  const LandBorderDeclarationInput({
    required this.tenderNo,
    required this.company,
    required this.signatory,
    required this.designation,
    required this.date,
  });
}

// ── Letter builder ────────────────────────────────────────────────────────────

List<LetterBlock> buildLandBorderDeclaration(LandBorderDeclarationInput i) {
  return [
    // ── Title ───────────────────────────────────────────────────────────────
    LetterBlock.plain(
      LetterBlockKind.title,
      'DECLARATION — COMPLIANCE WITH LAND BORDER RESTRICTION',
    ),
    LetterBlock(LetterBlockKind.subtitle, [
      const LetterSpan(
        'GFR Rule 144(xi)   |   GeM GTC Clause 26   |   DOE Order (PP No. 4) dated 23.02.2023',
      ),
    ]),
    LetterBlock(LetterBlockKind.subtitle, [
      const LetterSpan('GeM Bid No.: '),
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

    // ── Clause 1 ─────────────────────────────────────────────────────────────
    LetterBlock(LetterBlockKind.body, [
      const LetterSpan('1.   '),
      LetterSpan(i.company, bold: true),
      const LetterSpan(
        ' is incorporated and established under the laws of India and is not from'
        ' a country sharing a land border with India.',
      ),
    ]),

    const LetterBlock.spacer(),

    // ── Clause 2 ─────────────────────────────────────────────────────────────
    LetterBlock(LetterBlockKind.body, [
      const LetterSpan('2.   No natural person holding '),
      const LetterSpan('more than 25%', bold: true),
      const LetterSpan(' (for a company/LLP) of '),
      LetterSpan(i.company, bold: true),
      const LetterSpan(
        "'s shares, capital, or profits is a citizen of a country sharing a land"
        ' border with India, nor does any such person control its management, policy, or Board.',
      ),
    ]),

    const LetterBlock.spacer(),

    // ── Clause 3 ─────────────────────────────────────────────────────────────
    LetterBlock(LetterBlockKind.body, [
      const LetterSpan('3.   '),
      LetterSpan(i.company, bold: true),
      const LetterSpan(
        ' has no subsidiary, associate, or controlled entity registered in a country'
        ' sharing a land border with India.',
      ),
    ]),

    const LetterBlock.spacer(),

    // ── Clause 4 ─────────────────────────────────────────────────────────────
    LetterBlock(LetterBlockKind.body, [
      const LetterSpan('4.   '),
      LetterSpan(i.company, bold: true),
      const LetterSpan(
        ' has no Specified Transfer of Technology (ToT) arrangement with any entity'
        ' from such a country, as defined under GTC Clause 26.IX.',
      ),
    ]),

    const LetterBlock.spacer(),

    // ── Clause 5 ─────────────────────────────────────────────────────────────
    LetterBlock.plain(
      LetterBlockKind.body,
      '5.   We hereby certify that the information provided in this declaration is'
      ' true and accurate to the best of our knowledge.',
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
