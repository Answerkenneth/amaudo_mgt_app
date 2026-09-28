import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';

/// Shared compact stat display for privileged/executive dashboards.
/// [value] must be a real figure or an honest placeholder ("--",
/// "No data yet") — never a fabricated number.
class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final String? status;

  const StatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.button),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primaryOrange, size: 20),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: AppTextSize.caption,
              color: AppColors.textSecondary,
            ),
          ),
          if (status != null) ...[
            const SizedBox(height: 4),
            Text(
              status!,
              style: const TextStyle(
                fontSize: AppTextSize.caption - 1,
                color: AppColors.placeholderText,
              ),
            ),
          ],
        ],
      ),
    );
  }
}