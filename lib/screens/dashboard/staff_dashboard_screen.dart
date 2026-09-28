import 'package:flutter/material.dart';
import '../../core/constants/app_dimens.dart';
import '../../models/user_model.dart';
import '../../widgets/dashboard/dashboard_card.dart';
import '../../widgets/dashboard/dashboard_greeting_header.dart';

class StaffDashboardScreen extends StatelessWidget {
  final UserModel user;
  const StaffDashboardScreen({super.key, required this.user});

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
            title: 'Work Overview',
            subtitle: 'No data yet',
            icon: Icons.work_outline_rounded,
          ),
          const SizedBox(height: AppSpacing.md),
          const DashboardCard(
            title: 'Assigned Tasks',
            subtitle: 'No data yet',
            icon: Icons.checklist_outlined,
          ),
          const SizedBox(height: AppSpacing.md),
          const DashboardCard(
            title: 'Appointments',
            subtitle: 'No data yet',
            icon: Icons.calendar_month_outlined,
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
          const SizedBox(height: AppSpacing.md),
          DashboardCard(
            title: 'Workplace Information',
            subtitle: user.workplace ?? 'No workplace on file',
            icon: Icons.local_hospital_outlined,
          ),
        ],
      ),
    );
  }
}