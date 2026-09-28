import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import 'appointments_screen.dart';

/// AppointmentsScreen has no Scaffold/AppBar of its own (it's built
/// to live inside the bottom-tab shell). This just wraps it so
/// dashboard cards ("Today's Appointments", "Medication
/// Management", "Upcoming Appointment", etc.) can push straight to
/// the exact same, already-working appointments list — including
/// medication-type appointments — without duplicating that screen.
class AppointmentsListPage extends StatelessWidget {
  final String title;
  const AppointmentsListPage({super.key, this.title = 'Appointments'});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: Text(title),
      ),
      body: const SafeArea(child: AppointmentsScreen()),
    );
  }
}