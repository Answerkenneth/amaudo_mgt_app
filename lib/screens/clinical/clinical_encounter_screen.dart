import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../models/appointment_model.dart';
import '../../models/diagnosis_model.dart';
import '../../services/appointment_service.dart';
import '../../services/auth_service.dart';
import '../../services/clinical_encounter_service.dart';
import '../../services/diagnosis_service.dart';

/// Records the clinical part of a completed appointment.
///
/// The first completed clinical appointment for a patient is the initial
/// assessment and uses the structured diagnosis categories. Once a diagnosis
/// exists, later completed appointments are recorded as follow-ups.
class ClinicalEncounterScreen extends StatefulWidget {
  final String patientUid;
  final String? careRequestId;
  final String? appointmentId;

  const ClinicalEncounterScreen({
    super.key,
    required this.patientUid,
    this.careRequestId,
    this.appointmentId,
  });

  @override
  State<ClinicalEncounterScreen> createState() =>
      _ClinicalEncounterScreenState();
}

class _ClinicalEncounterScreenState extends State<ClinicalEncounterScreen> {
  final _otherController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _followUpNotesController = TextEditingController();

  DiagnosisCategory? _selectedCategory;
  bool _isSubmitting = false;
  bool _isChecking = true;
  bool _gateOk = true;
  bool _hasPreviousDiagnosis = false;
  String? _errorMessage;
  String? _gateBlockReason;

  static const List<DiagnosisCategory> _diagnosisOptions = [
    DiagnosisCategory.anxietyDisorders,
    DiagnosisCategory.depressiveDisorders,
    DiagnosisCategory.adhd,
    DiagnosisCategory.ptsd,
    DiagnosisCategory.schizophrenia,
    DiagnosisCategory.bipolarDisorders,
    DiagnosisCategory.bpd,
    DiagnosisCategory.epilepsy,
    DiagnosisCategory.other,
  ];

  @override
  void initState() {
    super.initState();
    _loadClinicalState();
  }

  Future<void> _loadClinicalState() async {
    try {
      if (widget.appointmentId != null) {
        final appointment = await AppointmentService.instance
            .fetchAppointment(widget.appointmentId!);
        final completed = appointment?.status == AppointmentStatus.completed;
        if (!completed) {
          if (!mounted) return;
          setState(() {
            _isChecking = false;
            _gateOk = false;
            _gateBlockReason =
                'Clinical recording is only available after the appointment '
                'has been confirmed as completed.';
          });
          return;
        }
      }

      final diagnoses = await DiagnosisService.instance
          .fetchDiagnosesForPatient(widget.patientUid);
      if (!mounted) return;
      setState(() {
        _hasPreviousDiagnosis = diagnoses.isNotEmpty;
        _isChecking = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isChecking = false;
        _gateOk = false;
        _gateBlockReason = 'Could not load the clinical appointment.';
      });
    }
  }

  @override
  void dispose() {
    _otherController.dispose();
    _descriptionController.dispose();
    _followUpNotesController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_isSubmitting) return;

    if (!_hasPreviousDiagnosis && _selectedCategory == null) {
      setState(() => _errorMessage = 'Please select a diagnosis.');
      return;
    }

    if (!_hasPreviousDiagnosis &&
        _selectedCategory == DiagnosisCategory.other &&
        _otherController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please describe the illness.');
      return;
    }

    if (_hasPreviousDiagnosis &&
        _followUpNotesController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please enter the follow-up notes.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final currentUser = await AuthService.instance.fetchCurrentUserProfile();
      if (currentUser == null) {
        throw const AuthException('You must be signed in to do this.');
      }

      final role = currentUser.role.name;

      if (_hasPreviousDiagnosis) {
        await ClinicalEncounterService.instance.createEncounter(
          patientUid: widget.patientUid,
          practitionerUid: currentUser.uid,
          practitionerRole: role,
          encounterType: 'follow-up',
          chiefConcern: 'Follow-up clinical appointment',
          careRequestId: widget.careRequestId,
          appointmentId: widget.appointmentId,
          clinicalNotes: _followUpNotesController.text.trim(),
        );
      } else {
        final diagnosisText = _selectedCategory == DiagnosisCategory.other
            ? _otherController.text.trim()
            : _selectedCategory!.label;

        final encounter =
            await ClinicalEncounterService.instance.createEncounter(
          patientUid: widget.patientUid,
          practitionerUid: currentUser.uid,
          practitionerRole: role,
          encounterType: 'initial-assessment',
          chiefConcern: diagnosisText,
          careRequestId: widget.careRequestId,
          appointmentId: widget.appointmentId,
          clinicalNotes: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
        );

        await DiagnosisService.instance.createDiagnosis(
          patientUid: widget.patientUid,
          encounterId: encounter.encounterId,
          diagnosedByUid: currentUser.uid,
          diagnosedByRole: role,
          category: _selectedCategory!,
          otherIllnessText: _selectedCategory == DiagnosisCategory.other
              ? _otherController.text.trim()
              : null,
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
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
    final initialAssessment = !_hasPreviousDiagnosis;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: Text(initialAssessment
            ? 'Initial Clinical Assessment'
            : 'Follow-up Clinical Appointment'),
      ),
      body: SafeArea(
        child: _isChecking
            ? const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primaryOrange,
                ),
              )
            : !_gateOk
                ? Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.lock_clock_outlined,
                          color: AppColors.textSecondary,
                          size: 40,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          _gateBlockReason ?? 'Not available yet.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: AppColors.errorTint,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.input),
                            ),
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: AppColors.error),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                        ],
                        Text(
                          initialAssessment
                              ? 'Diagnosis'
                              : 'Follow-up notes',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        if (initialAssessment) ...[
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.inputFill,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.input),
                              border: Border.all(
                                color: AppColors.inputBorder,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButtonFormField<DiagnosisCategory>(
                                initialValue: _selectedCategory,
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  contentPadding:
                                      EdgeInsets.symmetric(vertical: 14),
                                ),
                                hint: const Text(
                                  'Select a diagnosis',
                                  style: TextStyle(
                                    color: AppColors.placeholderText,
                                  ),
                                ),
                                items: _diagnosisOptions
                                    .map(
                                      (category) => DropdownMenuItem(
                                        value: category,
                                        child: Text(category.label),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) => setState(
                                  () => _selectedCategory = value,
                                ),
                              ),
                            ),
                          ),
                          if (_selectedCategory == DiagnosisCategory.other) ...[
                            const SizedBox(height: AppSpacing.md),
                            TextField(
                              controller: _otherController,
                              decoration: InputDecoration(
                                labelText: 'Describe the illness',
                                filled: true,
                                fillColor: AppColors.inputFill,
                                border: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.input),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.md),
                          TextField(
                            controller: _descriptionController,
                            maxLines: 4,
                            decoration: InputDecoration(
                              labelText: 'Clinical description (optional)',
                              filled: true,
                              fillColor: AppColors.inputFill,
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(AppRadius.input),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ] else
                          TextField(
                            controller: _followUpNotesController,
                            maxLines: 6,
                            decoration: InputDecoration(
                              labelText: 'Follow-up notes',
                              filled: true,
                              fillColor: AppColors.inputFill,
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(AppRadius.input),
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
                            onPressed: _isSubmitting ? null : _handleSave,
                            child: _isSubmitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(initialAssessment
                                    ? 'Save Diagnosis'
                                    : 'Save Follow-up'),
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}
