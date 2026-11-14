import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gem/core/theme.dart';
import 'package:gem/features/home_page.dart';
import 'package:gem/features/news_page.dart';
import 'package:gem/features/scroll_hint.dart';
import 'package:gem/features/trainings/trainings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/authenticated_journey_store.dart';

class NewsStore extends AuthenticatedJourneyStore {
  NewsStore(super.prefs);
  int loads = 0;
  @override
  Future<void> loadGemVideos() async => loads++;
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
const _story = {
  'video_id': 'StOrY_12345',
  'title': '#GeMSellerSpeak | A weaver from Varanasi',
  'published_at': '2026-11-04T09:00:00+00:00',
  'kind': 'story',
  'duration_seconds': 95,
};
Map<String, dynamic> _tip(int day) => {
  'video_id': 'TiP_video_$day',
  'title': 'GeM tip $day #GeMShorts',
  'published_at': '2026-11-0${day}T09:00:00+00:00',
  'kind': 'tip',
  'duration_seconds': 45,
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
    store.gemVideosFailed = true;
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
    // The bulletin lives in the "Learn & Stay Current" shelf.
    expect(find.text('GEM WEEKLY'), findsOneWidget);
    expect(find.text('GeM Bulletin October Week #4'), findsOneWidget);
    expect(find.text('GeM Bulletin October Week #3'), findsNothing);
    final seeAll = find.descendant(
      of: find
          .ancestor(
            of: find.text('Learn & Stay Current'),
            matching: find.byType(Row),
          )
          .first,
      matching: find.text('See all'),
    );
    await tester.ensureVisible(seeAll);
    await tester.tap(seeAll);
    await tester.pumpAndSettle();
    expect(find.byType(NewsPage), findsOneWidget);
    expect(find.text('GeM Bulletin October Week #3'), findsOneWidget);
  });

  testWidgets('News shows success stories and earlier bulletins, not tips', (
    tester,
  ) async {
    store.bulletins = [Map.of(_week4), Map.of(_week3)];
    store.gemVideos = [Map.of(_story), _tip(1)];
    await show(tester, NewsPage(store: store));
    expect(find.text('Success stories'), findsOneWidget);
    expect(find.text(_story['title']! as String), findsOneWidget);
    expect(find.text('4 Nov 2026 · 1:35'), findsOneWidget);
    expect(find.text('Earlier bulletins'), findsOneWidget);
    expect(find.text('GeM tip 1 #GeMShorts'), findsNothing);
  });

  testWidgets('Trainings shows new GeM tips, three until expanded', (
    tester,
  ) async {
    store.gemVideos = [_tip(4), _tip(3), _tip(2), _tip(1), Map.of(_story)];
    await show(tester, TrainingsPage(store: store));
    expect(store.loads, 1);
    expect(find.text('New from GeM'), findsOneWidget);
    expect(find.text('GeM tip 4 #GeMShorts'), findsOneWidget);
    expect(find.text('GeM tip 2 #GeMShorts'), findsOneWidget);
    expect(find.text('GeM tip 1 #GeMShorts'), findsNothing);
    expect(find.text(_story['title']! as String), findsNothing);
    await tester.tap(find.text('See all'));
    await tester.pumpAndSettle();
    expect(find.text('GeM tip 1 #GeMShorts'), findsOneWidget);
    expect(find.text('Show fewer'), findsOneWidget);
  });

  testWidgets('Trainings hides New from GeM until videos exist', (
    tester,
  ) async {
    await show(tester, TrainingsPage(store: store));
    expect(find.text('New from GeM'), findsNothing);
    expect(find.text('Modules'), findsOneWidget);
  });
}
