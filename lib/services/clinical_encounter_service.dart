import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/clinical_encounter_model.dart';
import 'auth_exception.dart';

class ClinicalEncounterService {
  ClinicalEncounterService._internal();
  static final ClinicalEncounterService instance =
      ClinicalEncounterService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'clinicalEncounters';

  Future<ClinicalEncounterModel> createEncounter({
    required String patientUid,
    required String practitionerUid,
    required String practitionerRole,
    required String encounterType,
    required String chiefConcern,
    String? careRequestId,
    String? appointmentId,
    String? clinicalNotes,
    String? assessment,
    bool followUpRequired = false,
    String? followUpType,
    DateTime? followUpDate,
    String? followUpLocation,
  }) async {
    if (practitionerRole != 'doctor' && practitionerRole != 'nurse') {
      throw const AuthException(
        'Only doctors and nurses can record clinical encounters.',
      );
    }

    try {
      final model = ClinicalEncounterModel(
        encounterId: '',
        patientUid: patientUid,
        practitionerUid: practitionerUid,
        practitionerRole: practitionerRole,
        careRequestId: careRequestId,
        appointmentId: appointmentId,
        encounterType: encounterType,
        chiefConcern: chiefConcern,
        clinicalNotes: clinicalNotes,
        assessment: assessment,
        followUpRequired: followUpRequired,
        followUpType: followUpType,
        followUpDate: followUpDate,
        followUpLocation: followUpLocation,
        createdBy: practitionerUid,
      );
      final ref = await _firestore.collection(_collection).add(model.toCreateMap());
      final doc = await ref.get();
      return ClinicalEncounterModel.fromSnapshot(doc);
    } on FirebaseException catch (e) {
      developer.log(
        'createEncounter FirebaseException -> code: ${e.code}, message: ${e.message}',
        name: 'AmaudoClinical',
        error: e,
      );
      throw AuthException(_mapError(e));
    }
  }

  Future<List<ClinicalEncounterModel>> fetchEncountersForPatient(
    String patientUid, {
    int limit = 30,
  }) async {
    try {
      final snap = await _firestore
          .collection(_collection)
          .where('patientUid', isEqualTo: patientUid)
          .limit(limit)
          .get();
      final items = snap.docs.map(ClinicalEncounterModel.fromSnapshot).toList()
        ..sort((a, b) =>
            (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      return items;
    } on FirebaseException catch (e) {
      developer.log(
        'fetchEncountersForPatient FirebaseException -> '
        'code: ${e.code}, message: ${e.message}',
        name: 'AmaudoClinical',
        error: e,
      );
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