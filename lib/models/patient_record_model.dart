import 'package:cloud_firestore/cloud_firestore.dart';

enum PatientStatus { notAdmitted, admitted, discharged }

extension PatientStatusX on PatientStatus {
  String get storageValue => name;

  String get label {
    switch (this) {
      case PatientStatus.notAdmitted:
        return 'Not Admitted';
      case PatientStatus.admitted:
        return 'Admitted';
      case PatientStatus.discharged:
        return 'Discharged';
    }
  }

  static PatientStatus fromStorageValue(String? value) {
    return PatientStatus.values.firstWhere(
      (s) => s.storageValue == value,
      orElse: () => PatientStatus.notAdmitted,
    );
  }
}

enum AdmissionType { shortStay, normal }

extension AdmissionTypeX on AdmissionType {
  String get storageValue => name;

  String get label =>
      this == AdmissionType.shortStay ? 'Short Stay' : 'Normal';

  static AdmissionType? fromStorageValue(String? value) {
    if (value == null) return null;

    return AdmissionType.values
        .where((t) => t.storageValue == value)
        .cast<AdmissionType?>()
        .firstWhere(
          (_) => true,
          orElse: () => null,
        );
  }
}

/// Clinical/administrative record stored at `patients/{patientUid}`.
/// Created at PATIENT REGISTRATION time (not only on admission) so
/// [profileCompleted] and [primaryHealthcareCenter] can exist from
/// day one. Holds no identity fields (name/phone/email) — those stay
/// in `users/{uid}` only.
class PatientRecordModel {
  final String patientUid;
  final PatientStatus status;
  final String? primaryHealthcareCenter;
  final bool profileCompleted;
  final DateTime? admissionDate;
  final DateTime? dischargeDate;
  final String? dischargeSummary;
  final String? assignedDoctorUid;
  final String? assignedNurseUid;
  final List assignedStaffUids;
  final String? amaudoFacility;
  final String? clinicalSummary;

  final AdmissionType? admissionType;
  final String? admittedByUid;
  final bool adminReferralRequired;
  final String? adminReferralNote;

  final bool dischargeRequested;
  final String? dischargeRequestedByUid;
  final DateTime? dischargeRequestedAt;

  final String createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool hasAccount;
  final String? unregisteredFullName;
  final String? unregisteredPhone;
  const PatientRecordModel({
    required this.patientUid,
    this.status = PatientStatus.notAdmitted,
    this.primaryHealthcareCenter,
    this.profileCompleted = false,
    this.admissionDate,
    this.dischargeDate,
    this.dischargeSummary,
    this.assignedDoctorUid,
    this.assignedNurseUid,
    this.assignedStaffUids = const [],
    this.amaudoFacility,
    this.clinicalSummary,
    this.admissionType,
    this.admittedByUid,
    this.adminReferralRequired = false,
    this.adminReferralNote,
    this.dischargeRequested = false,
    this.dischargeRequestedByUid,
    this.dischargeRequestedAt,
    required this.createdBy,
    this.createdAt,
    this.updatedAt,
    this.hasAccount = true,
    this.unregisteredFullName,
    this.unregisteredPhone,
  });

  /// Profile completion currently means: Primary Healthcare Center is
  /// on file. Never requires diagnosis/medication/admission fields.
  static bool computeProfileCompleted({
    String? primaryHealthcareCenter,
  }) {
    return primaryHealthcareCenter != null &&
        primaryHealthcareCenter.trim().isNotEmpty;
  }

  Map<String, dynamic> toCreateMap({required String createdByUid}) {
    return {
      'patientUid': patientUid,
      'status': status.storageValue,
      'primaryHealthcareCenter': primaryHealthcareCenter,
      'profileCompleted':
          computeProfileCompleted(
        primaryHealthcareCenter: primaryHealthcareCenter,
      ),
      'admissionDate': null,
      'dischargeDate': null,
      'dischargeSummary': null,
      'assignedDoctorUid': null,
      'assignedNurseUid': null,
      'assignedStaffUids': [],
      'amaudoFacility': null,
      'clinicalSummary': null,
      'createdBy': createdByUid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory PatientRecordModel.fromMap(
    String patientUid,
    Map<String, dynamic> map,
  ) {
    return PatientRecordModel(
      patientUid: patientUid,
      status: PatientStatusX.fromStorageValue(
        map['status'] as String?,
      ),
      primaryHealthcareCenter:
          map['primaryHealthcareCenter'] as String?,
      profileCompleted:
          map['profileCompleted'] as bool? ?? false,
      admissionDate:
          (map['admissionDate'] as Timestamp?)?.toDate(),
      dischargeDate:
          (map['dischargeDate'] as Timestamp?)?.toDate(),
      dischargeSummary:
          map['dischargeSummary'] as String?,
      assignedDoctorUid:
          map['assignedDoctorUid'] as String?,
      assignedNurseUid:
          map['assignedNurseUid'] as String?,
      assignedStaffUids:
          (map['assignedStaffUids'] as List?)
                  ?.map((e) => e.toString())
                  .toList() ??
              const [],
      amaudoFacility:
          map['amaudoFacility'] as String?,
      clinicalSummary:
          map['clinicalSummary'] as String?,

      admissionType:
          AdmissionTypeX.fromStorageValue(
        map['admissionType'] as String?,
      ),
      admittedByUid:
          map['admittedByUid'] as String?,
      adminReferralRequired:
          map['adminReferralRequired'] as bool? ?? false,
      adminReferralNote:
          map['adminReferralNote'] as String?,

      dischargeRequested:
          map['dischargeRequested'] as bool? ?? false,
      dischargeRequestedByUid:
          map['dischargeRequestedByUid'] as String?,
      dischargeRequestedAt:
          (map['dischargeRequestedAt'] as Timestamp?)?.toDate(),

      createdBy:
          map['createdBy'] as String? ?? '',
      createdAt:
          (map['createdAt'] as Timestamp?)?.toDate(),
      updatedAt:
          (map['updatedAt'] as Timestamp?)?.toDate(),
          hasAccount: map['hasAccount'] as bool? ?? true,
          unregisteredFullName: map['unregisteredFullName'] as String?,
          unregisteredPhone: map['unregisteredPhone'] as String?,
    );
  }

  factory PatientRecordModel.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    if (data == null) {
      throw StateError(
        'Patient record ${doc.id} has no data.',
      );
    }
    return PatientRecordModel.fromMap(doc.id, data);
  }
}

class AdmissionHistoryEntry {
  final String type;
  final DateTime dateTime;
  final String performedBy;
  final String? note;
  final DateTime? createdAt;

  const AdmissionHistoryEntry({
    required this.type,
    required this.dateTime,
    required this.performedBy,
    this.note,
    this.createdAt,
  });

  factory AdmissionHistoryEntry.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return AdmissionHistoryEntry(
      type: data['type'] as String? ?? 'admission',
      dateTime: (data['dateTime'] as Timestamp).toDate(),
      performedBy: data['performedBy'] as String? ?? '',
      note: data['note'] as String?,
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}