import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/appointment_model.dart';
import 'auth_exception.dart';

/// Appointment data access. Follows the same single-equality-filter,
/// client-side-sort pattern established in CareRequestService — no
/// composite index required for any query here.
class AppointmentService {
  AppointmentService._internal();
  static final AppointmentService instance = AppointmentService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'appointments';

  Future<AppointmentModel> createAppointment({
    required String patientUid,
    required String practitionerUid,
    required String practitionerRole,
    required String purpose,
    required DateTime scheduledAt,
    AppointmentType type = AppointmentType.clinical,
    String? healthcareCenter,
    String? location,
    String? careRequestId,
  }) async {
    if (practitionerRole != 'doctor' && practitionerRole != 'nurse') {
      throw const AuthException(
        'Only doctors and nurses can schedule appointments.',
      );
    }

    try {
      final model = AppointmentModel(
        appointmentId: '',
        patientUid: patientUid,
        practitionerUid: practitionerUid,
        practitionerRole: practitionerRole,
        purpose: purpose,
        type: type,
        healthcareCenter: healthcareCenter,
        location: location,
        scheduledAt: scheduledAt,
        careRequestId: careRequestId,
        createdBy: practitionerUid,
      );
      final ref = await _firestore.collection(_collection).add(model.toCreateMap());
      final doc = await ref.get();
      return AppointmentModel.fromSnapshot(doc);
    } on FirebaseException catch (e) {
      developer.log(
        'createAppointment FirebaseException -> '
        'code: ${e.code}, message: ${e.message}',
        name: 'AmaudoAppointment',
        error: e,
      );
      throw AuthException(_mapError(e));
    }
  }

  Future<AppointmentModel?> fetchAppointment(String appointmentId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(appointmentId).get();
      if (!doc.exists) return null;
      return AppointmentModel.fromSnapshot(doc);
    } on FirebaseException catch (e) {
      throw AuthException(_mapError(e));
    }
  }

  Future<List<AppointmentModel>> fetchAppointmentsForPatient(
    String patientUid, {
    int limit = 30,
  }) async {
    try {
      final snap = await _firestore
          .collection(_collection)
          .where('patientUid', isEqualTo: patientUid)
          .limit(limit)
          .get();
      final items = snap.docs.map(AppointmentModel.fromSnapshot).toList()
        ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
      return items;
    } on FirebaseException catch (e) {
      developer.log(
        'fetchAppointmentsForPatient FirebaseException -> '
        'code: ${e.code}, message: ${e.message}',
        name: 'AmaudoAppointment',
        error: e,
      );
      throw AuthException(_mapError(e));
    }
  }

  Future<List<AppointmentModel>> fetchAppointmentsForPractitioner(
    String practitionerUid, {
    int limit = 30,
  }) async {
    try {
      final snap = await _firestore
          .collection(_collection)
          .where('practitionerUid', isEqualTo: practitionerUid)
          .limit(limit)
          .get();
      final items = snap.docs.map(AppointmentModel.fromSnapshot).toList()
        ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
      return items;
    } on FirebaseException catch (e) {
      developer.log(
        'fetchAppointmentsForPractitioner FirebaseException -> '
        'code: ${e.code}, message: ${e.message}',
        name: 'AmaudoAppointment',
        error: e,
      );
      throw AuthException(_mapError(e));
    }
  }

    Future<void> updateStatus({
    required String appointmentId,
    required AppointmentStatus status,
  }) async {
    try {
      await _firestore.collection(_collection).doc(appointmentId).update({
        'status': status.storageValue,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw AuthException(_mapError(e));
    }
  }

  /// The practitioner's explicit confirmation of whether a scheduled
  /// appointment actually occurred. Only 'completed' or 'missed' are
  /// valid outcomes here — this is never inferred automatically from
  /// the scheduled time passing.
   Future<void> recordOutcome({
    required String appointmentId,
    required AppointmentStatus outcome,
    required String recordedByUid,
  }) async {
    if (outcome != AppointmentStatus.completed &&
        outcome != AppointmentStatus.missed) {
      throw const AuthException(
        'Invalid appointment outcome.',
      );
    }
    try {
      await _firestore.collection(_collection).doc(appointmentId).update({
        'status': outcome.storageValue,
        // occurredAt only reflects a genuine clinical interaction —
        // it must be null for a missed appointment, not a timestamp
        // implying it happened.
        'occurredAt': outcome == AppointmentStatus.completed
            ? FieldValue.serverTimestamp()
            : null,
        'outcomeRecordedBy': recordedByUid,
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
      case 'not-found':
        return 'Appointment not found.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}