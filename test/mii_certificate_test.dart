import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:gem/features/bid_docs/mii_certificate_text.dart';

MiiCertificateInput _input({double pct = 100}) => MiiCertificateInput(
  tenderNo: 'GEM/2026/B/7845020',
  localContentPercent: pct,
  company: 'Z',
  valueAdditionLocation: 'India',
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
      expect(text, contains('Date: Oct 04 2026'));
      expect(
        text,
        contains('Self Certification under Preference to “MAKE IN INDIA” Policy'),
      );
      expect(text, contains('(Refer Clause No. 2.8 & 3.4.4 of ITT)'));
      expect(text, contains('CERTIFICATE'));
      expect(text, contains('P-45021/2/2017-BE-II dt. 15.06.2017'));
      expect(text, contains('we hereby certify that we Z are local supplier'));
      expect(text, contains('minimum Local content (50%)'));
      expect(text, contains('against tender no GEM/2026/B/7845020'));
      expect(text, contains('Local Content : 100%'));
      expect(text, contains('Rule 175(1)(i)(h)'));
      expect(text, contains('Rule 151 (iii)'));
      expect(text, contains('Duly authorized to sign the bid for and on behalf of Z.'));
      expect(blocks.where((b) => b.isSpacer).length, 1);
      expect(blocks.last.plainText, 'Owner');
    });

    test('Class-II quotes 20% minimum', () {
      final text = buildMiiCertificate(_input(pct: 35))
          .map((b) => b.plainText)
          .join('\n');
      expect(text, contains('minimum Local content (20%)'));
      expect(text, contains('Local Content : 35%'));
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
        containsAll(['Z', 'GEM/2026/B/7845020', 'Local Content : 100%', 'India']),
      );
    });

    test('building below 20% is a programming error', () {
      expect(() => buildMiiCertificate(_input(pct: 10)), throwsA(isA<AssertionError>()));
    });
  });
}
