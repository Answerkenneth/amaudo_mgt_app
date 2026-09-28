import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import '../models/care_request_model.dart';
import 'auth_exception.dart';

/// Care-request data access.
///
/// IMPORTANT: every query here uses a SINGLE Firestore equality
/// filter with a bounded limit, sorting results in Dart afterward.
/// This avoids requiring a composite index.
class CareRequestService {
  CareRequestService._internal();

  static final CareRequestService instance =
      CareRequestService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _collection = 'careRequests';
  static const String _patientsCollection = 'patients';

  Future<List<CareRequestModel>> fetchRequestsForPatient(
    String patientUid, {
    int limit = 20,
  }) async {
    try {
      final snap = await _firestore
          .collection(_collection)
          .where('patientUid', isEqualTo: patientUid)
          .limit(limit)
          .get();

      final items = snap.docs
          .map(CareRequestModel.fromSnapshot)
          .toList()
        ..sort(
          (a, b) => (b.requestedAt ?? DateTime(0))
              .compareTo(a.requestedAt ?? DateTime(0)),
        );

      return items;
    } on FirebaseException catch (e) {
      developer.log(
        'fetchRequestsForPatient FirebaseException -> '
        'code: ${e.code}, message: ${e.message}',
        name: 'AmaudoCareRequest',
        error: e,
      );

 throw AuthException(_mapError(e));
    }
  }

  Future<CareRequestModel?> fetchActiveRequestForPatient(
    String patientUid,
  ) async {
    final all = await fetchRequestsForPatient(patientUid);

    for (final r in all) {
      if (r.status == CareRequestStatus.pending ||
          r.status == CareRequestStatus.accepted) {
        return r;
      }
    }

    return null;
  }

  Future<CareRequestModel> createCareRequest({
    required String patientUid,
    required String reason,
    String? onsetInfo,
    String? impact,
    String? additionalInfo,
  }) async {
    final existing = await fetchActiveRequestForPatient(patientUid);

    if (existing != null) {
      throw const AuthException(
        'You already have an active care request.',
      );
    }

    try {
      final model = CareRequestModel(
        requestId: '',
        patientUid: patientUid,
        reason: reason,
        onsetInfo: onsetInfo,
        impact: impact,
        additionalInfo: additionalInfo,
      );

      final ref = await _firestore
          .collection(_collection)
          .add(model.toCreateMap());

      final doc = await ref.get();

      return CareRequestModel.fromSnapshot(doc);
    } on FirebaseException catch (e) {
      developer.log(
        'createCareRequest FirebaseException -> '
        'code: ${e.code}, message: ${e.message}',
        name: 'AmaudoCareRequest',
        error: e,
      );

      throw AuthException(_mapError(e));
    }
  }

  Future<void> cancelRequest(String requestId) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(requestId)
          .update({
        'status': CareRequestStatus.cancelled.storageValue,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw AuthException(_mapError(e));
    }
  }

  Future<List<CareRequestModel>> fetchPendingRequests({
    int limit = 50,
  }) async {
    try {
      final snap = await _firestore
          .collection(_collection)
          .where(
            'status',
            isEqualTo: CareRequestStatus.pending.storageValue,
          )
          .limit(limit)
          .get();

      final items = snap.docs
          .map(CareRequestModel.fromSnapshot)
          .toList()
        ..sort(
          (a, b) => (a.requestedAt ?? DateTime(0))
              .compareTo(b.requestedAt ?? DateTime(0)),
        );

      return items;
    } on FirebaseException catch (e) {
      developer.log(
        'fetchPendingRequests FirebaseException -> '
        'code: ${e.code}, message: ${e.message}',
        name: 'AmaudoCareRequest',
        error: e,
      );

      throw AuthException(_mapError(e));
    }
  }

  /// Accepts EXACTLY ONE care request identified by [requestId].
  ///
  /// The request and its corresponding patient assignment are updated
  /// inside one Firestore transaction. patientRef is never explicitly
  /// read — an unassigned practitioner has no `allow read` permission
  /// on a patient record they're not yet linked to. The subsequent
  /// transaction.update(patientRef, ...) is still fully validated
  /// server-side by the `allow update` rule (which checks
  /// assignedDoctorUid/assignedNurseUid == null internally via
  /// resource.data) — that check does not require the caller to have
  /// separate read access. This preserves both the "already assigned"
  /// guard and concurrency safety without granting any new read
  /// access.
  Future<void> acceptRequest({
    required String requestId,
    required String patientUid,
    required String staffUid,
    required String staffRole,
  }) async {
    if (staffRole != 'doctor' && staffRole != 'nurse') {
      throw const AuthException(
        'Only doctors and nurses can accept care requests.',
      );
    }

    final assignmentField =
        staffRole == 'doctor'
            ? 'assignedDoctorUid'
            : 'assignedNurseUid';

    final requestRef =
        _firestore.collection(_collection).doc(requestId);

    final patientRef =
        _firestore.collection(_patientsCollection).doc(patientUid);

    try {
      await _firestore.runTransaction((transaction) async {
        final requestSnap = await transaction.get(requestRef);

        if (!requestSnap.exists ||
            requestSnap.data()?['status'] !=
                CareRequestStatus.pending.storageValue) {
          throw const AuthException(
            'This request is no longer available.',
          );
        }

        transaction.update(requestRef, {
          'status': CareRequestStatus.accepted.storageValue,
          'acceptedByUid': staffUid,
          'acceptedByRole': staffRole,
          'acceptedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        transaction.update(patientRef, {
          assignmentField: staffUid,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } on AuthException {
      rethrow;
    } on FirebaseException catch (e) {
      developer.log(
        'acceptRequest FirebaseException -> '
        'code: ${e.code}, message: ${e.message}, '
        'requestId: $requestId, patientUid: $patientUid, '
        'staffUid: $staffUid, staffRole: $staffRole',
        name: 'AmaudoCareRequest',
        error: e,
      );
      // Without a pre-read of the patient doc, a denial at this
      // point most likely means the patient already has this role
      // assigned (blocked by the update rule) or the patient record
      // doesn't exist (blocked as not-found). Both are covered here.
      if (e.code == 'permission-denied') {
        throw AuthException(
          'This patient may already have a $staffRole assigned, or '
          'the request is no longer available. Please refresh and '
          'try again.',
        );
      }
      if (e.code == 'not-found') {
        throw const AuthException('Patient record not found.');
      }
      throw AuthException(_mapError(e));
    }
  }

    Future<void> completeRequest(String requestId) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(requestId)
          .update({
        'status': CareRequestStatus.completed.storageValue,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw AuthException(_mapError(e));
    }
  }

  Future<void> saveDecision({
    required String requestId,
    required String decision,
    String? notes,
  }) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(requestId)
          .update({
        'practitionerDecision': decision,
        'practitionerDecisionNotes': notes,
        'decisionRecordedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw AuthException(_mapError(e));
    }
  }

  /// Director-only: approves the request, allowing the Admin/CMHP
  /// Coordinator assignment workflow (a later chunk) to proceed.
  /// Does NOT touch the existing `status` field — that remains tied
  /// to the practitioner acceptance lifecycle already in place.
  /// Idempotent and safe to call after a prior Review — Review never
  /// blocks a later Approve.
  Future<void> directorApprove({
    required String requestId,
    required String directorUid,
  }) async {
    try {
      await _firestore.collection(_collection).doc(requestId).update({
        'directorDecision': DirectorDecision.approved.storageValue,
        'directorApprovedByUid': directorUid,
        'directorApprovedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw AuthException(_mapError(e));
    }
  }

  /// Director-only: saves the internal Review Note and/or draft
  /// Referral Note. Neither note is ever written to the main
  /// document — they live in restricted subcollections so a
  /// patient's existing full-document read access to their own
  /// request can never expose the internal review note, and never
  /// exposes the referral note until it is explicitly sent.
  Future<void> directorSaveReview({
    required String requestId,
    required String directorUid,
    String? reviewNote,
    String? referralNote,
  }) async {
    try {
      final batch = _firestore.batch();
      final requestRef = _firestore.collection(_collection).doc(requestId);

      batch.update(requestRef, {
        'directorDecision': DirectorDecision.review.storageValue,
        'directorReviewedByUid': directorUid,
        'directorReviewedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (reviewNote != null) {
        batch.set(
          requestRef.collection('directorPrivate').doc('notes'),
          {
            'reviewNote': reviewNote,
            'updatedByUid': directorUid,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      if (referralNote != null) {
        // Only the note text and updatedAt are touched here — 'sent'
        // state is never modified by this method, so editing a draft
        // referral note can never accidentally un-send or re-send it.
        batch.set(
          requestRef.collection('referral').doc('current'),
          {
            'referralNote': referralNote,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      await batch.commit();
    } on FirebaseException catch (e) {
      throw AuthException(_mapError(e));
    }
  }

  /// Director-only: marks the already-saved draft Referral Note as
  /// sent, making it readable by the patient. Call directorSaveReview
  /// first to actually write the note text.
  Future<void> directorSendReferral({
    required String requestId,
    required String directorUid,
  }) async {
    try {
      final requestRef = _firestore.collection(_collection).doc(requestId);
      final batch = _firestore.batch();

      batch.update(requestRef, {
        'directorReferralSent': true,
        'directorReferralSentByUid': directorUid,
        'directorReferralSentAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      batch.set(
        requestRef.collection('referral').doc('current'),
        {
          'sent': true,
          'sentByUid': directorUid,
          'sentAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await batch.commit();
    } on FirebaseException catch (e) {
      throw AuthException(_mapError(e));
    }
  }

  Future<CareRequestModel?> fetchRequestById(String requestId) async {
    try {
      final doc =
          await _firestore.collection(_collection).doc(requestId).get();
      if (!doc.exists) return null;
      return CareRequestModel.fromSnapshot(doc);
    } on FirebaseException catch (e) {
      throw AuthException(_mapError(e));
    }
  }

  /// Reads the internal review note. Access is enforced entirely by
  /// Firestore rules (Director/Admin/privileged only) — never by
  /// this method.
  Future<String?> fetchDirectorReviewNote(String requestId) async {
    try {
      final doc = await _firestore
          .collection(_collection)
          .doc(requestId)
          .collection('directorPrivate')
          .doc('notes')
          .get();
      if (!doc.exists) return null;
      return doc.data()?['reviewNote'] as String?;
    } on FirebaseException {
      return null;
    }
  }

  /// Returns the referral note and its sent state. Readable by the
  /// Director/privileged roles always; readable by the patient only
  /// once sent — both enforced server-side by Firestore rules.
  Future<Map<String, dynamic>?> fetchReferralNote(String requestId) async {
    try {
      final doc = await _firestore
          .collection(_collection)
          .doc(requestId)
          .collection('referral')
          .doc('current')
          .get();
      if (!doc.exists) return null;
      return doc.data();
    } on FirebaseException {
      return null;
    }
  }
  /// Admin/CMHP Coordinator only: Director-approved requests still
  /// awaiting practitioner assignment. Single equality filter
  /// (directorDecision) with status filtered client-side — avoids a
  /// composite index.
  Future<List<CareRequestModel>> fetchApprovedUnassignedRequests({
    int limit = 50,
  }) async {
    try {
      final snap = await _firestore
          .collection(_collection)
          .where('directorDecision',
              isEqualTo: DirectorDecision.approved.storageValue)
          .limit(limit)
          .get();
      final items = snap.docs
          .map(CareRequestModel.fromSnapshot)
          .where((r) => r.status == CareRequestStatus.pending)
          .toList()
        ..sort((a, b) =>
            (a.requestedAt ?? DateTime(0)).compareTo(b.requestedAt ?? DateTime(0)));
      return items;
    } on FirebaseException catch (e) {
      throw AuthException(_mapError(e));
    }
  }

  /// Requests specifically assigned to this practitioner — replaces
  /// the old open pending-queue query for Doctor/Nurse.
  Future<List<CareRequestModel>> fetchAssignedRequestsForPractitioner(
    String staffUid, {
    int limit = 50,
  }) async {
    try {
      final snap = await _firestore
          .collection(_collection)
          .where('acceptedByUid', isEqualTo: staffUid)
          .limit(limit)
          .get();
      final items = snap.docs.map(CareRequestModel.fromSnapshot).toList()
        ..sort((a, b) =>
            (b.acceptedAt ?? DateTime(0)).compareTo(a.acceptedAt ?? DateTime(0)));
      return items;
    } on FirebaseException catch (e) {
      throw AuthException(_mapError(e));
    }
  }

  /// Admin/CMHP Coordinator only: assigns an approved, still-pending
  /// request to a specific registered doctor/nurse, and simultaneously
  /// claims the patient's assignment slot — the same mechanism the
  /// old self-accept flow used, now administratively driven.
   Future<void> assignPractitioner({
    required String requestId,
    required String patientUid,
    required String practitionerUid,
    required String practitionerRole,
    String? chpClinicalRole,
  }) async {
    var resolvedRole = practitionerRole;
    if (practitionerRole == 'chp') {
      if (chpClinicalRole != 'doctor' && chpClinicalRole != 'nurse') {
        throw const AuthException(
          'This CHP account has no clinical role configured.',
        );
      }
      resolvedRole = chpClinicalRole!;
    }
    if (resolvedRole != 'doctor' && resolvedRole != 'nurse') {
      throw const AuthException('Only doctors, nurses, or CHP can be assigned.');
    }
    final assignmentField =
        resolvedRole == 'doctor' ? 'assignedDoctorUid' : 'assignedNurseUid';

    final requestRef = _firestore.collection(_collection).doc(requestId);
    final patientRef = _firestore.collection(_patientsCollection).doc(patientUid);

    try {
      await _firestore.runTransaction((transaction) async {
        final requestSnap = await transaction.get(requestRef);
        if (!requestSnap.exists ||
            requestSnap.data()?['directorDecision'] != DirectorDecision.approved.storageValue ||
            requestSnap.data()?['status'] != CareRequestStatus.pending.storageValue) {
          throw const AuthException('This request is not available for assignment.');
        }
        transaction.update(requestRef, {
          'status': CareRequestStatus.accepted.storageValue,
          'acceptedByUid': practitionerUid,
          'acceptedByRole': resolvedRole,
          'acceptedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        transaction.update(patientRef, {
          assignmentField: practitionerUid,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } on AuthException {
      rethrow;
    } on FirebaseException catch (e) {
      developer.log('assignPractitioner FirebaseException -> code: ${e.code}, message: ${e.message}',
          name: 'AmaudoCareRequest', error: e);
      throw AuthException(_mapError(e));
    }
  }
    /// Director sends the already-saved review note to Admin and/or
  /// CMHP Coordinator. Can be called again later to send to the
  /// other one — each flag is independent and additive.
   Future<void> directorSendReviewTo({
    required String requestId,
    required String directorUid,
    bool toAdmin = false,
    bool toCmhp = false,
    bool toChp = false,
    bool toDirector = false,
  }) async {
    try {
      final updates = <String, dynamic>{'updatedAt': FieldValue.serverTimestamp()};
      if (toAdmin) updates['reviewSentToAdmin'] = true;
      if (toCmhp) updates['reviewSentToCmhp'] = true;
      if (toChp) updates['reviewSentToChp'] = true;
      if (toDirector) updates['reviewSentToDirector'] = true;
      await _firestore.collection(_collection).doc(requestId).update(updates);
    } on FirebaseException catch (e) {
      throw AuthException(_mapError(e));
    }
  }
    Future<void> chpSaveReviewNote({
    required String requestId,
    required String chpUid,
    required String reviewNote,
  }) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(requestId)
          .collection('chpPrivate')
          .doc('notes')
          .set({
        'reviewNote': reviewNote,
        'updatedByUid': chpUid,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw AuthException(_mapError(e));
    }
  }

  Future<void> chpShareReviewTo({
    required String requestId,
    required String chpUid,
    bool toAdmin = false,
    bool toCmhp = false,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updatedByUid': chpUid,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (toAdmin) updates['sentToAdmin'] = true;
      if (toCmhp) updates['sentToCmhp'] = true;
      await _firestore
          .collection(_collection)
          .doc(requestId)
          .collection('chpPrivate')
          .doc('notes')
          .set(updates, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw AuthException(_mapError(e));
    }
  }

  Future<void> chpSaveReferralDraft({
    required String requestId,
    required String chpUid,
    required String referralNote,
  }) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(requestId)
          .collection('chpPrivate')
          .doc('referralDraft')
          .set({
        'referralNote': referralNote,
        'updatedByUid': chpUid,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw AuthException(_mapError(e));
    }
  }

  Future<Map<String, dynamic>?> fetchChpPrivateNote(String requestId) async {
    try {
      final doc = await _firestore
          .collection(_collection)
          .doc(requestId)
          .collection('chpPrivate')
          .doc('notes')
          .get();
      return doc.exists ? doc.data() : null;
    } on FirebaseException {
      return null;
    }
  }

  Future<String?> fetchChpReferralDraft(String requestId) async {
    try {
      final doc = await _firestore
          .collection(_collection)
          .doc(requestId)
          .collection('chpPrivate')
          .doc('referralDraft')
          .get();
      return doc.data()?['referralNote'] as String?;
    } on FirebaseException {
      return null;
    }
  }
  /// CHP-only: sends a review or referral SUGGESTION to the Director.
  /// Deliberately separate from directorSaveReview/directorSendReferral
  /// — never touches directorPrivate/notes or referral/current, so a
  /// CHP message can never be confused with, or overwrite, the
  /// Director's own internal note or the patient-facing referral.
  Future<void> chpSendMessageToDirector({
    required String requestId,
    required String chpUid,
    required String messageType, // 'review' or 'referral'
    required String text,
  }) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(requestId)
          .collection('chpMessages')
          .add({
        'authorUid': chpUid,
        'messageType': messageType,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw AuthException(_mapError(e));
    }
  }

  Future<List<Map<String, dynamic>>> fetchChpMessages(String requestId) async {
    try {
      final snap = await _firestore
          .collection(_collection)
          .doc(requestId)
          .collection('chpMessages')
          .get();
      final items = snap.docs.map((d) => d.data()).toList()
        ..sort((a, b) {
          final aTs = a['createdAt'] as Timestamp?;
          final bTs = b['createdAt'] as Timestamp?;
          return (bTs?.toDate() ?? DateTime(0)).compareTo(aTs?.toDate() ?? DateTime(0));
        });
      return items;
    } on FirebaseException catch (e) {
      throw AuthException(_mapError(e));
    }
  }
  /// Admin/CMHP Coordinator writes feedback back to the Director in
  /// response to a sent review. Kept in its own subcollection —
  /// entirely separate from the patient-facing referral note.
  Future<void> submitReviewFeedback({
    required String requestId,
    required String authorUid,
    required String authorRole,
    required String feedbackText,
  }) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(requestId)
          .collection('directorFeedback')
          .add({
        'authorUid': authorUid,
        'authorRole': authorRole,
        'feedbackText': feedbackText,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw AuthException(_mapError(e));
    }
  }

  Future<List<Map<String, dynamic>>> fetchReviewFeedback(String requestId) async {
    try {
      final snap = await _firestore
          .collection(_collection)
          .doc(requestId)
          .collection('directorFeedback')
          .get();
      final items = snap.docs.map((d) => d.data()).toList()
        ..sort((a, b) {
          final aTs = a['createdAt'] as Timestamp?;
          final bTs = b['createdAt'] as Timestamp?;
          return (bTs?.toDate() ?? DateTime(0)).compareTo(aTs?.toDate() ?? DateTime(0));
        });
      return items;
    } on FirebaseException catch (e) {
      throw AuthException(_mapError(e));
    }
  }
    /// Persistent, status-independent list — an approved request stays
  /// visible here regardless of whether it has since been assigned.
  Future<List<CareRequestModel>> fetchRequestsByDirectorDecision(
    DirectorDecision decision, {
    int limit = 100,
  }) async {
    try {
      final snap = await _firestore
          .collection(_collection)
          .where('directorDecision', isEqualTo: decision.storageValue)
          .limit(limit)
          .get();
      final items = snap.docs.map(CareRequestModel.fromSnapshot).toList()
        ..sort((a, b) =>
            (b.updatedAt ?? DateTime(0)).compareTo(a.updatedAt ?? DateTime(0)));
      return items;
    } on FirebaseException catch (e) {
      throw AuthException(_mapError(e));
    }
  }

  Future<List<CareRequestModel>> fetchReferredRequests({int limit = 100}) async {
    try {
      final snap = await _firestore
          .collection(_collection)
          .where('directorReferralSent', isEqualTo: true)
          .limit(limit)
          .get();
      final items = snap.docs.map(CareRequestModel.fromSnapshot).toList()
        ..sort((a, b) => (b.directorReferralSentAt ?? DateTime(0))
            .compareTo(a.directorReferralSentAt ?? DateTime(0)));
      return items;
    } on FirebaseException catch (e) {
      throw AuthException(_mapError(e));
    }
  }
    String _mapError(FirebaseException e) {
    String base;
    switch (e.code) {
      case 'permission-denied':
        base = 'You do not have permission to perform this action.';
        break;
      case 'unavailable':
        base = 'Service temporarily unavailable. Please try again.';
        break;
      default:
        base = 'Something went wrong. Please try again.';
    }
    if (kDebugMode) {
      return '$base\n[debug: ${e.code} — ${e.message}]';
    }
    return base;
  }
}