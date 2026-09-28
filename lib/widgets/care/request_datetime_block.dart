import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../utils/date_format_utils.dart';

/// Shared display block for a care request's requested time/date.
/// Required order: Requested Time first, then Requested Date
/// underneath — vertically stacked, never side by side.
class RequestDateTimeBlock extends StatelessWidget {
  final DateTime dateTime;
  const RequestDateTimeBlock({super.key, required this.dateTime});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Requested Time',
          style: TextStyle(
            fontSize: AppTextSize.caption,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          formatTime12Hour(dateTime),
          style: const TextStyle(
            fontSize: AppTextSize.body,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        const Text(
          'Requested Date',
          style: TextStyle(
            fontSize: AppTextSize.caption,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          formatLongDate(dateTime),
          style: const TextStyle(
            fontSize: AppTextSize.body,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}