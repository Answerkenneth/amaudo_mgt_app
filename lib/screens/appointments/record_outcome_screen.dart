import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../models/appointment_model.dart';
import '../../services/appointment_service.dart';
import '../../services/auth_exception.dart';
import '../../services/auth_service.dart';
import '../clinical/clinical_encounter_screen.dart';

/// Where the practitioner explicitly confirms whether a scheduled
/// appointment actually occurred. The system never assumes this —
/// per spec, only the practitioner's explicit action here unlocks
/// clinical recording for an appointment-based (in-person) visit.
class RecordOutcomeScreen extends StatefulWidget {
  final AppointmentModel appointment;
  const RecordOutcomeScreen({super.key, required this.appointment});

  @override
  State<RecordOutcomeScreen> createState() => _RecordOutcomeScreenState();
}

class _RecordOutcomeScreenState extends State<RecordOutcomeScreen> {
  bool _isSubmitting = false;
  String? _errorMessage;

  Future<void> _recordOutcome(AppointmentStatus outcome) async {
    if (_isSubmitting) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final currentUser = await AuthService.instance.fetchCurrentUserProfile();
      if (currentUser == null) {
        throw const AuthException('You must be signed in to do this.');
      }

      await AppointmentService.instance.recordOutcome(
        appointmentId: widget.appointment.appointmentId,
        outcome: outcome,
        recordedByUid: currentUser.uid,
      );

      if (!mounted) return;

      if (outcome == AppointmentStatus.completed) {
        // Clinical recording becomes available now — but the
        // practitioner still has to explicitly open and fill it in.
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ClinicalEncounterScreen(
              patientUid: widget.appointment.patientUid,
              appointmentId: widget.appointment.appointmentId,
              careRequestId: widget.appointment.careRequestId,
            ),
          ),
        );
      } else {
        Navigator.of(context).pop(true);
      }
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
    final a = widget.appointment;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Confirm Appointment Outcome'),
      ),
      body: SafeArea(
        child: Padding(
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
              Text(
                a.purpose,
                style: const TextStyle(
                  fontSize: AppTextSize.screenTitle - 4,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                'Did this appointment actually take place?',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _isSubmitting
                      ? null
                      : () => _recordOutcome(AppointmentStatus.completed),
                  child: const Text('Yes — Completed'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _isSubmitting
                      ? null
                      : () => _recordOutcome(AppointmentStatus.missed),
                  child: const Text('No — Did Not Occur'),
                ),
              ),
              if (_isSubmitting) ...[
                const SizedBox(height: AppSpacing.md),
                const Center(
                  child: CircularProgressIndicator(color: AppColors.primaryOrange),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}