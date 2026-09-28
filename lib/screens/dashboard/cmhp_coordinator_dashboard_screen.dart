import 'package:flutter/material.dart';

import '../../core/constants/app_dimens.dart';

import '../../models/user_model.dart';

import '../../widgets/dashboard/dashboard_card.dart';

import '../../widgets/dashboard/dashboard_greeting_header.dart';


import '../requests/care_request_lists_screen.dart';

/// Structural placeholder — practitioner-assignment functionality
/// (Section 20's actual CMHP Coordinator responsibilities) arrives in
/// a later sub-chunk of 4C-5R.

class CmhpCoordinatorDashboardScreen extends StatelessWidget {
  final UserModel user;

  const CmhpCoordinatorDashboardScreen({super.key, required this.user});

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