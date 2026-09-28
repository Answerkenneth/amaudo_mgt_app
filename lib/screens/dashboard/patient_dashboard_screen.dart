import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../models/patient_record_model.dart';
import '../../models/user_model.dart';
import '../../services/care_request_service.dart';
import '../../services/patient_service.dart';
import '../../services/profile_reminder_service.dart';
import '../../widgets/dashboard/dashboard_card.dart';
import '../../widgets/dashboard/dashboard_greeting_header.dart';
import '../appointments/appointments_list_page.dart';
import '../care/get_help_screen.dart';
import '../patients/patient_profile_screen.dart';
import '../profile/complete_profile_screen.dart';

class PatientDashboardScreen extends StatefulWidget {
  final UserModel user;
  const PatientDashboardScreen({super.key, required this.user});

  @override
  State<PatientDashboardScreen> createState() => _PatientDashboardScreenState();
}

class _PatientDashboardScreenState extends State<PatientDashboardScreen> {
  bool? _profileCompleted;
  PatientStatus? _patientStatus;
  bool? _hasSubmittedCareRequest;

  @override
  void initState() {
    super.initState();
    _checkProfile();
    _checkCareRequestStatus();
  }

  Future<void> _checkProfile() async {
    final record = await PatientService.instance.fetchPatientRecord(widget.user.uid);
    final completed = record?.profileCompleted ?? false;
    if (mounted) {
      setState(() {
        _profileCompleted = completed;
        _patientStatus = record?.status;
      });
    }
    await ProfileReminderService.instance.syncForUser(
      uid: widget.user.uid,
      profileCompleted: completed,
    );
  }

  Future<void> _checkCareRequestStatus() async {
    final requests = await CareRequestService.instance
        .fetchRequestsForPatient(widget.user.uid);
    if (mounted) {
      setState(() => _hasSubmittedCareRequest = requests.isNotEmpty);
    }
  }

  // Shown only to a patient who hasn't been admitted yet (a "new"
  // patient) and who has never submitted a care request. Disappears
  // as soon as fetchRequestsForPatient returns a non-empty list,
  // which _checkCareRequestStatus() re-checks after they visit
  // Get Help via either this popup or the existing dashboard card.
  bool get _showCareRequestPopup =>
      _patientStatus == PatientStatus.notAdmitted &&
      _hasSubmittedCareRequest == false;

  Future<void> _openGetHelp() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GetHelpScreen(patientUid: widget.user.uid),
      ),
    );
    _checkCareRequestStatus();
  }

  Future<void> _openCompleteProfile() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CompleteProfileScreen(patientUid: widget.user.uid),
      ),
    );
    if (result == true) _checkProfile();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
                   DashboardGreetingHeader(user: widget.user),
          if (_showCareRequestPopup) ...[
            const SizedBox(height: AppSpacing.lg),
            Material(
              color: AppColors.primaryOrange,
              borderRadius: BorderRadius.circular(AppRadius.button),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.button),
                onTap: _openGetHelp,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      const Icon(Icons.support_agent_outlined,
                          color: Colors.white),
                      const SizedBox(width: AppSpacing.sm),
                      const Expanded(
                        child: Text(
                          'New here? Submit a care request to get connected '
                          'with a doctor or nurse.',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          color: Colors.white),
                    ],
                  ),
                ),
              ),
            ),
          ],
          if (_profileCompleted == false) ...[
            const SizedBox(height: AppSpacing.lg),
            Material(
              color: AppColors.orangeTint,
              borderRadius: BorderRadius.circular(AppRadius.button),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.button),
                onTap: _openCompleteProfile,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          color: AppColors.primaryOrange),
                      const SizedBox(width: AppSpacing.sm),
                      const Expanded(
                        child: Text(
                          'Please complete your Amaudo profile to continue.',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          color: AppColors.primaryOrange),
                    ],
                  ),
                ),
              ),
            ),
          ],
                   const SizedBox(height: AppSpacing.lg),
          DashboardCard(
            title: 'Upcoming Appointment',
            subtitle: 'View your appointments',
            icon: Icons.calendar_month_outlined,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    const AppointmentsListPage(title: 'My Appointments'),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          DashboardCard(
            title: 'My Medication',
            subtitle: 'Managed by your assigned doctor or nurse',
            icon: Icons.medication_outlined,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const AppointmentsListPage(
                  title: 'My Medication Appointments',
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const DashboardCard(
            title: 'Notifications',
            subtitle: 'No data yet',
            icon: Icons.notifications_outlined,
          ),
          const SizedBox(height: AppSpacing.md),
          DashboardCard(
            title: 'Get Help',
            subtitle: 'Request assistance from a nurse or doctor',
            icon: Icons.support_agent_outlined,
            onTap: _openGetHelp,
          ),
          const SizedBox(height: AppSpacing.md),
          const DashboardCard(
            title: 'Chat with Care Team',
            subtitle: 'Message your assigned doctor or nurse',
            icon: Icons.chat_bubble_outline_rounded,
          ),
          const SizedBox(height: AppSpacing.md),
          DashboardCard(
            title: 'My Health Information',
            subtitle: 'Admission status, care team, and details',
            icon: Icons.folder_shared_outlined,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PatientProfileScreen(patientUid: widget.user.uid),
              ),
            ),
          ),
        ],
      ),
    );
  }
}