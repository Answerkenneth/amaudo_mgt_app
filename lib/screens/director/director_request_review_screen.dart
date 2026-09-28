import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../models/care_request_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/care_request_service.dart';
import '../../widgets/care/request_datetime_block.dart';

class DirectorRequestReviewScreen extends StatefulWidget {
  final String requestId;
  const DirectorRequestReviewScreen({super.key, required this.requestId});

  @override
  State<DirectorRequestReviewScreen> createState() =>
      _DirectorRequestReviewScreenState();
}

class _DirectorRequestReviewScreenState
    extends State<DirectorRequestReviewScreen> {
  final _reviewNoteController = TextEditingController();
  final _referralNoteController = TextEditingController();
  final _replyController = TextEditingController();

  CareRequestModel? _request;
  UserModel? _currentUser;
  UserModel? _patient;
  bool _referralAlreadySent = false;
  List<Map<String, dynamic>> _feedback = [];
  List<Map<String, dynamic>> _chpMessages = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  bool get _isChpUser => _currentUser?.role == UserRole.chp;
  bool get _isDirectorUser =>
      _currentUser?.role == UserRole.director ||
      _currentUser?.role == UserRole.ceo;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _reviewNoteController.dispose();
    _referralNoteController.dispose();
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await AuthService.instance.fetchCurrentUserProfile();
      final request =
          await CareRequestService.instance.fetchRequestById(widget.requestId);

      UserModel? patient;
      if (request != null) {
        try {
          patient = await AuthService.instance
              .fetchUserProfileByUid(request.patientUid);
        } catch (_) {}
      }

      String? reviewNote;
      Map<String, dynamic>? referral;
      List<Map<String, dynamic>> feedback = [];
      List<Map<String, dynamic>> chpMessages = [];

      final isDirectorRole =
          user?.role == UserRole.director || user?.role == UserRole.ceo;
      final isChpRole = user?.role == UserRole.chp;

      if (isDirectorRole) {
        try {
          reviewNote = await CareRequestService.instance
              .fetchDirectorReviewNote(widget.requestId);
        } catch (_) {}
        try {
          referral = await CareRequestService.instance
              .fetchReferralNote(widget.requestId);
        } catch (_) {}
        try {
          chpMessages = await CareRequestService.instance
              .fetchChpMessages(widget.requestId);
        } catch (_) {}
      } else if (isChpRole) {
        try {
          final chpNote = await CareRequestService.instance
              .fetchChpPrivateNote(widget.requestId);
          reviewNote = chpNote?['reviewNote'] as String?;
        } catch (_) {}
        try {
          final draft = await CareRequestService.instance
              .fetchChpReferralDraft(widget.requestId);
          if (draft != null) _referralNoteController.text = draft;
        } catch (_) {}
      }

      try {
        feedback = await CareRequestService.instance
            .fetchReviewFeedback(widget.requestId);
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _currentUser = user;
        _request = request;
        _patient = patient;
        _reviewNoteController.text = reviewNote ?? '';
        _referralNoteController.text =
            (isDirectorRole ? (referral?['referralNote'] as String?) : null) ??
                _referralNoteController.text;
        _referralAlreadySent = referral?['sent'] as bool? ?? false;
        _feedback = feedback;
        _chpMessages = chpMessages;
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(
          () => _errorMessage = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleApprove() async {
    if (_isSubmitting || _currentUser == null) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      await CareRequestService.instance.directorApprove(
        requestId: widget.requestId,
        directorUid: _currentUser!.uid,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Request approved.')));
      await _load();
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(
          () => _errorMessage = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _handleSaveReview() async {
    if (_isSubmitting || _currentUser == null) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      if (_isChpUser) {
        if (_reviewNoteController.text.trim().isEmpty) {
          setState(() => _errorMessage = 'Enter a review note first.');
          return;
        }
        await CareRequestService.instance.chpSaveReviewNote(
          requestId: widget.requestId,
          chpUid: _currentUser!.uid,
          reviewNote: _reviewNoteController.text.trim(),
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Review saved.')));
      } else {
        await CareRequestService.instance.directorSaveReview(
          requestId: widget.requestId,
          directorUid: _currentUser!.uid,
          reviewNote: _reviewNoteController.text.trim().isEmpty
              ? null
              : _reviewNoteController.text.trim(),
          referralNote: _referralNoteController.text.trim().isEmpty
              ? null
              : _referralNoteController.text.trim(),
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Review saved.')));
      }
      await _load();
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(
          () => _errorMessage = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _handleChpShareReview({
    required bool toAdmin,
    required bool toCmhp,
  }) async {
    if (_isSubmitting || _currentUser == null) return;
    if (_reviewNoteController.text.trim().isEmpty) {
      setState(
          () => _errorMessage = 'Enter and save a review note first.');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      await CareRequestService.instance.chpSaveReviewNote(
        requestId: widget.requestId,
        chpUid: _currentUser!.uid,
        reviewNote: _reviewNoteController.text.trim(),
      );
      await CareRequestService.instance.chpShareReviewTo(
        requestId: widget.requestId,
        chpUid: _currentUser!.uid,
        toAdmin: toAdmin,
        toCmhp: toCmhp,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Review shared.')));
      await _load();
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(
          () => _errorMessage = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _handleChpSendReviewToDirector() async {
    if (_isSubmitting || _currentUser == null) return;
    if (_reviewNoteController.text.trim().isEmpty) {
      setState(
          () => _errorMessage = 'Enter a review note before sending.');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      await CareRequestService.instance.chpSendMessageToDirector(
        requestId: widget.requestId,
        chpUid: _currentUser!.uid,
        messageType: 'review',
        text: _reviewNoteController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review sent to Director.')),
      );
      await _load();
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(
          () => _errorMessage = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _handleChpSaveDraft() async {
    if (_isSubmitting || _currentUser == null) return;
    if (_referralNoteController.text.trim().isEmpty) {
      setState(
          () => _errorMessage = 'Enter a referral draft before saving.');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      await CareRequestService.instance.chpSaveReferralDraft(
        requestId: widget.requestId,
        chpUid: _currentUser!.uid,
        referralNote: _referralNoteController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Draft saved.')));
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(
          () => _errorMessage = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _handleSendReferral() async {
    if (_isSubmitting || _currentUser == null) return;
    if (_referralNoteController.text.trim().isEmpty) {
      setState(
          () => _errorMessage = 'Enter a referral note before sending.');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      if (_isChpUser) {
        // CHP referral is always a SUGGESTION to the Director only —
        // never the patient-facing referral doc.
        await CareRequestService.instance.chpSendMessageToDirector(
          requestId: widget.requestId,
          chpUid: _currentUser!.uid,
          messageType: 'referral',
          text: _referralNoteController.text.trim(),
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Referral suggestion sent to Director.')),
        );
      } else {
        await CareRequestService.instance.directorSaveReview(
          requestId: widget.requestId,
          directorUid: _currentUser!.uid,
          referralNote: _referralNoteController.text.trim(),
        );
        await CareRequestService.instance.directorSendReferral(
          requestId: widget.requestId,
          directorUid: _currentUser!.uid,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Referral note sent.')));
      }
      await _load();
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(
          () => _errorMessage = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _handleSendReview({
    required bool toAdmin,
    required bool toCmhp,
    required bool toChp,
  }) async {
    if (_isSubmitting || _currentUser == null) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      await CareRequestService.instance.directorSaveReview(
        requestId: widget.requestId,
        directorUid: _currentUser!.uid,
        reviewNote: _reviewNoteController.text.trim().isEmpty
            ? null
            : _reviewNoteController.text.trim(),
      );
      await CareRequestService.instance.directorSendReviewTo(
        requestId: widget.requestId,
        directorUid: _currentUser!.uid,
        toAdmin: toAdmin,
        toCmhp: toCmhp,
        toChp: toChp,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Review shared.')));
      await _load();
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(
          () => _errorMessage = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _handleReply() async {
    if (_isSubmitting || _currentUser == null) return;
    if (_replyController.text.trim().isEmpty) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      await CareRequestService.instance.submitReviewFeedback(
        requestId: widget.requestId,
        authorUid: _currentUser!.uid,
        authorRole: _currentUser!.role.storageValue,
        feedbackText: _replyController.text.trim(),
      );
      _replyController.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Reply sent.')));
      await _load();
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(
          () => _errorMessage = 'Something went wrong. Please try again.');
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
        title: const Text('Review Care Request'),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primaryOrange,
                ),
              )
            : _request == null
                ? const Padding(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    child: Text(
                      'This request could not be found.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
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
                              borderRadius:
                                  BorderRadius.circular(AppRadius.input),
                            ),
                            child: Text(
                              _errorMessage!,
                              style:
                                  const TextStyle(color: AppColors.error),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                        ],
                        if (_patient != null) ...[
                          _Section(
                            title: 'Patient Information',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _patient!.fullName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                if (_patient!.phone != null)
                                  Text(
                                    'Phone: ${_patient!.phone}',
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                if (_patient!.email != null)
                                  Text(
                                    'Email: ${_patient!.email}',
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                if (_patient!.address != null)
                                  Text(
                                    'Address: ${_patient!.address}',
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                if ([
                                  _patient!.localGovernmentArea,
                                  _patient!.state,
                                  _patient!.country
                                ].whereType<String>().isNotEmpty)
                                  Text(
                                    [
                                      _patient!.localGovernmentArea,
                                      _patient!.state,
                                      _patient!.country
                                    ].whereType<String>().join(', '),
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                        ],
                        _Section(
                          title: "Patient's Concern",
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _request!.reason ?? 'No details provided',
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              if (_request!.onsetInfo != null) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'Onset: ${_request!.onsetInfo}',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                              if (_request!.impact != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Impact: ${_request!.impact}',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                              if (_request!.additionalInfo != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Additional: ${_request!.additionalInfo}',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                              if (_request!.requestedAt != null) ...[
                                const SizedBox(height: AppSpacing.sm),
                                RequestDateTimeBlock(
                                  dateTime: _request!.requestedAt!,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _Section(
                          title: 'Current Decision',
                          child: Text(
                            _request!.directorDecision?.label ??
                                'Not yet reviewed',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                                               if (_isDirectorUser || _isChpUser) ...[
                          const SizedBox(height: AppSpacing.lg),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryOrange,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              onPressed: _isSubmitting ? null : _handleApprove,
                              child: const Text('Approve'),
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          _isChpUser
                              ? 'Review Note'
                              : 'Review Note (internal — never shown to the patient)',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        TextField(
                          controller: _reviewNoteController,
                          maxLines: 4,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: AppColors.inputFill,
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.input),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed:
                                _isSubmitting ? null : _handleSaveReview,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primaryOrange,
                              side: const BorderSide(
                                color: AppColors.primaryOrange,
                              ),
                              minimumSize:
                                  const Size(double.infinity, 44),
                            ),
                            child: const Text('Save Review'),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        const Text(
                          'Share Review With',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: _isDirectorUser
                              ? [
                                  OutlinedButton(
                                    onPressed: _isSubmitting
                                        ? null
                                        : () => _handleSendReview(
                                              toAdmin: true,
                                              toCmhp: false,
                                              toChp: false,
                                            ),
                                    child: Text(
                                      _request!.reviewSentToAdmin
                                          ? 'Sent to Admin ✓'
                                          : 'Send to Admin',
                                    ),
                                  ),
                                  OutlinedButton(
                                    onPressed: _isSubmitting
                                        ? null
                                        : () => _handleSendReview(
                                              toAdmin: false,
                                              toCmhp: true,
                                              toChp: false,
                                            ),
                                    child: Text(
                                      _request!.reviewSentToCmhp
                                          ? 'Sent to CMHP ✓'
                                          : 'Send to CMHP',
                                    ),
                                  ),
                                  OutlinedButton(
                                    onPressed: _isSubmitting
                                        ? null
                                        : () => _handleSendReview(
                                              toAdmin: false,
                                              toCmhp: false,
                                              toChp: true,
                                            ),
                                    child: Text(
                                      _request!.reviewSentToChp
                                          ? 'Sent to CHP ✓'
                                          : 'Send to CHP',
                                    ),
                                  ),
                                ]
                              : [
                                  OutlinedButton(
                                    onPressed: _isSubmitting
                                        ? null
                                        : () => _handleChpShareReview(
                                              toAdmin: true,
                                              toCmhp: false,
                                            ),
                                    child:
                                        const Text('Send to Admin'),
                                  ),
                                  OutlinedButton(
                                    onPressed: _isSubmitting
                                        ? null
                                        : () => _handleChpShareReview(
                                              toAdmin: false,
                                              toCmhp: true,
                                            ),
                                    child:
                                        const Text('Send to CMHP'),
                                  ),
                                  OutlinedButton(
                                    onPressed: _isSubmitting
                                        ? null
                                        : _handleChpSendReviewToDirector,
                                    child:
                                        const Text('Send to Director'),
                                  ),
                                ],
                        ),
                        if (_feedback.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.lg),
                          const Text(
                            'Feedback',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          ..._feedback.map(
                            (f) => Container(
                              margin: const EdgeInsets.only(
                                bottom: AppSpacing.sm,
                              ),
                              padding:
                                  const EdgeInsets.all(AppSpacing.md),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.button,
                                ),
                                border: Border.all(
                                  color: AppColors.divider,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    (f['authorRole'] as String? ?? '')
                                        .toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: AppTextSize.caption,
                                      fontWeight: FontWeight.w700,
                                      color:
                                          AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    f['feedbackText'] as String? ?? '',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        if (_isDirectorUser &&
                            _chpMessages.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.lg),
                          const Text(
                            'Messages from CHP',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          ..._chpMessages.map(
                            (m) => Container(
                              margin: const EdgeInsets.only(
                                bottom: AppSpacing.sm,
                              ),
                              padding:
                                  const EdgeInsets.all(AppSpacing.md),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.button,
                                ),
                                border: Border.all(
                                  color: AppColors.divider,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    (m['messageType'] as String? ?? '')
                                        .toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: AppTextSize.caption,
                                      fontWeight: FontWeight.w700,
                                      color:
                                          AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    m['text'] as String? ?? '',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        if (_isDirectorUser) ...[
                          const SizedBox(height: AppSpacing.md),
                          TextField(
                            controller: _replyController,
                            decoration: InputDecoration(
                              hintText: 'Reply to feedback…',
                              filled: true,
                              fillColor: AppColors.inputFill,
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(AppRadius.input),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          OutlinedButton(
                            onPressed:
                                _isSubmitting ? null : _handleReply,
                            style: OutlinedButton.styleFrom(
                              minimumSize:
                                  const Size(double.infinity, 44),
                            ),
                            child: const Text('Send Reply'),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          _isChpUser
                              ? 'Referral Draft (visible to Director only — never sent to patient automatically)'
                              : (_referralAlreadySent
                                  ? 'Referral Note (already sent to patient)'
                                  : 'Referral Note (visible to the patient only if sent)'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        TextField(
                          controller: _referralNoteController,
                          maxLines: 4,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: AppColors.inputFill,
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.input),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        if (_isChpUser)
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _isSubmitting
                                      ? null
                                      : _handleChpSaveDraft,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor:
                                        AppColors.primaryOrange,
                                    side: const BorderSide(
                                      color: AppColors.primaryOrange,
                                    ),
                                    padding:
                                        const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                  ),
                                  child:
                                      const Text('Save Draft'),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _isSubmitting
                                      ? null
                                      : _handleSendReferral,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        AppColors.primaryOrange,
                                    foregroundColor: Colors.white,
                                    padding:
                                        const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                  ),
                                  child:
                                      const Text('Send to Director'),
                                ),
                              ),
                            ],
                          )
                        else
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _isSubmitting
                                      ? null
                                      : _handleSaveReview,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor:
                                        AppColors.primaryOrange,
                                    side: const BorderSide(
                                      color: AppColors.primaryOrange,
                                    ),
                                    padding:
                                        const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                  ),
                                  child:
                                      const Text('Save Draft'),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: (_isSubmitting ||
                                          _referralAlreadySent)
                                      ? null
                                      : _handleSendReferral,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        AppColors.primaryOrange,
                                    foregroundColor: Colors.white,
                                    padding:
                                        const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                  ),
                                  child: Text(
                                    _referralAlreadySent
                                        ? 'Referral Sent'
                                        : 'Send Referral',
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({
    required this.title,
    required this.child,
  });

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
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }
}