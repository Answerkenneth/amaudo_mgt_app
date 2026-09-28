import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../services/auth_service.dart';
import '../../services/care_request_service.dart';

/// Admin/CMHP Coordinator: read a Director's shared review note and
/// send feedback back. Kept entirely separate from the patient-facing
/// referral note.
class ReviewFeedbackScreen extends StatefulWidget {
  final String requestId;
  const ReviewFeedbackScreen({super.key, required this.requestId});

  @override
  State<ReviewFeedbackScreen> createState() => _ReviewFeedbackScreenState();
}

class _ReviewFeedbackScreenState extends State<ReviewFeedbackScreen> {
  final _feedbackController = TextEditingController();
  String? _reviewNote;
  List<Map<String, dynamic>> _feedbackHistory = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _currentUserUid;
  String? _currentUserRole;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final user = await AuthService.instance.fetchCurrentUserProfile();
      final note =
          await CareRequestService.instance.fetchDirectorReviewNote(widget.requestId);
      final feedback =
          await CareRequestService.instance.fetchReviewFeedback(widget.requestId);
      if (!mounted) return;
      setState(() {
        _currentUserUid = user?.uid;
        _currentUserRole = user?.role.name;
        _reviewNote = note;
        _feedbackHistory = feedback;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSubmit() async {
    if (_isSubmitting || _currentUserUid == null || _currentUserRole == null) return;
    if (_feedbackController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Enter feedback before sending.');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      await CareRequestService.instance.submitReviewFeedback(
        requestId: widget.requestId,
        authorUid: _currentUserUid!,
        authorRole: _currentUserRole!,
        feedbackText: _feedbackController.text.trim(),
      );
      _feedbackController.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Feedback sent to Director.')));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Director Review'),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primaryOrange),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.errorTint,
                          borderRadius: BorderRadius.circular(AppRadius.input),
                        ),
                        child: Text(_errorMessage!,
                            style: const TextStyle(color: AppColors.error)),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    Container(
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
                          const Text("Director's Review Note",
                              style: TextStyle(fontWeight: FontWeight.w800)),
                          const SizedBox(height: AppSpacing.sm),
                          Text(_reviewNote?.isNotEmpty == true
                              ? _reviewNote!
                              : 'No review note provided.'),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const Text('Your Feedback', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: AppSpacing.xs),
                    TextField(
                      controller: _feedbackController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.inputFill,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.input),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryOrange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: _isSubmitting ? null : _handleSubmit,
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Send Feedback to Director'),
                      ),
                    ),
                    if (_feedbackHistory.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.lg),
                      const Text('Feedback History',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      const SizedBox(height: AppSpacing.sm),
                      ..._feedbackHistory.map((f) => Container(
                            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
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
                                  (f['authorRole'] as String? ?? '').toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: AppTextSize.caption,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(f['feedbackText'] as String? ?? ''),
                              ],
                            ),
                          )),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}