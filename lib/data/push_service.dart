import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../firebase_options.dart';
import 'app_store.dart';

/// Firebase Cloud Messaging for bid alerts on Android and iOS. Stays off on
/// web and until `flutterfire configure` replaces lib/firebase_options.dart;
/// the server sends the notifications, this only registers the device.
class PushService implements PushBridge {
  final AppStore store;
  PushService(this.store);

  /// A notification arrived while the app was open (the OS shows none).
  void Function(RemoteMessage message)? onForeground;

  /// The user tapped a notification while the app was running.
  void Function(RemoteMessage message)? onOpened;

  bool _ready = false;
  String? _registered;
  RemoteMessage? _launch;

  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  @override
  bool get supported => _ready;

  Future<void> init() async {
    final mobile =
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    if (kIsWeb || !mobile) return;
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _launch = await _messaging.getInitialMessage();
    } catch (_) {
      return; // Not configured: the in-app inbox still works.
    }
    _ready = true;
    FirebaseMessaging.onMessage.listen((m) => onForeground?.call(m));
    FirebaseMessaging.onMessageOpenedApp.listen((m) => onOpened?.call(m));
    // FCM identifies this install by its Firebase Installation ID (FID); it
    // arrives here after register() and whenever it changes.
    _messaging.onRegistered.listen((fid) async {
      try {
        await _register(fid);
      } catch (_) {
        // Retried on the next launch or sign-in.
      }
    });
  }

  /// Every alert opens the inbox; the payload never chooses a route.
  @override
  String? takeLaunchRoute() {
    final launched = _launch != null;
    _launch = null;
    return launched ? '/alerts' : null;
  }

  @override
  Future<bool> enable() async {
    if (!_ready || !store.signedIn) return false;
    try {
      if (!_allowed(await _messaging.requestPermission())) return false;
      await _registerCurrent();
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> refresh() async {
    if (!_ready || !store.signedIn) return;
    try {
      if (_allowed(await _messaging.getNotificationSettings())) {
        await _registerCurrent();
      }
    } catch (_) {
      // Retried on the next launch or sign-in.
    }
  }

  @override
  Future<void> detach() async {
    if (!_ready) return;
    final fid = _registered;
    _registered = null;
    if (fid != null) await store.unregisterPushDevice(fid);
    // Retires this FID, so the next account on the device gets a fresh one
    // and the server drops any copy it still holds on the next send.
    await _messaging.unregister();
  }

  bool _allowed(NotificationSettings settings) =>
      settings.authorizationStatus == AuthorizationStatus.authorized ||
      settings.authorizationStatus == AuthorizationStatus.provisional;

  Future<void> _registerCurrent() async {
    // Already known this session (sign-out clears it): re-save it so the
    // server has this account and the current language.
    final known = _registered;
    if (known != null) return _register(known);
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      // FCM needs the APNs token first; it can lag the permission prompt.
      for (var i = 0; i < 5 && await _messaging.getAPNSToken() == null; i++) {
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }
    await _messaging.register(); // onRegistered delivers the FID.
  }

  Future<void> _register(String fid) async {
    if (!store.signedIn) return;
    await store.registerPushDevice(
      fid,
      defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
    );
    _registered = fid;
  }
}
