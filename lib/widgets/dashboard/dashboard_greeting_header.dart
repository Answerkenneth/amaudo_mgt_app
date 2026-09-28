import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../models/user_model.dart';

/// Shared greeting header used at the top of every role dashboard.
/// Uses the authenticated user's real name and role — never
/// hard-coded.
class DashboardGreetingHeader extends StatelessWidget {
  final UserModel user;

  const DashboardGreetingHeader({super.key, required this.user});

  String get _timeOfDayGreeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final firstName =
        user.fullName.trim().isNotEmpty ? user.fullName.trim().split(' ').first : 'there';
    final initials = user.fullName.trim().isNotEmpty
        ? user.fullName.trim().split(' ').map((p) => p[0]).take(2).join().toUpperCase()
        : 'A';

    return Row(
      children: [
        CircleAvatar(
          radius: 26,
          backgroundColor: AppColors.orangeTint,
          child: Text(
            initials,
            style: const TextStyle(
              color: AppColors.primaryOrange,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$_timeOfDayGreeting, $firstName',
                style: const TextStyle(
                  fontSize: AppTextSize.screenTitle - 4,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                user.workplace != null
                    ? '${user.displayRole} • ${user.workplace}'
                    : user.displayRole,
                style: const TextStyle(
                  fontSize: AppTextSize.caption + 1,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}