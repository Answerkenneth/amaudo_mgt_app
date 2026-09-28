import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../models/user_model.dart';

/// Displays a single Care Team member (doctor or nurse) using their
/// real profile information — never a raw Firebase UID. Shows a
/// clear empty state when no practitioner of that type is assigned.
class CareTeamMemberTile extends StatelessWidget {
  final String roleLabel; // 'Doctor' or 'Nurse'
  final UserModel? practitioner;
  final bool isLoading;

  const CareTeamMemberTile({
    super.key,
    required this.roleLabel,
    required this.practitioner,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: AppColors.orangeTint,
              shape: BoxShape.circle,
            ),
            child: Icon(
              roleLabel == 'Doctor'
                  ? Icons.medical_information_outlined
                  : Icons.health_and_safety_outlined,
              color: AppColors.primaryOrange,
              size: 18,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  roleLabel,
                  style: const TextStyle(
                    fontSize: AppTextSize.caption + 1,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                if (isLoading)
                  const Text(
                    'Loading…',
                    style: TextStyle(color: AppColors.placeholderText),
                  )
                else if (practitioner == null)
                  Text(
                    'No $roleLabel assigned yet.',
                    style: const TextStyle(color: AppColors.placeholderText),
                  )
                else ...[
                  Text(
                    practitioner!.fullName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (practitioner!.workplace != null &&
                      practitioner!.workplace!.trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      practitioner!.workplace!,
                      style: const TextStyle(
                        fontSize: AppTextSize.caption + 1,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}