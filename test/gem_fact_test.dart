import 'package:flutter_test/flutter_test.dart';
import 'package:gem/core/models.dart';

void main() {
  const langs = ['en', 'hi', 'mr', 'bn', 'pa', 'gu', 'ta', 'te', 'kn'];

  // Fact Deck UI labels — just check that non-en languages are translated.
  const labels = [
    ('GeM FACT', 'GeM तथ्य'),
    ('OFFICIAL DATA', 'आधिकारिक आँकड़े'),
    ('WHY GeM?', 'GeM क्यों?'),
    ('Swipe', 'स्वाइप करें'),
  ];

  test('Fact Deck UI labels are translated in every language', () {
    for (final (en, hi) in labels) {
      for (final lang in langs) {
        final val = tr(lang, en, hi);
        expect(val.isNotEmpty, isTrue, reason: '$lang label empty for "$en"');
        if (lang != 'en') {
          expect(val, isNot(equals(en)), reason: '$lang untranslated for "$en"');
        }
      }
    }
  });

  // Fact figures — the figure string must be a substring of the full sentence
  // shown in the old GemFact boxes (still used as keys in kTranslations).
  const facts = [
    (
      figure: ('68%', '68%'),
      text: (
        '68% of GeM orders are delivered by small businesses like yours.',
        'GeM के 68% ऑर्डर आप जैसे छोटे व्यवसाय पूरे करते हैं।',
      ),
    ),
    (
      figure: ('₹5.4 lakh crore', '₹5.4 लाख करोड़'),
      text: (
        '₹5.4 lakh crore of government orders went through GeM in 2024-25.',
        '2024-25 में GeM पर ₹5.4 लाख करोड़ के सरकारी ऑर्डर दिए गए।',
      ),
    ),
    (
      figure: ('10 days', '10 दिनों'),
      text: (
        'GeM rules say buyers must pay you within 10 days of accepting delivery.',
        'GeM नियमों के अनुसार, डिलीवरी स्वीकार करने के 10 दिनों के भीतर खरीदार को भुगतान करना होता है।',
      ),
    ),
  ];

  test('each fact figure appears inside its sentence in every language', () {
    for (final f in facts) {
      for (final lang in langs) {
        final figure = tr(lang, f.figure.$1, f.figure.$2);
        final text = tr(lang, f.text.$1, f.text.$2);
        if (lang != 'en') {
          expect(text, isNot(equals(f.text.$1)), reason: '$lang untranslated');
        }
        expect(
          text.contains(figure),
          isTrue,
          reason: '$lang: "$figure" in "$text"',
        );
      }
    }
  });

  // Fact Deck sources — just check they are non-empty and translated.
  const sources = [
    ('Source: PIB, Aug 2025', 'स्रोत: PIB, अगस्त 2025'),
    ('Source: PIB, Apr 2026', 'स्रोत: PIB, अप्रैल 2026'),
    ('Source: DD News, Jan 2025', 'स्रोत: DD News, जनवरी 2025'),
    ('Source: Ministry of MSME', 'स्रोत: MSME मंत्रालय'),
    ('Source: GeM Terms & Conditions', 'स्रोत: GeM नियम और शर्तें'),
  ];

  test('Fact Deck sources are translated in every language', () {
    for (final (en, hi) in sources) {
      for (final lang in langs) {
        final val = tr(lang, en, hi);
        expect(val.isNotEmpty, isTrue, reason: '$lang source empty for "$en"');
        if (lang != 'en') {
          expect(val, isNot(equals(en)), reason: '$lang untranslated for "$en"');
        }
      }
    }
  });
}
