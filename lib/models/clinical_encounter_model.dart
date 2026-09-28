import 'package:cloud_firestore/cloud_firestore.dart';

enum EncounterStatus { scheduled, inProgress, completed, cancelled }

extension EncounterStatusX on EncounterStatus {
  String get storageValue => name;

  String get label {
    switch (this) {
      case EncounterStatus.scheduled:
        return 'Scheduled';
      case EncounterStatus.inProgress:
        return 'In Progress';
      case EncounterStatus.completed:
        return 'Completed';
      case EncounterStatus.cancelled:
        return 'Cancelled';
    }
  }

  static EncounterStatus fromStorageValue(String? value) {
    return EncounterStatus.values.firstWhere(
      (s) => s.storageValue == value,
      orElse: () => EncounterStatus.scheduled,
    );
  }
}

/// A single clinical interaction, stored at
/// `clinicalEncounters/{encounterId}`. Deliberately created by the
/// practitioner — never auto-generated from a care request or an
/// appointment. May reference either/both to preserve traceability.
class ClinicalEncounterModel {
  final String encounterId;
  final String patientUid;
  final String practitionerUid;
  final String practitionerRole; // 'doctor' or 'nurse'
  final String? careRequestId;
  final String? appointmentId;
  final String encounterType; // e.g. 'consultation', 'assessment', 'follow-up'
  final String chiefConcern;
  final String? clinicalNotes;
  final String? assessment;
  final EncounterStatus status;
  final bool followUpRequired;
  final String? followUpType;
  final DateTime? followUpDate;
  final String? followUpLocation;
  final String createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ClinicalEncounterModel({
    required this.encounterId,
    required this.patientUid,
    required this.practitionerUid,
    required this.practitionerRole,
    this.careRequestId,
    this.appointmentId,
    required this.encounterType,
    required this.chiefConcern,
    this.clinicalNotes,
    this.assessment,
    this.status = EncounterStatus.completed,
    this.followUpRequired = false,
    this.followUpType,
    this.followUpDate,
    this.followUpLocation,
    required this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toCreateMap() {
    return {
      'patientUid': patientUid,
      'practitionerUid': practitionerUid,
      'practitionerRole': practitionerRole,
      'careRequestId': careRequestId,
      'appointmentId': appointmentId,
      'encounterType': encounterType,
      'chiefConcern': chiefConcern,
      'clinicalNotes': clinicalNotes,
      'assessment': assessment,
      'status': status.storageValue,
      'followUpRequired': followUpRequired,
      'followUpType': followUpType,
      'followUpDate':
          followUpDate != null ? Timestamp.fromDate(followUpDate!) : null,
      'followUpLocation': followUpLocation,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory ClinicalEncounterModel.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    if (data == null) {
      throw StateError('Clinical encounter ${doc.id} has no data.');
    }
    return ClinicalEncounterModel(
      encounterId: doc.id,
      patientUid: data['patientUid'] as String? ?? '',
      practitionerUid: data['practitionerUid'] as String? ?? '',
      practitionerRole: data['practitionerRole'] as String? ?? '',
      careRequestId: data['careRequestId'] as String?,
      appointmentId: data['appointmentId'] as String?,
      encounterType: data['encounterType'] as String? ?? 'consultation',
      chiefConcern: data['chiefConcern'] as String? ?? '',
      clinicalNotes: data['clinicalNotes'] as String?,
      assessment: data['assessment'] as String?,
      status: EncounterStatusX.fromStorageValue(data['status'] as String?),
      followUpRequired: data['followUpRequired'] as bool? ?? false,
      followUpType: data['followUpType'] as String?,
      followUpDate: (data['followUpDate'] as Timestamp?)?.toDate(),
      followUpLocation: data['followUpLocation'] as String?,
      createdBy: data['createdBy'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}