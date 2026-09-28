import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import 'auth_exception.dart';

/// Read-only directory of registered doctor/nurse accounts, used by
/// Admin/CMHP Coordinator when assigning an approved care request.
/// Only returns users who actually exist in `users` with role doctor
/// or nurse — never invented/fake entries.
class PractitionerDirectoryService {
  PractitionerDirectoryService._internal();
  static final PractitionerDirectoryService instance =
      PractitionerDirectoryService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<UserModel>> fetchPractitioners({int limit = 100}) async {
    try {
      final snap = await _firestore
          .collection('users')
          .where('role', whereIn: ['doctor', 'nurse', 'chp'])
          .limit(limit)
          .get();
      final items = snap.docs.map(UserModel.fromSnapshot).toList()
        ..sort((a, b) => a.fullName.compareTo(b.fullName));
      return items;
    } on FirebaseException catch (e) {
      throw AuthException(
        e.code == 'permission-denied'
            ? 'You do not have permission to view the practitioner directory.'
            : 'Something went wrong. Please try again.',
      );
    }
  }
}