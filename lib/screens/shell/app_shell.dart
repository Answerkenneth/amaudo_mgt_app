import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/fcm_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/nav/amaudo_bottom_nav.dart';
import '../chat/conversations_list_screen.dart';
import '../appointments/appointments_screen.dart';
import '../notifications/notifications_screen.dart';
import '../settings/settings_screen.dart';
import '../dashboard/dashboard_router.dart';
/// Persistent authenticated application shell: WhatsApp-style 4-tab
/// bottom navigation (Home / Chat / Appointments / Settings) with
/// Notifications in the top-right app bar corner (carries the unread
/// badge). Settings and Notifications were swapped from their
/// original positions — Settings used to be the app bar icon and
/// Notifications used to be the 4th tab. Tab content (Home/Chat/
/// Appointments) is kept alive via IndexedStack so switching tabs
/// doesn't rebuild/reset each screen; Settings and Notifications are
/// both full pushed screens, same as before the swap.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;
  late final Future<UserModel?> _userFuture;

  static const List<String> _titles = [
    'Home',
    'Chat',
    'Appointments',
    'Settings',
  ];

     @override
  void initState() {
    super.initState();
    _userFuture = AuthService.instance.fetchCurrentUserProfile();
    // Covers both "after successful signup/login" (AppShell mounts
    // fresh via navigation) and "already logged in, reopens app"
    // (AppShell mounts on launch, routed here by AuthGate) — this is
    // the one landing point common to every authenticated role.
    FcmService.instance.initialize();
  }

  void _openNotifications() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const _NotificationsPage()),
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserModel?>(
      future: _userFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primaryOrange),
            ),
          );
        }

        final user = snapshot.data;
        final currentUid = AuthService.instance.currentUser?.uid;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.background,
            elevation: 0,
            foregroundColor: AppColors.textPrimary,
            title: Text(
              _titles[_currentIndex],
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            actions: [
              StreamBuilder<int>(
                stream: currentUid == null
                    ? const Stream<int>.empty()
                    : NotificationService.instance.watchUnreadCount(currentUid),
                builder: (context, unreadSnapshot) {
                  final unread = unreadSnapshot.data ?? 0;
                  return IconButton(
                    icon: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(Icons.notifications_none_rounded),
                        if (unread > 0)
                          Positioned(
                            right: -6,
                            top: -4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.error,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.icon),
                              ),
                              child: Text(
                                unread > 9 ? '9+' : '$unread',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    tooltip: 'Notifications',
                    onPressed: _openNotifications,
                  );
                },
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
          ),
                   body: SafeArea(
            child: IndexedStack(
              index: _currentIndex,
              children: [
                _HomeTab(user: user),
                const ConversationsListScreen(),
                const AppointmentsScreen(),
                // Settings' slot is never actually shown — tapping it
                // in the bottom nav pushes SettingsScreen instead of
                // switching to this index (see bottomNavigationBar
                // onTap below). Kept as a harmless placeholder so
                // IndexedStack always has 4 children matching the 4
                // nav items.
                const SizedBox.shrink(),
              ],
            ),
          ),
          bottomNavigationBar: AmaudoBottomNav(
            currentIndex: _currentIndex,
            onTap: (index) {
              if (index == 3) {
                _openSettings();
              } else {
                setState(() => _currentIndex = index);
              }
            },
          ),
        );
      },
    );
  }
}

/// Thin wrapper so the existing, unmodified NotificationsScreen (tab
/// content — no Scaffold/AppBar of its own) can also be reached as a
/// standalone pushed screen from the app bar, styled identically to
/// how SettingsScreen looks when pushed.
class _NotificationsPage extends StatelessWidget {
  const _NotificationsPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Notifications'),
      ),
      body: const SafeArea(child: NotificationsScreen()),
    );
  }
}

class _HomeTab extends StatelessWidget {
  final UserModel? user;
  const _HomeTab({required this.user});

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.hourglass_top_rounded,
                  color: AppColors.primaryOrange, size: 40),
              SizedBox(height: AppSpacing.md),
              Text(
                'Your Amaudo profile is still being set up.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }
    return DashboardRouter(user: user!);
  }
}