import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:gem/features/bid_docs/mii_certificate_text.dart';

MiiCertificateInput _input({double pct = 100}) => MiiCertificateInput(
  tenderNo: 'GEM/2026/B/7845020',
  localContentPercent: pct,
  company: 'Z',
  placeOfBusiness: 'India',
  signatory: 'Z',
  designation: 'Owner',
  date: DateTime(2026, 10, 4),
);

void main() {
  setUpAll(() => initializeDateFormatting('en'));

  group('classification', () {
    test('thresholds', () {
      expect(classifyLocalContent(100), LocalSupplierClass.classI);
      expect(classifyLocalContent(50), LocalSupplierClass.classI);
      expect(classifyLocalContent(49.99), LocalSupplierClass.classII);
      expect(classifyLocalContent(20), LocalSupplierClass.classII);
      expect(classifyLocalContent(19.99), LocalSupplierClass.notLocal);
      expect(classifyLocalContent(0), LocalSupplierClass.notLocal);
    });
    test('minimum quoted in letter', () {
      expect(minimumLocalContentFor(LocalSupplierClass.classI), 50);
      expect(minimumLocalContentFor(LocalSupplierClass.classII), 20);
    });
  });

  group('validation', () {
    test('local content', () {
      expect(validateLocalContent('100'), isNull);
      expect(validateLocalContent('20'), isNull);
      expect(validateLocalContent('62.5'), isNull);
      expect(validateLocalContent(''), isNotNull);
      expect(validateLocalContent('abc'), isNotNull);
      expect(validateLocalContent('101'), isNotNull);
      expect(validateLocalContent('-1'), isNotNull);
      expect(validateLocalContent('19'), isNotNull);
    });
    test('tender number soft check', () {
      expect(looksLikeGemTenderNo('GEM/2026/B/7845020'), isTrue);
      expect(looksLikeGemTenderNo(' gem/2024/b/1234567 '), isTrue);
      expect(looksLikeGemTenderNo('12345'), isFalse);
    });
  });

  group('formatting', () {
    test('percent', () {
      expect(formatPercent(100), '100');
      expect(formatPercent(62.5), '62.5');
      expect(formatPercent(62.504), '62.5');
      expect(formatPercent(20), '20');
    });
    test('date matches reference letter', () {
      expect(formatLetterDate(DateTime(2026, 10, 4)), 'Oct 04 2026');
    });
  });

  group('letter', () {
    test('matches the reference letter (Class-I, 100%)', () {
      final blocks = buildMiiCertificate(_input());
      final text = blocks.map((b) => b.plainText).join('\n');
      expect(text, contains('SELF-CERTIFICATION OF LOCAL CONTENT'));
      expect(text, contains('P-45021/2/2017-PP (BE-II)-Part (4) Vol. II'));
      expect(text, contains('hereby declare:'));
      expect(text, contains('Class I'));
      expect(text, contains('Local Content (LC) of 100%'));
      expect(text, contains('GFR Rule 175(1)(i)(h)'));
      expect(text, contains('Rule 151(iii)'));
      expect(blocks.where((b) => b.isSpacer).length, 6);
      expect(blocks.last.plainText, 'Date:                              | Place:');
    });

    test('Class-II uses Class II label and correct percentage', () {
      final text = buildMiiCertificate(
        _input(pct: 35),
      ).map((b) => b.plainText).join('\n');
      expect(text, contains('Class II'));
      expect(text, contains('35%'));
    });

    test('user values are bold, boilerplate is not', () {
      final blocks = buildMiiCertificate(_input());
      final bold = [
        for (final b in blocks)
          for (final s in b.spans)
            if (s.bold) s.text,
      ];
      expect(
        bold,
        containsAll([
          'Z',
          'GEM/2026/B/7845020',
          '100%',
          'India',
        ]),
      );
    });

    test('building below 20% is a programming error', () {
      expect(
        () => buildMiiCertificate(_input(pct: 10)),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
