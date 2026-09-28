import 'package:cloud_firestore/cloud_firestore.dart';

/// Real Firestore counts for dashboard StatTiles, using server-side
/// aggregate count queries (Query.count()) against the EXISTING
/// `users` and `patients` collections — no new collection, no
/// pagination, no downloading of full documents. Free-tier
/// compatible: count aggregation queries do not require Blaze.
class DashboardStatsService {
  DashboardStatsService._internal();
  static final DashboardStatsService instance = DashboardStatsService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<int> _countUsersByRole(String role) async {
    final snap = await _firestore
        .collection('users')
        .where('role', isEqualTo: role)
        .count()
        .get();
    return snap.count ?? 0;
  }

  Future<int> _countPatientsByStatus(String status) async {
    final snap = await _firestore
        .collection('patients')
        .where('status', isEqualTo: status)
        .count()
        .get();
    return snap.count ?? 0;
  }

  Future<int> countTotalPatients() async {
    final snap = await _firestore.collection('users').where('role', isEqualTo: 'patient').count().get();
    return snap.count ?? 0;
  }
  Future<int> countAllUsers() async {
    final snap = await _firestore.collection('users').count().get();
    return snap.count ?? 0;
  }

  Future<int> countUsersByRoleValue(String role) => _countUsersByRole(role);
  Future<int> countActiveAdmissions() => _countPatientsByStatus('admitted');
  Future<int> countDischarged() => _countPatientsByStatus('discharged');
  Future<int> countDoctors() => _countUsersByRole('doctor');
  Future<int> countNurses() => _countUsersByRole('nurse');
  Future<int> countStaff() async {
    final results = await Future.wait([
      _countUsersByRole('staff'),
      _countUsersByRole('other'),
    ]);
    return results[0] + results[1];
  }
}