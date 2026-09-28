import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/diagnosis_model.dart';
import 'auth_exception.dart';
import 'auth_service.dart';
import 'patient_service.dart';

class DiagnosisService {
  DiagnosisService._internal();
  static final DiagnosisService instance = DiagnosisService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'diagnoses';

  Future<DiagnosisModel> createDiagnosis({
    required String patientUid,
    required String encounterId,
    required String diagnosedByUid,
    required String diagnosedByRole,
    required DiagnosisCategory category,
    String? otherIllnessText,
    String? diagnosisCode,
    String? description,
  }) async {
    if (diagnosedByRole != 'doctor' && diagnosedByRole != 'nurse') {
      throw const AuthException('Only doctors and nurses can record a diagnosis.');
    }
    if (category == DiagnosisCategory.other &&
        (otherIllnessText == null || otherIllnessText.trim().isEmpty)) {
      throw const AuthException('Please describe the illness for "Other illness".');
    }

    // Denormalize patient location/facility at creation time, reusing
    // existing services already used elsewhere in the app — no new
    // read paths introduced.
    String? country, state, lga, healthcareCenter;
    try {
      final patient = await AuthService.instance.fetchUserProfileByUid(patientUid);
      country = patient?.country;
      state = patient?.state;
      lga = patient?.localGovernmentArea;
    } catch (_) {}
    try {
      final record = await PatientService.instance.fetchPatientRecord(patientUid);
      healthcareCenter = record?.primaryHealthcareCenter;
    } catch (_) {}

    final diagnosisName = category == DiagnosisCategory.other
        ? otherIllnessText!.trim()
        : category.label;

    try {
      final model = DiagnosisModel(
        diagnosisId: '',
        patientUid: patientUid,
        encounterId: encounterId,
        diagnosedByUid: diagnosedByUid,
        diagnosedByRole: diagnosedByRole,
        category: category,
        otherIllnessText: category == DiagnosisCategory.other ? otherIllnessText!.trim() : null,
        diagnosisName: diagnosisName,
        diagnosisCode: diagnosisCode,
        description: description,
        patientCountry: country,
        patientState: state,
        patientLga: lga,
        healthcareCenter: healthcareCenter,
      );
      final ref = await _firestore.collection(_collection).add(model.toCreateMap());
      final doc = await ref.get();
      return DiagnosisModel.fromSnapshot(doc);
    } on FirebaseException catch (e) {
      developer.log('createDiagnosis FirebaseException -> code: ${e.code}, message: ${e.message}',
          name: 'AmaudoClinical', error: e);
      throw AuthException(_mapError(e));
    }
  }

  Future<List<DiagnosisModel>> fetchDiagnosesForPatient(
    String patientUid, {
    int limit = 30,
  }) async {
    try {
      final snap = await _firestore
          .collection(_collection)
          .where('patientUid', isEqualTo: patientUid)
          .limit(limit)
          .get();
      final items = snap.docs.map(DiagnosisModel.fromSnapshot).toList()
        ..sort((a, b) =>
            (b.diagnosedAt ?? DateTime(0)).compareTo(a.diagnosedAt ?? DateTime(0)));
      return items;
    } on FirebaseException catch (e) {
      throw AuthException(_mapError(e));
    }
  }

  /// Director/Admin (and CEO, which uses the Director grant) only —
  /// enforced by Firestore rules, not by this method. [start]/[end]
  /// filter server-side on `diagnosedAt` (a single-field range query
  /// — no composite index required) so a narrow window like "Today"
  /// never pulls the full collection just to discard most of it
  /// client-side. Geographic/illness normalization and aggregation
  /// happen client-side in DiagnosisAnalyticsEngine (see
  /// diagnosis_analytics_service.dart), over this bounded result —
  /// not a full-collection scan. At materially larger data volumes
  /// even this date-bounded scan should move to pre-aggregated
  /// rollup documents.
  Future<List<DiagnosisModel>> fetchDiagnosesForAnalytics({
    required DateTime start,
    required DateTime end,
    int limit = 1000,
  }) async {
    try {
      final snap = await _firestore
          .collection(_collection)
          .where('diagnosedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('diagnosedAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .limit(limit)
          .get();
      return snap.docs.map(DiagnosisModel.fromSnapshot).toList();
    } on FirebaseException catch (e) {
      throw AuthException(_mapError(e));
    }
  }

  Future<void> updateStatus({
    required String diagnosisId,
    required DiagnosisStatus status,
  }) async {
    try {
      await _firestore.collection(_collection).doc(diagnosisId).update({
        'status': status.storageValue,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw AuthException(_mapError(e));
    }
  }

  String _mapError(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return 'You do not have permission to perform this action.';
      case 'unavailable':
        return 'Service temporarily unavailable. Please try again.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}