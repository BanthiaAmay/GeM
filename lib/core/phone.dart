/// GeM seller onboarding currently supports Indian mobile numbers.
/// Normalization is validation of format, not verification of ownership.
String? normalizeWhatsapp(String input) {
  if (RegExp(r'[^\d\s()+-]').hasMatch(input)) return null;
  var digits = input.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 12 && digits.startsWith('91')) {
    digits = digits.substring(2);
  }
  if (!RegExp(r'^[6-9]\d{9}$').hasMatch(digits)) return null;
  return '+91$digits';
}
