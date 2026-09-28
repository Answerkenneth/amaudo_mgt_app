import 'package:flutter/material.dart';
import '../../core/constants/app_dimens.dart';
import '../../models/user_model.dart';
import '../../widgets/dashboard/dashboard_card.dart';
import '../../widgets/dashboard/dashboard_greeting_header.dart';
import '../director/director_care_requests_screen.dart';
import '../director/director_data_screen.dart';
import '../patients/patient_list_screen.dart';
import '../requests/care_request_lists_screen.dart';
import '../analytics/diagnosis_analytics_screen.dart';
class DirectorDashboardScreen extends StatefulWidget {
  final UserModel user;

  const DirectorDashboardScreen({
    super.key,
    required this.user,
  });

  @override
  State<DirectorDashboardScreen> createState() =>
      _DirectorDashboardScreenState();
}

class _DirectorDashboardScreenState
    extends State<DirectorDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DashboardGreetingHeader(user: widget.user),
          const SizedBox(height: AppSpacing.lg),
          const Text(
            'Organizational Overview',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          DashboardCard(
            title: 'Data',
            subtitle: 'Users, patients, admissions and staff records',
            icon: Icons.dataset_outlined,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const DirectorDataScreen(),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          DashboardCard(
            title: 'Care Requests',
            subtitle: 'Review, approve, or refer patient requests',
            icon: Icons.fact_check_outlined,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const DirectorCareRequestsScreen(),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          DashboardCard(
            title: 'Approved / Under Review / Referred',
            subtitle: 'Persistent searchable patient lists',
            icon: Icons.list_alt_outlined,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const CareRequestListsScreen(),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          DashboardCard(
            title: 'Patient Management',
            subtitle: 'Search, view, and manage all patients',
            icon: Icons.groups_outlined,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const PatientListScreen(),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const DashboardCard(
            title: 'Appointments',
            subtitle: 'No data yet',
            icon: Icons.calendar_month_outlined,
          ),
          const SizedBox(height: AppSpacing.md),
                   // Analytics is Director/Admin only. Legacy `ceo` accounts are
          // routed to this same dashboard (see DashboardRouter), so the
          // tile is hidden for them; the screen also enforces the role.
          if (widget.user.role == UserRole.director) ...[
            DashboardCard(
              title: 'Analytics',
              subtitle: 'Diagnosis distribution and geographic breakdown',
              icon: Icons.insights_outlined,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const DiagnosisAnalyticsScreen(),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          const SizedBox(height: AppSpacing.md),
          const DashboardCard(
            title: 'Notifications',
            subtitle: 'View your notifications',
            icon: Icons.notifications_outlined,
          ),
        ],
      ),
    );
  }
}
