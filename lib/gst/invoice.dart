import 'dart:math' as math;

/// Draft, user-reviewed invoice data. Monetary figures are INR rounded to 2 decimals.
class GstInvoice {
  final String id;
  final String direction; // sale or purchase
  final String fileName;
  final String sellerGstin;
  final String buyerGstin;
  final String invoiceNumber;
  final DateTime? invoiceDate;
  final String placeOfSupply;
  final double taxableValue, rate, cgst, sgst, igst;
  final bool reviewed;
  final String extraction;
  final String? documentPath;

  const GstInvoice({
    required this.id,
    required this.direction,
    required this.fileName,
    required this.sellerGstin,
    required this.buyerGstin,
    required this.invoiceNumber,
    required this.invoiceDate,
    required this.placeOfSupply,
    required this.taxableValue,
    required this.rate,
    required this.cgst,
    required this.sgst,
    required this.igst,
    required this.reviewed,
    required this.extraction,
    this.documentPath,
  });
  double get tax => cgst + sgst + igst;
  double get total => taxableValue + tax;
  String get period => invoiceDate == null
      ? 'unknown'
      : '${invoiceDate!.year}-${invoiceDate!.month.toString().padLeft(2, '0')}';
  String get fingerprint =>
      '${direction.toLowerCase()}|${sellerGstin.toUpperCase()}|${invoiceNumber.trim().toUpperCase()}|$period';
  Map<String, dynamic> toJson() => {
    'id': id,
    'direction': direction,
    'fileName': fileName,
    'sellerGstin': sellerGstin,
    'buyerGstin': buyerGstin,
    'invoiceNumber': invoiceNumber,
    'invoiceDate': invoiceDate?.toIso8601String(),
    'placeOfSupply': placeOfSupply,
    'taxableValue': taxableValue,
    'rate': rate,
    'cgst': cgst,
    'sgst': sgst,
    'igst': igst,
    'reviewed': reviewed,
    'extraction': extraction,
    'documentPath': documentPath,
  };
  factory GstInvoice.fromJson(Map<String, dynamic> j) => GstInvoice(
    id: '${j['id']}',
    direction: '${j['direction']}',
    fileName: '${j['fileName'] ?? ''}',
    sellerGstin: '${j['sellerGstin'] ?? ''}',
    buyerGstin: '${j['buyerGstin'] ?? ''}',
    invoiceNumber: '${j['invoiceNumber'] ?? ''}',
    invoiceDate: DateTime.tryParse('${j['invoiceDate'] ?? ''}'),
    placeOfSupply: '${j['placeOfSupply'] ?? ''}',
    taxableValue: (j['taxableValue'] as num?)?.toDouble() ?? 0,
    rate: (j['rate'] as num?)?.toDouble() ?? 0,
    cgst: (j['cgst'] as num?)?.toDouble() ?? 0,
    sgst: (j['sgst'] as num?)?.toDouble() ?? 0,
    igst: (j['igst'] as num?)?.toDouble() ?? 0,
    reviewed: j['reviewed'] == true,
    extraction: '${j['extraction'] ?? 'manual'}',
    documentPath: j['documentPath'] as String?,
  );
  GstInvoice copyWith({
    String? sellerGstin,
    String? buyerGstin,
    String? invoiceNumber,
    DateTime? invoiceDate,
    String? placeOfSupply,
    double? taxableValue,
    double? rate,
    double? cgst,
    double? sgst,
    double? igst,
    bool? reviewed,
    String? documentPath,
  }) => GstInvoice(
    id: id,
    direction: direction,
    fileName: fileName,
    sellerGstin: sellerGstin ?? this.sellerGstin,
    buyerGstin: buyerGstin ?? this.buyerGstin,
    invoiceNumber: invoiceNumber ?? this.invoiceNumber,
    invoiceDate: invoiceDate ?? this.invoiceDate,
    placeOfSupply: placeOfSupply ?? this.placeOfSupply,
    taxableValue: taxableValue ?? this.taxableValue,
    rate: rate ?? this.rate,
    cgst: cgst ?? this.cgst,
    sgst: sgst ?? this.sgst,
    igst: igst ?? this.igst,
    reviewed: reviewed ?? this.reviewed,
    extraction: extraction,
    documentPath: documentPath ?? this.documentPath,
  );
}

class GstInvoiceParser {
  static final gstin = RegExp(r'\b\d{2}[A-Z]{5}\d{4}[A-Z][A-Z0-9]Z[A-Z0-9]\b');
  static GstInvoice draft(
    String text, {
    required String id,
    required String name,
    required String direction,
  }) {
    final upper = text.toUpperCase();
    final gstins = gstin.allMatches(upper).map((m) => m.group(0)!).toList();
    final number = _capture(
      text,
      RegExp(
        r'(?:invoice\s*(?:no\.?|number|#)|bill\s*(?:no\.?|number))\s*[:#-]?\s*([A-Z0-9\-/]+)',
        caseSensitive: false,
      ),
    );
    final dateText = _capture(
      text,
      RegExp(
        r'(?:invoice\s*date|dated?|bill\s*date)\s*[:#-]?\s*(\d{1,2}[/-]\d{1,2}[/-]\d{2,4}|\d{4}-\d{2}-\d{2})',
        caseSensitive: false,
      ),
    );
    return GstInvoice(
      id: id,
      direction: direction,
      fileName: name,
      sellerGstin: gstins.isEmpty ? '' : gstins.first,
      buyerGstin: gstins.length < 2 ? '' : gstins[1],
      invoiceNumber: number,
      invoiceDate: parseDate(dateText),
      placeOfSupply: _capture(
        text,
        RegExp(
          r'place\s*of\s*supply\s*[:#-]?\s*([^\n\r]+)',
          caseSensitive: false,
        ),
      ).trim(),
      taxableValue: _amount(text, [
        'taxable value',
        'taxable amount',
        'assessable value',
      ]),
      rate: _amount(text, ['gst rate', 'tax rate', 'rate of tax']),
      cgst: _amount(text, ['cgst amount', 'cgst']),
      sgst: _amount(text, ['sgst amount', 'sgst']),
      igst: _amount(text, ['igst amount', 'igst']),
      reviewed: false,
      extraction: text.trim().isEmpty ? 'scanned_or_empty' : 'pdf_text',
    );
  }

  static String _capture(String text, RegExp pattern) =>
      pattern.firstMatch(text)?.group(1)?.trim() ?? '';
  static double _amount(String text, List<String> labels) {
    for (final label in labels) {
      final v = _capture(
        text,
        RegExp(
          '${RegExp.escape(label)}\\s*[:\\-]?\\s*(?:₹|Rs\\.?\\s*)?([\\d,]+(?:\\.\\d{1,2})?)',
          caseSensitive: false,
        ),
      );
      if (v.isNotEmpty) return double.tryParse(v.replaceAll(',', '')) ?? 0;
    }
    return 0;
  }

  static DateTime? parseDate(String s) {
    if (s.isEmpty) return null;
    final iso = DateTime.tryParse(s);
    if (iso != null) return iso;
    final bits = s.split(RegExp(r'[/-]'));
    if (bits.length != 3) return null;
    var day = int.tryParse(bits[0]),
        month = int.tryParse(bits[1]),
        year = int.tryParse(bits[2]);
    if (day == null || month == null || year == null) return null;
    if (year < 100) year += 2000;
    if (year < 2000 || month < 1 || month > 12 || day < 1 || day > 31) {
      return null;
    }
    final d = DateTime(year, month, day);
    return d.day == day && d.month == month ? d : null;
  }
}

/// ISO 7064 MOD 36, 36 checksum; syntax alone is not GST portal status verification.
bool gstinChecksumValid(String value) {
  final s = value.trim().toUpperCase();
  if (!GstInvoiceParser.gstin.hasMatch(s) || s.length != 15) return false;
  const alphabet = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  var factor = 2, sum = 0;
  for (var i = s.length - 2; i >= 0; i--) {
    final code = alphabet.indexOf(s[i]);
    if (code < 0) return false;
    final add = factor * code;
    sum += (add ~/ 36) + (add % 36);
    factor = factor == 2 ? 1 : 2;
  }
  return alphabet[(36 - sum % 36) % 36] == s[14];
}

List<String> invoiceIssues(GstInvoice i, Iterable<GstInvoice> others) {
  final issues = <String>[];
  if (i.invoiceNumber.trim().isEmpty) issues.add('Missing invoice number');
  if (i.invoiceDate == null) issues.add('Missing or invalid invoice date');
  if (i.sellerGstin.isEmpty) {
    issues.add('Missing supplier GSTIN');
  } else if (!gstinChecksumValid(i.sellerGstin)) {
    issues.add('Supplier GSTIN format/checksum needs review');
  }
  if (i.buyerGstin.isNotEmpty && !gstinChecksumValid(i.buyerGstin)) {
    issues.add('Buyer GSTIN format/checksum needs review');
  }
  if (!i.taxableValue.isFinite || i.taxableValue <= 0) {
    issues.add('Taxable value must be greater than zero');
  }
  if (!i.rate.isFinite || i.rate < 0 || i.rate > 100) {
    issues.add('GST rate is invalid');
  }
  for (final n in [i.cgst, i.sgst, i.igst]) {
    if (!n.isFinite || n < 0) {
      issues.add('Tax amount is invalid');
      break;
    }
  }
  if (i.rate > 0 &&
      i.taxableValue > 0 &&
      (i.tax - i.taxableValue * i.rate / 100).abs() >
          math.max(2, i.taxableValue * .001)) {
    issues.add('Tax total does not match taxable value × entered rate');
  }
  if (i.igst > 0 && (i.cgst > 0 || i.sgst > 0)) {
    issues.add('IGST and CGST/SGST both present; check supply type');
  }
  if (i.invoiceNumber.isNotEmpty &&
      i.sellerGstin.isNotEmpty &&
      others.any((o) => o.id != i.id && o.fingerprint == i.fingerprint)) {
    issues.add('Possible duplicate invoice');
  }
  if (i.placeOfSupply.isEmpty) issues.add('Place of supply needs review');
  return issues;
}

class GstSummary {
  final double sales, purchases, outputTax, potentialInputTax;
  final int reviewCount, invoiceCount;
  const GstSummary(
    this.sales,
    this.purchases,
    this.outputTax,
    this.potentialInputTax,
    this.reviewCount,
    this.invoiceCount,
  );
  double get roughDifference => math.max(0, outputTax - potentialInputTax);
  factory GstSummary.forPeriod(Iterable<GstInvoice> all, String period) {
    final rows = all.where((i) => i.period == period).toList();
    return GstSummary(
      rows
          .where((i) => i.direction == 'sale')
          .fold(0, (double n, i) => n + i.taxableValue),
      rows
          .where((i) => i.direction == 'purchase')
          .fold(0, (double n, i) => n + i.taxableValue),
      rows
          .where((i) => i.direction == 'sale')
          .fold(0, (double n, i) => n + i.tax),
      rows
          .where((i) => i.direction == 'purchase')
          .fold(0, (double n, i) => n + i.tax),
      rows
          .where((i) => !i.reviewed || invoiceIssues(i, rows).isNotEmpty)
          .length,
      rows.length,
    );
  }
}

class Gst2bEntry {
  final String supplierGstin, invoiceNumber;
  final double taxableValue, tax;
  const Gst2bEntry(
    this.supplierGstin,
    this.invoiceNumber,
    this.taxableValue,
    this.tax,
  );
  Map<String, dynamic> toJson() => {
    'supplierGstin': supplierGstin,
    'invoiceNumber': invoiceNumber,
    'taxableValue': taxableValue,
    'tax': tax,
  };
  factory Gst2bEntry.fromJson(Map<String, dynamic> j) => Gst2bEntry(
    '${j['supplierGstin'] ?? ''}',
    '${j['invoiceNumber'] ?? ''}',
    (j['taxableValue'] as num?)?.toDouble() ?? 0,
    (j['tax'] as num?)?.toDouble() ?? 0,
  );
  String get key =>
      '${supplierGstin.trim().toUpperCase()}|${invoiceNumber.trim().toUpperCase()}';
}

List<Gst2bEntry> parse2bCsv(String source) {
  final lines = source
      .replaceAll('\r\n', '\n')
      .split('\n')
      .where((l) => l.trim().isNotEmpty)
      .toList();
  if (lines.isEmpty) return [];
  final head = _csvLine(
    lines.first,
  ).map((s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')).toList();
  int col(List<String> options) {
    for (final o in options) {
      final i = head.indexOf(o);
      if (i >= 0) return i;
    }
    return -1;
  }

  final g = col(['suppliergstin', 'gstinofsupplier', 'gstin']),
      n = col(['invoicenumber', 'invoiceno']),
      v = col(['taxablevalue']),
      cg = col(['cgst']),
      sg = col(['sgst']),
      ig = col(['igst']);
  if (g < 0 || n < 0 || v < 0) {
    throw const FormatException(
      'CSV needs Supplier GSTIN, Invoice number and Taxable value columns',
    );
  }
  final result = <Gst2bEntry>[];
  for (final line in lines.skip(1)) {
    final cells = _csvLine(line);
    String at(int i) => i < 0 || i >= cells.length ? '' : cells[i].trim();
    double amount(int i) => double.tryParse(at(i).replaceAll(',', '')) ?? 0;
    if (at(g).isEmpty || at(n).isEmpty) continue;
    result.add(
      Gst2bEntry(at(g), at(n), amount(v), amount(cg) + amount(sg) + amount(ig)),
    );
  }
  return result;
}

List<String> _csvLine(String line) {
  final out = <String>[];
  final b = StringBuffer();
  var quoted = false;
  for (var i = 0; i < line.length; i++) {
    final c = line[i];
    if (c == '"') {
      if (quoted && i + 1 < line.length && line[i + 1] == '"') {
        b.write('"');
        i++;
      } else {
        quoted = !quoted;
      }
    } else if (c == ',' && !quoted) {
      out.add(b.toString());
      b.clear();
    } else {
      b.write(c);
    }
  }
  out.add(b.toString());
  return out;
}
