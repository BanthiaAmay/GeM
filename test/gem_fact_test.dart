import 'package:flutter_test/flutter_test.dart';
import 'package:gem/core/models.dart';

void main() {
  const langs = ['en', 'hi', 'mr', 'bn', 'pa', 'gu', 'ta', 'te', 'kn'];
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
}
