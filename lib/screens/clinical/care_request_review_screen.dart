import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../models/care_request_model.dart';
import '../../services/auth_exception.dart';
import '../../services/auth_service.dart';
import '../../widgets/care/request_datetime_block.dart';
import 'clinical_encounter_screen.dart';
import '../../services/care_request_service.dart';

/// Where an accepting practitioner reviews a patient's concern and
/// records their NEXT-STEP DECISION — never a diagnosis. Accepting a
/// care request never implies clinical judgment has occurred; this
/// screen is the explicit, separate step where that judgment is made
/// and recorded.
class CareRequestReviewScreen extends StatefulWidget {
  final CareRequestModel request;
  const CareRequestReviewScreen({super.key, required this.request});

  @override
  State<CareRequestReviewScreen> createState() =>
      _CareRequestReviewScreenState();
}

enum _NextStepOption {
  remoteAssessment,
  inPersonAssessment,
  appointmentRequired,
  followUp,
  referral,
}

extension on _NextStepOption {
  String get label {
    switch (this) {
      case _NextStepOption.remoteAssessment:
        return 'Continue with remote assessment';
      case _NextStepOption.inPersonAssessment:
        return 'In-person assessment recommended';
      case _NextStepOption.appointmentRequired:
        return 'Appointment required';
      case _NextStepOption.followUp:
        return 'Schedule follow-up';
      case _NextStepOption.referral:
        return 'Referral recommended';
    }
  }

  String get storageValue => name;
}

class _CareRequestReviewScreenState extends State<CareRequestReviewScreen> {
  final _notesController = TextEditingController();
  _NextStepOption? _selectedOption;
  bool _isSubmitting = false;
  String? _errorMessage;
  bool _decisionSaved = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveDecision() async {
    if (_isSubmitting || _selectedOption == null) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      // Decision is recorded directly on the care request document —
      // the practitioner already owns it (acceptedByUid == self), so
      // this uses the same trusted update path as completing a
      // request, not a new privilege.
      await CareRequestService.instance.saveDecision(
  requestId: widget.request.requestId,
  decision: _selectedOption!.storageValue,
  notes: _notesController.text.trim().isEmpty
      ? null
      : _notesController.text.trim(),
);
      if (!mounted) return;
      setState(() => _decisionSaved = true);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Review Care Request'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.errorTint,
                    borderRadius: BorderRadius.circular(AppRadius.input),
                  ),
                  child: Text(_errorMessage!,
                      style: const TextStyle(color: AppColors.error)),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              _Section(
                title: 'Patient\'s Concern',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.reason ?? 'No details provided',
                        style: const TextStyle(color: AppColors.textPrimary)),
                    if (r.onsetInfo != null) ...[
                      const SizedBox(height: 6),
                      Text('Onset: ${r.onsetInfo}',
                          style: const TextStyle(color: AppColors.textSecondary)),
                    ],
                    if (r.impact != null) ...[
                      const SizedBox(height: 4),
                      Text('Impact: ${r.impact}',
                          style: const TextStyle(color: AppColors.textSecondary)),
                    ],
                    if (r.additionalInfo != null) ...[
                      const SizedBox(height: 4),
                      Text('Additional: ${r.additionalInfo}',
                          style: const TextStyle(color: AppColors.textSecondary)),
                    ],
                    if (r.requestedAt != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      RequestDateTimeBlock(dateTime: r.requestedAt!),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_decisionSaved) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.orangeTint,
                    borderRadius: BorderRadius.circular(AppRadius.button),
                  ),
                  child: const Text(
                    'Decision recorded. If a clinical interaction has already '
                    'taken place, you can record a Clinical Encounter next.',
                    style: TextStyle(color: AppColors.textPrimary),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                               if (_selectedOption == _NextStepOption.remoteAssessment)
                  // Remote assessment: no appointment involved, so
                  // this is the one path allowed straight into
                  // clinical recording — the practitioner's explicit
                  // save IS the record of the remote interaction.
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ClinicalEncounterScreen(
                          patientUid: r.patientUid,
                          careRequestId: r.requestId,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.assignment_outlined),
                    label: const Text('Record Clinical Appointment'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryOrange,
                      side: const BorderSide(color: AppColors.primaryOrange),
                      minimumSize: const Size(double.infinity, 44),
                    ),
                  )
                else
                  // In-person / appointment / follow-up / referral:
                  // clinical recording is gated behind an actual
                  // appointment being confirmed as completed — direct
                  // the practitioner to the patient's profile to
                  // schedule that appointment first.
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.orangeTint,
                      borderRadius: BorderRadius.circular(AppRadius.button),
                    ),
                    child: const Text(
                      'Schedule an appointment for this patient from their '
                      'profile. Clinical recording becomes available once '
                      'you confirm the appointment took place.',
                      style: TextStyle(color: AppColors.textPrimary),
                    ),
                  ),
              ] else ...[
                const Text(
                  'What is the appropriate next step?',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                const SizedBox(height: AppSpacing.sm),
                ..._NextStepOption.values.map((option) => RadioListTile<_NextStepOption>(
                      value: option,
                      groupValue: _selectedOption,
                      onChanged: (v) => setState(() => _selectedOption = v),
                      title: Text(option.label),
                      activeColor: AppColors.primaryOrange,
                      contentPadding: EdgeInsets.zero,
                    )),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Notes (optional)',
                    filled: true,
                    fillColor: AppColors.inputFill,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.input),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryOrange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _selectedOption == null || _isSubmitting
                        ? null
                        : _saveDecision,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Save Decision'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.button),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }
}