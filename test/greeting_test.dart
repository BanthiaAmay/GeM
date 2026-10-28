import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gem/core/theme.dart';
import 'package:gem/data/app_store.dart';
import 'package:gem/features/language_page.dart';
import 'package:gem/features/scroll_hint.dart';

void main() {
  ScrollMoreHint.debugDisableBounce = true;

  Future<AppStore> store() async {
    SharedPreferences.setMockInitialValues({});
    return AppStore(await SharedPreferences.getInstance());
  }

  testWidgets('first visit tours other languages then settles on English', (
    tester,
  ) async {
    final s = await store();
    await tester.pumpWidget(
      MaterialApp(
        theme: saathiTheme(),
        home: LanguagePage(store: s),
      ),
    );
    await tester.pump();
    // The tour visits every other language before English (last in
    // supportedLanguages order), so the very first frame is Hindi, not
    // the settled "Hello." yet.
    expect(find.text('नमस्ते.'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 900));
    // Let the whole tour (<=9 frames * 360ms) finish.
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Skip'), findsNothing);
    expect(find.text('Hello.'), findsOneWidget);
    expect(s.hasSeenGreetingIntro, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping Skip jumps straight to the settled greeting', (
    tester,
  ) async {
    final s = await store();
    await tester.pumpWidget(
      MaterialApp(
        theme: saathiTheme(),
        home: LanguagePage(store: s),
      ),
    );
    await tester.pump();
    expect(find.text('Skip'), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Skip'), findsNothing);
    expect(find.text('Hello.'), findsOneWidget);
    expect(s.hasSeenGreetingIntro, isTrue);
  });

  testWidgets('returning visit shows the settled greeting with no tour', (
    tester,
  ) async {
    final s = await store();
    await s.markGreetingIntroSeen();
    await tester.pumpWidget(
      MaterialApp(
        theme: saathiTheme(),
        home: LanguagePage(store: s),
      ),
    );
    await tester.pump();
    expect(find.text('Skip'), findsNothing);
    expect(find.text('Hello.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Skip'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion skips the tour and still marks it seen', (
    tester,
  ) async {
    final s = await store();
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          theme: saathiTheme(),
          home: LanguagePage(store: s),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Skip'), findsNothing);
    expect(find.text('Hello.'), findsOneWidget);
    expect(s.hasSeenGreetingIntro, isTrue);
  });

  testWidgets('selecting a language mid-tour jumps straight to it', (
    tester,
  ) async {
    final s = await store();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: saathiTheme(),
        home: LanguagePage(store: s),
      ),
    );
    await tester.pump();
    expect(find.text('Skip'), findsOneWidget);
    await tester.ensureVisible(find.text('मराठी'));
    await tester.tap(find.text('मराठी'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Skip'), findsNothing);
    expect(find.text('नमस्कार.'), findsOneWidget);
    expect(s.language, 'mr');
  });

  testWidgets('the tour never exposes an intermediate greeting to semantics', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final s = await store();
    await tester.pumpWidget(
      MaterialApp(
        theme: saathiTheme(),
        home: LanguagePage(store: s),
      ),
    );
    await tester.pump();
    // Sample several points across the tour; the accessible label for the
    // greeting must always already read the *final* (English) greeting.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 250));
      final tree =
          // ignore: deprecated_member_use
          tester.binding.pipelineOwner.semanticsOwner!.rootSemanticsNode!;
      var found = false;
      void visit(SemanticsNode n) {
        if ((n.label).contains('Hello.')) found = true;
        n.visitChildren((c) {
          visit(c);
          return true;
        });
      }

      visit(tree);
      expect(found, isTrue, reason: 'frame $i');
    }
    handle.dispose();
  });
}
