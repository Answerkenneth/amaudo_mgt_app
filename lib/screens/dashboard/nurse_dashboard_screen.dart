import 'package:flutter/material.dart';
import '../../core/constants/app_dimens.dart';
import '../../models/user_model.dart';
import '../../widgets/dashboard/dashboard_card.dart';
import '../../widgets/dashboard/dashboard_greeting_header.dart';
import '../appointments/appointments_list_page.dart';
import '../patients/patient_list_screen.dart';

class NurseDashboardScreen extends StatelessWidget {
  final UserModel user;
  const NurseDashboardScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DashboardGreetingHeader(user: user),
          const SizedBox(height: AppSpacing.lg),
         
         const SizedBox(height: AppSpacing.md),
          DashboardCard(
            title: 'Assigned Patients',
            subtitle: 'View and manage your patients',
            icon: Icons.groups_outlined,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PatientListScreen()),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const DashboardCard(
            title: "Today's Tasks",
            subtitle: 'No data yet',
            icon: Icons.checklist_outlined,
          ),
                    const SizedBox(height: AppSpacing.md),
          DashboardCard(
            title: 'Medication',
            subtitle: 'View and support medication schedules',
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