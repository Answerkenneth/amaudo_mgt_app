import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../models/care_request_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/care_request_service.dart';
import 'director_request_review_screen.dart';

/// Director-only list of care requests requiring attention. Reuses
/// the existing status=='pending' query — requests remain 'pending'
/// through Director review/approval until a practitioner actually
/// accepts them (a separate lifecycle, unchanged by this chunk), so
/// this same list naturally includes undecided, reviewed, and
/// already-approved-but-not-yet-accepted requests.
class DirectorCareRequestsScreen extends StatefulWidget {
  const DirectorCareRequestsScreen({super.key});

  @override
  State<DirectorCareRequestsScreen> createState() =>
      _DirectorCareRequestsScreenState();
}

class _DirectorCareRequestsScreenState
    extends State<DirectorCareRequestsScreen> {
  bool _isAuthorized = false;
  List<CareRequestModel> _items = [];
  final Map<String, String> _patientNames = {};
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final user = await AuthService.instance.fetchCurrentUserProfile();
    final authorized =
        user != null && (user.role == UserRole.director || user.role == UserRole.ceo || user.role == UserRole.chp);
    if (!mounted) return;
    setState(() {
  _isAuthorized = authorized;
});
    if (authorized) await _load();
    if (!authorized && mounted) setState(() => _isLoading = false);
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final items = await CareRequestService.instance.fetchPendingRequests();
      for (final item in items) {
        if (!_patientNames.containsKey(item.patientUid)) {
          final identity =
              await AuthService.instance.fetchUserProfileByUid(item.patientUid);
          _patientNames[item.patientUid] = identity?.fullName ?? 'A patient';
        }
      }
      if (!mounted) return;
      setState(() => _items = items);
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Care Requests'),
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
                : RefreshIndicator(
                    onRefresh: _load,
                    child: _errorMessage != null
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            children: [
                              Text(_errorMessage!,
                                  style: const TextStyle(color: AppColors.error)),
                              const SizedBox(height: AppSpacing.sm),
                              TextButton(onPressed: _load, child: const Text('Retry')),
                            ],
                          )
                        : _items.isEmpty
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: const [
                                  Padding(
                                    padding: EdgeInsets.all(AppSpacing.xl),
                                    child: Center(
                                      child: Text(
                                        'No care requests awaiting review',
                                        style:
                                            TextStyle(color: AppColors.textSecondary),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.all(AppSpacing.lg),
                                itemCount: _items.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: AppSpacing.sm),
                                itemBuilder: (context, index) {
                                  final item = _items[index];
                                  return _RequestTile(
                                    patientName:
                                        _patientNames[item.patientUid] ?? 'A patient',
                                    request: item,
                                    onTap: () async {
                                      await Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => DirectorRequestReviewScreen(
                                            requestId: item.requestId,
                                          ),
                                        ),
                                      );
                                      _load();
                                    },
                                  );
                                },
                              ),
                  ),
      ),
    );
  }
}

class _RequestTile extends StatelessWidget {
  final String patientName;
  final CareRequestModel request;
  final VoidCallback onTap;

  const _RequestTile({
    required this.patientName,
    required this.request,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final decision = request.directorDecision;
    final badgeColor = decision == DirectorDecision.approved
        ? AppColors.success
        : decision == DirectorDecision.review
            ? AppColors.primaryOrange
            : AppColors.textSecondary;
    final badgeLabel = decision?.label ?? 'Not yet reviewed';

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
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patientName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (request.reason != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        request.reason!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.icon),
                ),
                child: Text(
                  badgeLabel,
                  style: TextStyle(
                    color: badgeColor,
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