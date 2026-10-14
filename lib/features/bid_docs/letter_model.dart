library;

import 'dart:typed_data';

enum LetterBlockKind {
  date,
  title,
  subtitle,
  heading,
  body,
  spacer,
  signature,
  titleUnderlined,
  productTable,
  productImage,
}

class LetterSpan {
  final String text;
  final bool bold;
  const LetterSpan(this.text, {this.bold = false});
}

class LetterBlock {
  final LetterBlockKind kind;
  final List<LetterSpan> spans;
  final List<String>? tableHeaders;
  final List<List<String>>? tableRows;
  final Uint8List? imageBytes;

  const LetterBlock(this.kind, this.spans)
      : tableHeaders = null,
        tableRows = null,
        imageBytes = null;

  LetterBlock.plain(this.kind, String text)
      : spans = [LetterSpan(text)],
        tableHeaders = null,
        tableRows = null,
        imageBytes = null;

  const LetterBlock.spacer()
      : kind = LetterBlockKind.spacer,
        spans = const [],
        tableHeaders = null,
        tableRows = null,
        imageBytes = null;

  LetterBlock.table({
    required this.tableHeaders,
    required this.tableRows,
  })  : kind = LetterBlockKind.productTable,
        spans = const [],
        imageBytes = null;

  LetterBlock.productImage(this.imageBytes)
      : kind = LetterBlockKind.productImage,
        spans = const [],
        tableHeaders = null,
        tableRows = null;

  String get plainText => spans.map((s) => s.text).join();
  bool get isSpacer => kind == LetterBlockKind.spacer;
  bool get isBoldKind =>
      kind == LetterBlockKind.title ||
      kind == LetterBlockKind.subtitle ||
      kind == LetterBlockKind.titleUnderlined;
}
