import '../models/diagnosis_model.dart';
import 'diagnosis_service.dart';

/// PHASE 2 — CHUNK 1: Analytics data foundation only.
///
/// This file does NOT compute totals, breakdowns, percentages, or
/// anything geographic-hierarchy-aware. It only:
///   1. reads real `diagnoses` documents (via the existing
///      [DiagnosisService.fetchDiagnosesForAnalytics], unchanged),
///   2. normalizes the four location fields for future
///      grouping/filtering, and
///   3. exposes the result as [AnalyticsDiagnosisRecord]s.
///
/// Derived values (diagnosis totals, unique patients, illness
/// breakdowns, per-location counts, etc.) are explicitly deferred to
/// a later chunk, per the Chunk 1 spec.

/// Normalizes a single free-text location value (Country / State /
/// LGA / Primary Health Care) so formatting differences alone never
/// create duplicate groups — e.g. "Abia" / "abia" / "ABIA" collapse
/// to one group, and "Aba North" / "aba-north" / "ABA NORTH" collapse
/// to another. Only formatting is collapsed; nothing is guessed, and
/// the original Firestore value is never modified — normalization
/// happens only on the in-memory copy, at read time.
class LocationNormalizer {
  LocationNormalizer._();

  /// Grouping key: trimmed, lowercased, hyphens/underscores/common
  /// punctuation treated as spaces, runs of whitespace collapsed.
  /// Two raw values belong to the same group only when this key
  /// matches exactly.
  static String key(String? raw) {
    final trimmed = (raw ?? '').trim();
    if (trimmed.isEmpty) return '';
    final lower = trimmed.toLowerCase();
    final noPunctuation = lower
        .replaceAll(RegExp(r"[.,;:'’`_/]"), ' ')
        .replaceAll('-', ' ');
    return noPunctuation.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static bool isBlank(String? raw) => key(raw).isEmpty;

  /// Display label for a group: the collapsed value, title-cased for
  /// consistent display regardless of how any individual document had
  /// it typed. Blank/missing is reported as "Not recorded" rather
  /// than invented or silently dropped, so missing data stays visible
  /// instead of being hidden or faked.
  static String display(String? raw) {
    final k = key(raw);
    if (k.isEmpty) return 'Not recorded';
    return k
        .split(' ')
        .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  static NormalizedLocation normalize(String? raw) {
    return NormalizedLocation(
      raw: raw,
      key: key(raw),
      label: display(raw),
      isBlank: isBlank(raw),
    );
  }
}

/// One location field (Country, State, LGA, or Primary Health Care)
/// after normalization. [raw] preserves exactly what was stored in
/// Firestore for that diagnosis document, unmodified.
class NormalizedLocation {
  final String? raw;
  final String key;
  final String label;
  final bool isBlank;

  const NormalizedLocation({
    required this.raw,
    required this.key,
    required this.label,
    required this.isBlank,
  });
}

/// A single diagnosis, flattened to only the fields Analytics needs,
/// with the four location fields normalized. Built directly from an
/// existing [DiagnosisModel] — no new Firestore fields, no invented
/// data. If [illnessName] or [diagnosedAt] is missing on the source
/// document, that is reported as-is (empty string / null) rather than
/// backfilled.
class AnalyticsDiagnosisRecord {
  final String diagnosisId;
  final String patientUid;
  final String illnessName;
  final DateTime? diagnosedAt;
  final NormalizedLocation country;
  final NormalizedLocation state;
  final NormalizedLocation lga;
  final NormalizedLocation primaryHealthcareCenter;

  const AnalyticsDiagnosisRecord({
    required this.diagnosisId,
    required this.patientUid,
    required this.illnessName,
    required this.diagnosedAt,
    required this.country,
    required this.state,
    required this.lga,
    required this.primaryHealthcareCenter,
  });

  factory AnalyticsDiagnosisRecord.fromDiagnosis(DiagnosisModel d) {
    return AnalyticsDiagnosisRecord(
      diagnosisId: d.diagnosisId,
      patientUid: d.patientUid,
      illnessName: d.diagnosisName,
      diagnosedAt: d.diagnosedAt,
      country: LocationNormalizer.normalize(d.patientCountry),
      state: LocationNormalizer.normalize(d.patientState),
      lga: LocationNormalizer.normalize(d.patientLga),
      // Source field is `healthcareCenter` on DiagnosisModel — this is
      // the only "Primary Health Care" value that actually exists in
      // the data today.
      primaryHealthcareCenter: LocationNormalizer.normalize(d.healthcareCenter),
    );
  }
}

/// Data-layer entry point for Analytics. Reads real diagnosis data
/// for a date range and returns it normalized and ready for a future
/// aggregation layer (illness breakdowns, geographic counts, unique
/// patients, etc.) to consume. Does no aggregation itself.
class DiagnosisAnalyticsService {
  DiagnosisAnalyticsService._internal();
  static final DiagnosisAnalyticsService instance =
      DiagnosisAnalyticsService._internal();

  /// Fetches diagnoses in [start]..[end] via the existing,
  /// unmodified [DiagnosisService.fetchDiagnosesForAnalytics] and
  /// returns them as normalized [AnalyticsDiagnosisRecord]s.
  Future<List<AnalyticsDiagnosisRecord>> loadRecords({
    required DateTime start,
    required DateTime end,
    int limit = 1000,
  }) async {
    final diagnoses = await DiagnosisService.instance.fetchDiagnosesForAnalytics(
      start: start,
      end: end,
      limit: limit,
    );
    return diagnoses.map(AnalyticsDiagnosisRecord.fromDiagnosis).toList();
  }
}