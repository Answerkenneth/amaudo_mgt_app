import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';

/// Tab-embedded content (no own Scaffold/AppBar — hosted inside
/// AppShell). Structural only for this chunk: professional empty
/// state, no fake conversation data. Full chat backend arrives in a
/// later chunk.
class ConversationsListScreen extends StatelessWidget {
  const ConversationsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.orangeTint,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                color: AppColors.primaryOrange,
                size: 32,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'No conversations yet',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: AppTextSize.body,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Conversations with your care team will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: AppTextSize.caption + 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}