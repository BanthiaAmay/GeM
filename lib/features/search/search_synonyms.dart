/// Synonym, jargon and Hinglish expansion maps for the search engine.
///
/// Each entry maps one or more query tokens to canonical tokens that the
/// index uses. Add entries here — the engine picks them up automatically.
library;

/// Maps a normalised query token → list of canonical tokens to match against.
/// All strings here are lowercase ASCII (normalised the same way the engine
/// normalises queries and index terms).
const Map<String, List<String>> kSynonyms = {
  // ── Tender / bid jargon ─────────────────────────────────────────────────
  'tender': ['bid', 'tender'],
  'tendor': ['bid', 'tender'], // common typo
  'tenders': ['bid', 'tender'],
  'bids': ['bid', 'tender'],
  'gem': ['bid', 'gem'],
  'govt': ['government'],
  'govt.': ['government'],

  // ── Finance / banking jargon ────────────────────────────────────────────
  'bg': ['security', 'deposit', 'bid', 'guarantee'],
  'bank guarantee': ['security', 'deposit', 'finance', 'guarantee'],
  'emd': ['earnest money deposit', 'deposit'],
  'earnest money': ['earnest money deposit', 'deposit'],
  'od': ['overdraft', 'finance'],
  'overdraft': ['overdraft', 'finance'],
  'working capital': ['finance', 'working capital'],
  'loan for order': ['invoice financing', 'finance', 'working capital'],
  'money before payment': ['invoice financing', 'finance'],
  'invoice financing': ['invoice financing', 'finance'],
  'invoice finance': ['invoice financing', 'finance'],

  // ── Registration / compliance ────────────────────────────────────────────
  'udyam': ['msme', 'registration', 'udyam'],
  'msme': ['msme', 'registration'],
  'gst': ['gst', 'registration'],
  'gst bharna': ['gst', 'registration'],
  'gst filing': ['gst', 'registration'],
  'pan': ['pan', 'identity'],

  // ── Product / HSN categories (Hinglish) ─────────────────────────────────
  'bijli ka saman': ['electrical', 'led', 'lighting', 'it'],
  'bijli': ['electrical', 'led', 'lighting', 'it'],
  'kursi': ['chair', 'furniture'],
  'mez': ['desk', 'furniture', 'table'],
  'table': ['furniture', 'desk', 'table'],
  'stationery': ['office', 'stationery', 'supplies'],
  'safai': ['cleaning', 'housekeeping'],
  'cleaning': ['cleaning', 'housekeeping'],

  // ── Product keywords ────────────────────────────────────────────────────
  'led': ['led', 'lighting', 'it'],
  'led light': ['led', 'lighting', 'it'],
  'tube light': ['led', 'lighting', 'it'],
  'led tube': ['led', 'lighting', 'it'],
  'laptop': ['it', 'computer', 'laptop'],
  'computer': ['it', 'computer'],
  'printer': ['it', 'printer', 'office'],
  'sanitiser': ['cleaning', 'sanitiser', 'other'],
  'sanitizer': ['cleaning', 'sanitiser', 'other'],
  'ppe': ['ppe', 'cleaning', 'other'],
  'mask': ['ppe', 'cleaning', 'other'],

  // ── Ask-style / question triggers ───────────────────────────────────────
  'why': ['why'],
  'how': ['how'],
  'what': ['what'],
  'kya': ['what'],
  'kaise': ['how'],
  'kyun': ['why'],
};

/// Maps Hinglish / transliterated tokens to English category keywords.
/// Checked BEFORE the main synonym map, so Devanagari doesn't need to be
/// normalised to ASCII first.
const Map<String, List<String>> kHinglishMap = {
  'bijli ka saman': ['electrical', 'it', 'lighting'],
  'bijli': ['electrical', 'it'],
  'kursi': ['furniture', 'chair'],
  'mez': ['furniture', 'desk'],
  'safai saman': ['cleaning'],
  'gst bharna': ['gst', 'registration'],
  'tendor': ['bid', 'tender'],
};

/// Maps Devanagari query fragments to canonical English tokens.
const Map<String, List<String>> kDevanagariMap = {
  'बोली': ['bid', 'tender'],
  'निविदा': ['bid', 'tender'],
  'स्टेशनरी': ['stationery', 'office'],
  'फर्नीचर': ['furniture'],
  'कुर्सी': ['furniture', 'chair'],
  'सफाई': ['cleaning'],
  'आईटी': ['it'],
  'बिजली': ['electrical', 'it', 'lighting'],
  'उद्यम': ['udyam', 'msme', 'registration'],
  'MSME': ['msme', 'registration'],
  'वित्त': ['finance'],
};

/// Query tokens that strongly suggest a "question / ask" intent.
const Set<String> kQuestionTokens = {
  'why', 'how', 'what', 'where', 'when',
  'kya', 'kaise', 'kyun', 'kab', 'kahan',
};
