import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gem/core/theme.dart';
import 'package:gem/data/app_store.dart';
import 'package:gem/features/onboarding_flow_1.dart';
import 'package:gem/features/scroll_hint.dart';

// The app theme fills and outlines every TextField. The OTP page's
// invisible input must never paint any of that over the six boxes
// (it once hid everything but their bottom edges). Using a loud red
// theme fill/outline makes any leak unmistakable.
void main() {
  ScrollMoreHint.debugDisableBounce = true;
  testWidgets('OTP input paints nothing over the drawn boxes', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    SharedPreferences.setMockInitialValues({});
    final s = AppStore(await SharedPreferences.getInstance());
    final key = GlobalKey();
    const red = BorderSide(color: Color(0xFFFF0000), width: 3);
    final theme = saathiTheme().copyWith(
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: Color(0xFFFF0000),
        border: OutlineInputBorder(borderSide: red),
        enabledBorder: OutlineInputBorder(borderSide: red),
        focusedBorder: OutlineInputBorder(borderSide: red),
      ),
    );
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(theme: theme, home: FlowOtpPage(store: s)),
      ),
    );
    await tester.pumpAndSettle();

    final box = tester
        .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
        .map((w) => tester.getRect(find.byWidget(w)))
        .firstWhere((r) => r.width == 46 && r.height == 56);
    late ui.Image image;
    late ByteData data;
    await tester.runAsync(() async {
      final render =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      image = await render.toImage(pixelRatio: 1);
      data = (await image.toByteData())!;
    });

    // Scan the whole OTP row (all six boxes) for any red pixel.
    final row = Rect.fromLTRB(0, box.top - 4, image.width.toDouble(), box.bottom + 4);
    var red0 = 0;
    for (var y = row.top.floor(); y < row.bottom.ceil(); y++) {
      for (var x = 0; x < image.width; x++) {
        final o = (y * image.width + x) * 4;
        if (data.getUint8(o) > 200 &&
            data.getUint8(o + 1) < 80 &&
            data.getUint8(o + 2) < 80) {
          red0++;
        }
      }
    }
    expect(red0, 0, reason: 'themed TextField fill/border leaked over the boxes');

    // ...and the input is still there to take focus and text.
    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField), '123');
    await tester.pump();
    expect(find.text('3'), findsOneWidget);

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
