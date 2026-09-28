import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../models/user_model.dart';

class RoleSelector extends StatelessWidget {
  final UserRole? selectedRole;
  final ValueChanged<UserRole?> onChanged;

  const RoleSelector({
    super.key,
    required this.selectedRole,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Role',
          style: TextStyle(
            fontSize: AppTextSize.label,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Container(
          decoration: BoxDecoration(
            color: AppColors.inputFill,
            borderRadius: BorderRadius.circular(AppRadius.input),
            border: Border.all(color: AppColors.inputBorder),
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: DropdownButtonHideUnderline(
            child: DropdownButtonFormField<UserRole>(
              initialValue: selectedRole,
              icon: const Icon(Icons.keyboard_arrow_down_rounded,
                  color: AppColors.textSecondary),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 14),
              ),
              hint: const Text(
                'Select your role',
                style: TextStyle(color: AppColors.placeholderText),
              ),
              style: const TextStyle(
                fontSize: AppTextSize.body,
                color: AppColors.textPrimary,
              ),
              validator: (value) =>
                  value == null ? 'Please select a role' : null,
                           items: UserRole.values
                  // UserRole.ceo remains in the enum for backward
                  // compatibility with existing accounts, but is no
                  // longer offered as a registration choice — new
                  // privileged registrations use Director instead.
                  .where((role) => role != UserRole.ceo)
                  .map(
                    (role) => DropdownMenuItem(
                      value: role,
                      child: Text(role.label),
                    ),
                  )
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}