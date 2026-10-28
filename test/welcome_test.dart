import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gem/core/models.dart';
import 'package:gem/core/theme.dart';
import 'package:gem/data/app_store.dart';
import 'package:gem/features/scroll_hint.dart';
import 'package:gem/features/welcome_page.dart';

void main() {
  ScrollMoreHint.debugDisableBounce = true;
  testWidgets('welcome screen fits in every language on a small phone', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final s = AppStore(await SharedPreferences.getInstance());
    for (final size in const [Size(320, 568), Size(390, 844)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      for (final lang in supportedLanguages) {
        s.setLanguage(lang[0]);
        await tester.pumpWidget(
          MaterialApp(
            theme: saathiTheme(),
            home: WelcomePage(store: s),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '${lang[0]} $size');
        expect(find.text(s.t('Get started', 'शुरू करें')), findsOneWidget);
      }
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
