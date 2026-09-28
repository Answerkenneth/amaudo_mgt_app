import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../models/care_request_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/care_request_service.dart';
import '../assignment/select_practitioner_screen.dart';
import '../director/director_request_review_screen.dart';
import 'review_feedback_screen.dart';

/// Persistent, searchable lists for Director/Admin/CMHP Coordinator:
/// Approved / Under Review / Referred. Unlike the original "unassigned
/// only" query, entries here never disappear after assignment — they
/// remain visible for tracking, per the corrected requirement.
class CareRequestListsScreen extends StatefulWidget {
  const CareRequestListsScreen({super.key});

  @override
  State<CareRequestListsScreen> createState() => _CareRequestListsScreenState();
}

class _CareRequestListsScreenState extends State<CareRequestListsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  UserModel? _currentUser;
  bool _isAuthorized = false;

  final Map<String, UserModel?> _patientCache = {};
  final _searchController = TextEditingController();
  String _searchQuery = '';

  List<CareRequestModel> _approved = [];
  List<CareRequestModel> _underReview = [];
  List<CareRequestModel> _referred = [];

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _init();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final user = await AuthService.instance.fetchCurrentUserProfile();
        final authorized = user != null &&
        (user.role == UserRole.director ||
            user.role == UserRole.ceo ||
            user.role == UserRole.admin ||
            user.role == UserRole.cmhpCoordinator ||
            user.role == UserRole.chp);
    setState(() {
      _currentUser = user;
      _isAuthorized = authorized;
    });
    if (authorized) {
      await _load();
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final approved = await CareRequestService.instance
          .fetchRequestsByDirectorDecision(DirectorDecision.approved);
      final underReview = await CareRequestService.instance
          .fetchRequestsByDirectorDecision(DirectorDecision.review);
      final referred = await CareRequestService.instance.fetchReferredRequests();

      for (final r in [...approved, ...underReview, ...referred]) {
        if (!_patientCache.containsKey(r.patientUid)) {
          final identity =
              await AuthService.instance.fetchUserProfileByUid(r.patientUid);
          _patientCache[r.patientUid] = identity;
        }
      }

      if (!mounted) return;
      setState(() {
        _approved = approved;
        _underReview = underReview;
        _referred = referred;
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

  List<CareRequestModel> _filtered(List<CareRequestModel> items) {
    if (_searchQuery.trim().isEmpty) return items;
    final q = _searchQuery.trim().toLowerCase();
    return items.where((r) {
      final p = _patientCache[r.patientUid];
      final name = p?.fullName.toLowerCase() ?? '';
      final phone = p?.phone?.toLowerCase() ?? '';
      return name.contains(q) || phone.contains(q);
    }).toList();
  }

  Future<void> _handleTap(CareRequestModel request) async {
    final role = _currentUser?.role;
    if (role == UserRole.director || role == UserRole.ceo || role == UserRole.chp) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DirectorRequestReviewScreen(requestId: request.requestId),
        ),
      );
      _load();
      return;
    }

    // Admin / CMHP Coordinator
    if (_tabController.index == 1) {
      final sharedWithMe = role == UserRole.admin
          ? request.reviewSentToAdmin
          : request.reviewSentToCmhp;
      if (!sharedWithMe) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This review has not been shared with you yet.'),
          ),
        );
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ReviewFeedbackScreen(requestId: request.requestId),
        ),
      );
      _load();
      return;
    }

    if (_tabController.index == 0) {
      if (request.status == CareRequestStatus.pending) {
        final selected = await Navigator.of(context).push<UserModel>(
          MaterialPageRoute(builder: (_) => const SelectPractitionerScreen()),
        );
        if (selected == null) return;
        try {
          await CareRequestService.instance.assignPractitioner(
            requestId: request.requestId,
            patientUid: request.patientUid,
            practitionerUid: selected.uid,
            practitionerRole: selected.role.storageValue,
            chpClinicalRole: selected.chpClinicalRole
          );
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Assigned to ${selected.fullName}.')),
          );
          _load();
        } on AuthException catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(e.message)));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This request has already been assigned.')),
        );
      }
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('This patient has been referred by the Director.')),
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
        title: const Text('Care Requests'),
        bottom: _isAuthorized
            ? TabBar(
                controller: _tabController,
                labelColor: AppColors.primaryOrange,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.primaryOrange,
                onTap: (_) => setState(() {}),
                tabs: const [
                  Tab(text: 'Approved'),
                  Tab(text: 'Under Review'),
                  Tab(text: 'Referred'),
                ],
              )
            : null,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primaryOrange),
              )
            : !_isAuthorized
                ? const Padding(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    child: Text(
                      'You are not authorized to access this screen.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (v) => setState(() => _searchQuery = v),
                          decoration: InputDecoration(
                            hintText: 'Search by patient name or phone',
                            prefixIcon: const Icon(Icons.search_rounded),
                            filled: true,
                            fillColor: AppColors.inputFill,
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.input),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      if (_errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                          child: Text(_errorMessage!,
                              style: const TextStyle(color: AppColors.error)),
                        ),
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildList(_filtered(_approved)),
                            _buildList(_filtered(_underReview)),
                            _buildList(_filtered(_referred)),
                          ],
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildList(List<CareRequestModel> items) {
    if (items.isEmpty) {
      return const Center(
        child: Text('No requests found', style: TextStyle(color: AppColors.textSecondary)),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          final r = items[index];
          final patient = _patientCache[r.patientUid];
          return _PatientRequestTile(
            patient: patient,
            request: r,
            onTap: () => _handleTap(r),
          );
        },
      ),
    );
  }
}

class _PatientRequestTile extends StatelessWidget {
  final UserModel? patient;
  final CareRequestModel request;
  final VoidCallback onTap;

  const _PatientRequestTile({
    required this.patient,
    required this.request,
    required this.onTap,
  });

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
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                patient?.fullName ?? 'Unknown patient',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              if (patient?.phone != null) ...[
                const SizedBox(height: 2),
                Text(patient!.phone!,
                    style: const TextStyle(
                        fontSize: AppTextSize.caption + 1,
                        color: AppColors.textSecondary)),
              ],
              if (patient?.email != null) ...[
                const SizedBox(height: 2),
                Text(patient!.email!,
                    style: const TextStyle(
                        fontSize: AppTextSize.caption + 1,
                        color: AppColors.textSecondary)),
              ],
              if ([patient?.localGovernmentArea, patient?.state, patient?.country]
                  .whereType<String>()
                  .isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  [patient?.localGovernmentArea, patient?.state, patient?.country]
                      .whereType<String>()
                      .join(', '),
                  style: const TextStyle(
                      fontSize: AppTextSize.caption + 1,
                      color: AppColors.textSecondary),
                ),
              ],
              if (request.reason != null) ...[
                const SizedBox(height: 4),
                Text(request.reason!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textSecondary)),
              ],
              const SizedBox(height: AppSpacing.xs),
                            Text(
                request.status == CareRequestStatus.accepted
                    ? 'Assigned'
                    : (request.directorReferralSent ? 'Referred' : 'Unassigned'),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: AppTextSize.caption,
                  color: request.status == CareRequestStatus.accepted
                      ? AppColors.success
                      : (request.directorReferralSent
                          ? AppColors.primaryOrangeDark
                          : AppColors.primaryOrange),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}