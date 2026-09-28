import 'package:flutter/material.dart';

/// App-wide [Navigator] key, needed so notification deep links can
/// push a screen from places that have no [BuildContext] of their
/// own — a background/terminated-state FCM tap, in particular,
/// happens outside any widget's build method. Every other part of
/// the app should keep using its local [BuildContext] as normal;
/// this key exists solely for NotificationRouter.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();