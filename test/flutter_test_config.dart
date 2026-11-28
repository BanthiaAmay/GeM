// Runs before every test file. `flutter test` has no audio plugin, so UI
// sounds (FactToast, section-complete chime) are switched off for tests.
import 'dart:async';

import 'package:gem/core/sounds.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  Sounds.enabled = false;
  await testMain();
}
