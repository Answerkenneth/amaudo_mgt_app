import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../models/patient_record_model.dart';
import '../../models/user_model.dart';
import '../../models/clinical_encounter_model.dart';
import '../../models/diagnosis_model.dart';
import '../../models/appointment_model.dart';
import '../../services/auth_service.dart';
import '../../services/patient_service.dart';
import '../../services/clinical_encounter_service.dart';
import '../../services/diagnosis_service.dart';
import '../../widgets/auth/auth_text_field.dart';
import '../../widgets/auth/auth_primary_button.dart';
import '../../widgets/auth/auth_error_banner.dart';
import '../../widgets/patients/care_team_member_tile.dart';
import '../../services/appointment_service.dart';
import '../../widgets/appointments/schedule_appointment_dialog.dart';

class PatientProfileScreen extends StatefulWidget {
  final String patientUid;

  const PatientProfileScreen({
    super.key,
    required this.patientUid,
  });

  @override
  State<PatientProfileScreen> createState() => _PatientProfileScreenState();
}

class _PatientProfileScreenState extends State<PatientProfileScreen> {
  UserModel? _currentUser;
  UserModel? _patientIdentity;
  PatientRecordModel? _record;
  List<AdmissionHistoryEntry> _history = [];

  UserModel? _assignedDoctor;
  UserModel? _assignedNurse;
  bool _isLoadingCareTeam = false;

  // Clinical history and diagnosis display.
  List<ClinicalEncounterModel> _encounters = [];
  List<DiagnosisModel> _diagnoses = [];
  final Map<String, UserModel?> _practitionerCache = {};

  bool _isLoading = true;
  String? _errorMessage;

  static const String _amaudoOrganizationName =
      'Amaudo Integrated Community Mental Health Foundation';

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        AuthService.instance.fetchCurrentUserProfile(),
        AuthService.instance.fetchUserProfileByUid(widget.patientUid),
        PatientService.instance.fetchPatientRecord(widget.patientUid),
      ]);

      List<AdmissionHistoryEntry> history = [];
      try {
        history = await PatientService.instance
            .fetchAdmissionHistory(widget.patientUid);
      } catch (_) {
        // History may be legitimately inaccessible; leave empty.
      }

      if (!mounted) return;

      setState(() {
        _currentUser = results[0] as UserModel?;
        _patientIdentity = results[1] as UserModel?;
        _record = results[2] as PatientRecordModel?;
        _history = history;
      });

      await _loadCareTeam();
      await _loadClinicalHistory();
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _errorMessage = 'Something went wrong. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Resolves assignedDoctorUid/assignedNurseUid (internal Firebase
  /// UIDs, never shown directly) into real practitioner profiles for
  /// display. Uses the existing AuthService.fetchUserProfileByUid,
  /// which is already gated by Firestore's `users` read rule (a
  /// patient may read a doctor/nurse profile only when that specific
  /// practitioner is recorded as their own assigned staff) — no new
  /// read access is introduced here.
  Future<void> _loadCareTeam() async {
    final doctorUid = _record?.assignedDoctorUid;
    final nurseUid = _record?.assignedNurseUid;

    if (doctorUid == null && nurseUid == null) return;

    setState(() => _isLoadingCareTeam = true);

    try {
      final results = await Future.wait([
        doctorUid != null
            ? AuthService.instance.fetchUserProfileByUid(doctorUid)
            : Future.value(null),
        nurseUid != null
            ? AuthService.instance.fetchUserProfileByUid(nurseUid)
            : Future.value(null),
      ]);

      if (!mounted) return;

      setState(() {
        _assignedDoctor = results[0];
        _assignedNurse = results[1];
      });
    } finally {
      if (mounted) setState(() => _isLoadingCareTeam = false);
    }
  }

  /// Loads clinical encounters and diagnoses for this patient.
  ///
  /// Practitioner UIDs are resolved through the existing user-profile
  /// lookup so the UI displays real practitioner names rather than
  /// exposing Firebase UIDs.
  Future<void> _loadClinicalHistory() async {
    try {
      final encounters =
          await ClinicalEncounterService.instance.fetchEncountersForPatient(
        widget.patientUid,
      );

      List<DiagnosisModel> diagnoses = [];

      try {
        diagnoses = await DiagnosisService.instance
            .fetchDiagnosesForPatient(widget.patientUid);
      } catch (_) {
        // Diagnoses may be legitimately inaccessible/empty; leave empty.
      }

      for (final encounter in encounters) {
        if (!_practitionerCache.containsKey(encounter.practitionerUid)) {
          final profile = await AuthService.instance
              .fetchUserProfileByUid(encounter.practitionerUid);

          _practitionerCache[encounter.practitionerUid] = profile;
        }
      }

      if (!mounted) return;

      setState(() {
        _encounters = encounters;
        _diagnoses = diagnoses;
      });
    } catch (_) {
      // Clinical history may be legitimately inaccessible;
      // leave empty rather than surfacing a hard error on
      // the whole patient profile.
    }
  }

  List<DiagnosisModel> _diagnosesForEncounter(String encounterId) {
    return _diagnoses
        .where((diagnosis) => diagnosis.encounterId == encounterId)
        .toList();
  }

  bool get _canManage {
    if (_currentUser == null) return false;

    if ({
      UserRole.admin,
      UserRole.director,
      UserRole.ceo,
    }.contains(_currentUser!.role)) {
      return true;
    }

    if (_currentUser!.role == UserRole.doctor &&
        _record?.assignedDoctorUid == _currentUser!.uid) {
      return true;
    }

    if (_currentUser!.role == UserRole.nurse &&
        _record?.assignedNurseUid == _currentUser!.uid) {
      return true;
    }

    if ({
          UserRole.doctor,
          UserRole.nurse,
        }.contains(_currentUser!.role) &&
        _record == null) {
      return true;
    }

    return false;
  }

  bool get _canAdmit => _currentUser?.role == UserRole.admin;

  Future<void> _openAdmitDialog() async {
    final result = await showDialog<_AdmitDischargeResult>(
      context: context,
      builder: (context) => _AdmitDialog(),
    );

    if (result == null) return;

    try {
      String? doctorUid;
      String? nurseUid;

      if (result.staffIdentifier != null &&
          result.staffIdentifier!.isNotEmpty) {
        final found = await AuthService.instance.findAccountForRecovery(
          identifier: result.staffIdentifier!,
        );

        if (found == null) {
          _showSnack('No staff account found for that phone/email.');
          return;
        }

        if (found.role == UserRole.doctor) {
          doctorUid = found.uid;
        } else if (found.role == UserRole.nurse) {
          nurseUid = found.uid;
        } else {
          _showSnack('That account is not a doctor or nurse.');
          return;
        }
      }

      await PatientService.instance.admitPatient(
        patientUid: widget.patientUid,
        assignedDoctorUid: doctorUid,
        assignedNurseUid: nurseUid,
        note: result.note,
        admittedByUid: _currentUser!.uid,
        admissionType: result.admissionType ?? AdmissionType.normal,
        adminReferralRequired: result.referralRequired,
        adminReferralNote: result.referralNote,
      );

      _showSnack('Patient admitted.');
      _loadAll();
    } on AuthException catch (e) {
      _showSnack(e.message);
    } catch (_) {
      _showSnack('Something went wrong. Please try again.');
    }
  }

   Future<void> _openScheduleAppointmentDialog() async {
    if (_currentUser == null) return;
    final result = await showDialog<ScheduleAppointmentResult>(
      context: context,
      builder: (context) => const ScheduleAppointmentDialog(),
    );
    if (result == null) return;

    try {
      await AppointmentService.instance.createAppointment(
        patientUid: widget.patientUid,
        practitionerUid: _currentUser!.uid,
        practitionerRole: _currentUser!.role.storageValue,
        purpose: result.purpose,
        scheduledAt: result.scheduledAt,
        type: result.type,
        healthcareCenter: result.healthcareCenter,
        location: result.location,
      );

      _showSnack('Appointment scheduled.');
    } on AuthException catch (e) {
      _showSnack(e.message);
    } catch (_) {
      _showSnack('Something went wrong. Please try again.');
    }
  }

  Future<void> _openScheduleMedicationAppointmentDialog() async {
    if (_currentUser == null) return;
    final result = await showDialog<ScheduleAppointmentResult>(
      context: context,
      builder: (context) => const ScheduleAppointmentDialog(
        type: AppointmentType.medication,
      ),
    );
    if (result == null) return;

    try {
      await AppointmentService.instance.createAppointment(
        patientUid: widget.patientUid,
        practitionerUid: _currentUser!.uid,
        practitionerRole: _currentUser!.role.storageValue,
        purpose: result.purpose,
        scheduledAt: result.scheduledAt,
        type: result.type,
        healthcareCenter: result.healthcareCenter,
        location: result.location,
      );

      _showSnack('Medication appointment scheduled.');
    } on AuthException catch (e) {
      _showSnack(e.message);
    } catch (_) {
      _showSnack('Something went wrong. Please try again.');
    }
  }
  

  Future<void> _openDischargeDialog() async {
    final result = await showDialog<_AdmitDischargeResult>(
      context: context,
      builder: (context) => _DischargeDialog(),
    );

    if (result == null) return;

    try {
      await PatientService.instance.dischargePatient(
        patientUid: widget.patientUid,
        summary: result.note,
      );

      _showSnack('Patient discharged.');
      _loadAll();
    } on AuthException catch (e) {
      _showSnack(e.message);
    } catch (_) {
      _showSnack('Something went wrong. Please try again.');
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: Text(_patientIdentity?.fullName ?? 'Patient'),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primaryOrange,
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_errorMessage != null) ...[
                      AuthErrorBanner(message: _errorMessage!),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    if (_patientIdentity == null)
                      const Text(
                        'You do not have permission to view this patient\'s '
                        'personal information.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                        ),
                      )
                    else ...[
                      _SectionCard(
                        title: 'Patient Information',
                        children: [
                          _InfoRow(
                            label: 'Name',
                            value: _patientIdentity!.fullName,
                          ),
                          if (_patientIdentity!.phone != null)
                            _InfoRow(
                              label: 'Phone',
                              value: _patientIdentity!.phone!,
                            ),
                          if (_patientIdentity!.email != null)
                            _InfoRow(
                              label: 'Email',
                              value: _patientIdentity!.email!,
                            ),
                          if (_patientIdentity!.address != null)
                            _InfoRow(
                              label: 'Address',
                              value: _patientIdentity!.address!,
                            ),
                          if (_patientIdentity!.state != null)
                            _InfoRow(
                              label: 'Location',
                              value: [
                                _patientIdentity!.localGovernmentArea,
                                _patientIdentity!.state,
                                _patientIdentity!.country,
                              ].whereType<String>().join(', '),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    _SectionCard(
                      title: 'Admission Status',
                      children: [
                        _InfoRow(
                          label: 'Status',
                          value: (_record?.status ??
                                  PatientStatus.notAdmitted)
                              .label,
                        ),
                        if (_record?.admissionDate != null)
                          _InfoRow(
                            label: 'Admission Date',
                            value:
                                _record!.admissionDate!.toLocal().toString(),
                          ),
                        if (_record?.dischargeDate != null)
                          _InfoRow(
                            label: 'Discharge Date',
                            value:
                                _record!.dischargeDate!.toLocal().toString(),
                          ),
                        if (_record?.dischargeSummary != null)
                          _InfoRow(
                            label: 'Discharge Summary',
                            value: _record!.dischargeSummary!,
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Healthcare Team — resolved to real names, never
                    // raw UIDs. See _loadCareTeam().
                    _SectionCard(
                      title: 'Healthcare Team',
                      children: [
                        CareTeamMemberTile(
                          roleLabel: 'Doctor',
                          practitioner: _assignedDoctor,
                          isLoading: _isLoadingCareTeam,
                        ),
                        const Divider(height: AppSpacing.md),
                        CareTeamMemberTile(
                          roleLabel: 'Nurse',
                          practitioner: _assignedNurse,
                          isLoading: _isLoadingCareTeam,
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // Amaudo Healthcare Information — organization is
                    // a fixed constant (not a per-user stored field);
                    // Healthcare Center uses the patient's own
                    // primaryHealthcareCenter, since that's the
                    // center associated with THIS patient's care,
                    // distinct from wherever a given staff member
                    // happens to work.
                    _SectionCard(
                      title: 'Amaudo Healthcare Information',
                      children: [
                        const _InfoRow(
                          label: 'Organization',
                          value: _amaudoOrganizationName,
                        ),
                        _InfoRow(
                          label: 'Healthcare Center',
                          value: (_record?.primaryHealthcareCenter != null &&
                                  _record!.primaryHealthcareCenter!
                                      .trim()
                                      .isNotEmpty)
                              ? _record!.primaryHealthcareCenter!
                              : 'Not provided',
                        ),
                        if (_patientIdentity?.state != null)
                          _InfoRow(
                            label: 'Location',
                            value: [
                              _patientIdentity!.localGovernmentArea,
                              _patientIdentity!.state,
                              _patientIdentity!.country,
                            ].whereType<String>().join(', '),
                          ),
                        if (_patientIdentity?.localGovernmentArea != null)
                          _InfoRow(
                            label: 'Local Government Area',
                            value:
                                _patientIdentity!.localGovernmentArea!,
                          ),
                      ],
                    ),

                    if (_history.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      _SectionCard(
                        title: 'History',
                        children: _history
                            .map(
                              (h) => _InfoRow(
                                label: h.type == 'admission'
                                    ? 'Admitted'
                                    : 'Discharged',
                                value: h.dateTime.toLocal().toString(),
                              ),
                            )
                            .toList(),
                      ),
                    ],

                    // Clinical History — displays the encounters and
                    // diagnoses already stored in Firestore.
                    if (_encounters.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Clinical History',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ..._encounters.map((encounter) {
                        final practitioner =
                            _practitionerCache[encounter.practitionerUid];

                        final encounterDiagnoses =
                            _diagnosesForEncounter(encounter.encounterId);

                        return Padding(
                          padding: const EdgeInsets.only(
                            bottom: AppSpacing.sm,
                          ),
                          child: _SectionCard(
                            title: encounter.encounterType,
                            children: [
                              _InfoRow(
                                label: 'Practitioner',
                                value: practitioner?.fullName ??
                                    'Not available',
                              ),
                              if (encounter.createdAt != null)
                                _InfoRow(
                                  label: 'Date',
                                  value: encounter.createdAt!
                                      .toLocal()
                                      .toString(),
                                ),
                              _InfoRow(
                                label: 'Concern',
                                value: encounter.chiefConcern,
                              ),
                              if (encounter.assessment != null)
                                _InfoRow(
                                  label: 'Assessment',
                                  value: encounter.assessment!,
                                ),
                              if (encounter.clinicalNotes != null)
                                _InfoRow(
                                  label: 'Clinical Notes',
                                  value: encounter.clinicalNotes!,
                                ),
                              if (encounter.followUpRequired)
                                const _InfoRow(
                                  label: 'Follow-up',
                                  value: 'Required',
                                ),
                              if (encounterDiagnoses.isEmpty)
                                const _InfoRow(
                                  label: 'Diagnosis',
                                  value: 'None recorded',
                                )
                              else
                                ...encounterDiagnoses.map(
                                  (diagnosis) => _InfoRow(
                                    label: 'Diagnosis',
                                    value: diagnosis.category == DiagnosisCategory.other
                                        ? (diagnosis.otherIllnessText?.trim().isNotEmpty ?? false)
                                            ? diagnosis.otherIllnessText!.trim()
                                            : diagnosis.category.label
                                        : diagnosis.category.label,
                                  ),
                                ),
                            ],
                          ),
                        );
                      }),
                    ],

                    if (_canManage) ...[
                      const SizedBox(height: AppSpacing.lg),
                      if (_canAdmit &&
                          _record?.status != PatientStatus.admitted)
                        AuthPrimaryButton(
                          label: 'Admit Patient',
                          onPressed: _openAdmitDialog,
                        ),
                      if (_record?.status == PatientStatus.admitted) ...[
                        const SizedBox(height: AppSpacing.sm),
                        AuthPrimaryButton(
                          label: 'Discharge Patient',
                          onPressed: _openDischargeDialog,
                        ),
                      ],
                                            const SizedBox(height: AppSpacing.sm),
                      OutlinedButton.icon(
                        onPressed: _openScheduleAppointmentDialog,
                        icon: const Icon(
                          Icons.calendar_month_outlined,
                        ),
                        label: const Text('Schedule Appointment'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryOrange,
                          side: const BorderSide(
                            color: AppColors.primaryOrange,
                          ),
                          minimumSize: const Size(
                            double.infinity,
                            44,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      OutlinedButton.icon(
                        onPressed: _openScheduleMedicationAppointmentDialog,
                        icon: const Icon(
                          Icons.medication_outlined,
                        ),
                        label: const Text('Schedule Medication Appointment'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryOrange,
                          side: const BorderSide(
                            color: AppColors.primaryOrange,
                          ),
                          minimumSize: const Size(
                            double.infinity,
                            44,
                          ),
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

class _AdmitDischargeResult {
  final String? staffIdentifier;
  final String? note;
  final AdmissionType? admissionType;
  final bool referralRequired;
  final String? referralNote;

  const _AdmitDischargeResult({
    this.staffIdentifier,
    this.note,
    this.admissionType,
    this.referralRequired = false,
    this.referralNote,
  });
}

class _AdmitDialog extends StatefulWidget {
  @override
  State<_AdmitDialog> createState() => _AdmitDialogState();
}

class _AdmitDialogState extends State<_AdmitDialog> {
  final _staffController = TextEditingController();
  final _noteController = TextEditingController();
  final _referralNoteController = TextEditingController();

  AdmissionType _admissionType = AdmissionType.normal;
  bool _referralRequired = false;

  @override
  void dispose() {
    _staffController.dispose();
    _noteController.dispose();
    _referralNoteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          AppRadius.sheet - 12,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Admit Patient',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Admission Type',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            RadioListTile<AdmissionType>(
              value: AdmissionType.shortStay,
              groupValue: _admissionType,
              onChanged: (value) {
                if (value != null) {
                  setState(() => _admissionType = value);
                }
              },
              title: const Text('Short Stay'),
              contentPadding: EdgeInsets.zero,
            ),
            RadioListTile<AdmissionType>(
              value: AdmissionType.normal,
              groupValue: _admissionType,
              onChanged: (value) {
                if (value != null) {
                  setState(() => _admissionType = value);
                }
              },
              title: const Text('Normal'),
              contentPadding: EdgeInsets.zero,
            ),
            CheckboxListTile(
              value: _referralRequired,
              onChanged: (value) {
                setState(() => _referralRequired = value ?? false);
              },
              title: const Text('Referral Required'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
            ),
            if (_referralRequired) ...[
              const SizedBox(height: AppSpacing.sm),
              AuthTextField(
                label: 'Referral Note (optional)',
                hint: 'Referral details',
                controller: _referralNoteController,
                validator: (_) => null,
                prefixIcon: Icons.assignment_outlined,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            AuthTextField(
              label: 'Assign Doctor or Nurse (optional)',
              hint: 'Their phone number or email',
              controller: _staffController,
              validator: (_) => null,
              prefixIcon: Icons.badge_outlined,
            ),
            const SizedBox(height: AppSpacing.md),
            AuthTextField(
              label: 'Note (optional)',
              hint: 'Admission note',
              controller: _noteController,
              validator: (_) => null,
              prefixIcon: Icons.notes_outlined,
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryOrange,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => Navigator.of(context).pop(
                      _AdmitDischargeResult(
                        staffIdentifier:
                            _staffController.text.trim(),
                        note: _noteController.text.trim(),
                        admissionType: _admissionType,
                        referralRequired: _referralRequired,
                        referralNote:
                            _referralNoteController.text.trim().isEmpty
                                ? null
                                : _referralNoteController.text.trim(),
                      ),
                    ),
                    child: const Text('Admit'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DischargeDialog extends StatefulWidget {
  @override
  State<_DischargeDialog> createState() => _DischargeDialogState();
}

class _DischargeDialogState extends State<_DischargeDialog> {
  final _summaryController = TextEditingController();

  @override
  void dispose() {
    _summaryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          AppRadius.sheet - 12,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Discharge Patient',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AuthTextField(
              label: 'Discharge Summary (optional)',
              hint: 'Summary or notes',
              controller: _summaryController,
              validator: (_) => null,
              prefixIcon: Icons.notes_outlined,
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryOrange,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => Navigator.of(context).pop(
                      _AdmitDischargeResult(
                        note: _summaryController.text.trim(),
                      ),
                    ),
                    child: const Text('Discharge'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleAppointmentResult {
  final String purpose;
  final DateTime scheduledAt;
  final String? healthcareCenter;
  final String? location;

  const _ScheduleAppointmentResult({
    required this.purpose,
    required this.scheduledAt,
    this.healthcareCenter,
    this.location,
  });
}

class _ScheduleAppointmentDialog extends StatefulWidget {
  @override
  State<_ScheduleAppointmentDialog> createState() =>
      _ScheduleAppointmentDialogState();
}

class _ScheduleAppointmentDialogState
    extends State<_ScheduleAppointmentDialog> {
  final _purposeController = TextEditingController();
  final _centerController = TextEditingController();
  final _locationController = TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  @override
  void dispose() {
    _purposeController.dispose();
    _centerController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(
        const Duration(days: 1),
      ),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(
        const Duration(days: 365),
      ),
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  // ONLY MODIFIED METHOD:
  // The original showTimePicker was triggering the red
  // BoxConstraints error when its keyboard/manual-input mode
  // opened. The MediaQuery builder below prevents the keyboard's
  // viewInsets from changing the time-picker dialog constraints.
  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(
        hour: 10,
        minute: 0,
      ),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            viewInsets: EdgeInsets.zero,
          ),
          child: SafeArea(
            child: child!,
          ),
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          AppRadius.sheet - 12,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Schedule Appointment',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AuthTextField(
                label: 'Purpose',
                hint: 'e.g. In-person clinical assessment',
                controller: _purposeController,
                validator: (_) => null,
                prefixIcon: Icons.description_outlined,
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _pickDate,
                      child: Text(
                        _selectedDate == null
                            ? 'Select Date'
                            : '${_selectedDate!.day}/'
                                '${_selectedDate!.month}/'
                                '${_selectedDate!.year}',
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _pickTime,
                      child: Text(
                        _selectedTime == null
                            ? 'Select Time'
                            : _selectedTime!.format(context),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              AuthTextField(
                label: 'Healthcare Center (optional)',
                hint: 'e.g. Amaudo Itumbauzo Clinic',
                controller: _centerController,
                validator: (_) => null,
                prefixIcon: Icons.local_hospital_outlined,
              ),
              const SizedBox(height: AppSpacing.md),
              AuthTextField(
                label: 'Location (optional)',
                hint: 'Additional location details',
                controller: _locationController,
                validator: (_) => null,
                prefixIcon: Icons.location_on_outlined,
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryOrange,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        if (_purposeController.text.trim().isEmpty ||
                            _selectedDate == null ||
                            _selectedTime == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Please provide a purpose, date, and time.',
                              ),
                            ),
                          );
                          return;
                        }

                        final scheduledAt = DateTime(
                          _selectedDate!.year,
                          _selectedDate!.month,
                          _selectedDate!.day,
                          _selectedTime!.hour,
                          _selectedTime!.minute,
                        );

                        Navigator.of(context).pop(
                          _ScheduleAppointmentResult(
                            purpose:
                                _purposeController.text.trim(),
                            scheduledAt: scheduledAt,
                            healthcareCenter:
                                _centerController.text.trim().isEmpty
                                    ? null
                                    : _centerController.text.trim(),
                            location:
                                _locationController.text.trim().isEmpty
                                    ? null
                                    : _locationController.text.trim(),
                          ),
                        );
                      },
                      child: const Text('Schedule'),
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

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          AppRadius.button,
        ),
        border: Border.all(
          color: AppColors.divider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: AppTextSize.caption + 1,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}