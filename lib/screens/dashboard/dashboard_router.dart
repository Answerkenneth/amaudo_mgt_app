import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import 'patient_dashboard_screen.dart';
import 'nurse_dashboard_screen.dart';
import 'doctor_dashboard_screen.dart';
import 'staff_dashboard_screen.dart';
import 'other_role_dashboard_screen.dart';
import 'director_dashboard_screen.dart';
import 'admin_dashboard_screen.dart';
import 'cmhp_coordinator_dashboard_screen.dart';
import 'chp_dashboard_screen.dart';

/// Single source of truth for role -> dashboard routing.
///
/// CEO is no longer a separate active role. UserRole.ceo remains in
/// the model only so pre-existing Firestore documents with
/// role: "ceo" keep deserializing correctly — any such account now
/// routes to the same DirectorDashboardScreen as an active Director,
/// since Director is the current organizational overseer role and
/// this avoids leaving a separate CEO dashboard as a live route.
class DashboardRouter extends StatelessWidget {
  final UserModel user;
  const DashboardRouter({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    switch (user.role) {
      case UserRole.patient:
        return PatientDashboardScreen(user: user);
      case UserRole.nurse:
        return NurseDashboardScreen(user: user);
      case UserRole.doctor:
        return DoctorDashboardScreen(user: user);
      case UserRole.staff:
        return StaffDashboardScreen(user: user);
      case UserRole.director:
      case UserRole.ceo:
        return DirectorDashboardScreen(user: user);
      case UserRole.admin:
        return AdminDashboardScreen(user: user);
      case UserRole.cmhpCoordinator:
        return CmhpCoordinatorDashboardScreen(user: user);
              case UserRole.chp:
        return ChpDashboardScreen(user: user);
      case UserRole.other:
        return OtherRoleDashboardScreen(user: user);
    }
  }
}