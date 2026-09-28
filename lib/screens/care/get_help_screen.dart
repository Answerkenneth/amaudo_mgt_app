import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../models/care_request_model.dart';
import '../../services/auth_exception.dart';
import '../../services/care_request_service.dart';
import '../../widgets/auth/auth_text_field.dart';
import '../../widgets/auth/auth_primary_button.dart';
import '../../widgets/auth/auth_error_banner.dart';
import '../../widgets/care/request_datetime_block.dart';
class GetHelpScreen extends StatefulWidget {
  final String patientUid;
  const GetHelpScreen({super.key, required this.patientUid});

  @override
  State<GetHelpScreen> createState() => _GetHelpScreenState();
}

class _GetHelpScreenState extends State<GetHelpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final _onsetController = TextEditingController();
  final _impactController = TextEditingController();
  final _additionalController = TextEditingController();

  CareRequestModel? _activeRequest;
  List<CareRequestModel> _history = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _onsetController.dispose();
    _impactController.dispose();
    _additionalController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final all = await CareRequestService.instance
          .fetchRequestsForPatient(widget.patientUid);
      CareRequestModel? active;
      for (final r in all) {
        if (r.status == CareRequestStatus.pending ||
            r.status == CareRequestStatus.accepted) {
          active = r;
          break;
        }
      }
      if (!mounted) return;
      setState(() {
        _activeRequest = active;
        _history = all;
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

  Future<void> _handleRequest() async {
    if (_isSubmitting) return;
    final formValid = _formKey.currentState?.validate() ?? false;
    if (!formValid) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await CareRequestService.instance.createCareRequest(
        patientUid: widget.patientUid,
        reason: _reasonController.text.trim(),
        onsetInfo: _onsetController.text.trim().isEmpty
            ? null
            : _onsetController.text.trim(),
        impact: _impactController.text.trim().isEmpty
            ? null
            : _impactController.text.trim(),
        additionalInfo: _additionalController.text.trim().isEmpty
            ? null
            : _additionalController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your care request has been sent to the healthcare team.'),
        ),
      );
      _reasonController.clear();
      _onsetController.clear();
      _impactController.clear();
      _additionalController.clear();
      await _load();
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

  Future<void> _handleCancel() async {
    if (_activeRequest == null) return;
    try {
      await CareRequestService.instance.cancelRequest(_activeRequest!.requestId);
      await _load();
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
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
        title: const Text('Get Help'),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primaryOrange),
              )
            : RefreshIndicator(
                onRefresh: _load,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_errorMessage != null) ...[
                        AuthErrorBanner(message: _errorMessage!),
                        const SizedBox(height: AppSpacing.sm),
                        TextButton(onPressed: _load, child: const Text('Retry')),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      if (_activeRequest == null) _buildForm() else _buildActiveStatus(),
                      const SizedBox(height: AppSpacing.xl),
                      const Text(
                        'My Care Requests',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      if (_history.isEmpty)
                        const Text(
                          'You have not requested care yet.',
                          style: TextStyle(color: AppColors.textSecondary),
                        )
                      else
                        ..._history.map((r) => Padding(
                              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                              child: _HistoryTile(request: r),
                            )),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tell us what you\'re experiencing',
            style: TextStyle(
              fontSize: AppTextSize.screenTitle - 4,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'Describe what you\'re experiencing, when it started, and '
            'anything else you think a nurse or doctor should know.',
            style: TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: AppSpacing.lg),
          AuthTextField(
            label: 'What\'s going on?',
            hint: 'Describe what you\'re experiencing',
            controller: _reasonController,
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Please tell us what you\'re experiencing'
                : null,
            prefixIcon: Icons.edit_note_rounded,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppSpacing.md),
          AuthTextField(
            label: 'When did this start? (optional)',
            hint: 'e.g. 3 days ago',
            controller: _onsetController,
            validator: (_) => null,
            prefixIcon: Icons.schedule_outlined,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppSpacing.md),
          AuthTextField(
            label: 'How is this affecting you? (optional)',
            hint: 'e.g. Trouble sleeping, hard to concentrate',
            controller: _impactController,
            validator: (_) => null,
            prefixIcon: Icons.psychology_outlined,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppSpacing.md),
          AuthTextField(
            label: 'Anything else we should know? (optional)',
            hint: 'Anything else that might help',
            controller: _additionalController,
            validator: (_) => null,
            prefixIcon: Icons.notes_outlined,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: AppSpacing.lg),
          AuthPrimaryButton(
            label: 'Submit Request',
            isLoading: _isSubmitting,
            onPressed: _handleRequest,
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Amaudo is not an emergency-response service. If you need '
            'urgent help, please contact emergency services directly.',
            style: TextStyle(
              fontSize: AppTextSize.caption,
              color: AppColors.placeholderText,
            ),
          ),
        ],
      ),
    );
  }
    String _resolveStatusHeading(CareRequestModel r) {
    // Assigned takes priority — do not override an existing Assigned
    // display. Referred is checked next, ahead of Approved/Under
    // Review/Pending, per the required Pending -> Referred transition.
    if (r.status == CareRequestStatus.accepted) {
      return 'A ${r.acceptedByRole ?? 'practitioner'} is now assisting you';
    }
    if (r.directorReferralSent) {
      return 'Referred';
    }
    if (r.directorDecision == DirectorDecision.approved) {
      return 'Approved';
    }
    if (r.directorDecision == DirectorDecision.review) {
      return 'Under Review';
    }
    return 'Waiting for a nurse or doctor';
  }

  String _resolveStatusDetail(CareRequestModel r) {
    if (r.status == CareRequestStatus.accepted) {
      return 'They will reach out to you soon.';
    }
    if (r.directorReferralSent) {
      return 'The Director has sent a referral for your care. See details below.';
    }
    if (r.directorDecision == DirectorDecision.approved) {
      return 'Your request has been approved and is being assigned to a practitioner.';
    }
    if (r.directorDecision == DirectorDecision.review) {
      return 'Your request is currently under review by our care team.';
    }
    return 'Your request has been sent. Status: Pending.';
  }
  Widget _buildActiveStatus() {
    final r = _activeRequest!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          r.status == CareRequestStatus.accepted
              ? Icons.check_circle_outline_rounded
              : Icons.hourglass_top_rounded,
          color: r.status == CareRequestStatus.accepted
              ? AppColors.success
              : AppColors.primaryOrange,
          size: 40,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          _resolveStatusHeading(r),
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: AppTextSize.body,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          _resolveStatusDetail(r),
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        if (r.status == CareRequestStatus.pending) ...[
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton(
            onPressed: _handleCancel,
            child: const Text('Cancel Request'),
          ),
        ],
        // Referral display is intentionally independent of assignment
        // status — appears as soon as the Director sends it.
        FutureBuilder<Map<String, dynamic>?>(
          future: CareRequestService.instance.fetchReferralNote(r.requestId),
          builder: (context, snapshot) {
            final data = snapshot.data;
            if (data == null || data['sent'] != true) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.orangeTint,
                  borderRadius: BorderRadius.circular(AppRadius.button),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Referral', style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(data['referralNote'] as String? ?? ''),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
class _HistoryTile extends StatelessWidget {
  final CareRequestModel request;
  const _HistoryTile({required this.request});

  Color _statusColor(CareRequestStatus s) {
    switch (s) {
      case CareRequestStatus.pending:
        return AppColors.primaryOrange;
      case CareRequestStatus.accepted:
        return AppColors.success;
      case CareRequestStatus.completed:
        return AppColors.textSecondary;
      case CareRequestStatus.declined:
      case CareRequestStatus.cancelled:
        return AppColors.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.button),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  request.reason ?? 'No details provided',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _statusColor(request.status).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.icon),
                ),
                child: Text(
                  request.status.label,
                  style: TextStyle(
                    color: _statusColor(request.status),
                    fontWeight: FontWeight.w700,
                    fontSize: AppTextSize.caption,
                  ),
                ),
              ),
            ],
          ),
          if (request.requestedAt != null) ...[
            const SizedBox(height: AppSpacing.sm),
            RequestDateTimeBlock(dateTime: request.requestedAt!),
          ],
        ],
      ),
    );
  }
}