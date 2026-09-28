import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../models/appointment_model.dart';
import '../auth/auth_text_field.dart';

class ScheduleAppointmentResult {
  final String purpose;
  final DateTime scheduledAt;
  final AppointmentType type;
  final String? healthcareCenter;
  final String? location;
  const ScheduleAppointmentResult({
    required this.purpose,
    required this.scheduledAt,
    this.type = AppointmentType.clinical,
    this.healthcareCenter,
    this.location,
  });
}

/// Shared appointment-scheduling dialog, used by both
/// PatientProfileScreen (direct scheduling) and
/// ClinicalEncounterScreen (follow-up scheduling) — a single source
/// of truth for the scheduling UI, per the "do not create a second
/// appointment system" requirement. [type] also covers medication
/// appointments (date + time + clinic/location, same fields as any
/// other appointment — no separate medication-scheduling UI needed).
class ScheduleAppointmentDialog extends StatefulWidget {
  final AppointmentType type;
  const ScheduleAppointmentDialog({
    super.key,
    this.type = AppointmentType.clinical,
  });

  @override
  State<ScheduleAppointmentDialog> createState() =>
      _ScheduleAppointmentDialogState();
}

class _ScheduleAppointmentDialogState
    extends State<ScheduleAppointmentDialog> {
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
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    // MediaQuery override: showTimePicker's internal dialog does not
    // automatically shrink for the on-screen keyboard the way a
    // bottom sheet does. Removing the keyboard's viewInsets just for
    // this picker's own layout pass stops its fixed-height Column
    // from overflowing into the keyboard (the red RenderFlex
    // constraint error fixed previously).
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(
            viewInsets: mediaQuery.viewInsets.copyWith(bottom: 0),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sheet - 12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                           Text(
                widget.type == AppointmentType.medication
                    ? 'Schedule Medication Appointment'
                    : 'Schedule Appointment',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
              ),
              const SizedBox(height: AppSpacing.md),
              AuthTextField(
                label: 'Purpose',
                hint: widget.type == AppointmentType.medication
                    ? 'e.g. Monthly depot injection'
                    : 'e.g. In-person clinical assessment',
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
                            : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
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
                          ScheduleAppointmentResult(
                            purpose: _purposeController.text.trim(),
                            scheduledAt: scheduledAt,
                            type: widget.type,
                            healthcareCenter:
                                _centerController.text.trim().isEmpty
                                    ? null
                                    : _centerController.text.trim(),
                            location: _locationController.text.trim().isEmpty
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