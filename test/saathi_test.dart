import 'support/authenticated_journey_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gem/core/theme.dart';
import 'package:gem/data/app_store.dart';
import 'package:gem/features/saathi_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SaathiStore extends AuthenticatedJourneyStore {
  SaathiStore(super.prefs);
  final asked = <List<SaathiTurn>>[];
  String? failWith;
  @override
  Future<String> askSaathi(List<SaathiTurn> turns) async {
    asked.add(turns);
    if (failWith != null) throw SaathiException(failWith!);
    return 'Answer ${asked.length}';
  }
}

void main() {
  late SaathiStore store;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = SaathiStore(await SharedPreferences.getInstance());
  });

  Future<void> open(WidgetTester tester, {Object? question}) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: saathiTheme(),
        onGenerateRoute: (settings) => MaterialPageRoute(
          settings: RouteSettings(name: '/saathi', arguments: question),
          builder: (_) => SaathiPage(store: store),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a suggestion is asked and the conversation is kept', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('Ask Saathi anything'), findsOneWidget);
    await tester.ensureVisible(find.text('How do I register on GeM?'));
    await tester.tap(find.text('How do I register on GeM?'));
    await tester.pumpAndSettle();
    expect(find.text('Answer 1'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'And documents?');
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();
    expect(find.text('Answer 2'), findsOneWidget);
    // The second question carries the earlier turns as context.
    expect(store.asked.last.map((t) => t.role), ['user', 'model', 'user']);
    expect(store.asked.last.last.text, 'And documents?');
  });

  testWidgets('a question from search is asked straight away', (tester) async {
    await open(tester, question: 'What is EMD?');
    expect(store.asked.single.single.text, 'What is EMD?');
    expect(find.text('Answer 1'), findsOneWidget);
  });

  testWidgets('the daily limit is explained', (tester) async {
    store.failWith = 'daily_limit';
    await open(tester, question: 'Hello');
    expect(find.textContaining('today’s question limit'), findsOneWidget);
  });
}
