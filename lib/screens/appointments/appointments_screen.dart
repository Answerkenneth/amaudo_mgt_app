import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../models/appointment_model.dart';
import '../../models/user_model.dart';
import '../../services/appointment_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/care/request_datetime_block.dart';
import 'appointment_detail_screen.dart';

/// Tab-embedded content (no own Scaffold/AppBar). Loads real
/// appointment data for patients (their own appointments) and
/// doctors/nurses (appointments where they are the practitioner).
/// Other roles retain the original structural empty state.
class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  UserModel? _currentUser;
  List<AppointmentModel> _appointments = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool get _isPatient => _currentUser?.role == UserRole.patient;
  bool get _isPractitioner =>
      _currentUser?.role == UserRole.doctor || _currentUser?.role == UserRole.nurse;

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await AuthService.instance.fetchCurrentUserProfile();
      List<AppointmentModel> appointments = [];

      if (user != null) {
        if (user.role == UserRole.patient) {
          appointments =
              await AppointmentService.instance.fetchAppointmentsForPatient(user.uid);
        } else if (user.role == UserRole.doctor || user.role == UserRole.nurse) {
          appointments = await AppointmentService.instance
              .fetchAppointmentsForPractitioner(user.uid);
        }
      }

      if (!mounted) return;
      setState(() {
        _currentUser = user;
        _appointments = appointments;
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryOrange),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_errorMessage!, style: const TextStyle(color: AppColors.error)),
              const SizedBox(height: AppSpacing.sm),
              TextButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    if (!_isPatient && !_isPractitioner) {
      // Original structural placeholder for staff/other/privileged roles.
      return SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Upcoming',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            const SizedBox(height: AppSpacing.sm),
            const _EmptySection(message: 'No upcoming appointments yet'),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'Past',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            const SizedBox(height: AppSpacing.sm),
            const _EmptySection(message: 'No past appointments yet'),
          ],
        ),
      );
    }

    final now = DateTime.now();
    final upcoming = _appointments
        .where((a) =>
            a.status == AppointmentStatus.scheduled && a.scheduledAt.isAfter(now))
        .toList();
    final past = _appointments
        .where((a) =>
            a.status != AppointmentStatus.scheduled || !a.scheduledAt.isAfter(now))
        .toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Upcoming',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (upcoming.isEmpty)
              const _EmptySection(message: 'No upcoming appointments yet')
            else
              ...upcoming.map((a) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _AppointmentTile(appointment: a, isPatientView: _isPatient),
                  )),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'Past',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (past.isEmpty)
              const _EmptySection(message: 'No past appointments yet')
            else
              ...past.map((a) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _AppointmentTile(appointment: a, isPatientView: _isPatient),
                  )),
          ],
        ),
      ),
    );
  }
}

class _AppointmentTile extends StatelessWidget {
  final AppointmentModel appointment;
  final bool isPatientView;

  const _AppointmentTile({required this.appointment, required this.isPatientView});

  Color get _statusColor {
  switch (appointment.status) {
    case AppointmentStatus.scheduled:
      return AppColors.primaryOrange;
    case AppointmentStatus.completed:
      return AppColors.success;
    case AppointmentStatus.cancelled:
      return AppColors.error;
    case AppointmentStatus.missed:
      return AppColors.error;
  }
}

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.button),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.button),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                AppointmentDetailScreen(appointmentId: appointment.appointmentId),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.button),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                                       Text(
                      appointment.purpose,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (appointment.type == AppointmentType.medication) ...[
                      const SizedBox(height: 2),
                      const Text(
                        'Medication',
                        style: TextStyle(
                          color: AppColors.primaryOrange,
                          fontWeight: FontWeight.w700,
                          fontSize: AppTextSize.caption,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    RequestDateTimeBlock(dateTime: appointment.scheduledAt),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.icon),
                ),
                child: Text(
                  appointment.status.label,
                  style: TextStyle(
                    color: _statusColor,
                    fontWeight: FontWeight.w700,
                    fontSize: AppTextSize.caption,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptySection extends StatelessWidget {
  final String message;
  const _EmptySection({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.button),
        border: Border.all(color: AppColors.divider),
      ),
      child: Center(
        child: Text(
          message,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      ),
    );
  }
}