/// Phase 8 tests — voice search flag and user-data indexing.
///
/// Covers:
///   1. AppSearchField hides the mic icon when showMic is false.
///   2. buildUserDataItems indexes outcome reference words so a buyer-name
///      search returns the user's order item under SearchType.myData.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gem/features/components.dart';
import 'package:gem/data/app_store.dart';
import 'package:gem/features/search/search_models.dart';
import 'package:gem/features/search/user_data_index.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // ── 1. Mic hidden when showMic is false ──────────────────────────────────

  testWidgets('AppSearchField hides mic when showMic is false', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppSearchField(
            controller: controller,
            hint: 'Search',
            onChanged: (_) {},
            showMic: false,
          ),
        ),
      ),
    );

    // Neither mic icon variant should appear.
    expect(find.byIcon(Icons.mic), findsNothing);
    expect(find.byIcon(Icons.mic_none), findsNothing);
  });

  testWidgets(
    'AppSearchField shows mic_none when showMic is true (not listening)',
    (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppSearchField(
              controller: controller,
              hint: 'Search',
              onChanged: (_) {},
              showMic: true,
              isListening: false,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.mic_none), findsOneWidget);
      expect(find.byIcon(Icons.mic), findsNothing);
    },
  );

  // ── 2. Buyer-name search returns myData item ──────────────────────────────

  test(
    'buildUserDataItems indexes outcome reference; buyer search returns myData item',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final store = AppStore(prefs);

      // Inject an outcome whose reference is a buyer name.
      store.outcomes = [
        {'stage': 'first_order', 'reference': 'Delhi Police'},
      ];

      final items = buildUserDataItems(store);

      // Must contain at least one myData item.
      expect(items, isNotEmpty);

      // Find items whose keywords include 'delhi police' (or 'delhi' / 'police').
      final matchingItems = items.where((item) {
        final kws = item.keywords.map((k) => k.toLowerCase()).toList();
        return kws.contains('delhi police') ||
            (kws.contains('delhi') && kws.contains('police'));
      }).toList();

      expect(
        matchingItems,
        isNotEmpty,
        reason: 'Expected at least one item with delhi/police in keywords',
      );

      // Every matching item must be typed myData.
      for (final item in matchingItems) {
        expect(item.type, equals(SearchType.myData));
      }

      // The subtitle must be the buyer reference.
      expect(matchingItems.first.subtitleEn, equals('Delhi Police'));
    },
  );
}
