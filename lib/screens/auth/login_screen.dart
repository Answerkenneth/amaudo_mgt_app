import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../services/auth_service.dart';
import '../../utils/validators.dart';
import '../../widgets/auth/auth_text_field.dart';
import '../../widgets/auth/auth_password_field.dart';
import '../../widgets/auth/auth_primary_button.dart';
import '../../widgets/auth/auth_error_banner.dart';
import '../../widgets/auth/social_auth_button.dart';
import '../../widgets/auth/google_web_button.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _rememberMe = true;
  bool _isSubmitting = false;
  bool _isGoogleSubmitting = false;
  String? _errorMessage;

  StreamSubscription<GoogleSignInAuthenticationEvent>?
      _webGoogleAuthSubscription;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _initWebGoogleButton();
    }
  }

  Future<void> _initWebGoogleButton() async {
    // WEB ONLY: authenticate() isn't implemented on web, so instead
    // we render Google's own button (see google_web_button.dart) and
    // listen for the result here, exactly the way google_sign_in's
    // own migration guide documents for web.
    await AuthService.instance.ensureGoogleSignInReady();
    _webGoogleAuthSubscription =
        GoogleSignIn.instance.authenticationEvents.listen(
      (event) {
        if (event is GoogleSignInAuthenticationEventSignIn) {
          _handleWebGoogleAccount(event.user);
        }
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(
          () => _errorMessage = 'Google sign-in failed. Please try again.',
        );
      },
    );
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    _webGoogleAuthSubscription?.cancel();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_isSubmitting || _isGoogleSubmitting) return;

    final formValid = _formKey.currentState?.validate() ?? false;
    if (!formValid) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await AuthService.instance.applyRememberMePreference(_rememberMe);
      await AuthService.instance.signInWithIdentifier(
        identifier: _identifierController.text,
        password: _passwordController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _errorMessage = 'Something went wrong. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    if (_isSubmitting || _isGoogleSubmitting) return;

    setState(() {
      _isGoogleSubmitting = true;
      _errorMessage = null;
    });

    try {
      await AuthService.instance.applyRememberMePreference(_rememberMe);
      final credential = await AuthService.instance.signInWithGoogle();
      if (credential == null) {
        if (mounted) setState(() => _isGoogleSubmitting = false);
        return;
      }
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    } on GoogleLinkRequiredException catch (e) {
      if (mounted) setState(() => _isGoogleSubmitting = false);
      await _handleGoogleLinkRequired(e);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _errorMessage = 'Something went wrong. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _isGoogleSubmitting = false);
    }
  }

   /// WEB ONLY: called with the account delivered via
  /// GoogleSignIn.instance.authenticationEvents after the user
  /// clicks Google's own rendered button (see initState). Mirrors
  /// _handleGoogleSignIn's post-authentication handling exactly, so
  /// linking/navigation behave identically to Android.
  Future<void> _handleWebGoogleAccount(GoogleSignInAccount account) async {
    if (_isSubmitting || _isGoogleSubmitting) return;

    setState(() {
      _isGoogleSubmitting = true;
      _errorMessage = null;
    });

    try {
      await AuthService.instance.applyRememberMePreference(_rememberMe);
      final credential =
          await AuthService.instance.completeGoogleSignInFromWebEvent(
        account,
      );
      if (credential == null) {
        if (mounted) setState(() => _isGoogleSubmitting = false);
        return;
      }
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    } on GoogleLinkRequiredException catch (e) {
      if (mounted) setState(() => _isGoogleSubmitting = false);
      await _handleGoogleLinkRequired(e);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _errorMessage = 'Something went wrong. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _isGoogleSubmitting = false);
    }
  }

  Future<void> _handleGoogleLinkRequired(
    GoogleLinkRequiredException e,
  ) async {
    final password = await showDialog<String>(
      context: context,
      builder: (context) => const _GoogleLinkPasswordDialog(),
    );

    if (password == null || password.isEmpty) return;
    if (!mounted) return;

    setState(() {
      _isGoogleSubmitting = true;
      _errorMessage = null;
    });

    try {
      await AuthService.instance.linkGoogleToPasswordAccount(
        authEmail: e.authEmail,
        password: password,
        pendingGoogleCredential: e.pendingGoogleCredential,
      );
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    } on AuthException catch (ex) {
      if (!mounted) return;
      setState(() => _errorMessage = ex.message);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _errorMessage = 'Something went wrong. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _isGoogleSubmitting = false);
    }
  }

  void _handleForgotPassword() {
    if (_isSubmitting || _isGoogleSubmitting) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final anyLoading = _isSubmitting || _isGoogleSubmitting;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Welcome back',
                  style: TextStyle(
                    fontSize: AppTextSize.screenTitle,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                const Text(
                  'Sign in with your phone number or email.',
                  style: TextStyle(
                    fontSize: AppTextSize.screenSubtitle,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (_errorMessage != null) ...[
                  AuthErrorBanner(message: _errorMessage!),
                  const SizedBox(height: AppSpacing.md),
                ],
                AuthTextField(
                  label: 'Phone Number or Email',
                  hint: '08012345678 or you@example.com',
                  controller: _identifierController,
                  validator: Validators.loginIdentifier,
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: Icons.person_outline_rounded,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: AppSpacing.md),
                AuthPasswordField(
                  label: 'Password',
                  hint: 'Enter your password',
                  controller: _passwordController,
                  validator: (value) => (value == null || value.isEmpty)
                      ? 'Password is required'
                      : null,
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: Checkbox(
                        value: _rememberMe,
                        activeColor: AppColors.primaryOrange,
                        onChanged: anyLoading
                            ? null
                            : (value) => setState(
                                  () => _rememberMe = value ?? true,
                                ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    const Text(
                      'Remember me',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: AppTextSize.body,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: anyLoading ? null : _handleForgotPassword,
                      child: const Text(
                        'Forgot Password?',
                        style: TextStyle(
                          color: AppColors.primaryOrange,
                          fontWeight: FontWeight.w600,
                          fontSize: AppTextSize.body,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                AuthPrimaryButton(
                  label: 'Sign In',
                  isLoading: _isSubmitting,
                  onPressed: _handleLogin,
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: const [
                    Expanded(child: Divider(color: AppColors.divider)),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                      ),
                      child: Text(
                        'or continue with',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: AppTextSize.caption + 1,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: AppColors.divider)),
                  ],
                ),
                             const SizedBox(height: AppSpacing.md),
                if (kIsWeb)
                  Center(
                    child: _isGoogleSubmitting
                        ? const Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: AppSpacing.sm,
                            ),
                            child: CircularProgressIndicator(
                              color: AppColors.primaryOrange,
                            ),
                          )
                        // Google's own rendered button — required on
                        // web since authenticate() isn't supported
                        // there; see google_web_button.dart. Sign-in
                        // completion is handled by the
                        // authenticationEvents listener set up in
                        // initState, not by an onPressed here.
                        : buildGoogleRenderedButton(),
                  )
                else
                  SocialAuthButton(
                    label: 'Continue with Google',
                    isLoading: _isGoogleSubmitting,
                    onPressed: anyLoading ? null : _handleGoogleSignIn,
                    icon: const Icon(
                      Icons.g_mobiledata_rounded,
                      size: 26,
                      color: AppColors.primaryOrange,
                    ),
                  ),
                const SizedBox(height: AppSpacing.lg),
                Center(
                  child: GestureDetector(
                    onTap: anyLoading
                        ? null
                        : () => Navigator.of(context)
                            .pushReplacementNamed('/register'),
                    child: RichText(
                      text: const TextSpan(
                        style: TextStyle(
                          fontSize: AppTextSize.body,
                          color: AppColors.textSecondary,
                        ),
                        children: [
                          TextSpan(text: "Don't have an account?  "),
                          TextSpan(
                            text: 'Create one',
                            style: TextStyle(
                              color: AppColors.primaryOrange,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small password-confirmation dialog shown only when Google Sign-In
/// detects an email collision with an existing phone+password
/// account. Styled consistently with the app's existing dialog and
/// form patterns — not a new design.
class _GoogleLinkPasswordDialog extends StatefulWidget {
  const _GoogleLinkPasswordDialog();

  @override
  State<_GoogleLinkPasswordDialog> createState() =>
      _GoogleLinkPasswordDialogState();
}

class _GoogleLinkPasswordDialogState
    extends State<_GoogleLinkPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sheet - 12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Confirm your password',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                'An Amaudo account already exists with this email. '
                'Enter its password once to connect Google Sign-In to '
                'your existing account.',
                style: TextStyle(
                  fontSize: AppTextSize.caption + 1,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AuthPasswordField(
                label: 'Password',
                hint: 'Enter your existing password',
                controller: _passwordController,
                validator: (value) => (value == null || value.isEmpty)
                    ? 'Password is required'
                    : null,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryOrange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppRadius.input),
                        ),
                      ),
                      onPressed: () {
                        if (_formKey.currentState?.validate() ?? false) {
                          Navigator.of(context)
                              .pop(_passwordController.text);
                        }
                      },
                      child: const Text('Connect'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}