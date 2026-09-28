import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';

/// Standalone pushable screen (own Scaffold/AppBar). Structural shell
/// only — real-time messaging is implemented in a later chunk.
class ChatDetailScreen extends StatelessWidget {
  final String conversationTitle;

  const ChatDetailScreen({super.key, required this.conversationTitle});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: Text(conversationTitle),
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: Text(
            'Messaging for this conversation will be available soon.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      ),
    );
  }
}