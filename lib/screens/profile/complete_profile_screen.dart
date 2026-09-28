import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../services/auth_exception.dart';
import '../../services/patient_service.dart';
import '../../services/profile_reminder_service.dart';
import '../../utils/validators.dart';
import '../../widgets/auth/auth_text_field.dart';
import '../../widgets/auth/auth_primary_button.dart';
import '../../widgets/auth/auth_error_banner.dart';

/// Lets a patient supply the one piece of information that makes
/// their profile complete: Primary Healthcare Center. Never asks for
/// diagnosis, medication, or any clinical information — those belong
/// to the later care workflow, not basic profile completion.
class CompleteProfileScreen extends StatefulWidget {
  final String patientUid;
  const CompleteProfileScreen({super.key, required this.patientUid});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phcController = TextEditingController();

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _phcController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_isSubmitting) return;
    final formValid = _formKey.currentState?.validate() ?? false;
    if (!formValid) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await PatientService.instance.completePatientProfile(
        patientUid: widget.patientUid,
        primaryHealthcareCenter: _phcController.text,
      );
      await ProfileReminderService.instance.syncForUser(
        uid: widget.patientUid,
        profileCompleted: true,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Complete Your Profile'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'One more thing',
                  style: TextStyle(
                    fontSize: AppTextSize.screenTitle,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                const Text(
                  'If you already visit a healthcare centre, let us know '
                  'which one. If you have never visited one, you can '
                  'leave this and continue — you can complete it anytime.',
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
                  label: 'Primary Healthcare Centre',
                  hint: 'e.g. Amaudo Itumbauzo Clinic',
                  controller: _phcController,
                  validator: (v) =>
                      Validators.requiredField(v, 'Primary Healthcare Centre'),
                  prefixIcon: Icons.local_hospital_outlined,
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: AppSpacing.xl),
                AuthPrimaryButton(
                  label: 'Save',
                  isLoading: _isSubmitting,
                  onPressed: _handleSave,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}