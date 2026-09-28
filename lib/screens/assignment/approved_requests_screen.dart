import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../models/care_request_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/care_request_service.dart';
import 'select_practitioner_screen.dart';

/// Admin / CMHP Coordinator: Director-approved requests awaiting
/// practitioner assignment.
class ApprovedRequestsScreen extends StatefulWidget {
  const ApprovedRequestsScreen({super.key});

  @override
  State<ApprovedRequestsScreen> createState() => _ApprovedRequestsScreenState();
}

class _ApprovedRequestsScreenState extends State<ApprovedRequestsScreen> {
  bool _isAuthorized = false;
  List<CareRequestModel> _items = [];
  final Map<String, String> _patientNames = {};
  bool _isLoading = true;
  String? _errorMessage;
  bool _isAssigning = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final user = await AuthService.instance.fetchCurrentUserProfile();
    final authorized = user != null &&
        (user.role == UserRole.admin || user.role == UserRole.cmhpCoordinator);
    if (!mounted) return;
    setState(() => _isAuthorized = authorized);
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
      final items = await CareRequestService.instance.fetchApprovedUnassignedRequests();
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

  Future<void> _handleAssign(CareRequestModel request) async {
    if (_isAssigning) return;
    final selected = await Navigator.of(context).push<UserModel>(
      MaterialPageRoute(builder: (_) => const SelectPractitionerScreen()),
    );
    if (selected == null) return;

    setState(() => _isAssigning = true);
    try {
      await CareRequestService.instance.assignPractitioner(
        requestId: request.requestId,
        patientUid: request.patientUid,
        practitionerUid: selected.uid,
        practitionerRole: selected.role.storageValue,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Assigned to ${selected.fullName}.')),
      );
      await _load();
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _isAssigning = false);
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
        title: const Text('Approved Requests'),
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
                : _errorMessage != null
                    ? Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Text(_errorMessage!,
                            style: const TextStyle(color: AppColors.error)),
                      )
                    : _items.isEmpty
                        ? const Center(
                            child: Text(
                              'No approved requests awaiting assignment',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            itemCount: _items.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: AppSpacing.sm),
                            itemBuilder: (context, index) {
                              final item = _items[index];
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
                                    Text(_patientNames[item.patientUid] ?? 'A patient',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimary)),
                                    if (item.reason != null) ...[
                                      const SizedBox(height: 4),
                                      Text(item.reason!,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              color: AppColors.textSecondary)),
                                    ],
                                    const SizedBox(height: AppSpacing.sm),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primaryOrange,
                                          foregroundColor: Colors.white,
                                        ),
                                        onPressed:
                                            _isAssigning ? null : () => _handleAssign(item),
                                        child: const Text('Assign Practitioner'),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
      ),
    );
  }
}