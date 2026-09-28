import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../models/patient_record_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/patient_service.dart';
import 'patient_profile_screen.dart';

class PatientListScreen extends StatefulWidget {
  const PatientListScreen({super.key});

  @override
  State<PatientListScreen> createState() => _PatientListScreenState();
}

class _PatientListScreenState extends State<PatientListScreen> {
  UserModel? _currentUser;
  bool _isLoadingUser = true;

  final _searchController = TextEditingController();

  final List<PatientListItem> _items = [];
  DocumentSnapshot<Map<String, dynamic>>? _lastDocument;
  bool _hasMore = true;
  bool _isLoadingPage = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserThenFirstPage();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _isPrivileged =>
      _currentUser != null &&
      {
        UserRole.admin,
        UserRole.director,
        UserRole.ceo,
      }.contains(_currentUser!.role);

  bool get _isDoctor => _currentUser?.role == UserRole.doctor;

  bool get _isNurse => _currentUser?.role == UserRole.nurse;

  bool get _isChp => _currentUser?.role == UserRole.chp;

  bool get _effectiveIsDoctor =>
      _isDoctor || (_isChp && _currentUser?.chpClinicalRole == 'doctor');

  Future<void> _loadCurrentUserThenFirstPage() async {
    final user = await AuthService.instance.fetchCurrentUserProfile();

    if (!mounted) return;

    setState(() {
      _currentUser = user;
      _isLoadingUser = false;
    });

    await _loadPage(reset: true);
  }

  Future<void> _loadPage({bool reset = false}) async {
    if (_currentUser == null) return;

    if (!_isPrivileged && !_effectiveIsDoctor && !_isNurse && !_isChp) {
      return;
    }

    if (_isLoadingPage) return;

    setState(() {
      _isLoadingPage = true;
      _errorMessage = null;

      if (reset) {
        _items.clear();
        _lastDocument = null;
        _hasMore = true;
      }
    });

    try {
      PatientPage page;

      if (_isPrivileged) {
        page = await PatientService.instance.fetchAllPatients(
          searchPrefix: _searchController.text,
          startAfter: reset ? null : _lastDocument,
        );
      } else {
        page = await PatientService.instance.fetchAssignedPatients(
          staffUid: _currentUser!.uid,
          isDoctor: _effectiveIsDoctor,
          startAfter: reset ? null : _lastDocument,
        );
      }

      if (!mounted) return;

      setState(() {
        _items.addAll(page.items);
        _lastDocument = page.lastDocument;
        _hasMore = page.hasMore;
      });
    } on AuthException catch (e) {
      if (!mounted) return;

      setState(() => _errorMessage = e.message);
    } catch (_) {
      if (!mounted) return;

      setState(
        () => _errorMessage = 'Something went wrong. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() => _isLoadingPage = false);
      }
    }
  }

  List<PatientListItem> get _displayedItems {
    return _items;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Patients'),
      ),
      body: SafeArea(
        child: _isLoadingUser
            ? const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primaryOrange,
                ),
              )
            : (!_isPrivileged &&
                    !_effectiveIsDoctor &&
                    !_isNurse &&
                    !_isChp)
                ? const Padding(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    child: Text(
                      'You do not have permission to view patient records.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          AppSpacing.sm,
                          AppSpacing.lg,
                          0,
                        ),
                        child: Column(
                          children: [
                            if (_isPrivileged)
                              TextField(
                                controller: _searchController,
                                decoration: InputDecoration(
                                  hintText: 'Search by name',
                                  prefixIcon: const Icon(
                                    Icons.search_rounded,
                                  ),
                                  filled: true,
                                  fillColor: AppColors.inputFill,
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.md,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.input,
                                    ),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                onSubmitted: (_) => _loadPage(reset: true),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      if (_errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                          ),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: AppColors.error,
                            ),
                          ),
                        ),
                      Expanded(
                        child: _displayedItems.isEmpty && !_isLoadingPage
                            ? const Center(
                                child: Text(
                                  'No patients found',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                padding:
                                    const EdgeInsets.all(AppSpacing.lg),
                                itemCount: _displayedItems.length +
                                    (_hasMore ? 1 : 0),
                                separatorBuilder: (_, _) =>
                                    const SizedBox(
                                  height: AppSpacing.sm,
                                ),
                                itemBuilder: (context, index) {
                                  if (index >= _displayedItems.length) {
                                    return Center(
                                      child: _isLoadingPage
                                          ? const CircularProgressIndicator(
                                              color:
                                                  AppColors.primaryOrange,
                                            )
                                          : TextButton(
                                              onPressed: () =>
                                                  _loadPage(),
                                              child:
                                                  const Text('Load more'),
                                            ),
                                    );
                                  }

                                  final item = _displayedItems[index];

                                  final status = item.record?.status ??
                                      PatientStatus.notAdmitted;

                                  return _PatientTile(
                                    item: item,
                                    status: status,
                                    isPrivileged: _isPrivileged,
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              PatientProfileScreen(
                                            patientUid: item.uid,
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
      ),
    );
  }
}

class _PatientTile extends StatelessWidget {
  final PatientListItem item;
  final PatientStatus status;
  final bool isPrivileged;
  final VoidCallback onTap;

  const _PatientTile({
    required this.item,
    required this.status,
    required this.isPrivileged,
    required this.onTap,
  });

  Color get _statusColor {
    switch (status) {
      case PatientStatus.admitted:
        return AppColors.success;

      case PatientStatus.discharged:
        return AppColors.textSecondary;

      case PatientStatus.notAdmitted:
        return AppColors.primaryOrange;
    }
  }

  String _displayStatus(PatientStatus status) {
    // Privileged users see the actual internal patient status.
    if (isPrivileged) {
      return status.label;
    }

    // Assigned patients (doctors, nurses, and CHP)
    // only see whether care is ongoing or has ended.
    return status == PatientStatus.discharged
        ? 'Discharged'
        : 'Approved';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.button),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.button),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.button),
            border: Border.all(
              color: AppColors.divider,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.fullName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (item.phone != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.phone!,
                        style: const TextStyle(
                          fontSize: AppTextSize.caption + 1,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(
                    AppRadius.icon,
                  ),
                ),
                child: Text(
                  _displayStatus(status),
                  style: TextStyle(
                    color: _statusColor,
                    fontWeight: FontWeight.w700,
                    fontSize: AppTextSize.caption,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
