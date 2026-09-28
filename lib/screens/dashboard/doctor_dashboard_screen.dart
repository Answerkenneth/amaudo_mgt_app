import 'package:flutter/material.dart';
import '../../core/constants/app_dimens.dart';
import '../../models/user_model.dart';
import '../../widgets/dashboard/dashboard_card.dart';
import '../../widgets/dashboard/dashboard_greeting_header.dart';
import '../appointments/appointments_list_page.dart';
import '../patients/patient_list_screen.dart';

class DoctorDashboardScreen extends StatelessWidget {
  final UserModel user;
  const DoctorDashboardScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DashboardGreetingHeader(user: user),
          const SizedBox(height: AppSpacing.lg),
          DashboardCard(
            title: 'Assigned Patients',
            subtitle: 'View and manage your patients',
            icon: Icons.groups_outlined,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PatientListScreen()),
            ),
          ),
                   const SizedBox(height: AppSpacing.md),
          DashboardCard(
            title: "Today's Appointments",
            subtitle: 'View and manage appointments',
            icon: Icons.calendar_month_outlined,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    const AppointmentsListPage(title: 'Appointments'),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          DashboardCard(
            title: 'Medication Management',
            subtitle: 'Schedule and manage medication appointments',
            icon: Icons.medication_outlined,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const AppointmentsListPage(
                  title: 'Medication Appointments',
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const DashboardCard(
            title: 'Messages',
            subtitle: 'No data yet',
            icon: Icons.chat_bubble_outline_rounded,
          ),
          const SizedBox(height: AppSpacing.md),
          const DashboardCard(
            title: 'Notifications',
            subtitle: 'No data yet',
            icon: Icons.notifications_outlined,
          ),
        ],
      ),
    );
  }
}