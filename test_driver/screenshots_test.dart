// Host side of the App Store screenshot run (tool/screenshots.sh): opens each
// screen in the running app, waits for live data, then saves a simulator
// screenshot (status bar included) to $SCREENSHOT_DIR/<NN>-<screen>.png.
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';

const _screens = [
  ('01-home', '/home'),
  ('02-bids', '/bids'),
  ('03-news', '/news'),
  ('04-trainings', '/trainings'),
  ('05-saathi', '/saathi'),
  ('06-welcome', '/welcome'),
];

Future<void> main() async {
  final device = Platform.environment['SIM_UDID']!;
  final dir = Platform.environment['SCREENSHOT_DIR'] ?? 'build/screenshots';
  Directory(dir).createSync(recursive: true);
  final driver = await FlutterDriver.connect();
  await Future<void>.delayed(const Duration(seconds: 6)); // splash → Home
  for (final (name, route) in _screens) {
    await driver.requestData(route);
    await Future<void>.delayed(const Duration(seconds: 7)); // data + images
    final shot = await Process.run('xcrun', [
      'simctl', 'io', device, 'screenshot', '$dir/$name.png', //
    ]);
    stdout.writeln(shot.exitCode == 0 ? 'Saved $dir/$name.png' : shot.stderr);
  }
  await driver.close();
}
