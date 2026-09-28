import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../models/patient_record_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/patient_service.dart';

/// Read-only "Full User Information" view reached from Director Data
/// by tapping any user in any tab. Displays only what already exists
/// on `users/{uid}` (via [UserModel]) and, for patients,
/// `patients/{uid}` (via [PatientRecordModel]) — no new source of
/// truth, no password/token/credential fields, and no editing.
///
/// Callers that already have the [UserModel] and/or
/// [PatientRecordModel] in memory (e.g. the Director Data tabs) pass
/// them in via [initialUser]/[initialRecord] so this screen reuses
/// that data instead of re-reading it. Anything missing is fetched
/// once, read-only, using the existing services.
class UserDetailScreen extends StatefulWidget {
  final String uid;
  final UserModel? initialUser;
  final PatientRecordModel? initialRecord;

  const UserDetailScreen({
    super.key,
    required this.uid,
    this.initialUser,
    this.initialRecord,
  });

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  UserModel? _user;
  PatientRecordModel? _record;
  String? _assignedDoctorName;
  String? _assignedNurseName;
  bool _isLoading = true;
  String? _errorMessage;

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
      final user = widget.initialUser ??
          await AuthService.instance.fetchUserProfileByUid(widget.uid);
      PatientRecordModel? record = widget.initialRecord;
      // Try to load a patient record whenever we don't already have
      // one and we can't rule out this being a patient — either we
      // already know the role is patient, or there's no users/{uid}
      // account at all, which is exactly the case for an admin-added
      // patient admitted without an account (hasAccount: false).
      if (record == null && (user == null || user.role == UserRole.patient)) {
        try {
          record =
              await PatientService.instance.fetchPatientRecord(widget.uid);
        } catch (_) {
          // Record may be legitimately inaccessible/absent; the rest
          // of the identity view still renders without it.
        }
      }

           if (!mounted) return;
      setState(() {
        _user = user;
        _record = record;
      });

      // Resolve assigned-staff UIDs to display names. Kept separate
      // from the block above so a failure here never blocks the
      // rest of the (already-loaded) identity view.
      if (record?.assignedDoctorUid != null) {
        try {
          final doctor = await AuthService.instance
              .fetchUserProfileByUid(record!.assignedDoctorUid!);
          if (mounted) setState(() => _assignedDoctorName = doctor?.fullName);
        } catch (_) {}
      }
      if (record?.assignedNurseUid != null) {
        try {
          final nurse = await AuthService.instance
              .fetchUserProfileByUid(record!.assignedNurseUid!);
          if (mounted) setState(() => _assignedNurseName = nurse?.fullName);
        } catch (_) {}
      }
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _errorMessage = 'Something went wrong. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
        title: const Text('Full User Information'),
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryOrange),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_errorMessage!, style: const TextStyle(color: AppColors.error)),
            const SizedBox(height: AppSpacing.sm),
            TextButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

       final user = _user;
    final record = _record;

    // Neither a users/{uid} account nor a patients/{uid} record
    // exists for this uid — genuinely nothing to show.
    if (user == null && record == null) {
      return const Center(
        child: Text(
          'This user could not be found.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    // An admin-added patient who was admitted without an account
    // intentionally has no users/{uid} doc — that's expected, not an
    // error, so render their record directly instead of treating a
    // missing account as "not found".
    final displayName =
        user?.fullName ?? record?.unregisteredFullName ?? 'Unregistered patient';
    final displayRole =
        user?.displayRole ?? 'Patient (admitted without an account)';

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _HeaderCard(fullName: displayName, displayRole: displayRole),
        const SizedBox(height: AppSpacing.lg),
        if (user != null) ...[
          _InfoSection(
            title: 'Identity',
            rows: [
              _InfoRow('Full name', user.fullName),
              _InfoRow('Gender', user.gender?.label),
              _InfoRow('Age', user.age?.toString()),
              _InfoRow('Email', user.email),
              _InfoRow('Phone', user.phone),
              _InfoRow('Role', user.displayRole),
              if (user.role == UserRole.other)
                _InfoRow('Custom role', user.customRole),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _InfoSection(
            title: 'Location',
            rows: [
              _InfoRow('Country', user.country),
              _InfoRow('State', user.state),
              _InfoRow('Local Government Area', user.localGovernmentArea),
              if (user.address != null) _InfoRow('Address', user.address),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _InfoSection(
            title: 'Workplace',
            rows: [
              _InfoRow(
                user.role == UserRole.patient
                    ? 'Primary Healthcare Centre'
                    : 'Workplace / Facility',
                user.workplace,
              ),
              if (user.workLocation != null)
                _InfoRow('Specific Work Location', user.workLocation),
              if (user.chpClinicalRole != null)
                _InfoRow('CHP Clinical Role', user.chpClinicalRole),
            ],
          ),
        ] else ...[
          // No account exists at all for this uid — show only what's
          // actually on the patient record instead of Identity /
          // Location / Workplace sections that don't apply.
          _InfoSection(
            title: 'Identity',
            rows: [
              _InfoRow('Full name', record?.unregisteredFullName),
              _InfoRow('Phone', record?.unregisteredPhone),
              const _InfoRow(
                'Role',
                'Patient (admitted without an account)',
              ),
            ],
          ),
        ],
        if (user?.role == UserRole.patient || (user == null && record != null)) ...[
          const SizedBox(height: AppSpacing.md),
          _InfoSection(
            title: 'Patient Record',
            rows: record == null
                ? [const _InfoRow('Status', 'Not available')]
                : [
                    _InfoRow('Status', record.status.label),
                    _InfoRow(
                      'Primary Healthcare Centre',
                      record.primaryHealthcareCenter,
                    ),
                    _InfoRow(
                      'Admission Date',
                      _formatDate(record.admissionDate),
                    ),
                    _InfoRow(
                      'Discharge Date',
                      _formatDate(record.dischargeDate),
                    ),
                    _InfoRow('Amaudo Facility', record.amaudoFacility),
                    _InfoRow(
                      'Assigned Doctor',
                      record.assignedDoctorUid == null
                          ? null
                          : (_assignedDoctorName ?? 'Unknown'),
                    ),
                    _InfoRow(
                      'Assigned Nurse',
                      record.assignedNurseUid == null
                          ? null
                          : (_assignedNurseName ?? 'Unknown'),
                    ),
                  ],
          ),
        ],
        if (user != null) ...[
          const SizedBox(height: AppSpacing.md),
          _InfoSection(
            title: 'Profile Dates',
            rows: [
              _InfoRow('Registered', _formatDate(user.createdAt)),
              _InfoRow('Last Updated', _formatDate(user.updatedAt)),
            ],
          ),
        ],
      ],
    );
  }

  String? _formatDate(DateTime? date) {
    if (date == null) return null;
    final local = date.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)}';
  }
}

class _HeaderCard extends StatelessWidget {
  final String fullName;
  final String displayRole;
  const _HeaderCard({required this.fullName, required this.displayRole});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.orangeTint,
        borderRadius: BorderRadius.circular(AppRadius.button),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 26,
            backgroundColor: AppColors.primaryOrange,
            child: Icon(Icons.person_outline_rounded, color: Colors.white),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: AppTextSize.body + 2,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  displayRole,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow {
  final String label;
  final String? value;
  const _InfoRow(this.label, this.value);
}

class _InfoSection extends StatelessWidget {
  final String title;
  final List<_InfoRow> rows;

  const _InfoSection({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    // Rows whose value is null/blank still render with "Not on file"
    // rather than being hidden, so the Director sees the field exists
    // but simply isn't populated for this user.
    return Container(
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
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: AppTextSize.label,
              color: AppColors.textSecondary,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final row in rows) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 150,
                    child: Text(
                      row.label,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: AppTextSize.caption + 1,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      (row.value == null || row.value!.trim().isEmpty)
                          ? 'Not on file'
                          : row.value!,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: AppTextSize.body,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}