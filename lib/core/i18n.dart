// Key-based translation lookup. The English string IS the catalogue key.
// A missing translation for the active language silently falls back to
// English rather than showing a blank or breaking the layout.
import 'i18n_data.dart';

/// code -> native display name, used by the language picker.
const kLanguages = <String, String>{
  'en': 'English',
  'hi': 'हिन्दी',
  'mr': 'मराठी',
  'bn': 'বাংলা',
  'ta': 'தமிழ்',
  'te': 'తెలుగు',
  'kn': 'ಕನ್ನಡ',
  'ml': 'മലയാളം',
  'gu': 'ગુજરાતી',
  'pa': 'ਪੰਜਾਬੀ',
};

/// Script -> font family, used to pick the right Noto font per language.
/// Devanagari (hi, mr) is bundled today; the rest fall back to the
/// platform's system font until their Noto fonts are added to pubspec.yaml.
const kLanguageFontFamily = <String, String>{
  'hi': 'NotoSansDevanagari',
  'mr': 'NotoSansDevanagari',
  'bn': 'NotoSansBengali',
  'ta': 'NotoSansTamil',
  'te': 'NotoSansTelugu',
  'kn': 'NotoSansKannada',
  'ml': 'NotoSansMalayalam',
  'gu': 'NotoSansGujarati',
  'pa': 'NotoSansGurmukhi',
};

String i18n(String lang, String en) {
  if (lang == 'en') return en;
  return kTranslations[lang]?[en] ?? en;
}
