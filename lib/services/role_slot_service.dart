import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import 'auth_exception.dart';

/// Enforces at most one active CEO, one Director, and one Admin
/// account across the whole application — without Cloud Functions or
/// Blaze.
///
/// Mechanism: three fixed documents, `roleSlots/ceo`,
/// `roleSlots/director`, `roleSlots/admin`. A privileged role can only
/// be claimed by writing that document, and Firestore security rules
/// permit only a `create` (a write to a currently non-existent
/// document) on these paths — never an update or overwrite. The claim
/// happens inside the SAME client-side transaction that also creates
/// the registering user's profile, so if the slot is already taken,
/// the entire registration transaction aborts and nothing is created.
///
/// This is a real database-level guarantee, not UI hiding — but it
/// relies on Firestore's optimistic-concurrency transactions rather
/// than a server-side atomic lock: if two clients race to claim the
/// same slot at the exact same instant, Firestore detects the
/// conflicting write during commit and automatically retries one of
/// the transactions, which will then see the slot as already taken
/// and abort cleanly. The security rule is the actual backstop that
/// makes this safe even if a modified client skips the transaction
/// logic entirely.
class RoleSlotService {
  RoleSlotService._internal();
  static final RoleSlotService instance = RoleSlotService._internal();

  static const String _collection = 'roleSlots';

   static const Set<UserRole> privilegedRoles = {
    UserRole.ceo,
    UserRole.director,
    UserRole.admin,
    UserRole.cmhpCoordinator,
    UserRole.chp,
  };

  static bool isPrivileged(UserRole role) => privilegedRoles.contains(role);

  DocumentReference<Map<String, dynamic>> _slotRef(
    FirebaseFirestore firestore,
    UserRole role,
  ) {
    return firestore.collection(_collection).doc(role.storageValue);
  }

  /// Must be called from within an active Firestore transaction, on
  /// the same [transaction] that also writes the registering user's
  /// profile document, so the slot claim and profile creation succeed
  /// or fail together atomically. Throws [AuthException] if the slot
  /// is already held by another account.
  ///
  /// Note on transaction ordering: this performs a read (transaction
  /// .get) followed immediately by a write (transaction.set) — call
  /// this before any other writes in the same transaction, and after
  /// any other reads, since Firestore transactions require all reads
  /// to happen before any writes.
  Future<void> claimWithinTransaction({
    required Transaction transaction,
    required FirebaseFirestore firestore,
    required UserRole role,
    required String uid,
  }) async {
    final ref = _slotRef(firestore, role);
    final snapshot = await transaction.get(ref);
    if (snapshot.exists) {
      throw AuthException(
        'The ${role.label} role is already assigned to another account.',
      );
    }
    transaction.set(ref, {
      'uid': uid,
      'claimedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Best-effort, non-transactional check used only to give the user
  /// early feedback in the UI before they submit registration. This
  /// is NOT the enforcement mechanism — claimWithinTransaction (via
  /// the security rules) is what actually prevents duplicates, since
  /// this check has an inherent race window between checking and the
  /// user actually submitting.
  Future<bool> isRoleTaken({
    required FirebaseFirestore firestore,
    required UserRole role,
  }) async {
    if (!isPrivileged(role)) return false;
    final doc = await _slotRef(firestore, role).get();
    return doc.exists;
  }
}