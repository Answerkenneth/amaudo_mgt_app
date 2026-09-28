import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/patient_record_model.dart';
import 'auth_exception.dart';

/// Lightweight combined view used by list screens: clinical record
/// (may be null if the patient has never been admitted) plus the
/// identity fields needed for display, read separately from
/// `users/{uid}` so identity is never duplicated in Firestore.
class PatientListItem {
  final String uid;
  final String fullName;
  final String? phone;
  final PatientRecordModel? record;

  const PatientListItem({
    required this.uid,
    required this.fullName,
    this.phone,
    this.record,
  });
}

class PatientPage {
  final List<PatientListItem> items;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;
  final bool hasMore;

  const PatientPage({
    required this.items,
    required this.lastDocument,
    required this.hasMore,
  });
}

/// Patient-management data access. All authorization is enforced by
/// Firestore security rules — this service issues only bounded,
/// paginated queries and never attempts to read more than one page
/// at a time.
class PatientService {
  PatientService._internal();
  static final PatientService instance = PatientService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _patientsCollection = 'patients';
  static const String _usersCollection = 'users';
  static const String _historySubcollection = 'admissionHistory';

  Future<PatientRecordModel?> fetchPatientRecord(String patientUid) async {
    try {
      final doc =
          await _firestore.collection(_patientsCollection).doc(patientUid).get();
      if (!doc.exists) return null;
      return PatientRecordModel.fromSnapshot(doc);
    } on FirebaseException catch (e) {
      throw AuthException(_mapError(e));
    }
  }

  Future<List<AdmissionHistoryEntry>> fetchAdmissionHistory(
    String patientUid,
  ) async {
    try {
      final snap = await _firestore
          .collection(_patientsCollection)
          .doc(patientUid)
          .collection(_historySubcollection)
          .orderBy('dateTime', descending: true)
          .limit(30)
          .get();
      return snap.docs.map(AdmissionHistoryEntry.fromSnapshot).toList();
    } on FirebaseException catch (e) {
      throw AuthException(_mapError(e));
    }
  }

  /// Admits a patient — creates the patients/{uid} record if it does
  /// not yet exist, or re-admits (status -> admitted) if it does.
  /// Also appends an admissionHistory entry. Runs as a transaction so
  /// the record write and the history write succeed or fail together.
  Future<void> admitPatient({
    required String patientUid,
    DateTime? admissionDate,
    String? assignedDoctorUid,
    String? assignedNurseUid,
    String? amaudoFacility,
    String? note,
    required String admittedByUid,
    required AdmissionType admissionType,
    bool adminReferralRequired = false,
    String? adminReferralNote,
  }) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) {
      throw const AuthException('You must be signed in to perform this action.');
    }

    final ref = _firestore.collection(_patientsCollection).doc(patientUid);
    final historyRef = ref.collection(_historySubcollection).doc();
    final effectiveDate = admissionDate ?? DateTime.now();

    try {
      await _firestore.runTransaction((transaction) async {
        final existing = await transaction.get(ref);
        final existingData = existing.data();

        final data = <String, dynamic>{
          'patientUid': patientUid,
          'status': PatientStatus.admitted.storageValue,
          'admissionDate': Timestamp.fromDate(effectiveDate),
          'dischargeDate': null,
          'dischargeSummary': null,
          'assignedDoctorUid': assignedDoctorUid,
          'assignedNurseUid': assignedNurseUid,
          'assignedStaffUids':
              existingData?['assignedStaffUids'] ?? <String>[],
          'amaudoFacility': amaudoFacility,
          'clinicalSummary': existingData?['clinicalSummary'],
          'admissionType': admissionType.storageValue,
          'admittedByUid': admittedByUid,
          'adminReferralRequired': adminReferralRequired,
          'adminReferralNote': adminReferralNote,
          'createdBy':
              existing.exists ? existingData!['createdBy'] : currentUid,
          'createdAt': existing.exists
              ? existingData!['createdAt']
              : FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (existing.exists) {
          transaction.update(ref, data);
        } else {
          transaction.set(ref, data);
        }

        transaction.set(historyRef, {
          'type': 'admission',
          'dateTime': Timestamp.fromDate(effectiveDate),
          'performedBy': currentUid,
          'note': note,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });
    } on FirebaseException catch (e) {
      throw AuthException(_mapError(e));
    }
  }

  Future<void> dischargePatient({
    required String patientUid,
    DateTime? dischargeDate,
    String? summary,
  }) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) {
      throw const AuthException('You must be signed in to perform this action.');
    }

    final ref = _firestore.collection(_patientsCollection).doc(patientUid);
    final historyRef = ref.collection(_historySubcollection).doc();
    final effectiveDate = dischargeDate ?? DateTime.now();

    try {
      await _firestore.runTransaction((transaction) async {
        final existing = await transaction.get(ref);
        if (!existing.exists) {
          throw const AuthException(
            'This patient has not been admitted yet.',
          );
        }

        transaction.update(ref, {
          'status': PatientStatus.discharged.storageValue,
          'dischargeDate': Timestamp.fromDate(effectiveDate),
          'dischargeSummary': summary,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        transaction.set(historyRef, {
          'type': 'discharge',
          'dateTime': Timestamp.fromDate(effectiveDate),
          'performedBy': currentUid,
          'note': summary,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });
    } on AuthException {
      rethrow;
    } on FirebaseException catch (e) {
      throw AuthException(_mapError(e));
    }
  }

  Future<void> assignCareTeam({
    required String patientUid,
    String? doctorUid,
    String? nurseUid,
  }) async {
    final ref = _firestore.collection(_patientsCollection).doc(patientUid);
    try {
      final existing = await ref.get();
      if (!existing.exists) {
        throw const AuthException(
          'This patient has not been admitted yet.',
        );
      }

      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (doctorUid != null) updates['assignedDoctorUid'] = doctorUid;
      if (nurseUid != null) updates['assignedNurseUid'] = nurseUid;
      await ref.update(updates);
    } on AuthException {
      rethrow;
    } on FirebaseException catch (e) {
      throw AuthException(_mapError(e));
    }
  }

  /// Patients assigned to the given doctor or nurse. Server-side
  /// filtered and paginated — never loads the full collection.
  Future<PatientPage> fetchAssignedPatients({
    required String staffUid,
    required bool isDoctor,
    PatientStatus? statusFilter,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = 20,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection(_patientsCollection)
          .where(
            isDoctor ? 'assignedDoctorUid' : 'assignedNurseUid',
            isEqualTo: staffUid,
          );

      if (statusFilter != null) {
        query = query.where(
          'status',
          isEqualTo: statusFilter.storageValue,
        );
      }

      query = query.orderBy(FieldPath.documentId).limit(limit);
      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snap = await query.get();
          final items = await Future.wait(snap.docs.map((doc) async {
      final record = PatientRecordModel.fromSnapshot(doc);
      final identity = await _fetchIdentity(doc.id);

      return PatientListItem(
        uid: doc.id,
        // Admin-added patients with no account (hasAccount: false)
        // have no users/{uid} doc, so `identity` is null for them —
        // fall back to the name/phone already stored on the patient
        // record itself instead of a generic placeholder.
        fullName: (identity?['fullName'] as String?) ??
            record.unregisteredFullName ??
            'Unknown patient',
        phone: (identity?['phone'] as String?) ?? record.unregisteredPhone,
        record: record,
      );
    }));
      return PatientPage(
        items: items,
        lastDocument: snap.docs.isNotEmpty ? snap.docs.last : null,
        hasMore: snap.docs.length == limit,
      );
    } on FirebaseException catch (e) {
      throw AuthException(_mapError(e));
    }
  }

  /// Full patient directory — privileged roles only (enforced by
  /// Firestore rules on the underlying `users` read, not by this
  /// method). Optional [searchPrefix] does a prefix-range match on
  /// fullName (case-sensitive, Firestore's standard prefix-query
  /// pattern). Firestore may require a one-time composite index the
  /// first time a search is run — it will print a direct console
  /// link if so.
  Future<PatientPage> fetchAllPatients({
    String? searchPrefix,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = 20,
  }) async {
    try {
      // Query only by role. The previous role + fullName ordering required
      // a composite Firestore index and could fail the entire patient list
      // when that index was not available. Patient identity remains in users;
      // patient clinical records remain in patients/{uid}.
      final isSearching = searchPrefix != null && searchPrefix.trim().isNotEmpty;
      Query<Map<String, dynamic>> query = _firestore
          .collection(_usersCollection)
          .where('role', isEqualTo: 'patient');

      if (!isSearching) {
        query = query.limit(limit);
        if (startAfter != null) {
          query = query.startAfterDocument(startAfter);
        }
      } else {
        // Search is performed client-side so it does not depend on a
        // composite index. Use the bounded directory size already used by
        // the privileged user lists.
        query = query.limit(200);
      }

      final snap = await query.get();
      final prefix = searchPrefix?.trim().toLowerCase();
      final matchingDocs = isSearching
          ? snap.docs.where((doc) {
              final name = (doc.data()['fullName'] as String? ?? '')
                  .toLowerCase();
              return name.startsWith(prefix!);
            }).toList()
          : snap.docs;

            final items = await Future.wait(matchingDocs.map((doc) async {
        final data = doc.data();
        final record = await fetchPatientRecord(doc.id);
        return PatientListItem(
          uid: doc.id,
          fullName: data['fullName'] as String? ?? 'Unknown patient',
          phone: data['phone'] as String?,
          record: record,
        );
      }));

      // Admin-added patients with no account (hasAccount: false) have
      // no users/{uid} doc, so the query above never includes them.
      // Fetch them separately (single equality filter — no composite
      // index needed) and fold them in, only on the first page so
      // they don't reappear on every subsequent "load more" page.
      if (startAfter == null) {
        final unregisteredSnap = await _firestore
            .collection(_patientsCollection)
            .where('hasAccount', isEqualTo: false)
            .limit(200)
            .get();

        final unregisteredItems = unregisteredSnap.docs
            .map((doc) {
              final record = PatientRecordModel.fromSnapshot(doc);
              return PatientListItem(
                uid: doc.id,
                fullName: record.unregisteredFullName ?? 'Unknown patient',
                phone: record.unregisteredPhone,
                record: record,
              );
            })
            .where((item) {
              if (!isSearching) return true;
              return item.fullName.toLowerCase().startsWith(prefix!);
            })
            .toList();

        items.addAll(unregisteredItems);
      }

      items.sort((a, b) => a.fullName.toLowerCase().compareTo(
            b.fullName.toLowerCase(),
          ));

      return PatientPage(
        items: items,
        lastDocument: isSearching
            ? null
            : (snap.docs.isNotEmpty ? snap.docs.last : null),
        hasMore: !isSearching && snap.docs.length == limit,
      );
    } on FirebaseException catch (e) {
      throw AuthException(_mapError(e));
    }
  }
Future<List<PatientListItem>> fetchPatientsByStatus({
  required PatientStatus status,
}) async {
  try {
    final snap = await _firestore
        .collection(_patientsCollection)
        .where(
          'status',
          isEqualTo: status.storageValue,
        )
        .get();

       final items = await Future.wait(snap.docs.map((doc) async {
      final record = PatientRecordModel.fromSnapshot(doc);
      final identity = await _fetchIdentity(doc.id);

      return PatientListItem(
        uid: doc.id,
        fullName: (identity?['fullName'] as String?) ??
            record.unregisteredFullName ??
            'Unknown patient',
        phone: (identity?['phone'] as String?) ?? record.unregisteredPhone,
        record: record,
      );
    }));
    items.sort(
      (a, b) => a.fullName.toLowerCase().compareTo(
            b.fullName.toLowerCase(),
          ),
    );

    return items;
  } on FirebaseException catch (e) {
    throw AuthException(_mapError(e));
  }
}
  Future<Map<String, dynamic>?> _fetchIdentity(String uid) async {
    try {
      final doc = await _firestore.collection(_usersCollection).doc(uid).get();
      return doc.data();
    } on FirebaseException {
      return null;
    }
  }

  /// Used by Complete Profile. Only ever writes primaryHealthcareCenter
  /// and profileCompleted — the Firestore rule independently enforces
  /// that a patient cannot smuggle in changes to any other field via
  /// this call.
  Future<void> completePatientProfile({
    required String patientUid,
    required String primaryHealthcareCenter,
  }) async {
    try {
      await _firestore.collection(_patientsCollection).doc(patientUid).update({
        'primaryHealthcareCenter': primaryHealthcareCenter.trim(),
        'profileCompleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw AuthException(_mapError(e));
    }
  }
  Future<void> requestDischarge({required String patientUid, required String requestedByUid}) async {
    try {
      await _firestore.collection(_patientsCollection).doc(patientUid).update({
        'dischargeRequested': true,
        'dischargeRequestedByUid': requestedByUid,
        'dischargeRequestedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw AuthException(_mapError(e));
    }
  }

  Future<void> approveDischarge({
    required String patientUid,
    required String approvedByUid,
    String? summary,
  }) async {
    try {
      await _firestore.collection(_patientsCollection).doc(patientUid).update({
        'status': PatientStatus.discharged.storageValue,
        'dischargeDate': FieldValue.serverTimestamp(),
        'dischargeSummary': summary,
        'dischargeRequested': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw AuthException(_mapError(e));
    }
  }
  Future<String> admitPatientWithoutAccount({
  required String fullName,
  String? phone,
  required String admittedByUid,
  required AdmissionType admissionType,
  String? amaudoFacility,
  String? note,
  String? assignedDoctorUid,
  String? assignedNurseUid,
}) async {
  final ref = _firestore.collection(_patientsCollection).doc();
  final historyRef = ref.collection(_historySubcollection).doc();
  final now = DateTime.now();

  try {
    await _firestore.runTransaction((transaction) async {
      transaction.set(ref, {
        'patientUid': ref.id,
        'hasAccount': false,
        'unregisteredFullName': fullName.trim(),
        'unregisteredPhone': phone?.trim(),
        'status': PatientStatus.admitted.storageValue,
        'admissionDate': Timestamp.fromDate(now),
        'admissionType': admissionType.storageValue,
        'admittedByUid': admittedByUid,
        'dischargeDate': null,
        'dischargeSummary': null,
        'dischargeRequested': false,
        'assignedDoctorUid': assignedDoctorUid,
        'assignedNurseUid': assignedNurseUid,
        'assignedStaffUids': <String>[],
        'amaudoFacility': amaudoFacility,
        'clinicalSummary': null,
        'createdBy': admittedByUid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      transaction.set(historyRef, {
        'type': 'admission',
        'dateTime': Timestamp.fromDate(now),
        'performedBy': admittedByUid,
        'note': note,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });

    return ref.id;
  } on FirebaseException catch (e) {
    throw AuthException(_mapError(e));
  }
}
  String _mapError(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return 'You do not have permission to view or manage this patient.';
      case 'unavailable':
        return 'Service temporarily unavailable. Please try again.';
      case 'not-found':
        return 'Patient record not found.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}