import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../models/appointment_model.dart';
import '../../models/user_model.dart';
import '../../services/appointment_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/care/request_datetime_block.dart';
import '../clinical/clinical_encounter_screen.dart';

class AppointmentDetailScreen extends StatefulWidget {
  final String appointmentId;
  const AppointmentDetailScreen({super.key, required this.appointmentId});

  @override
  State<AppointmentDetailScreen> createState() => _AppointmentDetailScreenState();
}

class _AppointmentDetailScreenState extends State<AppointmentDetailScreen> {
  AppointmentModel? _appointment;
  UserModel? _currentUser;
  UserModel? _otherParty;
  bool _isLoading = true;
  String? _errorMessage;

  bool _isRecordingOutcome = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final current = await AuthService.instance.fetchCurrentUserProfile();
      final appointment =
          await AppointmentService.instance.fetchAppointment(widget.appointmentId);

      UserModel? otherParty;
      if (appointment != null && current != null) {
        final otherUid = current.uid == appointment.patientUid
            ? appointment.practitionerUid
            : appointment.patientUid;
        otherParty = await AuthService.instance.fetchUserProfileByUid(otherUid);
      }

      if (!mounted) return;
      setState(() {
        _currentUser = current;
        _appointment = appointment;
        _otherParty = otherParty;
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool get _isPatientView => _currentUser?.uid == _appointment?.patientUid;

  /// Only the assigned practitioner may record the outcome — checked
  /// against the authenticated user's own UID, never a UI-only
  /// assumption. Firestore rules independently enforce the same
  /// restriction server-side.
  bool get _isPractitionerView =>
      _currentUser != null &&
      _appointment != null &&
      _currentUser!.uid == _appointment!.practitionerUid;

  Future<void> _recordOutcome(AppointmentStatus outcome) async {
    if (_isRecordingOutcome || _appointment == null || _currentUser == null) {
      return;
    }
    setState(() => _isRecordingOutcome = true);

    try {
      await AppointmentService.instance.recordOutcome(
        appointmentId: _appointment!.appointmentId,
        outcome: outcome,
        recordedByUid: _currentUser!.uid,
      );
      await _load();
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isRecordingOutcome = false);
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
        title: const Text('Appointment'),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primaryOrange),
              )
            : _errorMessage != null
                ? Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Text(_errorMessage!,
                        style: const TextStyle(color: AppColors.error)),
                  )
                : _appointment == null
                    ? const Padding(
                        padding: EdgeInsets.all(AppSpacing.lg),
                        child: Text(
                          'This appointment could not be found or you do not '
                          'have permission to view it.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _appointment!.purpose,
                              style: const TextStyle(
                                fontSize: AppTextSize.screenTitle - 4,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            _SectionCard(
                              title: _isPatientView
                                  ? (_appointment!.practitionerRole == 'doctor'
                                      ? 'Doctor'
                                      : 'Nurse')
                                  : 'Patient',
                              children: [
                                _InfoRow(
                                  label: 'Name',
                                  value: _otherParty?.fullName ?? 'Not available',
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.md),
                            _SectionCard(
                              title: 'Schedule',
                              children: [
                                RequestDateTimeBlock(
                                  dateTime: _appointment!.scheduledAt,
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.md),
                                                      _SectionCard(
                              title: 'Details',
                              children: [
                                _InfoRow(
                                  label: 'Type',
                                  value: _appointment!.type.label,
                                ),
                                _InfoRow(
                                  label: 'Healthcare Center',
                                  value: _appointment!.healthcareCenter ??
                                      'Not provided',
                                ),
                                _InfoRow(
                                  label: 'Location',
                                  value: _appointment!.location ?? 'Not provided',
                                ),
                                _InfoRow(
                                  label: 'Status',
                                  value: _appointment!.status.label,
                                ),
                              ],
                            ),
                            // Practitioner-only outcome controls —
                            // never shown to the patient. Only
                            // appears while the appointment is still
                            // Scheduled.
                                                      if (_isPractitionerView &&
                                _appointment!.status ==
                                    AppointmentStatus.scheduled) ...[
                              const SizedBox(height: AppSpacing.md),
                              _SectionCard(
                                title: _appointment!.type ==
                                        AppointmentType.medication
                                    ? 'Medication'
                                    : 'Appointment Outcome',
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: AppSpacing.sm,
                                    ),
                                    child: Text(
                                      _appointment!.type ==
                                              AppointmentType.medication
                                          ? 'Has this medication been '
                                              'administered?'
                                          : 'Did this appointment take place?',
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                AppColors.primaryOrange,
                                            foregroundColor: Colors.white,
                                          ),
                                          onPressed: _isRecordingOutcome
                                              ? null
                                              : () => _recordOutcome(
                                                    AppointmentStatus.completed,
                                                  ),
                                              child: Text(
                                                _appointment!.type ==
                                                        AppointmentType
                                                            .medication
                                                    ? 'Medication Administered'
                                                    : 'Proceed',
                                              ),
                                        ),
                                      ),
                                
                                      const SizedBox(width: AppSpacing.sm),
                                      Expanded(
                                        child: OutlinedButton(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: AppColors.error,
                                            side: const BorderSide(
                                              color: AppColors.error,
                                            ),
                                          ),
                                          onPressed: _isRecordingOutcome
                                              ? null
                                              : () => _recordOutcome(
                                                    AppointmentStatus.missed,
                                                  ),
                                          child: const Text('Did Not Hold'),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (_isRecordingOutcome) ...[
                                    const SizedBox(height: AppSpacing.sm),
                                    const Center(
                                      child: CircularProgressIndicator(
                                        color: AppColors.primaryOrange,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                            // Clinical recording entry point — only
                            // once the practitioner has explicitly
                            // confirmed the appointment as completed.
                            // The actual gate (verifying status ==
                            // completed) lives in
                            // ClinicalEncounterScreen itself, per the
                            // existing architecture.
                               if (_isPractitionerView &&
                                _appointment!.type ==
                                    AppointmentType.clinical &&
                                _appointment!.status ==
                                    AppointmentStatus.completed) ...[
                              const SizedBox(height: AppSpacing.lg),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => ClinicalEncounterScreen(
                                        patientUid: _appointment!.patientUid,
                                        appointmentId: _appointment!.appointmentId,
                                        careRequestId: _appointment!.careRequestId,
                                      ),
                                    ),
                                  ),
                                  icon: const Icon(Icons.assignment_outlined),
                                  label: const Text('Record Clinical Appointment'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.primaryOrange,
                                    side: const BorderSide(
                                      color: AppColors.primaryOrange,
                                    ),
                                    minimumSize: const Size(double.infinity, 44),
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

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SectionCard({required this.title, required this.children});

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
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
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
  const _InfoRow({required this.label, required this.value});

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
            child: Text(value, style: const TextStyle(color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}