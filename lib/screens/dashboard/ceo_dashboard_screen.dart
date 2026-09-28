import 'package:flutter/material.dart';
import '../../core/constants/app_dimens.dart';
import '../../models/user_model.dart';
import '../../widgets/dashboard/dashboard_card.dart';
import '../../widgets/dashboard/dashboard_greeting_header.dart';
import '../../widgets/dashboard/stat_tile.dart';
import '../patients/patient_list_screen.dart';

class CeoDashboardScreen extends StatelessWidget {
  final UserModel user;
  const CeoDashboardScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DashboardGreetingHeader(user: user),
          const SizedBox(height: AppSpacing.lg),
          const Text(
            'Executive Overview',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          const SizedBox(height: AppSpacing.sm),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: AppSpacing.sm,
            mainAxisSpacing: AppSpacing.sm,
            childAspectRatio: 1.5,
            children: const [
              StatTile(label: 'Total Patients', value: '--', icon: Icons.groups_outlined),
              StatTile(label: 'Active Admissions', value: '--', icon: Icons.local_hospital_outlined),
              StatTile(label: 'Discharges', value: '--', icon: Icons.assignment_turned_in_outlined),
              StatTile(label: 'Total Staff', value: '--', icon: Icons.badge_outlined),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          DashboardCard(
            title: 'Patient Management',
            subtitle: 'Search, view, and manage all patients',
            icon: Icons.groups_outlined,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PatientListScreen()),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const DashboardCard(
            title: 'Doctors & Nurses',
            subtitle: 'No data yet',
            icon: Icons.medical_information_outlined,
          ),
          const SizedBox(height: AppSpacing.md),
          const DashboardCard(
            title: 'Appointments',
            subtitle: 'No data yet',
            icon: Icons.calendar_month_outlined,
          ),
          const SizedBox(height: AppSpacing.md),
          const DashboardCard(
            title: 'Organizational Analytics',
            subtitle: 'Coming soon',
            icon: Icons.insights_outlined,
          ),
          const SizedBox(height: AppSpacing.md),
          const DashboardCard(
            title: 'Reports',
            subtitle: 'Coming soon',
            icon: Icons.description_outlined,
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