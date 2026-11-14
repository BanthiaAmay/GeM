import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gem/core/models.dart';
import 'package:gem/core/theme.dart';
import 'package:gem/data/app_store.dart';
import 'package:gem/features/home_page.dart';
import 'package:gem/features/scroll_hint.dart';

// The bottom nav has five equal tabs, so at 320px each label gets about
// 64px. Measured with the app's real bundled fonts (not the square test
// font), every label must fit on one line, unclipped, in all 9 languages.
// Latin text is measured with the Noto Latin glyphs inside Noto Sans
// Devanagari, which run wider than the iOS system font the app asks for,
// so a pass here leaves a safe margin.
Future<void> _loadFont(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    final bytes = File(f).readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}

void main() {
  ScrollMoreHint.debugDisableBounce = true;

  setUpAll(() async {
    for (final script in [
      'Devanagari',
      'Bengali',
      'Gujarati',
      'Gurmukhi',
      'Tamil',
      'Telugu',
      'Kannada',
    ]) {
      await _loadFont('NotoSans$script', ['assets/fonts/NotoSans$script.ttf']);
    }
  });

  testWidgets('bottom nav labels fit 320–360px in every language', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final s = AppStore(await SharedPreferences.getInstance());
    addTearDown(tester.view.reset);
    final cut = <String>[];
    for (final width in [320.0, 360.0]) {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      for (final lang in supportedLanguages) {
        s.setLanguage(lang[0]);
        await tester.pumpWidget(
          MaterialApp(theme: saathiTheme(), home: HomePage(store: s)),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '${lang[0]} @ $width');
        for (final tab in [
          'home',
          'tools',
          'calculators',
          'financialHub',
          'profile',
        ]) {
          final label = find.byKey(ValueKey('nav-label-$tab'));
          expect(label, findsOneWidget, reason: tab);
          final text = tester.renderObject<RenderParagraph>(label);
          // Measure as the selected (bold) tab: the widest it ever gets.
          final painter = TextPainter(
            text: TextSpan(
              text: text.text.toPlainText(),
              style: AppText.label.copyWith(
                fontFamily: 'NotoSansDevanagari',
                fontFamilyFallback: saathiTheme().textTheme.bodyMedium
                    ?.fontFamilyFallback,
                fontWeight: FontWeight.w700,
              ),
            ),
            textDirection: TextDirection.ltr,
            textScaler: TextScaler.noScaling,
          )..layout();
          final room = text.constraints.maxWidth;
          if (painter.width > room) {
            cut.add(
              '${lang[0]} @ $width: $tab "${text.text.toPlainText()}" '
              '${painter.width.toStringAsFixed(1)} > '
              '${room.toStringAsFixed(1)}',
            );
          }
          painter.dispose();
        }
      }
    }
    expect(cut, isEmpty, reason: cut.join('\n'));
  });
}
