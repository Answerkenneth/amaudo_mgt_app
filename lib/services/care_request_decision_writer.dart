import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_exception.dart';

/// Writes the practitioner's post-acceptance next-step decision onto
/// the existing careRequests/{requestId} document. Deliberately
/// separate from acceptRequest() — accepting a request and deciding
/// what happens next are two distinct actions, matching the
/// no-auto-diagnosis principle.
class CareRequestServiceDecisionWriter {
  static Future<void> saveDecision({
    required String requestId,
    required String decision,
    String? notes,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection('careRequests')
          .doc(requestId)
          .update({
        'practitionerDecision': decision,
        'decisionNotes': notes,
        'decidedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw const AuthException(
          'You do not have permission to record a decision on this request.',
        );
      }
      throw const AuthException('Something went wrong. Please try again.');
    }
  }
}