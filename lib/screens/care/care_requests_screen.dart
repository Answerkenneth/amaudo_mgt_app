import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../models/care_request_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/care_request_service.dart';
import '../clinical/care_request_review_screen.dart';
/// Doctor/Nurse: requests specifically assigned to them by
/// Admin/CMHP Coordinator. Unassigned requests are never visible
/// here — see Director's approval pipeline.
class CareRequestsScreen extends StatefulWidget {
  const CareRequestsScreen({super.key});

  @override
  State<CareRequestsScreen> createState() => _CareRequestsScreenState();
}

class _CareRequestsScreenState extends State<CareRequestsScreen> {
  UserModel? _currentUser;
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
    if (!mounted) return;
    setState(() => _currentUser = user);
    await _load();
  }

  Future<void> _load() async {
    if (_currentUser == null) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final items = await CareRequestService.instance
          .fetchAssignedRequestsForPractitioner(_currentUser!.uid);
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
                                    'No care requests assigned to you yet',
                                    style: TextStyle(color: AppColors.textSecondary),
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
                              return Material(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(AppRadius.button),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(AppRadius.button),
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          CareRequestReviewScreen(request: item),
                                    ),
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(AppSpacing.md),
                                    decoration: BoxDecoration(
                                      borderRadius:
                                          BorderRadius.circular(AppRadius.button),
                                      border: Border.all(color: AppColors.divider),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _patientNames[item.patientUid] ?? 'A patient',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.textPrimary),
                                        ),
                                        if (item.reason != null) ...[
                                          const SizedBox(height: 4),
                                          Text(item.reason!,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  color: AppColors.textSecondary)),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
              ),
      ),
    );
  }
}