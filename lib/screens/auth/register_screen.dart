
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../utils/validators.dart';
import '../../widgets/auth/auth_text_field.dart';
import '../../widgets/auth/auth_password_field.dart';
import '../../widgets/auth/role_selector.dart';
import '../../widgets/auth/auth_primary_button.dart';
import '../../widgets/auth/auth_error_banner.dart';
import '../../widgets/auth/gender_selector.dart';
/// Registration screen.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _emailController = TextEditingController();
  final _ageController = TextEditingController();
  final _customRoleController = TextEditingController();

  final _countryController = TextEditingController();
  final _stateController = TextEditingController();
  final _lgaController = TextEditingController();
  final _addressController = TextEditingController();
  final _workplaceController = TextEditingController();
  final _workLocationController = TextEditingController();

  final _hearAboutAmaudoOtherController = TextEditingController();

  UserRole? _selectedRole;
  Gender? _selectedGender;
  String? _chpClinicalRole;
  String? _hearAboutAmaudo;

  final List<String> _hearAboutOptions = [
    'Friend or Family',
    'Social Media',
    'Google Search',
    'Healthcare Professional',
    'Community Outreach',
    'Amaudo Website',
    'Referral',
    'Other',
  ];

  bool _isSubmitting = false;
  String? _errorMessage;

  bool _isCheckingRoleAvailability = false;
  String? _privilegedRoleTakenWarning;

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _emailController.dispose();
     _ageController.dispose();
    _customRoleController.dispose();
    _countryController.dispose();
    _stateController.dispose();
    _lgaController.dispose();
    _addressController.dispose();
    _workplaceController.dispose();
    _workLocationController.dispose();
    _hearAboutAmaudoOtherController.dispose();
    super.dispose();
  }

  Future<void> _handleRoleChanged(UserRole? role) async {
    setState(() {
      _selectedRole = role;
      _privilegedRoleTakenWarning = null;
    });

    if (role == null) return;

    // Best-effort early hint only — not the actual enforcement, which
    // happens atomically at submit time regardless of this check.
    const privileged = {UserRole.ceo, UserRole.director, UserRole.admin};
    if (!privileged.contains(role)) return;

    setState(() => _isCheckingRoleAvailability = true);
    try {
      final taken = await AuthService.instance.isPrivilegedRoleTaken(role);
      if (!mounted) return;
      setState(() {
        _privilegedRoleTakenWarning = taken
            ? 'The ${role.label} role is already assigned to another '
                'account. You can still submit, but registration will be '
                'blocked if this remains true.'
            : null;
      });
    } catch (_) {
      // Silently ignore — the real check happens at submit time.
    } finally {
      if (mounted) setState(() => _isCheckingRoleAvailability = false);
    }
  }

  Future<void> _handleRegister() async {
    if (_isSubmitting) return;

    final formValid = _formKey.currentState?.validate() ?? false;
    if (!formValid || _selectedRole == null) {
      setState(() {
        _errorMessage = _selectedRole == null
            ? 'Please select a role to continue.'
            : null;
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final isPatient = _selectedRole == UserRole.patient;

    try {
      await AuthService.instance.registerWithPhoneAndPassword(
        fullName: _fullNameController.text,
        phone: _phoneController.text,
        password: _passwordController.text,
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text,
        gender: _selectedGender,
        age: _ageController.text.trim().isEmpty
            ? null
            : int.tryParse(_ageController.text.trim()),
        role: _selectedRole!,
        chpClinicalRole: _chpClinicalRole,
        customRole: _selectedRole == UserRole.other
            ? _customRoleController.text
            : null,
        country: _countryController.text,
        state: _stateController.text,
        localGovernmentArea: _lgaController.text,
        address: isPatient ? _addressController.text : null,
        workplace: _workplaceController.text.trim().isEmpty
            ? null
            : _workplaceController.text,
        workLocation: isPatient ? null : _workLocationController.text,

        // Patient-only fields.
        hearAboutAmaudo: _selectedRole == UserRole.patient
            ? _hearAboutAmaudo
            : null,
        hearAboutAmaudoOther: _selectedRole == UserRole.patient
            ? _hearAboutAmaudoOtherController.text
            : null,
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

  @override
  Widget build(BuildContext context) {
    final isPatient = _selectedRole == UserRole.patient;
    final showWorkplaceFields =
        _selectedRole != null && _selectedRole != UserRole.patient;

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
                  'Create your account',
                  style: TextStyle(
                    fontSize: AppTextSize.screenTitle,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                const Text(
                  'Join the Amaudo community healthcare network.',
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
                  label: 'Full Name',
                  hint: 'e.g. Adaeze Okafor',
                  controller: _fullNameController,
                  validator: Validators.fullName,
                  prefixIcon: Icons.person_outline_rounded,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: AppSpacing.md),
                AuthTextField(
                  label: 'Phone Number',
                  hint: '08012345678 or +2348012345678',
                  controller: _phoneController,
                  validator: Validators.phone,
                  keyboardType: TextInputType.phone,
                  prefixIcon: Icons.phone_outlined,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: AppSpacing.md),
                AuthPasswordField(
                  label: 'Password',
                  hint: 'At least 8 characters',
                  controller: _passwordController,
                  validator: Validators.password,
                ),
                const SizedBox(height: AppSpacing.md),
                AuthPasswordField(
                  label: 'Confirm Password',
                  hint: 'Re-enter your password',
                  controller: _confirmPasswordController,
                  validator: (value) => Validators.confirmPassword(
                    value,
                    _passwordController.text,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AuthTextField(
                  label: 'Email (optional)',
                  hint: 'you@example.com',
                  controller: _emailController,
                  validator: Validators.emailOptional,
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: Icons.mail_outline_rounded,
                  textInputAction: TextInputAction.next,
                ),
                 const SizedBox(height: AppSpacing.md),
                               const SizedBox(height: AppSpacing.md),
                GenderSelector(
                  selectedGender: _selectedGender,
                  onChanged: (value) =>
                      setState(() => _selectedGender = value),
                ),
                const SizedBox(height: AppSpacing.md),
                AuthTextField(
                  label: 'Age (optional)',
                  hint: 'Enter your age',
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return null;
                    final parsed = int.tryParse(value.trim());
                    if (parsed == null || parsed <= 0 || parsed > 120) {
                      return 'Enter a valid age';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                RoleSelector(
                  selectedRole: _selectedRole,
                  onChanged: _handleRoleChanged,
                ),
                if (_isCheckingRoleAvailability) ...[
                  const SizedBox(height: AppSpacing.xs),
                  const Text(
                    'Checking role availability…',
                    style: TextStyle(
                      fontSize: AppTextSize.caption,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                if (_privilegedRoleTakenWarning != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _privilegedRoleTakenWarning!,
                    style: const TextStyle(
                      fontSize: AppTextSize.caption + 1,
                      color: AppColors.error,
                    ),
                  ),
                ],
                if (_selectedRole == UserRole.chp) ...[
                  const SizedBox(height: AppSpacing.md),
                  const Text(
                    'Are you also a Doctor or Nurse?',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<String>(
                          value: 'doctor',
                          groupValue: _chpClinicalRole,
                          onChanged: (v) =>
                              setState(() => _chpClinicalRole = v),
                          title: const Text('Doctor'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<String>(
                          value: 'nurse',
                          groupValue: _chpClinicalRole,
                          onChanged: (v) =>
                              setState(() => _chpClinicalRole = v),
                          title: const Text('Nurse'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ],
                if (_selectedRole == UserRole.other) ...[
                  const SizedBox(height: AppSpacing.md),
                  AuthTextField(
                    label: 'Specify your role',
                    hint: 'e.g. Volunteer Counsellor',
                    controller: _customRoleController,
                    validator: Validators.customRole,
                    prefixIcon: Icons.badge_outlined,
                    textInputAction: TextInputAction.next,
                  ),
                ],

                // Patient-only "How did you hear about Amaudo?" field.
                if (_selectedRole == UserRole.patient) ...[
                  const SizedBox(height: AppSpacing.lg),
                  const Text(
                    'How did you hear about Amaudo?',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.inputFill,
                      borderRadius: BorderRadius.circular(AppRadius.input),
                      border: Border.all(color: AppColors.inputBorder),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButtonFormField<String>(
                        initialValue: _hearAboutAmaudo,
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AppColors.textSecondary,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 14),
                        ),
                        hint: const Text(
                          'Select an option (optional)',
                          style: TextStyle(
                            color: AppColors.placeholderText,
                          ),
                        ),
                        items: _hearAboutOptions
                            .map(
                              (option) => DropdownMenuItem(
                                value: option,
                                child: Text(option),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _hearAboutAmaudo = value),
                      ),
                    ),
                  ),
                  if (_hearAboutAmaudo == 'Other') ...[
                    const SizedBox(height: AppSpacing.md),
                    AuthTextField(
                      label: 'Please specify',
                      hint: 'Tell us how you heard about Amaudo',
                      controller: _hearAboutAmaudoOtherController,
                      validator: (_) => null,
                      prefixIcon: Icons.edit_outlined,
                      textInputAction: TextInputAction.done,
                    ),
                  ],
                ],

                const SizedBox(height: AppSpacing.lg),
                const Text(
                  'Location & Workplace',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                AuthTextField(
                  label: 'Country',
                  hint: 'e.g. Nigeria',
                  controller: _countryController,
                  validator: (v) => Validators.requiredField(v, 'Country'),
                  prefixIcon: Icons.public_outlined,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: AppSpacing.md),
                AuthTextField(
                  label: 'State',
                  hint: 'e.g. Abia',
                  controller: _stateController,
                  validator: (v) => Validators.requiredField(v, 'State'),
                  prefixIcon: Icons.map_outlined,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: AppSpacing.md),
                AuthTextField(
                  label: 'Local Government Area',
                  hint: 'e.g. Bende',
                  controller: _lgaController,
                  validator: (v) =>
                      Validators.requiredField(v, 'Local Government Area'),
                  prefixIcon: Icons.location_city_outlined,
                  textInputAction: TextInputAction.next,
                ),
                if (isPatient) ...[
                  const SizedBox(height: AppSpacing.md),
                  AuthTextField(
                    label: 'Address',
                    hint: 'Street address',
                    controller: _addressController,
                    validator: (v) => Validators.requiredField(v, 'Address'),
                    prefixIcon: Icons.home_outlined,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AuthTextField(
                    label: 'Primary Healthcare Centre (optional)',
                    hint: 'e.g. Amaudo Itumbauzo Clinic',
                    controller: _workplaceController,
                    prefixIcon: Icons.local_hospital_outlined,
                    textInputAction: TextInputAction.done,
                  ),
                ],
                if (showWorkplaceFields) ...[
                  const SizedBox(height: AppSpacing.md),
                  AuthTextField(
                    label: 'Workplace / Facility',
                    hint: 'e.g. Amaudo Itumbauzo Clinic',
                    controller: _workplaceController,
                    validator: (v) => Validators.requiredField(
                      v,
                      'Workplace / Facility',
                    ),
                    prefixIcon: Icons.local_hospital_outlined,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AuthTextField(
                    label: 'Specific Work Location',
                    hint: 'e.g. Community outreach — Uzuakoli',
                    controller: _workLocationController,
                    validator: (v) => Validators.requiredField(
                      v,
                      'Specific Work Location',
                    ),
                    prefixIcon: Icons.pin_drop_outlined,
                    textInputAction: TextInputAction.done,
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                AuthPrimaryButton(
                  label: 'Create Account',
                  isLoading: _isSubmitting,
                  onPressed: _handleRegister,
                ),
                const SizedBox(height: AppSpacing.lg),
                Center(
                  child: GestureDetector(
                    onTap: _isSubmitting
                        ? null
                        : () => Navigator.of(context)
                            .pushReplacementNamed('/login'),
                    child: RichText(
                      text: const TextSpan(
                        style: TextStyle(
                          fontSize: AppTextSize.body,
                          color: AppColors.textSecondary,
                        ),
                        children: [
                          TextSpan(text: 'Already have an account?  '),
                          TextSpan(
                            text: 'Sign In',
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

