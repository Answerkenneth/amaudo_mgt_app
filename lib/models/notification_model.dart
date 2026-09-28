import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String recipientUid;
  final String type; // 'appointment' | 'careRequest' | 'admission' | 'discharge'
  final String title;
  final String body;
  final bool read;
  final DateTime? createdAt;

  /// Related-record identifiers (e.g. {'appointmentId': '...'} or
  /// {'careRequestId': '...'} or {'patientUid': '...'}) used to deep
  /// link a tap on this notification to the exact screen/record it
  /// refers to. Always a Map — empty for notifications that predate
  /// this field or that carry no related record. See
  /// NotificationRouter.
  final Map<String, dynamic> data;

  const NotificationModel({
    required this.id, required this.recipientUid, required this.type,
    required this.title, required this.body, this.read = false, this.createdAt,
    this.data = const {},
  });

  factory NotificationModel.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return NotificationModel(
      id: doc.id, recipientUid: d['recipientUid'] ?? '', type: d['type'] ?? '',
      title: d['title'] ?? '', body: d['body'] ?? '', read: d['read'] ?? false,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      data: Map<String, dynamic>.from(d['data'] as Map? ?? const {}),
    );
  }
}