import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/care_request_model.dart';
import '../models/notification_model.dart';
import '../models/user_model.dart';
import 'auth_service.dart';
import 'care_request_service.dart';
import 'navigation_service.dart';
import '../screens/appointments/appointment_detail_screen.dart';
import '../screens/assignment/approved_requests_screen.dart';
import '../screens/care/get_help_screen.dart';
import '../screens/clinical/care_request_review_screen.dart';
import '../screens/director/director_request_review_screen.dart';
import '../screens/patients/patient_profile_screen.dart';
import '../screens/requests/review_feedback_screen.dart';

/// Single source of truth for "a notification was tapped -> open the
/// exact record it refers to". Used by:
///   - NotificationsScreen (in-app bell/list tap)
///   - FcmService (system-tray tap while backgrounded, tap while the
///     app was fully closed, and a locally-shown foreground push)
///
/// Never opens the general dashboard: every known notification type
/// resolves to an existing detail screen for the exact underlying
/// record, self-loaded by ID exactly like every other push-to-detail
/// screen already in this app (see AppointmentDetailScreen,
/// PatientProfileScreen, DirectorRequestReviewScreen, etc). An
/// unrecognized/legacy notification (no `data`, or an id that no
/// longer resolves) is a no-op — the app is simply left on whatever
/// screen it was already showing, rather than forcing navigation
/// somewhere irrelevant.
class NotificationRouter {
  NotificationRouter._();

  // Prevents two near-simultaneous triggers (e.g. a background tap
  // and a stray onMessage for the same push) from stacking two
  // pushes of the same screen.
  static bool _routing = false;

  static Future<void> routeFromNotification(NotificationModel notification) {
    return _route(type: notification.type, data: notification.data);
  }

  /// [rawData] is a FCM RemoteMessage.data map — every value is a
  /// String, and `type` travels inside it (see functions/notifications.js).
  static Future<void> routeFromRemoteData(Map<String, dynamic> rawData) {
    final type = rawData['type'] as String?;
    if (type == null || type.isEmpty) return Future.value();
    return _route(type: type, data: rawData);
  }

  /// JSON-encodes {type, ...data} for use as a flutter_local_notifications
  /// payload (see LocalNotificationService.showNow / FcmService's
  /// foreground onMessage handling).
  static String encodePayload({
    required String type,
    required Map<String, dynamic> data,
  }) {
    return jsonEncode({'type': type, ...data});
  }

  /// Counterpart to [encodePayload] — decodes a locally-shown
  /// notification's tap payload and routes it.
  static Future<void> routeFromPayload(String payload) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map) return Future.value();
      return routeFromRemoteData(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return Future.value();
    }
  }

  static Future<void> _route({
    required String type,
    required Map<String, dynamic> data,
  }) async {
    if (_routing) return;
    _routing = true;
    try {
      switch (type) {
        case 'appointment':
          await _openAppointment(data);
          break;
        case 'careRequest':
          await _openCareRequest(data);
          break;
        case 'admission':
        case 'discharge':
          await _openPatient(data);
          break;
        default:
          // Unknown type: nothing to safely route to.
          break;
      }
    } catch (_) {
      // A deep-link failure (record deleted, permission denied,
      // navigator not ready, etc.) must never crash the app — the
      // person simply stays on whatever screen they were on.
    } finally {
      _routing = false;
    }
  }

  static String? _string(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value == null) return null;
    final str = value.toString();
    return str.isEmpty ? null : str;
  }

  /// Waits (briefly) for the root Navigator to be attached — needed
  /// because a terminated-app launch can call in before the first
  /// frame has built the widget tree the navigatorKey attaches to.
  static Future<NavigatorState?> _navigator() async {
    for (var attempt = 0; attempt < 30; attempt++) {
      final state = navigatorKey.currentState;
      if (state != null) return state;
      await Future.delayed(const Duration(milliseconds: 100));
    }
    return null;
  }

  static Future<void> _openAppointment(Map<String, dynamic> data) async {
    final appointmentId = _string(data, 'appointmentId');
    if (appointmentId == null) return;
    final nav = await _navigator();
    if (nav == null) return;
    nav.push(
      MaterialPageRoute(
        builder: (_) => AppointmentDetailScreen(appointmentId: appointmentId),
      ),
    );
  }

  static Future<void> _openPatient(Map<String, dynamic> data) async {
    final patientUid = _string(data, 'patientUid');
    if (patientUid == null) return;
    final nav = await _navigator();
    if (nav == null) return;
    nav.push(
      MaterialPageRoute(
        builder: (_) => PatientProfileScreen(patientUid: patientUid),
      ),
    );
  }

  /// Role-aware: a single 'careRequest' notification type covers the
  /// request itself, Director/CHP review, Admin/CMHP Coordinator
  /// review feedback, referral, and approval — each role acts on it
  /// through a different existing screen, so the recipient's current
  /// role (and, for the assigned practitioner, whether they've
  /// already recorded a decision) decides which one opens.
  static Future<void> _openCareRequest(Map<String, dynamic> data) async {
    final requestId = _string(data, 'careRequestId');
    if (requestId == null) return;

    final user = await AuthService.instance.fetchCurrentUserProfile();
    if (user == null) return;

    CareRequestModel? request;
    try {
      request = await CareRequestService.instance.fetchRequestById(requestId);
    } catch (_) {
      // Fall through to role-based defaults below.
    }

    final nav = await _navigator();
    if (nav == null) return;

    // Whoever accepted the request (doctor/nurse, or a CHP acting in
    // that capacity) records their next-step decision here,
    // regardless of role — this takes priority over the role
    // defaults below.
    if (request != null && request.acceptedByUid == user.uid) {
      final acceptedRequest = request;
      nav.push(
        MaterialPageRoute(
          builder: (_) => CareRequestReviewScreen(request: acceptedRequest),
        ),
      );
      return;
    }

    switch (user.role) {
      case UserRole.patient:
        nav.push(
          MaterialPageRoute(
            builder: (_) => GetHelpScreen(patientUid: user.uid),
          ),
        );
        break;

      case UserRole.director:
      case UserRole.ceo:
      case UserRole.chp:
        nav.push(
          MaterialPageRoute(
            builder: (_) => DirectorRequestReviewScreen(requestId: requestId),
          ),
        );
        break;

      case UserRole.admin:
      case UserRole.cmhpCoordinator:
        final sentToMe = user.role == UserRole.admin
            ? (request?.reviewSentToAdmin ?? false)
            : (request?.reviewSentToCmhp ?? false);
        if (sentToMe) {
          nav.push(
            MaterialPageRoute(
              builder: (_) => ReviewFeedbackScreen(requestId: requestId),
            ),
          );
        } else {
          // No single-record screen exists for "approved, awaiting
          // assignment" — this is the exact filtered list the
          // notification refers to (director-approved requests
          // awaiting Admin/CMHP Coordinator assignment).
          nav.push(
            MaterialPageRoute(
              builder: (_) => const ApprovedRequestsScreen(),
            ),
          );
        }
        break;

      default:
        break;
    }
  }
}