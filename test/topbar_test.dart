import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gem/features/brand_logo.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gem/core/models.dart';
import 'package:gem/core/theme.dart';
import 'package:gem/data/app_store.dart';
import 'package:gem/features/home_page.dart';
import 'package:gem/features/scroll_hint.dart';

// The Home top bar (logo lockup, language chip, bell, hamburger) must fit
// without overflow on the narrowest phones, in every language, and its
// controls must reach their real destinations — never a duplicate mark
// icon, never a fake one.
void main() {
  ScrollMoreHint.debugDisableBounce = true;

  Future<AppStore> store() async {
    SharedPreferences.setMockInitialValues({});
    return AppStore(await SharedPreferences.getInstance());
  }

  testWidgets('top bar fits on the narrowest supported phone, every language', (
    tester,
  ) async {
    final s = await store();
    for (final width in [320.0, 360.0, 390.0]) {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      for (final lang in supportedLanguages) {
        s.setLanguage(lang[0]);
        await tester.pumpWidget(
          MaterialApp(
            theme: saathiTheme(),
            home: HomePage(store: s),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '${lang[0]} @ $width');
      }
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('bell opens Updates, menu opens the drawer, no stray mark icon', (
    tester,
  ) async {
    final s = await store();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      MaterialApp(
        theme: saathiTheme(),
        home: HomePage(store: s),
      ),
    );
    await tester.pumpAndSettle();

    // Exactly one brand mark: the lockup's own icon, not a separate one.
    // (Its depth shadow paints the same artwork again, so count logos.)
    expect(find.byType(BrandLogo), findsOneWidget);
    expect(
      tester.widget<BrandLogo>(find.byType(BrandLogo)).variant,
      BrandLogoVariant.lockup,
    );

    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();
    expect(find.text('Opportunities, on your terms.'), findsOneWidget);

    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    expect(find.text('Register on GeM'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
