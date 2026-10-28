/// Turns a list of [LetterBlock]s into an A4 PDF. Generic: reused by every
/// generated bid document. Everything runs on-device — nothing is uploaded.
library;

import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'letter_model.dart';

/// Latin Noto Sans (OFL) — add both files under assets/fonts/ and list them
/// in pubspec.yaml. Needed so curly quotes and non-ASCII company names render.
/// If the assets are missing we fall back to built-in Helvetica and swap the
/// few characters Helvetica cannot draw.
const kLetterFontRegular = 'assets/fonts/NotoSans-Regular.ttf';
const kLetterFontBold = 'assets/fonts/NotoSans-Bold.ttf';

/// Preview + PDF share these so what the user sees is what prints.
const double kLetterBodySize = 11.5;
const double kLetterTitleSize = 15;
const double kLetterSubtitleSize = 11.5;
const double kLetterHeadingSize = 15;
const double kLetterSignatureGap = 56;
const double kLetterSideMarginPt = 56;
const double kLetterBottomMarginPt = 56;
const double kLetterBaseTopMarginPt = 56;

/// Range of the "Top Margin" slider: extra space added above the base margin,
/// so users can print onto company letterhead.
const double kLetterMaxExtraTopMarginPt = 160;

Future<Uint8List> buildLetterPdf(
  List<LetterBlock> blocks, {
  double extraTopMarginPt = 0,
}) async {
  pw.Font? regular;
  pw.Font? bold;
  try {
    regular = pw.Font.ttf(await rootBundle.load(kLetterFontRegular));
    bold = pw.Font.ttf(await rootBundle.load(kLetterFontBold));
  } catch (_) {
    // Fallback below.
  }
  final usingFallback = regular == null || bold == null;
  String safe(String s) => usingFallback
      ? s
            .replaceAll('“', '"')
            .replaceAll('”', '"')
            .replaceAll('‘', "'")
            .replaceAll('’', "'")
      : s;

  final doc = pw.Document(
    theme: usingFallback
        ? pw.ThemeData.withFont(
            base: pw.Font.helvetica(),
            bold: pw.Font.helveticaBold(),
          )
        : pw.ThemeData.withFont(base: regular, bold: bold),
  );

  pw.Widget render(LetterBlock b) {
    if (b.isSpacer) return pw.SizedBox(height: kLetterSignatureGap);

    if (b.kind == LetterBlockKind.productTable) {
      final headers = b.tableHeaders!;
      final rows = b.tableRows!;
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 10),
        child: pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400),
          columnWidths: {
            for (int i = 0; i < headers.length; i++)
              i: const pw.FlexColumnWidth(),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                for (final h in headers)
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(
                      safe(h),
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: kLetterBodySize,
                      ),
                    ),
                  ),
              ],
            ),
            for (final row in rows)
              pw.TableRow(
                children: [
                  for (final cell in row)
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(
                        safe(cell),
                        style: pw.TextStyle(fontSize: kLetterBodySize),
                      ),
                    ),
                ],
              ),
          ],
        ),
      );
    }

    if (b.kind == LetterBlockKind.productImage) {
      final bytes = b.imageBytes;
      if (bytes == null) return pw.SizedBox();
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 10),
        child: pw.ConstrainedBox(
          constraints: const pw.BoxConstraints(maxHeight: 150),
          child: pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.contain),
        ),
      );
    }

    final centered =
        b.kind == LetterBlockKind.title ||
        b.kind == LetterBlockKind.titleUnderlined ||
        b.kind == LetterBlockKind.subtitle ||
        b.kind == LetterBlockKind.heading;
    final size = switch (b.kind) {
      LetterBlockKind.title => kLetterTitleSize,
      LetterBlockKind.titleUnderlined => kLetterTitleSize,
      LetterBlockKind.subtitle => kLetterSubtitleSize,
      LetterBlockKind.heading => kLetterHeadingSize,
      _ => kLetterBodySize,
    };

    final spans = b.spans
        .map(
          (s) => pw.TextSpan(
            text: safe(s.text),
            style: pw.TextStyle(
              fontSize: size,
              fontWeight: (s.bold || b.isBoldKind)
                  ? pw.FontWeight.bold
                  : pw.FontWeight.normal,
              decoration:
                  (b.kind == LetterBlockKind.heading ||
                      b.kind == LetterBlockKind.titleUnderlined)
                  ? pw.TextDecoration.underline
                  : null,
              lineSpacing: 3,
            ),
          ),
        )
        .toList();

    return pw.Padding(
      padding: pw.EdgeInsets.only(
        bottom: b.kind == LetterBlockKind.signature ? 2 : 10,
        top:
            (b.kind == LetterBlockKind.title ||
                b.kind == LetterBlockKind.titleUnderlined)
            ? 14
            : 0,
      ),
      child: pw.RichText(
        textAlign: centered ? pw.TextAlign.center : pw.TextAlign.left,
        text: pw.TextSpan(children: spans),
      ),
    );
  }

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.fromLTRB(
        kLetterSideMarginPt,
        kLetterBaseTopMarginPt + extraTopMarginPt,
        kLetterSideMarginPt,
        kLetterBottomMarginPt,
      ),
      build: (_) => blocks.map(render).toList(),
    ),
  );
  return doc.save();
}
