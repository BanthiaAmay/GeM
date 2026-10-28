/// Bid-matching keywords inferred from what the seller already told us
/// (business name, "other" sector text, sector), so alerts do not depend on
/// them typing GeM's exact wording. Results are English search words, the
/// language GeM bids are published in; the seller can remove any of them.
library;

/// Word stem found in their text -> GeM wording that bids actually use.
const _kHints = <String, List<String>>{
  'textile': ['Uniform', 'Bedsheet', 'Towel'],
  'garment': ['Uniform', 'T-shirt'],
  'uniform': ['Uniform'],
  'tailor': ['Uniform', 'Stitching'],
  'furnit': ['Furniture', 'Office chair', 'Table'],
  'wood': ['Furniture', 'Table'],
  'steel': ['Steel almirah', 'Steel'],
  'iron': ['Steel', 'Fabrication'],
  'fabricat': ['Fabrication', 'Steel'],
  'electric': ['Electrical', 'Cable', 'LED lights'],
  'electronic': ['Electronic', 'CCTV'],
  'light': ['LED lights'],
  'solar': ['Solar'],
  'computer': ['Computer', 'Laptop', 'Printer cartridge'],
  'infotech': ['Computer', 'Software', 'Laptop'],
  'software': ['Software', 'Website'],
  'tech': ['Computer'],
  'print': ['Printing', 'Printer cartridge'],
  'stationer': ['Stationery', 'Paper'],
  'paper': ['Paper', 'Stationery'],
  'pharma': ['Medicine', 'Tablet', 'Injection'],
  'medic': ['Medicine', 'Surgical', 'Medical equipment'],
  'surgical': ['Surgical', 'Gloves'],
  'chemist': ['Medicine'],
  'chemical': ['Chemical', 'Disinfectant'],
  'clean': ['Housekeeping', 'Cleaning', 'Disinfectant'],
  'housekeep': ['Housekeeping'],
  'facility': ['Housekeeping', 'Manpower'],
  'security': ['Security services', 'CCTV'],
  'manpower': ['Manpower'],
  'staff': ['Manpower'],
  'travel': ['Taxi hiring', 'Bus hiring'],
  'transport': ['Transportation', 'Taxi hiring'],
  'logistic': ['Transportation'],
  'cater': ['Catering'],
  'food': ['Catering', 'Rice', 'Pulses'],
  'agro': ['Seeds', 'Fertilizer'],
  'agri': ['Seeds', 'Fertilizer'],
  'seed': ['Seeds'],
  'dairy': ['Milk', 'Ghee'],
  'construct': ['Civil works', 'Cement', 'Repair and maintenance'],
  'builder': ['Civil works', 'Cement'],
  'infra': ['Civil works', 'Road construction'],
  'cement': ['Cement'],
  'paint': ['Paint', 'Painting'],
  'plumb': ['Plumbing', 'Pipe'],
  'hardware': ['Hardware', 'Tools'],
  'plastic': ['Plastic', 'Dustbin'],
  'packag': ['Packaging', 'Carton'],
  'water': ['Water purifier', 'Water tank'],
  'event': ['Event management', 'Tent'],
  'tent': ['Tent', 'Event management'],
  'sport': ['Sports'],
  'toy': ['Toys'],
  'book': ['Books'],
  'auto': ['Vehicle', 'Tyre'],
  'motor': ['Vehicle', 'Motor'],
  'tyre': ['Tyre'],
};

/// Sector fallback when nothing more specific is known.
const _kSectorDefaults = <String, List<String>>{
  'manufacturing': ['Furniture', 'Uniform'],
  'trading': ['Stationery', 'Computer'],
  'services': ['Manpower', 'Housekeeping'],
  'agriculture': ['Seeds', 'Fertilizer'],
  'construction': ['Civil works', 'Repair and maintenance'],
};

/// Up to [max] keywords inferred from the onboarding profile, most specific
/// first (business name and described sector before the sector default).
List<String> inferKeywords(Map<String, dynamic> profile, {int max = 4}) {
  final text = [
    profile['businessName'],
    profile['sectorOther'],
  ].whereType<String>().join(' ').toLowerCase();
  final out = <String>[];
  void add(String k) {
    if (out.length < max &&
        !out.any((v) => v.toLowerCase() == k.toLowerCase())) {
      out.add(k);
    }
  }

  for (final word in text.split(RegExp(r'[^a-z]+'))) {
    if (word.length < 3) continue;
    for (final entry in _kHints.entries) {
      // Short stems only at a word start ("iron" must not match "environment").
      if (word.startsWith(entry.key) ||
          (entry.key.length >= 5 && word.contains(entry.key))) {
        entry.value.forEach(add);
      }
    }
  }
  if (out.isEmpty) {
    (_kSectorDefaults[profile['sector']] ?? const []).forEach(add);
  }
  return out;
}

/// One answer to "What does your business supply?": a plain-language group
/// the seller ticks, and the GeM search words it stands for.
class SupplyGroup {
  final String id;
  final String en, hi;
  final String subEn, subHi;
  final List<String> keywords;
  const SupplyGroup(
    this.id,
    this.en,
    this.hi,
    this.subEn,
    this.subHi,
    this.keywords,
  );
}

const kSupplyGroups = <SupplyGroup>[
  SupplyGroup(
    'furniture',
    'Furniture',
    'फर्नीचर',
    'Chairs, tables, almirahs',
    'कुर्सी, मेज़, अलमारी',
    ['Furniture', 'Office chair', 'Table', 'Steel almirah'],
  ),
  SupplyGroup(
    'stationery',
    'Office supplies & stationery',
    'कार्यालय सामग्री और स्टेशनरी',
    'Paper, pens, toner',
    'कागज़, पेन, टोनर',
    ['Stationery', 'Paper', 'Printer cartridge'],
  ),
  SupplyGroup(
    'it',
    'Computers & electronics',
    'कंप्यूटर और इलेक्ट्रॉनिक्स',
    'Laptops, printers, CCTV',
    'लैपटॉप, प्रिंटर, CCTV',
    ['Computer', 'Laptop', 'Printer', 'CCTV', 'Software'],
  ),
  SupplyGroup(
    'electrical',
    'Electrical & lighting',
    'बिजली और लाइटिंग',
    'Cables, LED lights, solar',
    'केबल, LED लाइट, सोलर',
    ['Electrical', 'Cable', 'LED lights', 'Solar'],
  ),
  SupplyGroup(
    'textiles',
    'Textiles & uniforms',
    'कपड़ा और वर्दी',
    'Uniforms, bedsheets, towels',
    'वर्दी, चादर, तौलिया',
    ['Uniform', 'Bedsheet', 'Towel', 'T-shirt'],
  ),
  SupplyGroup(
    'medical',
    'Medical & lab supplies',
    'चिकित्सा और लैब सामग्री',
    'Medicines, surgical items, gloves',
    'दवाइयाँ, सर्जिकल सामान, दस्ताने',
    ['Medicine', 'Surgical', 'Gloves', 'Medical equipment'],
  ),
  SupplyGroup(
    'cleaning',
    'Cleaning & housekeeping',
    'सफाई और हाउसकीपिंग',
    'Housekeeping, disinfectants',
    'हाउसकीपिंग, कीटाणुनाशक',
    ['Housekeeping', 'Cleaning', 'Disinfectant'],
  ),
  SupplyGroup(
    'manpower',
    'Manpower & security',
    'मैनपावर और सुरक्षा',
    'Staffing, security guards',
    'स्टाफ़, सुरक्षा गार्ड',
    ['Manpower', 'Security services'],
  ),
  SupplyGroup(
    'transport',
    'Vehicles & transport',
    'वाहन और परिवहन',
    'Taxi, bus and truck hiring',
    'टैक्सी, बस और ट्रक किराया',
    ['Taxi hiring', 'Bus hiring', 'Transportation', 'Vehicle', 'Tyre'],
  ),
  SupplyGroup(
    'food',
    'Food & catering',
    'भोजन और कैटरिंग',
    'Catering, groceries, milk',
    'कैटरिंग, राशन, दूध',
    ['Catering', 'Rice', 'Pulses', 'Milk'],
  ),
  SupplyGroup(
    'agriculture',
    'Agriculture',
    'कृषि',
    'Seeds, fertilizer, animal feed',
    'बीज, खाद, पशु आहार',
    ['Seeds', 'Fertilizer', 'Cattle feed'],
  ),
  SupplyGroup(
    'construction',
    'Construction & repair',
    'निर्माण और मरम्मत',
    'Civil works, paint, plumbing',
    'सिविल कार्य, पेंट, प्लंबिंग',
    ['Civil works', 'Repair and maintenance', 'Paint', 'Plumbing', 'Cement'],
  ),
  SupplyGroup(
    'printing',
    'Printing & packaging',
    'छपाई और पैकेजिंग',
    'Printing, cartons, packaging',
    'छपाई, कार्टन, पैकेजिंग',
    ['Printing', 'Packaging', 'Carton'],
  ),
];

/// The answers implied by [keywords]: each group they touch, with only the
/// words that were given (or all of its words when [whole] is set).
Map<String, Set<String>> answersFor(
  Iterable<String> keywords, {
  bool whole = false,
}) {
  final given = {for (final k in keywords) k.toLowerCase()};
  return {
    for (final g in kSupplyGroups)
      if (g.keywords.any((k) => given.contains(k.toLowerCase())))
        g.id: whole
            ? g.keywords.toSet()
            : g.keywords.where((k) => given.contains(k.toLowerCase())).toSet(),
  };
}

/// Alert keywords from the answers: one word from each ticked group in
/// turn, so every group is represented within the 10-keyword limit.
List<String> keywordsFromAnswers(
  Map<String, Set<String>> answers, {
  int max = 10,
}) {
  final queues = [
    for (final g in kSupplyGroups)
      if (answers[g.id]?.isNotEmpty ?? false)
        g.keywords.where(answers[g.id]!.contains).toList(),
  ];
  final out = <String>[];
  for (var i = 0; out.length < max && queues.any((q) => i < q.length); i++) {
    for (final q in queues) {
      if (i < q.length && out.length < max) out.add(q[i]);
    }
  }
  return out;
}
