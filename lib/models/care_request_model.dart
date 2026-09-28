import 'package:cloud_firestore/cloud_firestore.dart'; 
 
enum CareRequestStatus { pending, accepted, declined, cancelled, completed } 
 
extension CareRequestStatusX on CareRequestStatus { 
  String get storageValue => name; 
 
  String get label { 
    switch (this) { 
      case CareRequestStatus.pending: 
        return 'Pending'; 
      case CareRequestStatus.accepted: 
        return 'Accepted'; 
      case CareRequestStatus.declined: 
        return 'Declined'; 
      case CareRequestStatus.cancelled: 
        return 'Cancelled'; 
      case CareRequestStatus.completed: 
        return 'Resolved'; 
    } 
  } 
 
  static CareRequestStatus fromStorageValue(String? value) { 
    return CareRequestStatus.values.firstWhere( 
      (s) => s.storageValue == value, 
      orElse: () => CareRequestStatus.pending, 
    ); 
  } 
} 
 
/// The Director's decision on a care request. Deliberately separate 
/// from CareRequestStatus — Review is NOT a status change and does 
/// not block a later Approve. Only the DECISION metadata lives here; 
/// the actual note text lives in restricted subcollections (see 
/// CareRequestService) so a patient's existing full-document read 
/// access to their own request can never expose the internal review 
/// note, and never exposes the referral note until explicitly sent. 
enum DirectorDecision { approved, review } 
 
extension DirectorDecisionX on DirectorDecision { 
  String get storageValue => name; 
 
  String get label { 
    switch (this) { 
      case DirectorDecision.approved: 
        return 'Approved'; 
      case DirectorDecision.review: 
        return 'Under Review'; 
    } 
  } 
 
  static DirectorDecision? fromStorageValue(String? value) { 
    if (value == null) return null; 
    return DirectorDecision.values 
        .where((d) => d.storageValue == value) 
        .cast<DirectorDecision?>() 
        .firstWhere((_) => true, orElse: () => null); 
  } 
} 
 
class CareRequestModel { 
  final String requestId; 
  final String patientUid; 
  final CareRequestStatus status; 
  final String? reason; 
  final String? onsetInfo; 
  final String? impact; 
  final String? additionalInfo; 
  final String? acceptedByUid; 
  final String? acceptedByRole; 
  final DateTime? acceptedAt; 
  final DateTime? requestedAt; 
  final DateTime? createdAt; 
  final DateTime? updatedAt; 
  final DirectorDecision? directorDecision; 
  final String? directorReviewedByUid; 
  final DateTime? directorReviewedAt; 
  final String? directorApprovedByUid; 
  final DateTime? directorApprovedAt; 
  final bool directorReferralSent; 
  final String? directorReferralSentByUid; 
  final DateTime? directorReferralSentAt; 
 
  // Added for Director review-note routing. 
  final bool reviewSentToAdmin; 
  final bool reviewSentToCmhp; 
  final bool reviewSentToChp;
  final bool reviewSentToDirector;
 
  const CareRequestModel({ 
    required this.requestId, 
    required this.patientUid, 
    this.status = CareRequestStatus.pending, 
    this.reason, 
    this.onsetInfo, 
    this.impact, 
    this.additionalInfo, 
    this.acceptedByUid, 
    this.acceptedByRole, 
    this.acceptedAt, 
    this.requestedAt, 
    this.createdAt, 
    this.updatedAt, 
    this.directorDecision, 
    this.directorReviewedByUid, 
    this.directorReviewedAt, 
    this.directorApprovedByUid, 
    this.directorApprovedAt, 
    this.directorReferralSent = false, 
    this.directorReferralSentByUid, 
    this.directorReferralSentAt, 
 
    // New fields default to false so existing documents remain compatible. 
    this.reviewSentToAdmin = false, 
    this.reviewSentToCmhp = false, 
    this.reviewSentToChp = false,
    this.reviewSentToDirector = false,
  }); 
 
  Map<String, dynamic> toCreateMap() { 
    return { 
      'patientUid': patientUid, 
      'status': CareRequestStatus.pending.storageValue, 
      'reason': reason, 
      'onsetInfo': onsetInfo, 
      'impact': impact, 
      'additionalInfo': additionalInfo, 
      'acceptedByUid': null, 
      'acceptedByRole': null, 
      'acceptedAt': null, 
      'requestedAt': FieldValue.serverTimestamp(), 
      'createdAt': FieldValue.serverTimestamp(), 
      'updatedAt': FieldValue.serverTimestamp(), 
      'directorDecision': null, 
      'directorReviewedByUid': null, 
      'directorReviewedAt': null, 
      'directorApprovedByUid': null, 
      'directorApprovedAt': null, 
      'directorReferralSent': false, 
      'directorReferralSentByUid': null, 
      'directorReferralSentAt': null, 
 
      // New fields. 
      'reviewSentToAdmin': false, 
      'reviewSentToCmhp': false, 
      'reviewSentToChp': false,
      'reviewSentToDirector': false,
    }; 
  } 
 
  factory CareRequestModel.fromSnapshot( 
    DocumentSnapshot<Map<String, dynamic>> doc, 
  ) { 
    final data = doc.data(); 
 
    if (data == null) { 
      throw StateError('Care request ${doc.id} has no data.'); 
    } 
 
    return CareRequestModel( 
      requestId: doc.id, 
      patientUid: data['patientUid'] as String? ?? '', 
      status: CareRequestStatusX.fromStorageValue(data['status'] as String?), 
      reason: data['reason'] as String?, 
      onsetInfo: data['onsetInfo'] as String?, 
      impact: data['impact'] as String?, 
      additionalInfo: data['additionalInfo'] as String?, 
      acceptedByUid: data['acceptedByUid'] as String?, 
      acceptedByRole: data['acceptedByRole'] as String?, 
      acceptedAt: (data['acceptedAt'] as Timestamp?)?.toDate(), 
      requestedAt: (data['requestedAt'] as Timestamp?)?.toDate(), 
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(), 
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(), 
      directorDecision: 
          DirectorDecisionX.fromStorageValue(data['directorDecision'] as String?), 
      directorReviewedByUid: data['directorReviewedByUid'] as String?, 
      directorReviewedAt: 
          (data['directorReviewedAt'] as Timestamp?)?.toDate(), 
      directorApprovedByUid: data['directorApprovedByUid'] as String?, 
      directorApprovedAt: 
          (data['directorApprovedAt'] as Timestamp?)?.toDate(), 
      directorReferralSent: 
          data['directorReferralSent'] as bool? ?? false, 
      directorReferralSentByUid: 
          data['directorReferralSentByUid'] as String?, 
      directorReferralSentAt: 
          (data['directorReferralSentAt'] as Timestamp?)?.toDate(), 
 
      // New fields. 
      reviewSentToAdmin: 
          data['reviewSentToAdmin'] as bool? ?? false, 
      reviewSentToCmhp: 
          data['reviewSentToCmhp'] as bool? ?? false, 
      reviewSentToChp:
          data['reviewSentToChp'] as bool? ?? false,
      reviewSentToDirector:
          data['reviewSentToDirector'] as bool? ?? false,
    ); 
  } 
}