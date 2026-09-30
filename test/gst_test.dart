import 'package:flutter_test/flutter_test.dart';
import 'package:gem/gst/invoice.dart';

void main() {
  GstInvoice invoice({
    String id = 'a',
    String number = 'INV-1',
    String direction = 'sale',
    double taxable = 1000,
    double cgst = 90,
    double sgst = 90,
    double igst = 0,
    bool reviewed = false,
  }) => GstInvoice(
    id: id,
    direction: direction,
    fileName: 'invoice.pdf',
    sellerGstin: '27AAPFU0939F1ZV',
    buyerGstin: '',
    invoiceNumber: number,
    invoiceDate: DateTime(2026, 9, 18),
    placeOfSupply: 'Maharashtra',
    taxableValue: taxable,
    rate: 18,
    cgst: cgst,
    sgst: sgst,
    igst: igst,
    reviewed: reviewed,
    extraction: 'pdf_text',
  );
  test('extracts a draft but never auto-approves it', () {
    final x = GstInvoiceParser.draft(
      'Supplier GSTIN 27AAPFU0939F1ZV\nInvoice No: INV-1\nInvoice Date: 18/09/2026\nPlace of Supply: Maharashtra\nTaxable Value: 1,000.00\nGST Rate: 18\nCGST Amount: 90\nSGST Amount: 90',
      id: '1',
      name: 'sample.pdf',
      direction: 'sale',
    );
    expect(x.reviewed, false);
    expect(x.invoiceNumber, 'INV-1');
    expect(x.invoiceDate, DateTime(2026, 9, 18));
    expect(x.taxableValue, 1000);
    expect(x.tax, 180);
    expect(x.extraction, 'pdf_text');
  });
  test('checksum and arithmetic flags are distinct from live status', () {
    expect(gstinChecksumValid('27AAPFU0939F1ZV'), isTrue);
    expect(gstinChecksumValid('27AAPFU0939F1ZA'), isFalse);
    expect(invoiceIssues(invoice(), []), isEmpty);
    expect(
      invoiceIssues(invoice(cgst: 80), []),
      contains('Tax total does not match taxable value × entered rate'),
    );
  });
  test('duplicates, mixed tax components and missing fields are visible', () {
    final first = invoice();
    final second = invoice(id: 'b', igst: 180, cgst: 90, sgst: 90);
    final issues = invoiceIssues(second, [first]);
    expect(issues, contains('Possible duplicate invoice'));
    expect(
      issues,
      contains('IGST and CGST/SGST both present; check supply type'),
    );
  });
  test('summary separates output GST from unverified purchase tax', () {
    final s = GstSummary.forPeriod([
      invoice(),
      invoice(
        id: 'b',
        direction: 'purchase',
        number: 'P-1',
        taxable: 500,
        cgst: 45,
        sgst: 45,
      ),
    ], '2026-09');
    expect(s.sales, 1000);
    expect(s.purchases, 500);
    expect(s.outputTax, 180);
    expect(s.potentialInputTax, 90);
    expect(s.roughDifference, 90);
    expect(s.reviewCount, 2);
  });
  test(
    'comparison CSV reads quoted invoice numbers and rejects missing headers',
    () {
      final rows = parse2bCsv(
        'Supplier GSTIN,Invoice number,Taxable value,CGST,SGST,IGST\n27AAPFU0939F1ZV,"A,42",1000,90,90,0',
      );
      expect(rows.single.invoiceNumber, 'A,42');
      expect(rows.single.tax, 180);
      expect(() => parse2bCsv('Name,Amount\nA,2'), throwsFormatException);
    },
  );
  test('serialization preserves reviewed state and document path', () {
    final value = invoice(reviewed: true).copyWith(documentPath: 'user/a.pdf');
    final restored = GstInvoice.fromJson(value.toJson());
    expect(restored.reviewed, true);
    expect(restored.documentPath, 'user/a.pdf');
    expect(restored.period, '2026-09');
  });
}
