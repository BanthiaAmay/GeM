/// Phase 6 tests — language intelligence, Hinglish, Devanagari and typo
/// tolerance.
///
/// Covers every example from the Phase 6 spec:
///   1. Jargon: "money before payment" / "loan for order" → finance items
///      (requires the n-gram phrase-lookup added to _expandTokens).
///   2. Jargon: Udyam, tender, BG, EMD.
///   3. Hinglish: "bijli ka saman", "kursi", "gst bharna".
///   4. Typo tolerance (DL ≤ 1 for 4+ chars, ≤ 2 for 8+ chars):
///      "tendor" and "registartion".
///   5. Devanagari: "बोली", "कुर्सी" and Marathi additions "निविदा", "मेज".
///   6. 50 ms benchmark still passes.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:gem/features/search/search_engine.dart';
import 'package:gem/features/search/search_index.dart';

void main() {
  late SearchEngine engine;

  setUpAll(() {
    engine = SearchEngine(index: SearchIndex.instance);
  });

  // ── 1. Phrase jargon: "money before payment" ────────────────────────────

  test('"money before payment" returns invoice financing (phrase lookup)', () {
    final ids = engine.query('money before payment').map((r) => r.id).toSet();
    expect(
      ids,
      contains('fin-inv'),
      reason: 'Invoice financing not found for "money before payment"',
    );
  });

  // ── 2. Phrase jargon: "loan for order" ──────────────────────────────────

  test('"loan for order" returns working capital or invoice financing', () {
    final ids = engine.query('loan for order').map((r) => r.id).toSet();
    expect(
      ids.intersection({'fin-wc', 'fin-inv'}),
      isNotEmpty,
      reason: 'No finance items found for "loan for order"',
    );
  });

  // ── 3. Jargon: Udyam → MSME lesson ──────────────────────────────────────

  test('"Udyam" returns MSME / Udyam benefits lesson', () {
    final ids = engine.query('Udyam').map((r) => r.id).toSet();
    expect(ids, contains('gem101-m4'));
  });

  // ── 4. Jargon: tender = bid ──────────────────────────────────────────────

  test('"tender" returns bid-related content', () {
    final ids = engine.query('tender').map((r) => r.id).toSet();
    expect(ids, contains('gem101-m3'),
        reason: 'BG / bid lesson not found for "tender"');
  });

  // ── 5. Jargon: BG = bank guarantee ──────────────────────────────────────

  test('"BG" returns bank guarantee finance item', () {
    final ids = engine.query('BG').map((r) => r.id).toSet();
    expect(ids, contains('fin-bg'));
  });

  // ── 6. Jargon: EMD = earnest money deposit ───────────────────────────────

  test('"EMD" returns EMD finance item', () {
    final ids = engine.query('EMD').map((r) => r.id).toSet();
    expect(ids, contains('fin-emd'));
  });

  // ── 7. Hinglish: "bijli ka saman" → IT / electrical ─────────────────────

  test('"bijli ka saman" returns IT / electrical category', () {
    final ids =
        engine.query('bijli ka saman').map((r) => r.id).toSet();
    expect(ids, contains('cat-it'));
  });

  // ── 8. Hinglish: "kursi" → furniture ────────────────────────────────────

  test('"kursi" returns furniture category', () {
    final ids = engine.query('kursi').map((r) => r.id).toSet();
    expect(ids, contains('cat-furniture'));
  });

  // ── 9. Hinglish: "gst bharna" → GST lesson ──────────────────────────────

  test('"gst bharna" returns GST lesson', () {
    final ids = engine.query('gst bharna').map((r) => r.id).toSet();
    expect(ids, contains('gem101-m2'));
  });

  // ── 10. Typo tolerance: "tendor" (DL 1, 6 chars) ────────────────────────

  test('"tendor" (typo) returns bid-related content', () {
    final ids = engine.query('tendor').map((r) => r.id).toSet();
    expect(ids, contains('gem101-m3'));
  });

  // ── 11. Typo tolerance: "registartion" (DL 1, 12 chars) ────────────────

  test('"registartion" (8+ char typo) returns registration items', () {
    final ids = engine.query('registartion').map((r) => r.id).toSet();
    expect(
      ids.intersection({'gem101-m4', 'gem101-m2', 'faq-gst'}),
      isNotEmpty,
      reason: 'No registration items found for "registartion"',
    );
  });

  // ── 12. Devanagari: "बोली" (Hindi for bid) ──────────────────────────────

  test('"बोली" (Hindi for bid) returns bid-related content', () {
    final ids = engine.query('बोली').map((r) => r.id).toSet();
    expect(ids, contains('gem101-m3'));
  });

  // ── 13. Devanagari: "कुर्सी" (Hindi for chair) ──────────────────────────

  test('"कुर्सी" (Hindi for chair) returns furniture category', () {
    final ids = engine.query('कुर्सी').map((r) => r.id).toSet();
    expect(ids, contains('cat-furniture'));
  });

  // ── 14. Devanagari Marathi: "निविदा" (Marathi for tender) ───────────────

  test('"निविदा" (Marathi for tender) returns bid-related content', () {
    final ids = engine.query('निविदा').map((r) => r.id).toSet();
    expect(ids, contains('gem101-m3'));
  });

  // ── 15. Devanagari Marathi: "मेज" (desk/table) ──────────────────────────

  test('"मेज" (Marathi for desk/table) returns furniture category', () {
    final ids = engine.query('मेज').map((r) => r.id).toSet();
    expect(ids, contains('cat-furniture'),
        reason: 'Furniture not found for Marathi desk query "मेज"');
  });

  // ── 16. 50 ms benchmark ──────────────────────────────────────────────────

  test('50 ms benchmark: representative queries each complete under 50 ms', () {
    const queries = [
      'money before payment',
      'loan for order',
      'bijli ka saman',
      'bank guarantee',
      'udyam',
      'tendor',
      'registartion',
      'बोली',
      'gst bharna',
      'kursi',
    ];
    for (final q in queries) {
      final sw = Stopwatch()..start();
      engine.query(q);
      sw.stop();
      expect(
        sw.elapsedMilliseconds,
        lessThan(50),
        reason: '"$q" took ${sw.elapsedMilliseconds} ms (limit: 50 ms)',
      );
    }
  });
}
