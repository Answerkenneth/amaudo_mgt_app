import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../utils/validators.dart';
import '../../widgets/auth/auth_text_field.dart';
import '../../widgets/auth/auth_primary_button.dart';
import '../../widgets/auth/auth_error_banner.dart';

/// Admin-only tool for administrator-assisted account recovery.
/// Flow: search by phone/email -> display safe identifying info ->
/// explicit identity-verification confirmation -> send a normal
/// Firebase password-reset email to the account's real email on file.
///
/// This does NOT force-set a password and does NOT use a Cloud
/// Function or the Firebase Admin SDK — it triggers the exact same
/// free, self-service reset email as the regular Forgot Password
/// flow. Access is gated by AuthService.isCurrentUserAdmin, backed by
/// the server-verified `admin` custom claim.
class AdminRecoveryScreen extends StatefulWidget {
  const AdminRecoveryScreen({super.key});

  @override
  State<AdminRecoveryScreen> createState() => _AdminRecoveryScreenState();
}

class _AdminRecoveryScreenState extends State<AdminRecoveryScreen> {
  late final Future<bool> _isAdminFuture;
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();

  bool _isSearching = false;
  bool _isSendingReset = false;
  String? _errorMessage;

  UserModel? _foundAccount;
  bool _identityConfirmed = false;
  bool _resetSent = false;

  @override
  void initState() {
    super.initState();
    _isAdminFuture = AuthService.instance.isCurrentUserAdmin();
  }

  @override
  void dispose() {
    _identifierController.dispose();
    super.dispose();
  }

  void _resetSearchState() {
    _foundAccount = null;
    _identityConfirmed = false;
    _resetSent = false;
  }

  Future<void> _handleFindAccount() async {
    if (_isSearching) return;
    final formValid = _formKey.currentState?.validate() ?? false;
    if (!formValid) return;

    setState(() {
      _isSearching = true;
      _errorMessage = null;
      _resetSearchState();
    });

    try {
      final account = await AuthService.instance.findAccountForRecovery(
        identifier: _identifierController.text,
      );
      if (!mounted) return;
      if (account == null) {
        setState(() => _errorMessage = 'No matching account found.');
      } else {
        setState(() => _foundAccount = account);
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _errorMessage = 'Something went wrong. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _handleSendResetEmail() async {
    if (_isSendingReset || !_identityConfirmed || _foundAccount == null) {
      return;
    }

    setState(() {
      _isSendingReset = true;
      _errorMessage = null;
    });

    try {
      await AuthService.instance.requestPasswordReset(
        identifier: _identifierController.text,
      );
      if (!mounted) return;
      setState(() => _resetSent = true);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _errorMessage = 'Something went wrong. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _isSendingReset = false);
    }
  }

  void _handleStartOver() {
    setState(() {
      _identifierController.clear();
      _errorMessage = null;
      _resetSearchState();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Account Recovery'),
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
      ),
      body: SafeArea(
        child: FutureBuilder<bool>(
          future: _isAdminFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primaryOrange,
                ),
              );
            }

            if (snapshot.data != true) {
              return const Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  'You are not authorized to access this tool.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: _resetSent ? _buildResult() : _buildSearchAndConfirm(),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSearchAndConfirm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Account Recovery',
            style: TextStyle(
              fontSize: AppTextSize.screenTitle,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'Search for the account, verify the user\'s identity '
            'through your approved administrative process, then send '
            'them a password reset email.',
            style: TextStyle(
              fontSize: AppTextSize.screenSubtitle,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_errorMessage != null) ...[
            AuthErrorBanner(message: _errorMessage!),
            const SizedBox(height: AppSpacing.md),
          ],
          AuthTextField(
            label: "User's Phone Number or Email",
            hint: '08012345678 or you@example.com',
            controller: _identifierController,
            validator: Validators.loginIdentifier,
            keyboardType: TextInputType.emailAddress,
            prefixIcon: Icons.badge_outlined,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_foundAccount == null)
            AuthPrimaryButton(
              label: 'Find Account',
              isLoading: _isSearching,
              onPressed: _handleFindAccount,
            )
          else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.orangeTint,
                borderRadius: BorderRadius.circular(AppRadius.input),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _foundAccount!.fullName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: AppTextSize.body,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Phone: ${_foundAccount!.phone ?? 'Not on file'}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: AppTextSize.caption + 1,
                    ),
                  ),
                  Text(
                    'Role: ${_foundAccount!.displayRole}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: AppTextSize.caption + 1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: Checkbox(
                    value: _identityConfirmed,
                    activeColor: AppColors.primaryOrange,
                    onChanged: (value) =>
                        setState(() => _identityConfirmed = value ?? false),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                const Expanded(
                  child: Text(
                    'I have verified this user\'s identity and am '
                    'authorized to initiate recovery for this account.',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: AppTextSize.body,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            AuthPrimaryButton(
              label: 'Send Password Reset Email',
              isLoading: _isSendingReset,
              onPressed: _identityConfirmed ? _handleSendResetEmail : null,
            ),
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: TextButton(
                onPressed: _isSendingReset ? null : _handleStartOver,
                child: const Text(
                  'Search a different account',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResult() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.xl),
        const Icon(Icons.mark_email_read_outlined,
            color: AppColors.primaryOrange, size: 48),
        const SizedBox(height: AppSpacing.md),
        const Text(
          'Password Reset Email Sent',
          style: TextStyle(
            fontSize: AppTextSize.screenTitle,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          'Ask the user to check their inbox and Spam/Junk (and '
          'Promotions/Updates, if applicable) for the reset link. If '
          'the account has no email on file, this could not be sent — '
          'check the message above for details.',
          style: TextStyle(
            fontSize: AppTextSize.body,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        AuthPrimaryButton(
          label: 'Done',
          onPressed: _handleStartOver,
        ),
      ],
    );
  }
}