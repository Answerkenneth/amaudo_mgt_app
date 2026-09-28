import 'package:flutter/material.dart';
import '../../core/constants/app_dimens.dart';
import '../../models/user_model.dart';
import '../../widgets/dashboard/dashboard_card.dart';
import '../../widgets/dashboard/dashboard_greeting_header.dart';
import '../patients/patient_list_screen.dart';
import '../requests/care_request_lists_screen.dart';
import '../patients/admit_unregistered_patient_screen.dart';
import '../analytics/diagnosis_analytics_screen.dart';
class AdminDashboardScreen extends StatelessWidget {
  final UserModel user;
  const AdminDashboardScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DashboardGreetingHeader(user: user),
          const SizedBox(height: AppSpacing.lg),
          const DashboardCard(
            title: 'User Management',
            subtitle: 'No data yet',
            icon: Icons.manage_accounts_outlined,
          ),
          const SizedBox(height: AppSpacing.md),
          DashboardCard(
            title: 'Care Requests',
            subtitle: 'Approved, Under Review, and Referred patients',
            icon: Icons.assignment_ind_outlined,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const CareRequestListsScreen(),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          DashboardCard(
            title: 'Patient Overview',
            subtitle: 'Search, view, and manage all patients',
            icon: Icons.groups_outlined,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const PatientListScreen(),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const DashboardCard(
            title: 'Staff Overview',
            subtitle: 'No data yet',
            icon: Icons.badge_outlined,
          ),
          const SizedBox(height: AppSpacing.md),
          const DashboardCard(
            title: 'Appointments',
            subtitle: 'No data yet',
            icon: Icons.calendar_month_outlined,
          ),
          const SizedBox(height: AppSpacing.md),
           DashboardCard(
            title: 'Admission',
            subtitle: 'Admit severe cases to Amaudo Centre',
            icon: Icons.local_hospital_outlined,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PatientListScreen()),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          DashboardCard(
          title: 'Admit Patient Without Account',
          subtitle: 'For patients with no app account',
          icon: Icons.person_add_alt_outlined,
          onTap: () => Navigator.of(context).push(
           MaterialPageRoute(
          builder: (_) => const AdmitUnregisteredPatientScreen(),
    ),
  ),
),
          DashboardCard(
            title: 'Analytics',
            subtitle: 'Diagnosis and geographic analytics',
            icon: Icons.insights_outlined,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const DiagnosisAnalyticsScreen(),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const SizedBox(height: AppSpacing.md),
          const DashboardCard(
            title: 'Notifications',
            subtitle: 'No data yet',
            icon: Icons.notifications_outlined,
          ),
          const SizedBox(height: AppSpacing.md),
          DashboardCard(
            title: 'Account Recovery',
            subtitle: 'Assist users who cannot self-recover their account',
            icon: Icons.lock_reset_outlined,
            onTap: () => Navigator.of(context).pushNamed('/admin-recovery'),
          ),
        ],
      ),
    );
  }
}