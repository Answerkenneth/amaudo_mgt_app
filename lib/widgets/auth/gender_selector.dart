import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../models/user_model.dart';

/// Gender picker, styled to match [RoleSelector]. Applies to every
/// role — patient, doctor, nurse, staff, other, director, admin,
/// ceo, cmhpCoordinator, chp — since gender is a profile field, not
/// a role-specific one. Always optional: `selectedGender` may be
/// null and stays null until the person picks a value.
class GenderSelector extends StatelessWidget {
  final Gender? selectedGender;
  final ValueChanged<Gender?> onChanged;
  final String label;

  const GenderSelector({
    super.key,
    required this.selectedGender,
    required this.onChanged,
    this.label = 'Gender (optional)',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
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
            child: DropdownButtonFormField<Gender>(
              initialValue: selectedGender,
              icon: const Icon(Icons.keyboard_arrow_down_rounded,
                  color: AppColors.textSecondary),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 14),
              ),
              hint: const Text(
                'Select an option (optional)',
                style: TextStyle(color: AppColors.placeholderText),
              ),
              style: const TextStyle(
                fontSize: AppTextSize.body,
                color: AppColors.textPrimary,
              ),
              items: Gender.values
                  .map(
                    (gender) => DropdownMenuItem(
                      value: gender,
                      child: Text(gender.label),
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