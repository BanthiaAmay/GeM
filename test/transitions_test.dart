import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gem/core/transitions.dart';

void main() {
  testWidgets(
    'SoftRoute pushes and pops through its transition without error',
    (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          home: const Scaffold(body: Center(child: Text('Start'))),
        ),
      );
      expect(find.text('Start'), findsOneWidget);

      navigatorKey.currentState!.push(
        SoftRoute<void>(
          settings: const RouteSettings(name: '/next'),
          builder: (context) =>
              const Scaffold(body: Center(child: Text('Next'))),
        ),
      );

      // Step through the transition frame by frame instead of jumping
      // straight to pumpAndSettle(), so any error mid-animation surfaces
      // here rather than being skipped over.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      await tester.pump(const Duration(milliseconds: 80));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      expect(find.text('Next'), findsOneWidget);
      expect(find.text('Start'), findsNothing);

      navigatorKey.currentState!.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      expect(find.text('Start'), findsOneWidget);
    },
  );

  testWidgets('FadeRoute pushes through its transition without error', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: Center(child: Text('Splash'))),
      ),
    );

    navigatorKey.currentState!.pushReplacement(
      FadeRoute<void>(
        settings: const RouteSettings(name: '/home'),
        builder: (context) => const Scaffold(body: Center(child: Text('Home'))),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Splash'), findsNothing);
  });
}
