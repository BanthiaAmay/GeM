import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gem/data/app_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;
  late AppStore s;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    s = AppStore(prefs);
  });
  test(
    'tool results and language survive a restart; upstream changes invalidate ROI',
    () async {
      s.complete('roi', {'firstYear': 1000});
      s.setLanguage('hi');
      s.complete('eligibility', {
        'pan': true,
        'bank': true,
        'gst': 'yes',
        'udyam': true,
      });
      await s.persist();
      final restored = AppStore(prefs);
      expect(restored.hi, isTrue);
      expect(restored.completed, ['eligibility']);
      expect(restored.section('roi'), isEmpty);
      expect(restored.checklist.take(3), [true, true, true]);
    },
  );
  test('consent is required for events and withdrawal clears queue', () {
    s.event('page_view');
    expect(s.queue, isEmpty);
    s.setConsent(true);
    s.event('tool_started', page: 'revenue');
    expect(s.queue.length, 2);
    s.setConsent(false);
    expect(s.queue, isEmpty);
  });
  test('revenue result map round-trips through persist/restore', () async {
    s.complete('revenue', {
      'orderValue': 75000.0,
      'ordersLow': 3.0,
      'ordersHigh': 9.0,
      'low': 225000.0,
      'high': 675000.0,
      'category': 'office',
      'city': 'Pune',
      'source': 'user_assumptions',
    });
    await s.persist();
    final restored = AppStore(prefs);
    final sec = restored.section('revenue');
    expect(sec['orderValue'], 75000.0);
    expect(sec['ordersLow'], 3.0);
    expect(sec['ordersHigh'], 9.0);
    expect(sec['low'], 225000.0);
    expect(sec['high'], 675000.0);
    expect(restored.completed, contains('revenue'));
  });
  test('completing revenue invalidates any saved ROI result', () {
    // Constraint 7: revenue edits must wipe downstream ROI.
    s.complete('roi', {'firstYear': 5000, 'threeYear': 15000});
    expect(s.completed, contains('roi'));
    s.complete('revenue', {
      'orderValue': 100000,
      'ordersLow': 2,
      'ordersHigh': 6,
      'low': 200000,
      'high': 600000,
    });
    expect(s.completed, isNot(contains('roi')));
    expect(s.section('roi'), isEmpty);
  });
  // ── Phase 2 persistence tests ─────────────────────────────────
  test('new optional revenue fields round-trip through persist/restore', () async {
    s.complete('revenue', {
      'orderValue': 50000.0,
      'ordersLow': 3.0,
      'ordersHigh': 9.0,
      'low': 150000.0,
      'high': 450000.0,
      'orderValueVaries': true,
      'minOrderValue': 40000.0,
      'maxOrderValue': 60000.0,
      'priorOrdersCount': 12,
      'priorOrdersValue': 45000.0,
      'hasSeasonal': true,
      'seasonalMonths': [10, 11, 12],
      'source': 'user_assumptions',
    });
    await s.persist();
    final restored = AppStore(prefs);
    final sec = restored.section('revenue');
    expect(sec['orderValueVaries'], isTrue);
    expect(sec['minOrderValue'], 40000.0);
    expect(sec['maxOrderValue'], 60000.0);
    expect(sec['priorOrdersCount'], 12);
    expect(sec['priorOrdersValue'], 45000.0);
    expect(sec['hasSeasonal'], isTrue);
    expect(sec['seasonalMonths'], [10, 11, 12]);
    expect(restored.completed, contains('revenue'));
  });
  test('revenue section saved before new fields loads without error', () async {
    // Simulate an old-format section (no new optional keys at all).
    s.complete('revenue', {
      'orderValue': 80000.0,
      'ordersLow': 2.0,
      'ordersHigh': 8.0,
      'low': 160000.0,
      'high': 640000.0,
      'source': 'user_assumptions',
    });
    await s.persist();
    final restored = AppStore(prefs);
    final sec = restored.section('revenue');
    // Original keys still present
    expect(sec['orderValue'], 80000.0);
    expect(sec['low'], 160000.0);
    // New keys absent — must return null, not throw
    expect(sec['orderValueVaries'], isNull);
    expect(sec['minOrderValue'], isNull);
    expect(sec['maxOrderValue'], isNull);
    expect(sec['priorOrdersCount'], isNull);
    expect(sec['priorOrdersValue'], isNull);
    expect(sec['hasSeasonal'], isNull);
    expect(sec['seasonalMonths'], isNull);
    expect(restored.completed, contains('revenue'));
  });
  test('local deletion clears report and research data', () async {
    s.setConsent(true);
    s.complete('pricing', {'price': 10});
    await s.deleteData();
    expect(s.completed, isEmpty);
    expect(s.queue, isEmpty);
    expect(AppStore(prefs).data, isEmpty);
  });
  test('malformed local data fails safely', () async {
    await prefs.setString('saathi.v1.guest', 'not json');
    final restored = AppStore(prefs);
    expect(restored.data, isEmpty);
    expect(restored.status, 'local_recovery');
  });
}
