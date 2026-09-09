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
      s.changeLanguage();
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
