import 'diagnosis_analytics_service.dart';

/// PHASE 2 — CHUNK 2: Aggregation / calculations layer.
///
/// Takes the normalized [AnalyticsDiagnosisRecord]s produced by
/// [DiagnosisAnalyticsService] (Chunk 1) and computes:
///   - Medical Analytics: total diagnosis records, unique patients,
///     illness breakdown.
///   - Geographic Analytics: per-location record/unique-patient
///     counts for Country, State, LGA, and Primary Health Care.
///
/// This file does NOT build any UI. It includes aggregation and
/// cascading location filtering; time-based trend bucketing was
/// removed (superseded by the illness/category chart) since nothing
/// references it anymore.

/// How trend points are bucketed. Chosen automatically from the
/// span of the date range being analyzed — see
/// [DiagnosisAnalyticsEngine.computeTrend].
enum TrendGranularity { daily, weekly, monthly }

/// One point on the trend line/bar chart.
class TrendPoint {
  final DateTime bucketStart;
  final int records;
  final int uniquePatients;

  const TrendPoint({
    required this.bucketStart,
    required this.records,
    required this.uniquePatients,
  });
}

/// A full trend series over a date range, bucketed at [granularity].
/// [points] always covers every bucket in the range in chronological
/// order — including buckets with zero records — so gaps in the data
/// show as zero rather than being skipped.
class TrendResult {
  final TrendGranularity granularity;
  final List<TrendPoint> points;

  const TrendResult({required this.granularity, required this.points});
}

/// A location selection for scoping Analytics to a specific
/// Country/State/LGA/PHC, cascading top-down. Each field is a
/// normalized [LocationNormalizer] key (not a raw display string);
/// `null` means "not filtered at this level".
class LocationFilter {
  final String? countryKey;
  final String? stateKey;
  final String? lgaKey;
  final String? phcKey;

  const LocationFilter({this.countryKey, this.stateKey, this.lgaKey, this.phcKey});

  bool get isEmpty =>
      countryKey == null && stateKey == null && lgaKey == null && phcKey == null;
}

/// One selectable value for a location dropdown at a given level.
class LocationOption {
  final String key;
  final String label;
  const LocationOption({required this.key, required this.label});
}

/// One illness's contribution to Medical Analytics.
class IllnessBreakdown {
  final String illnessName;
  final int records;
  final int uniquePatients;

  /// % of [MedicalAnalyticsResult.totalRecords] this illness accounts
  /// for. 0 when there are no records at all.
  final double percentageOfRecords;

  const IllnessBreakdown({
    required this.illnessName,
    required this.records,
    required this.uniquePatients,
    required this.percentageOfRecords,
  });
}

/// Diagnosis Records → Unique Patients → Illness Breakdown, computed
/// from a set of [AnalyticsDiagnosisRecord]s.
class MedicalAnalyticsResult {
  final int totalRecords;
  final int totalUniquePatients;
  final List<IllnessBreakdown> illnessBreakdown;

  const MedicalAnalyticsResult({
    required this.totalRecords,
    required this.totalUniquePatients,
    required this.illnessBreakdown,
  });
}

/// Which location level a [LocationBreakdown] row belongs to.
enum LocationLevel { country, state, lga, primaryHealthcareCenter }

/// One location value's counts within a single [LocationLevel].
/// [key]/[label] come straight from [LocationNormalizer] — [key] is
/// the grouping key (formatting differences collapsed), [label] is
/// the tidied display value. A blank/missing value for that field
/// groups under `isBlank == true` ("Not recorded") rather than being
/// dropped, so missing data stays visible.
class LocationBreakdown {
  final LocationLevel level;
  final String key;
  final String label;
  final bool isBlank;
  final int records;
  final int uniquePatients;

  /// % of that level's total records this location accounts for.
  final double percentageOfRecords;

  const LocationBreakdown({
    required this.level,
    required this.key,
    required this.label,
    required this.isBlank,
    required this.records,
    required this.uniquePatients,
    required this.percentageOfRecords,
  });
}

/// Country → State → LGA → Primary Health Care counts, each level
/// computed independently over the full record set (not yet scoped
/// to a parent-level selection — cascading/filtering is a later,
/// UI-driven chunk).
class GeographicAnalyticsResult {
  final List<LocationBreakdown> byCountry;
  final List<LocationBreakdown> byState;
  final List<LocationBreakdown> byLga;
  final List<LocationBreakdown> byPrimaryHealthcareCenter;

  const GeographicAnalyticsResult({
    required this.byCountry,
    required this.byState,
    required this.byLga,
    required this.byPrimaryHealthcareCenter,
  });
}

class DiagnosisAnalyticsEngine {
  DiagnosisAnalyticsEngine._();

  /// Keeps only records matching every non-null field of [filter].
  /// Matching is on normalized keys, so "Abia"/"abia"/"ABIA" all
  /// match a `countryKey` of `'abia'` regardless of how any
  /// individual document had it typed.
  static List<AnalyticsDiagnosisRecord> applyLocationFilter(
    List<AnalyticsDiagnosisRecord> records,
    LocationFilter filter,
  ) {
    if (filter.isEmpty) return records;
    return records.where((r) {
      if (filter.countryKey != null && r.country.key != filter.countryKey) return false;
      if (filter.stateKey != null && r.state.key != filter.stateKey) return false;
      if (filter.lgaKey != null && r.lga.key != filter.lgaKey) return false;
      if (filter.phcKey != null &&
          r.primaryHealthcareCenter.key != filter.phcKey) {
        return false;
      }
      return true;
    }).toList();
  }

  /// Distinct selectable values for [level], drawn only from
  /// [records] — so passing records already scoped to a parent
  /// selection (e.g. records for the chosen Country) yields only the
  /// States that actually occur within that Country, cascading
  /// correctly. Options are real values found in the data; nothing
  /// is invented. Sorted alphabetically by label, blank/"Not
  /// recorded" values sorted last.
  static List<LocationOption> optionsFor(
    List<AnalyticsDiagnosisRecord> records,
    LocationLevel level,
  ) {
    final selector = _selectorFor(level);
    final labelByKey = <String, String>{};
    final blankByKey = <String, bool>{};
    for (final r in records) {
      final loc = selector(r);
      labelByKey[loc.key] = loc.label;
      blankByKey[loc.key] = loc.isBlank;
    }
    final options = labelByKey.entries
        .map((e) => LocationOption(key: e.key, label: e.value))
        .toList()
      ..sort((a, b) {
        final aBlank = blankByKey[a.key] ?? false;
        final bBlank = blankByKey[b.key] ?? false;
        if (aBlank != bBlank) return aBlank ? 1 : -1;
        return a.label.toLowerCase().compareTo(b.label.toLowerCase());
      });
    return options;
  }

  static NormalizedLocation Function(AnalyticsDiagnosisRecord) _selectorFor(
    LocationLevel level,
  ) {
    switch (level) {
      case LocationLevel.country:
        return (r) => r.country;
      case LocationLevel.state:
        return (r) => r.state;
      case LocationLevel.lga:
        return (r) => r.lga;
      case LocationLevel.primaryHealthcareCenter:
        return (r) => r.primaryHealthcareCenter;
    }
  }

  /// Buckets [records] into a chronological trend series covering
  /// every bucket between [rangeStart] and [rangeEnd] inclusive
  /// (empty buckets included as zero, not skipped). Granularity is
  /// chosen automatically from the span: ≤31 days → daily, ≤180 days
  /// → weekly (Monday-aligned), otherwise → monthly. A record with a
  /// null `diagnosedAt` is excluded — its date is genuinely unknown,
  /// so it can't be placed on a timeline; it's still counted in
  /// Medical/Geographic totals via [computeMedical]/[computeGeographic].
  static TrendResult computeTrend(
    List<AnalyticsDiagnosisRecord> records, {
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) {
    final spanDays = rangeEnd.difference(rangeStart).inDays;
    final granularity = spanDays <= 31
        ? TrendGranularity.daily
        : spanDays <= 180
            ? TrendGranularity.weekly
            : TrendGranularity.monthly;

    final bucketStarts = _bucketStarts(rangeStart, rangeEnd, granularity);

    final recordsByBucket = <DateTime, List<AnalyticsDiagnosisRecord>>{
      for (final b in bucketStarts) b: [],
    };
    for (final r in records) {
      final d = r.diagnosedAt;
      if (d == null) continue;
      final bucket = _bucketFor(d, granularity, bucketStarts);
      if (bucket != null) recordsByBucket[bucket]!.add(r);
    }

    final points = bucketStarts.map((b) {
      final bucketRecords = recordsByBucket[b]!;
      return TrendPoint(
        bucketStart: b,
        records: bucketRecords.length,
        uniquePatients: bucketRecords.map((r) => r.patientUid).toSet().length,
      );
    }).toList();

    return TrendResult(granularity: granularity, points: points);
  }

  static DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime _startOfWeek(DateTime d) {
    final startOfDay = _startOfDay(d);
    return startOfDay.subtract(Duration(days: startOfDay.weekday - DateTime.monday));
  }

  static DateTime _startOfMonth(DateTime d) => DateTime(d.year, d.month, 1);

  static DateTime _addBucket(DateTime bucketStart, TrendGranularity granularity) {
    switch (granularity) {
      case TrendGranularity.daily:
        return bucketStart.add(const Duration(days: 1));
      case TrendGranularity.weekly:
        return bucketStart.add(const Duration(days: 7));
      case TrendGranularity.monthly:
        return bucketStart.month == 12
            ? DateTime(bucketStart.year + 1, 1, 1)
            : DateTime(bucketStart.year, bucketStart.month + 1, 1);
    }
  }

  static List<DateTime> _bucketStarts(
    DateTime rangeStart,
    DateTime rangeEnd,
    TrendGranularity granularity,
  ) {
    DateTime cursor;
    switch (granularity) {
      case TrendGranularity.daily:
        cursor = _startOfDay(rangeStart);
        break;
      case TrendGranularity.weekly:
        cursor = _startOfWeek(rangeStart);
        break;
      case TrendGranularity.monthly:
        cursor = _startOfMonth(rangeStart);
        break;
    }
    final starts = <DateTime>[];
    while (!cursor.isAfter(rangeEnd)) {
      starts.add(cursor);
      cursor = _addBucket(cursor, granularity);
    }
    // Guard against a range so narrow no bucket start was generated
    // (shouldn't normally happen since cursor <= rangeEnd on entry).
    if (starts.isEmpty) starts.add(cursor);
    return starts;
  }

  /// Which bucket in [bucketStarts] [d] falls into, or null if [d]
  /// falls outside all of them (e.g. slightly before/after the range
  /// due to a record right at a boundary).
  static DateTime? _bucketFor(
    DateTime d,
    TrendGranularity granularity,
    List<DateTime> bucketStarts,
  ) {
    if (bucketStarts.isEmpty) return null;
    DateTime candidate;
    switch (granularity) {
      case TrendGranularity.daily:
        candidate = _startOfDay(d);
        break;
      case TrendGranularity.weekly:
        candidate = _startOfWeek(d);
        break;
      case TrendGranularity.monthly:
        candidate = _startOfMonth(d);
        break;
    }
    return bucketStarts.contains(candidate) ? candidate : null;
  }

  /// Diagnosis Records → Unique Patients → Illness Breakdown.
  /// Illness grouping uses the raw `illnessName` on each record
  /// as-is (this already comes pre-resolved from `DiagnosisModel` —
  /// the fixed category label, or the free-text "Other illness"
  /// value — so no further normalization is applied here). An empty
  /// `illnessName` groups under `'Not recorded'` rather than being
  /// dropped, so missing data stays visible instead of being hidden.
  ///
  /// Deduplicates by `diagnosisId` first: if the same diagnosis
  /// document ever appears more than once in [records] (e.g. an
  /// overlapping fetch), it is still counted exactly once — in the
  /// total, in unique-patient counting, and within whichever
  /// illness it belongs to. This is a distinct guarantee from
  /// unique-patient counting: two different diagnoses for the same
  /// patient and the same illness are NOT merged into one — only a
  /// repeated `diagnosisId` (the same diagnosis) is.
  static MedicalAnalyticsResult computeMedical(
    List<AnalyticsDiagnosisRecord> records,
  ) {
    final dedupedById = <String, AnalyticsDiagnosisRecord>{};
    for (final r in records) {
      dedupedById[r.diagnosisId] = r;
    }
    final deduped = dedupedById.values.toList();

    final totalRecords = deduped.length;
    final totalUniquePatients = deduped.map((r) => r.patientUid).toSet().length;

    final recordsByIllness = <String, List<AnalyticsDiagnosisRecord>>{};
    for (final r in deduped) {
      final name = r.illnessName.trim().isEmpty ? 'Not recorded' : r.illnessName.trim();
      recordsByIllness.putIfAbsent(name, () => []).add(r);
    }

    final breakdown = recordsByIllness.entries.map((entry) {
      final illnessRecords = entry.value;
      final uniquePatients = illnessRecords.map((r) => r.patientUid).toSet().length;
      return IllnessBreakdown(
        illnessName: entry.key,
        records: illnessRecords.length,
        uniquePatients: uniquePatients,
        percentageOfRecords:
            totalRecords == 0 ? 0 : (illnessRecords.length / totalRecords) * 100,
      );
    }).toList()
      ..sort((a, b) => b.records.compareTo(a.records));

    return MedicalAnalyticsResult(
      totalRecords: totalRecords,
      totalUniquePatients: totalUniquePatients,
      illnessBreakdown: breakdown,
    );
  }

  /// Country/State/LGA/PHC counts, each level independent over the
  /// full [records] set, grouped by each field's already-normalized
  /// key (see [AnalyticsDiagnosisRecord] / [LocationNormalizer]).
  ///
  /// Deduplicates by `diagnosisId` first, for the same reason and in
  /// the same way as [computeMedical]: if the same diagnosis
  /// document ever appears more than once in [records], it must
  /// still be counted once per location — otherwise Geographic
  /// counts could disagree with Medical's `totalRecords` for the
  /// identical filtered dataset.
  static GeographicAnalyticsResult computeGeographic(
    List<AnalyticsDiagnosisRecord> records,
  ) {
    final dedupedById = <String, AnalyticsDiagnosisRecord>{};
    for (final r in records) {
      dedupedById[r.diagnosisId] = r;
    }
    final deduped = dedupedById.values.toList();

    return GeographicAnalyticsResult(
      byCountry: _aggregateLevel(
        deduped,
        LocationLevel.country,
        (r) => r.country,
      ),
      byState: _aggregateLevel(
        deduped,
        LocationLevel.state,
        (r) => r.state,
      ),
      byLga: _aggregateLevel(
        deduped,
        LocationLevel.lga,
        (r) => r.lga,
      ),
      byPrimaryHealthcareCenter: _aggregateLevel(
        deduped,
        LocationLevel.primaryHealthcareCenter,
        (r) => r.primaryHealthcareCenter,
      ),
    );
  }

  static List<LocationBreakdown> _aggregateLevel(
    List<AnalyticsDiagnosisRecord> records,
    LocationLevel level,
    NormalizedLocation Function(AnalyticsDiagnosisRecord) selector,
  ) {
    final totalAtLevel = records.length;

    // Group by normalized key so "Abia"/"abia"/"ABIA" and
    // "Aba North"/"aba-north"/"ABA NORTH" collapse into one row each,
    // while genuinely different values never merge.
    final recordsByKey = <String, List<AnalyticsDiagnosisRecord>>{};
    final labelByKey = <String, String>{};
    final blankByKey = <String, bool>{};
    for (final r in records) {
      final loc = selector(r);
      recordsByKey.putIfAbsent(loc.key, () => []).add(r);
      labelByKey[loc.key] = loc.label;
      blankByKey[loc.key] = loc.isBlank;
    }

    final rows = recordsByKey.entries.map((entry) {
      final locRecords = entry.value;
      final uniquePatients = locRecords.map((r) => r.patientUid).toSet().length;
      return LocationBreakdown(
        level: level,
        key: entry.key,
        label: labelByKey[entry.key]!,
        isBlank: blankByKey[entry.key]!,
        records: locRecords.length,
        uniquePatients: uniquePatients,
        percentageOfRecords:
            totalAtLevel == 0 ? 0 : (locRecords.length / totalAtLevel) * 100,
      );
    }).toList()
      ..sort((a, b) => b.records.compareTo(a.records));

    return rows;
  }
}