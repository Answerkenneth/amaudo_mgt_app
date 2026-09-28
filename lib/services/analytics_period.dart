/// PHASE 2 — CHUNK 4: Period / date-range calculations.
///
/// Pure calendar math — no Firestore reads, no UI. Given a named
/// period, computes the concrete [start, end] range "now", and the
/// equivalent immediately-preceding range for period-over-period
/// comparison. This is a fresh implementation for the new Analytics
/// system; nothing here is reused from the pre-Phase-1 code.

/// A concrete, inclusive date range to query against
/// `diagnoses.diagnosedAt`.
class AnalyticsDateRange {
  final DateTime start;
  final DateTime end;

  const AnalyticsDateRange({required this.start, required this.end});
}

enum AnalyticsPeriod {
  today,
  thisWeek,
  thisMonth,
  lastMonth,
  thisYear,
  lastYear,
  custom,
}

class AnalyticsPeriodCalculator {
  AnalyticsPeriodCalculator._();

  static DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime _endOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

  /// Monday of the week containing [d], at 00:00.
  static DateTime _startOfWeek(DateTime d) {
    final startOfDay = _startOfDay(d);
    return startOfDay.subtract(Duration(days: startOfDay.weekday - DateTime.monday));
  }

  static DateTime _startOfMonth(int year, int month) => DateTime(year, month, 1);

  /// Last moment of [year]-[month], handling month/year rollover and
  /// varying month lengths correctly.
  static DateTime _endOfMonth(int year, int month) {
    final firstOfNextMonth =
        month == 12 ? DateTime(year + 1, 1, 1) : DateTime(year, month + 1, 1);
    return firstOfNextMonth.subtract(const Duration(milliseconds: 1));
  }

  /// The range for [period] as of now. For "this ___" periods the
  /// range runs from the start of that calendar unit up to now
  /// (partial, still in progress). For "last ___" periods it is the
  /// full, already-complete prior calendar unit. [customStart]/
  /// [customEnd] are required when [period] is [AnalyticsPeriod.custom].
  static AnalyticsDateRange current(
    AnalyticsPeriod period, {
    DateTime? customStart,
    DateTime? customEnd,
  }) {
    final now = DateTime.now();
    switch (period) {
      case AnalyticsPeriod.today:
        return AnalyticsDateRange(start: _startOfDay(now), end: now);
      case AnalyticsPeriod.thisWeek:
        return AnalyticsDateRange(start: _startOfWeek(now), end: now);
      case AnalyticsPeriod.thisMonth:
        return AnalyticsDateRange(start: _startOfMonth(now.year, now.month), end: now);
      case AnalyticsPeriod.lastMonth:
        final y = now.month == 1 ? now.year - 1 : now.year;
        final m = now.month == 1 ? 12 : now.month - 1;
        return AnalyticsDateRange(start: _startOfMonth(y, m), end: _endOfMonth(y, m));
      case AnalyticsPeriod.thisYear:
        return AnalyticsDateRange(start: DateTime(now.year, 1, 1), end: now);
      case AnalyticsPeriod.lastYear:
        return AnalyticsDateRange(
          start: DateTime(now.year - 1, 1, 1),
          end: DateTime(now.year - 1, 12, 31, 23, 59, 59, 999),
        );
      case AnalyticsPeriod.custom:
        if (customStart == null || customEnd == null) {
          throw ArgumentError(
            'customStart and customEnd are required for AnalyticsPeriod.custom',
          );
        }
        return AnalyticsDateRange(start: customStart, end: customEnd);
    }
  }

  /// The immediately-preceding range of the same kind/length as
  /// [currentRange], for period-over-period comparison (e.g. "this
  /// month" vs "last month", "this week" vs "the week before").
  /// Always a full, complete prior unit — never partial, even when
  /// [currentRange] itself is partial (e.g. "today" so far).
  static AnalyticsDateRange previous(
    AnalyticsPeriod period,
    AnalyticsDateRange currentRange,
  ) {
    switch (period) {
      case AnalyticsPeriod.today:
        final yesterday = currentRange.start.subtract(const Duration(days: 1));
        return AnalyticsDateRange(start: yesterday, end: _endOfDay(yesterday));
      case AnalyticsPeriod.thisWeek:
        final prevStart = currentRange.start.subtract(const Duration(days: 7));
        final prevEnd = currentRange.start.subtract(const Duration(milliseconds: 1));
        return AnalyticsDateRange(start: prevStart, end: prevEnd);
      case AnalyticsPeriod.thisMonth:
        final y = currentRange.start.month == 1
            ? currentRange.start.year - 1
            : currentRange.start.year;
        final m = currentRange.start.month == 1 ? 12 : currentRange.start.month - 1;
        return AnalyticsDateRange(start: _startOfMonth(y, m), end: _endOfMonth(y, m));
      case AnalyticsPeriod.lastMonth:
        final y = currentRange.start.month == 1
            ? currentRange.start.year - 1
            : currentRange.start.year;
        final m = currentRange.start.month == 1 ? 12 : currentRange.start.month - 1;
        return AnalyticsDateRange(start: _startOfMonth(y, m), end: _endOfMonth(y, m));
      case AnalyticsPeriod.thisYear:
        final y = currentRange.start.year - 1;
        return AnalyticsDateRange(
          start: DateTime(y, 1, 1),
          end: DateTime(y, 12, 31, 23, 59, 59, 999),
        );
      case AnalyticsPeriod.lastYear:
        final y = currentRange.start.year - 1;
        return AnalyticsDateRange(
          start: DateTime(y, 1, 1),
          end: DateTime(y, 12, 31, 23, 59, 59, 999),
        );
      case AnalyticsPeriod.custom:
        final durationMs = currentRange.end.difference(currentRange.start).inMilliseconds;
        final prevEnd = currentRange.start.subtract(const Duration(milliseconds: 1));
        final prevStart = prevEnd.subtract(Duration(milliseconds: durationMs));
        return AnalyticsDateRange(start: prevStart, end: prevEnd);
    }
  }
}