import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_model.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'auth_exception.dart';
// ...inside the NotificationService class:

/// Calls the sendNotification Cloud Function directly — for any
/// event that doesn't have a dedicated Firestore trigger. Most app
/// events don't need this: AppointmentService/CareRequestService
/// writes already fire onAppointmentCreated/onCareRequestCreated/
/// onCareRequestUpdated/onPatientRecordUpdated automatically.
Future<void> sendViaCloudFunction({
  required String recipientUid,
  required String type,
  required String title,
  required String body,
  Map<String, dynamic>? data,
}) async {
  try {
    await FirebaseFunctions.instance.httpsCallable('sendNotification').call({
      'recipientUid': recipientUid,
      'type': type,
      'title': title,
      'body': body,
      if (data != null) 'data': data,
    });
  } on FirebaseFunctionsException catch (e) {
    throw AuthException(e.message ?? 'Could not send notification.');
  }
}
class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> create({
    required String recipientUid,
    required String type,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    await _firestore.collection('notifications').add({
      'recipientUid': recipientUid, 'type': type, 'title': title, 'body': body,
      'read': false, 'data': data ?? {}, 'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<List<NotificationModel>> fetchForUser(String uid, {int limit = 50}) async {
    final snap = await _firestore.collection('notifications')
        .where('recipientUid', isEqualTo: uid).limit(limit).get();
    final items = snap.docs.map(NotificationModel.fromSnapshot).toList()
      ..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    return items;
  }
  /// Live unread count for the notification bell badge. A plain
  /// `snapshots()` on the filtered query (rather than a one-off
  /// `count()` read) so the badge updates itself the instant a
  /// notification is created or marked read elsewhere — no manual
  /// refresh/poll needed.
  Stream<int> watchUnreadCount(String uid) {
    return _firestore
        .collection('notifications')
        .where('recipientUid', isEqualTo: uid)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
  Future<void> markRead(String id) => _firestore.collection('notifications').doc(id).update({'read': true});
}