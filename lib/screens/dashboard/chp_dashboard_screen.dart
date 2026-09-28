import 'package:flutter/material.dart';
import '../../core/constants/app_dimens.dart';
import '../../models/user_model.dart';
import '../../widgets/dashboard/dashboard_card.dart';
import '../../widgets/dashboard/dashboard_greeting_header.dart';
import '../director/director_care_requests_screen.dart';
import '../patients/patient_list_screen.dart';
import '../requests/care_request_lists_screen.dart';

class ChpDashboardScreen extends StatelessWidget {
  final UserModel user;
  const ChpDashboardScreen({super.key, required this.user});

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
            title: 'New Care Requests',
            subtitle: 'Approve, review, or refer patient requests',
            icon: Icons.fact_check_outlined,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DirectorCareRequestsScreen()),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          DashboardCard(
            title: 'Approved / Under Review / Referred',
            subtitle: 'Persistent searchable patient lists',
            icon: Icons.list_alt_outlined,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CareRequestListsScreen()),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          DashboardCard(
            title: 'Assigned Patients',
            subtitle: 'Patients assigned to you as a practitioner',
            icon: Icons.groups_outlined,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PatientListScreen()),
            ),
          ),
        ],
      ),
    );
  }
}