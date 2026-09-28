import 'package:cloud_firestore/cloud_firestore.dart';

enum AppointmentStatus { scheduled, completed, cancelled, missed }

enum AppointmentType { clinical, medication }

extension AppointmentTypeX on AppointmentType {
  String get storageValue => name;

  String get label {
    switch (this) {
      case AppointmentType.clinical:
        return 'Clinical';
      case AppointmentType.medication:
        return 'Medication';
    }
  }

  static AppointmentType fromStorageValue(String? value) {
    // Default-safe: every appointment created before this field
    // existed has no 'type' key, and is a clinical appointment.
    return AppointmentType.values.firstWhere(
      (t) => t.storageValue == value,
      orElse: () => AppointmentType.clinical,
    );
  }
}

extension AppointmentStatusX on AppointmentStatus {
  String get storageValue => name;

  String get label {
    switch (this) {
      case AppointmentStatus.scheduled:
        return 'Scheduled';
      case AppointmentStatus.completed:
        return 'Completed';
      case AppointmentStatus.cancelled:
        return 'Cancelled';
      case AppointmentStatus.missed:
        return 'Did Not Occur';
    }
  }

  static AppointmentStatus fromStorageValue(String? value) {
    return AppointmentStatus.values.firstWhere(
      (s) => s.storageValue == value,
      orElse: () => AppointmentStatus.scheduled,
    );
  }
}

/// Stored at `appointments/{appointmentId}`. [occurredAt] and
/// [outcomeRecordedBy] are set only when the practitioner explicitly
/// confirms whether the appointment happened — the system never
/// infers this from the scheduled time passing. Holds no identity
/// fields — those are resolved for display via
/// AuthService.fetchUserProfileByUid.
class AppointmentModel {
  final String appointmentId;
  final String patientUid;
  final String practitionerUid;
  final String practitionerRole; // 'doctor' or 'nurse'
  final String purpose;
  final AppointmentType type;
  final String? healthcareCenter;
  final String? location;
  final DateTime scheduledAt;
  final AppointmentStatus status;
  final DateTime? occurredAt;
  final String? outcomeRecordedBy;
  final String? careRequestId;
  final String createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AppointmentModel({
    required this.appointmentId,
    required this.patientUid,
    required this.practitionerUid,
    required this.practitionerRole,
    required this.purpose,
    this.type = AppointmentType.clinical,
    this.healthcareCenter,
    this.location,
    required this.scheduledAt,
    this.status = AppointmentStatus.scheduled,
    this.occurredAt,
    this.outcomeRecordedBy,
    this.careRequestId,
    required this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toCreateMap() {
    return {
      'patientUid': patientUid,
      'practitionerUid': practitionerUid,
      'practitionerRole': practitionerRole,
      'purpose': purpose,
      'type': type.storageValue,
      'healthcareCenter': healthcareCenter,
      'location': location,
      'scheduledAt': Timestamp.fromDate(scheduledAt),
      'status': AppointmentStatus.scheduled.storageValue,
      'occurredAt': null,
      'outcomeRecordedBy': null,
      'careRequestId': careRequestId,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory AppointmentModel.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    if (data == null) {
      throw StateError('Appointment ${doc.id} has no data.');
    }
    return AppointmentModel(
      appointmentId: doc.id,
      patientUid: data['patientUid'] as String? ?? '',
      practitionerUid: data['practitionerUid'] as String? ?? '',
      practitionerRole: data['practitionerRole'] as String? ?? '',
      purpose: data['purpose'] as String? ?? '',
      type: AppointmentTypeX.fromStorageValue(data['type'] as String?),
      healthcareCenter: data['healthcareCenter'] as String?,
      location: data['location'] as String?,
      scheduledAt:
          (data['scheduledAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: AppointmentStatusX.fromStorageValue(data['status'] as String?),
      occurredAt: (data['occurredAt'] as Timestamp?)?.toDate(),
      outcomeRecordedBy: data['outcomeRecordedBy'] as String?,
      careRequestId: data['careRequestId'] as String?,
      createdBy: data['createdBy'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}