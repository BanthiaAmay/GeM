/// HSN (Harmonised System of Nomenclature) code → GeM category key map.
///
/// IMPORTANT: Verify every entry against the official GST HSN list before
/// release. Entries here are illustrative samples for search indexing only;
/// they are NOT legal or tax advice. Do not invent codes.
///
/// Key   = HSN code string (4- or 8-digit).
/// Value = category key in `categories` (core/models.dart).
const Map<String, String> kHsnToCategory = {
  // Office supplies
  '4820': 'office', // Registers, account books, notebooks, etc.
  '4820.10': 'office', // Registers and account books
  '4820.20': 'office', // Exercise books
  '4820.30': 'office', // Binders
  '9608': 'office', // Ball-point pens, felt-tipped pens, markers
  '9609': 'office', // Pencils, crayons, chalk
  '4821': 'office', // Paper labels
  '8443': 'office', // Printing machinery, photocopying apparatus (printers)

  // IT equipment
  '8471': 'it', // Automatic data processing machines (computers, laptops)
  '8473': 'it', // Parts for computers and data processing machines
  '8517': 'it', // Telephone sets, routers, network equipment
  '8528': 'it', // Monitors, projectors
  '8544': 'it', // Insulated wire, fibre-optic cables

  // Furniture
  '9403': 'furniture', // Other furniture (office furniture, school desks)
  '9401': 'furniture', // Seats (chairs)
  '9402': 'furniture', // Medical or dental furniture
  '9404': 'furniture', // Mattress supports, mattresses

  // Cleaning / housekeeping
  '3401': 'cleaning', // Soap, detergent
  '3402': 'cleaning', // Washing preparations, cleaning preparations
  '3406': 'cleaning', // Candles and tapers
  '8509': 'cleaning', // Vacuum cleaners and similar appliances
  '6305': 'cleaning', // Sacks and bags for packing

  // LED lighting (maps to 'it' as closest general category)
  '9405': 'it', // Lamps, lighting fittings (includes LED tube lights)
  '9405.10': 'it', // Chandeliers and other electric ceiling / wall lighting
  '9405.40': 'it', // Electric lamps and lighting fittings (LED bulbs/tubes)

  // Sanitisers / PPE (maps to 'other')
  '3808': 'other', // Disinfectants, antiseptics
  '3004': 'other', // Medicaments
  '6210': 'other', // Garments (PPE coveralls)
  '6217': 'other', // Clothing accessories (masks, gloves classified here)
  '3926': 'other', // Plastic gloves, PPE items
};
