import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final Future<UserModel?> _profileFuture;
  late final Future<bool> _isAdminFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = AuthService.instance.fetchCurrentUserProfile();
    _isAdminFuture = AuthService.instance.isCurrentUserAdmin();
  }

  Future<void> _handleSignOut() async {
    await AuthService.instance.signOut();
  }

  void _redirectToPasswordChange() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: const Text(
          'Amaudo',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: _handleSignOut,
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<UserModel?>(
          future: _profileFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primaryOrange,
                ),
              );
            }

            final profile = snapshot.data;

            if (profile != null && profile.mustChangePassword) {
              _redirectToPasswordChange();
              return const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primaryOrange,
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome${profile != null ? ', ${profile.fullName.split(' ').first}' : ''}',
                    style: const TextStyle(
                      fontSize: AppTextSize.screenTitle,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    profile != null
                        ? 'Signed in as ${profile.displayRole}'
                        : 'Your dashboard is being prepared.',
                    style: const TextStyle(
                      fontSize: AppTextSize.screenSubtitle,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: AppColors.orangeTint,
                      borderRadius: BorderRadius.circular(AppRadius.button),
                    ),
                    child: const Text(
                      'This is a placeholder home screen. Role-specific '
                      'dashboards (Patient, Nurse, Doctor, Staff, Director, '
                      'CEO, Admin, Other) will be built next.',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FutureBuilder<bool>(
                    future: _isAdminFuture,
                    builder: (context, adminSnapshot) {
                      if (adminSnapshot.data != true) {
                        return const SizedBox.shrink();
                      }
                      return OutlinedButton.icon(
                        onPressed: () => Navigator.of(context)
                            .pushNamed('/admin-recovery'),
                        icon: const Icon(Icons.admin_panel_settings_outlined),
                        label: const Text('Assisted Account Recovery'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryOrange,
                          side: const BorderSide(
                            color: AppColors.primaryOrange,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}