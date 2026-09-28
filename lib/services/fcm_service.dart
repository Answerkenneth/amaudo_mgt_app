import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'local_notification_service.dart';
import 'notification_router.dart';

/// Owns all FCM logic for the app — requesting permission, obtaining
/// the device's push token, keeping users/{uid}.fcmToken current on
/// Firestore, reacting to token refresh, and routing a tapped
/// notification (foreground, backgrounded, or launched-from-terminated)
/// to the exact screen it refers to via NotificationRouter. Nothing
/// else in the app should touch FirebaseMessaging directly; this is
/// the one place that does.
class FcmService {
  FcmService._internal();
  static final FcmService instance = FcmService._internal();

  static const String _usersCollection = 'users';

  // WEB ONLY: getToken() on web requires a VAPID key from Firebase
  // Console -> Project Settings -> Cloud Messaging -> Web
  // configuration -> "Web Push certificates". Token fetch on web is
  // skipped (not crashed) until this is filled in — see the guard
  // below.
  static const String _webVapidKey = 'REPLACE_WITH_YOUR_FCM_WEB_VAPID_KEY';

  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _onMessageSubscription;
  StreamSubscription<RemoteMessage>? _onMessageOpenedAppSubscription;
  bool _oneTimeSetupDone = false;
  bool _initialMessageHandled = false;

  /// Call after a successful signup/login, and once at startup if a
  /// user is already signed in (app_shell.dart does both, since it's
  /// the landing point for each). Safe to call every time that
  /// happens — permission request and the message listeners are only
  /// ever set up once per app process, but the token is always
  /// re-fetched and re-saved against whichever uid is signed in at
  /// call time, so a second user signing in later in the same
  /// session still gets their own token saved correctly.
  Future<void> initialize() async {
    if (!_oneTimeSetupDone) {
      _oneTimeSetupDone = true;
      try {
        final messaging = FirebaseMessaging.instance;

        // iOS/web actually prompt; Android <13 auto-grants silently,
        // Android 13+ shows the system prompt. A denial is a normal
        // outcome, not an error — _fetchAndSaveToken() below simply
        // won't find a token to save in that case.
        await messaging.requestPermission(alert: true, badge: true, sound: true);

        _tokenRefreshSubscription ??= messaging.onTokenRefresh.listen(
          _saveToken,
          onError: (Object e) => debugPrint('FcmService: onTokenRefresh error: $e'),
        );

        // App open and in the foreground when the push arrives: FCM
        // does NOT show a system-tray notification in this case, so
        // this is the one gap LocalNotificationService.showNow()
        // fills — and its payload carries the same {type, ...data}
        // a background/terminated tap gets, so tapping it deep links
        // identically.
        _onMessageSubscription ??= FirebaseMessaging.onMessage.listen(
          _handleForegroundMessage,
          onError: (Object e) => debugPrint('FcmService: onMessage error: $e'),
        );

        // App was backgrounded (not terminated) and the user tapped
        // the system-tray notification to bring it back to the
        // foreground.
        _onMessageOpenedAppSubscription ??=
            FirebaseMessaging.onMessageOpenedApp.listen(
          (message) => NotificationRouter.routeFromRemoteData(message.data),
          onError: (Object e) =>
              debugPrint('FcmService: onMessageOpenedApp error: $e'),
        );
      } catch (e) {
        // FCM being unavailable/misconfigured must never crash or
        // block sign-in/app startup.
        debugPrint('FcmService: one-time setup failed: $e');
      }
    }

    await _fetchAndSaveToken();
    await _handleInitialMessage();
  }

  /// App was fully terminated and launched by tapping the
  /// notification. Only ever meaningful once per process — checked
  /// again on a later initialize() call (e.g. a second sign-in in
  /// the same session) is harmless since getInitialMessage() itself
  /// only ever returns the message that launched the app, but the
  /// guard avoids re-navigating if initialize() is called twice in
  /// quick succession before the first pass completes.
  Future<void> _handleInitialMessage() async {
    if (_initialMessageHandled) return;
    _initialMessageHandled = true;
    try {
      final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        await NotificationRouter.routeFromRemoteData(initialMessage.data);
      }
    } catch (e) {
      debugPrint('FcmService: getInitialMessage failed: $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;
    final payload = NotificationRouter.encodePayload(
      type: (message.data['type'] as String?) ?? '',
      data: message.data,
    );
    LocalNotificationService.instance.showNow(
      title: notification.title ?? '',
      body: notification.body ?? '',
      payload: payload,
    );
  }

  Future<void> _fetchAndSaveToken() async {
    try {
      final token = kIsWeb
          ? (_webVapidKey.startsWith('REPLACE_WITH_')
              ? null
              : await FirebaseMessaging.instance.getToken(vapidKey: _webVapidKey))
          : await FirebaseMessaging.instance.getToken();

      if (token != null) await _saveToken(token);
    } catch (e) {
      debugPrint('FcmService: failed to get token: $e');
    }
  }

  Future<void> _saveToken(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    // Never write a token without an authenticated uid.
    if (uid == null) return;

    try {
      await FirebaseFirestore.instance.collection(_usersCollection).doc(uid).update({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('FcmService: failed to save token: $e');
    }
  }
}
