import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../models/notification_model.dart';
import '../../services/auth_service.dart';
import '../../services/notification_router.dart';
import '../../services/notification_service.dart';

/// Tab-embedded notification content.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  String _relativeTime(DateTime? createdAt) {
    if (createdAt == null) return '';

    final difference = DateTime.now().difference(createdAt);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    }
    if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    }
    if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    }

    return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = AuthService.instance.currentUser;

    if (currentUser == null) {
      return const Center(
        child: Text('Please sign in to view notifications.'),
      );
    }

    return FutureBuilder<List<NotificationModel>>(
      future: NotificationService.instance.fetchForUser(currentUser.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: AppColors.primaryOrange,
            ),
          );
        }

        if (snapshot.hasError) {
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
                      Icons.notifications_none_rounded,
                      color: AppColors.primaryOrange,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Text(
                    'Unable to load notifications',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: AppTextSize.body,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final notifications = snapshot.data ?? [];

        if (notifications.isEmpty) {
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
                      Icons.notifications_none_rounded,
                      color: AppColors.primaryOrange,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Text(
                    'No notifications yet',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: AppTextSize.body,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  const Text(
                    "You'll see notifications, appointment, and other updates here.",
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

        return ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: notifications.length,
          separatorBuilder: (_, __) =>
              const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, index) {
            final notification = notifications[index];

            return Material(
              color: notification.read
                  ? AppColors.inputFill
                  : AppColors.orangeTint,
              borderRadius: BorderRadius.circular(AppRadius.input),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.input),
                onTap: () async {
                  if (!notification.read) {
                    try {
                      await NotificationService.instance
                          .markRead(notification.id);
                    } catch (_) {
                      // A notification read failure should not break
                      // the notification screen.
                    }
                  }
                  await NotificationRouter.routeFromNotification(notification);
                },
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: AppColors.orangeTint,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.notifications_outlined,
                          color: AppColors.primaryOrange,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    notification.title,
                                    style: TextStyle(
                                      fontWeight: notification.read
                                          ? FontWeight.w600
                                          : FontWeight.w800,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                if (_relativeTime(
                                  notification.createdAt,
                                ).isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      left: AppSpacing.sm,
                                    ),
                                    child: Text(
                                      _relativeTime(
                                        notification.createdAt,
                                      ),
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: AppTextSize.caption,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              notification.body,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: AppTextSize.caption + 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}