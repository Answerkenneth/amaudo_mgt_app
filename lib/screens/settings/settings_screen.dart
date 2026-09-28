import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../widgets/auth/gender_selector.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late  Future<UserModel?> _userFuture;
  bool _isSigningOut = false;

  @override
  void initState() {
    super.initState();
    _userFuture = AuthService.instance.fetchCurrentUserProfile();
  }

  Future<void> _handleSignOut() async {
    if (_isSigningOut) return;
    setState(() => _isSigningOut = true);
    await AuthService.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }
 Future<void> _handleEditGender(Gender? currentGender) async {
    final result = await showDialog<Gender>(
      context: context,
      builder: (context) => _EditGenderDialog(initialGender: currentGender),
    );
    if (result == null || !mounted) return;

    try {
      await AuthService.instance.updateGender(result);
      if (!mounted) return;
      setState(() {
        _userFuture = AuthService.instance.fetchCurrentUserProfile();
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
       } catch (e) {
      // ignore: avoid_print
      print('_handleEditGender unexpected error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Something went wrong: $e')),
      );
    }
  }
    Future<void> _handleEditAge(int? currentAge) async {
    final result = await showDialog<int>(
      context: context,
      builder: (context) => _EditAgeDialog(initialAge: currentAge),
    );
    if (result == null || !mounted) return;

    try {
      await AuthService.instance.updateAge(result);
      if (!mounted) return;
      setState(() {
        _userFuture = AuthService.instance.fetchCurrentUserProfile();
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Something went wrong: $e')),
      );
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Settings'),
      ),
      body: SafeArea(
        child: FutureBuilder<UserModel?>(
          future: _userFuture,
          builder: (context, snapshot) {
            final user = snapshot.data;

            return ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                const _SectionLabel('Account'),
                _SettingsTile(
                  icon: Icons.person_outline_rounded,
                  title: 'Profile',
                  subtitle: user?.fullName ?? 'Loading…',
                ),
                _SettingsTile(
                  icon: Icons.badge_outlined,
                  title: 'Role',
                  subtitle: user?.displayRole ?? 'Loading…',
                ),
                                _SettingsTile(
                  icon: Icons.wc_outlined,
                  title: 'Gender',
                  subtitle: user?.gender?.label ?? 'Not on file',
                  onTap: user == null
                      ? null
                      : () => _handleEditGender(user.gender),
                ),
                _SettingsTile(
                  icon: Icons.cake_outlined,
                  title: 'Age',
                  subtitle: user?.age != null
                      ? '${user!.age}'
                      : 'Not provided',
                  onTap: user == null
                      ? null
                      : () => _handleEditAge(user.age),
                ),
                _SettingsTile(
                  icon: Icons.local_hospital_outlined,
                  title: 'Workplace / Location',
                  subtitle: user?.workplace ?? 'Not on file',
                ),
                const SizedBox(height: AppSpacing.lg),
                const _SectionLabel('Preferences'),

                
                const _SettingsTile(
                  icon: Icons.notifications_outlined,
                  title: 'Notifications',
                  subtitle: 'Coming soon',
                ),
                const _SettingsTile(
                  icon: Icons.alarm_outlined,
                  title: 'Reminder Preferences',
                  subtitle: 'Coming soon',
                ),
                const SizedBox(height: AppSpacing.lg),
                const _SectionLabel('Information'),
                _SettingsTile(
                  icon: Icons.info_outline_rounded,
                  title: 'About Amaudo',
                  subtitle: 'Our mission and community programmes',
                  onTap: () => Navigator.of(context).pushNamed('/about'),
                ),
                const SizedBox(height: AppSpacing.lg),
                const _SectionLabel('Security'),
                _SettingsTile(
                  icon: Icons.lock_outline_rounded,
                  title: 'Change Password',
                  subtitle:
                      'Use "Forgot Password" from the sign-in screen',
                ),
                _SettingsTile(
                  icon: Icons.logout_rounded,
                  title: 'Sign Out',
                  subtitle: null,
                  isLoading: _isSigningOut,
                  onTap: _handleSignOut,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 13,
          color: AppColors.textSecondary,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool isLoading;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.button),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.button),
          onTap: isLoading ? null : onTap,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.button),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: AppColors.primaryOrange,
                  size: 22,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: const TextStyle(
                            fontSize: AppTextSize.caption + 1,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (isLoading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primaryOrange,
                    ),
                  )
                else if (onTap != null)
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
class _EditGenderDialog extends StatefulWidget {
  final Gender? initialGender;
  const _EditGenderDialog({required this.initialGender});

  @override
  State<_EditGenderDialog> createState() => _EditGenderDialogState();
}

class _EditGenderDialogState extends State<_EditGenderDialog> {
  Gender? _gender;

  @override
  void initState() {
    super.initState();
    _gender = widget.initialGender;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Gender'),
      content: SizedBox(
        width: double.maxFinite,
        child: GenderSelector(
          label: 'Select gender',
          selectedGender: _gender,
          onChanged: (value) => setState(() => _gender = value),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _gender == null
              ? null
              : () => Navigator.of(context).pop(_gender),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
class _EditAgeDialog extends StatefulWidget {
  final int? initialAge;
  const _EditAgeDialog({required this.initialAge});

  @override
  State<_EditAgeDialog> createState() => _EditAgeDialogState();
}

class _EditAgeDialogState extends State<_EditAgeDialog> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialAge?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSave() {
    final parsed = int.tryParse(_controller.text.trim());
    if (parsed == null || parsed <= 0 || parsed > 120) {
      setState(() => _errorText = 'Enter a valid age');
      return;
    }
    Navigator.of(context).pop(parsed);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Age'),
      content: TextField(
        controller: _controller,
        keyboardType: TextInputType.number,
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'Enter your age',
          errorText: _errorText,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _handleSave, child: const Text('Save')),
      ],
    );
  }
}