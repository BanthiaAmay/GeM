import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gem/data/app_store.dart';
import 'package:gem/main.dart';

// Optional offscreen visual QA. Pass a locally installed font path; fonts are not copied into the repository.
void main() {
  const fontPath = String.fromEnvironment('SCREENSHOT_FONT');
  testWidgets('capture rendered desktop and mobile previews', (tester) async {
    await tester.runAsync(() async {
      final font = FontLoader('Roboto')
        ..addFont(
          Future.value(ByteData.sublistView(File(fontPath).readAsBytesSync())),
        );
      await font.load();
      final hindi = FontLoader('NotoSansDevanagari')
        ..addFont(rootBundle.load('assets/fonts/NotoSansDevanagari.ttf'));
      await hindi.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
    });
    final boundary = GlobalKey();
    for (final spec in [
      ('desktop', const Size(1440, 1100), '', 'en'),
      ('mobile', const Size(390, 1000), '', 'en'),
      ('mobile-hindi', const Size(390, 1000), '', 'hi'),
      ('gst-desktop', const Size(1440, 1100), 'gst', 'en'),
      ('gst-mobile', const Size(390, 1000), 'gst', 'en'),
    ]) {
      SharedPreferences.setMockInitialValues({'saathi.v1.onboarded': true});
      final s = AppStore(await SharedPreferences.getInstance());
      s.setLanguage(spec.$4);
      tester.view.physicalSize = spec.$2;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: SaathiApp(store: s),
        ),
      );
      await tester.pumpAndSettle();
      if (spec.$3.isNotEmpty) {
        tester.state<NavigatorState>(find.byType(Navigator)).pushNamed('/${spec.$3}');
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await render.toImage(pixelRatio: 1);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        File(
          'docs/screenshots/${spec.$1}.png',
        ).writeAsBytesSync(png!.buffer.asUint8List());
        image.dispose();
      });
    }
    await tester.pumpWidget(const SizedBox());
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }, skip: fontPath.isEmpty);
}
