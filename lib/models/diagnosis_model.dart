import 'package:cloud_firestore/cloud_firestore.dart';

enum DiagnosisCategory {
  anxietyDisorders,
  depressiveDisorders,
  adhd,
  ptsd,
  schizophrenia,
  bipolarDisorders,
  bpd,
  epilepsy,
  other,
}

extension DiagnosisCategoryX on DiagnosisCategory {
  String get storageValue => name;

  String get label {
    switch (this) {
      case DiagnosisCategory.anxietyDisorders:
        return 'Anxiety disorders';
      case DiagnosisCategory.depressiveDisorders:
        return 'Depressive disorders';
      case DiagnosisCategory.adhd:
        return 'Attention deficit, hyperactivity disorders (ADHD)';
      case DiagnosisCategory.ptsd:
        return 'Post-traumatic stress disorders (PTSD)';
      case DiagnosisCategory.schizophrenia:
        return 'Schizophrenia';
      case DiagnosisCategory.bipolarDisorders:
        return 'Bipolar disorders';
      case DiagnosisCategory.bpd:
        return 'Borderline personality disorders (BPD)';
      case DiagnosisCategory.epilepsy:
        return 'Epilepsy';
      case DiagnosisCategory.other:
        return 'Other illness';
    }
  }

  static DiagnosisCategory fromStorageValue(String? value) {
    return DiagnosisCategory.values.firstWhere(
      (c) => c.storageValue == value,
      orElse: () => DiagnosisCategory.other,
    );
  }
}

enum DiagnosisStatus { active, resolved, monitoring }

extension DiagnosisStatusX on DiagnosisStatus {
  String get storageValue => name;

  String get label {
    switch (this) {
      case DiagnosisStatus.active:
        return 'Active';
      case DiagnosisStatus.resolved:
        return 'Resolved';
      case DiagnosisStatus.monitoring:
        return 'Monitoring';
    }
  }

  static DiagnosisStatus fromStorageValue(String? value) {
    return DiagnosisStatus.values.firstWhere(
      (s) => s.storageValue == value,
      orElse: () => DiagnosisStatus.active,
    );
  }
}

/// Stored at `diagnoses/{diagnosisId}`. [category] is always one of
/// the fixed clinical options, or [DiagnosisCategory.other] with
/// [otherIllnessText] describing a condition outside that list.
/// [patientCountry]/[patientState]/[patientLga]/[healthcareCenter]
/// are denormalized from the patient's own users/{uid} and
/// patients/{uid} documents AT CREATION TIME, so Director/Admin/CMHP
/// Coordinator analytics can aggregate by illness x location without
/// per-document joins.
class DiagnosisModel {
  final String diagnosisId;
  final String patientUid;
  final String encounterId;
  final String diagnosedByUid;
  final String diagnosedByRole;
  final DiagnosisCategory category;
  final String? otherIllnessText;
  final String diagnosisName;
  final String? diagnosisCode;
  final String? description;
  final DiagnosisStatus status;
  final String? patientCountry;
  final String? patientState;
  final String? patientLga;
  final String? healthcareCenter;
  final DateTime? diagnosedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const DiagnosisModel({
    required this.diagnosisId,
    required this.patientUid,
    required this.encounterId,
    required this.diagnosedByUid,
    required this.diagnosedByRole,
    required this.category,
    this.otherIllnessText,
    required this.diagnosisName,
    this.diagnosisCode,
    this.description,
    this.status = DiagnosisStatus.active,
    this.patientCountry,
    this.patientState,
    this.patientLga,
    this.healthcareCenter,
    this.diagnosedAt,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toCreateMap() {
    return {
      'patientUid': patientUid,
      'encounterId': encounterId,
      'diagnosedByUid': diagnosedByUid,
      'diagnosedByRole': diagnosedByRole,
      'category': category.storageValue,
      'otherIllnessText': otherIllnessText,
      'diagnosisName': diagnosisName,
      'diagnosisCode': diagnosisCode,
      'description': description,
      'status': status.storageValue,
      'patientCountry': patientCountry,
      'patientState': patientState,
      'patientLga': patientLga,
      'healthcareCenter': healthcareCenter,
      'diagnosedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory DiagnosisModel.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    if (data == null) {
      throw StateError('Diagnosis ${doc.id} has no data.');
    }
    return DiagnosisModel(
      diagnosisId: doc.id,
      patientUid: data['patientUid'] as String? ?? '',
      encounterId: data['encounterId'] as String? ?? '',
      diagnosedByUid: data['diagnosedByUid'] as String? ?? '',
      diagnosedByRole: data['diagnosedByRole'] as String? ?? '',
      category: DiagnosisCategoryX.fromStorageValue(data['category'] as String?),
      otherIllnessText: data['otherIllnessText'] as String?,
      diagnosisName: data['diagnosisName'] as String? ?? '',
      diagnosisCode: data['diagnosisCode'] as String?,
      description: data['description'] as String?,
      status: DiagnosisStatusX.fromStorageValue(data['status'] as String?),
      patientCountry: data['patientCountry'] as String?,
      patientState: data['patientState'] as String?,
      patientLga: data['patientLga'] as String?,
      healthcareCenter: data['healthcareCenter'] as String?,
      diagnosedAt: (data['diagnosedAt'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}