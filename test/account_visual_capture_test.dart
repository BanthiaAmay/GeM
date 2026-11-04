import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gem/core/theme.dart';
import 'package:gem/data/app_store.dart';
import 'package:gem/features/account_page.dart';
import 'package:gem/features/gem_guide_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CaptureStore extends AppStore {
  CaptureStore(super.prefs);
  @override
  bool get configured => true;
}

// Optional visual QA. Loads a local font without bundling or copying it.
void main() {
  const fontPath = String.fromEnvironment('SCREENSHOT_FONT');
  testWidgets('capture signup and GeM guide', (tester) async {
    await tester.runAsync(() async {
      for (final family in [sfProText, sfProDisplay]) {
        await (FontLoader(family)..addFont(
              Future.value(
                ByteData.sublistView(File(fontPath).readAsBytesSync()),
              ),
            ))
            .load();
      }
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    });
    SharedPreferences.setMockInitialValues({});
    final store = CaptureStore(await SharedPreferences.getInstance())
      ..googleAvailable = false;
    for (final spec in [
      ('signup-mobile', const Size(390, 844), false),
      ('signup-desktop', const Size(1280, 1000), false),
      ('gem-guide-mobile', const Size(390, 844), true),
    ]) {
      tester.view.physicalSize = spec.$2;
      tester.view.devicePixelRatio = 1;
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: saathiTheme(),
            home: spec.$3
                ? GemGuidePage(store: store)
                : AccountPage(store: store, entry: true),
          ),
        ),
      );
      await tester.runAsync(
        () => precacheImage(
          const AssetImage('assets/brand/bid2scale-logo-lockup.png'),
          boundary.currentContext!,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await render.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File(
          'docs/screenshots/${spec.$1}.png',
        ).writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
    await tester.pumpWidget(const SizedBox());
    store.dispose();
    tester.view.reset();
  }, skip: fontPath.isEmpty);
}
