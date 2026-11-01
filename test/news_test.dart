import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gem/core/theme.dart';
import 'package:gem/features/home_page.dart';
import 'package:gem/features/news_page.dart';
import 'package:gem/features/scroll_hint.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/authenticated_journey_store.dart';

class NewsStore extends AuthenticatedJourneyStore {
  NewsStore(super.prefs);
  int loads = 0;
  @override
  Future<void> loadBulletins() async => loads++;
}

const _week4 = {
  'video_id': 'QwErTyUiOp3',
  'title': 'GeM Bulletin October Week #4',
  'published_at': '2026-10-29T11:00:00+00:00',
};
const _week3 = {
  'video_id': 'AbCdEfGh_-1',
  'title': 'GeM Bulletin October Week #3',
  'published_at': '2026-10-22T10:30:00+00:00',
};

void main() {
  ScrollMoreHint.debugDisableBounce = true;
  late NewsStore store;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = NewsStore(await SharedPreferences.getInstance());
  });

  Future<void> show(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: saathiTheme(),
        home: home,
        routes: {'/news': (_) => NewsPage(store: store)},
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('News lists bulletins newest first with the source', (
    tester,
  ) async {
    store.bulletins = [Map.of(_week4), Map.of(_week3)];
    await show(tester, NewsPage(store: store));
    expect(store.loads, 1);
    final week4 = tester.getTopLeft(find.text('GeM Bulletin October Week #4'));
    final week3 = tester.getTopLeft(find.text('GeM Bulletin October Week #3'));
    expect(week4.dy, lessThan(week3.dy));
    expect(find.text('29 Oct 2026'), findsOneWidget);
    expect(
      find.textContaining('Government e-Marketplace on YouTube'),
      findsOneWidget,
    );
  });

  testWidgets('News shows an empty state before the first bulletin', (
    tester,
  ) async {
    await show(tester, NewsPage(store: store));
    expect(find.text('No bulletins yet'), findsOneWidget);
  });

  testWidgets('News offers a retry when loading fails', (tester) async {
    store.bulletinsFailed = true;
    await show(tester, NewsPage(store: store));
    expect(find.text('Could not load news'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(store.loads, 2);
  });

  testWidgets('Home hides the bulletin card until one exists', (tester) async {
    await show(tester, HomePage(store: store));
    expect(store.loads, 1);
    expect(find.text('GeM Weekly Bulletin'), findsNothing);
  });

  testWidgets('Home shows the latest bulletin and opens News', (tester) async {
    store.bulletins = [Map.of(_week4), Map.of(_week3)];
    await show(tester, HomePage(store: store));
    expect(find.text('GeM Weekly Bulletin'), findsOneWidget);
    expect(find.text('GeM Bulletin October Week #4'), findsOneWidget);
    expect(find.text('GeM Bulletin October Week #3'), findsNothing);
    await tester.ensureVisible(find.text('See all'));
    await tester.tap(find.text('See all'));
    await tester.pumpAndSettle();
    expect(find.byType(NewsPage), findsOneWidget);
    expect(find.text('GeM Bulletin October Week #3'), findsOneWidget);
  });
}
