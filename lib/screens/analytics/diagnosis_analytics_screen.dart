import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/analytics_period.dart';
import '../../services/diagnosis_analytics_engine.dart';
import '../../services/diagnosis_analytics_service.dart';

/// PHASE 2 — CHUNK 6: Location filters, bar visualization, search & sort.
///
/// Deliberately a different structure from the old (pre-Phase-1,
/// discarded) screen: single-column stacked sections, plain
/// proportional bars instead of a charting package (none is in
/// pubspec.yaml, so none was added), and no sortable DataTable —
/// each section instead has its own search box and a sort-direction
/// toggle.
///
/// Director OR Admin only. There is no CEO Analytics access and no
/// separate CEO role. Blocked here at the screen layer regardless of
/// how the screen was reached. Note the `diagnoses` Firestore read
/// rule is a broader, app-wide grant (not Analytics-specific), so
/// this screen-level check is the Analytics-specific restriction.
/// Data flow: [AnalyticsPeriodCalculator] (Chunk 4) resolves the
/// selected period to a concrete range and its immediately-preceding
/// range → [DiagnosisAnalyticsService.loadRecords] (Chunk 1) loads
/// both, kept as raw records → [DiagnosisAnalyticsEngine.applyLocationFilter]
/// (Chunk 6) scopes them to the selected Country/State/LGA/PHC →
/// `.computeMedical`/`.computeGeographic` (Chunk 2) compute stats.
/// Location-filter changes recompute from the already-loaded raw
/// records in memory; only a period change re-reads Firestore.
/// Geographic breakdowns are current-period only — "previous"
/// geographic data isn't shown anywhere in this chunk.
class DiagnosisAnalyticsScreen extends StatefulWidget {
  const DiagnosisAnalyticsScreen({super.key});

  @override
  State<DiagnosisAnalyticsScreen> createState() => _DiagnosisAnalyticsScreenState();
}

class _DiagnosisAnalyticsScreenState extends State<DiagnosisAnalyticsScreen> {
  bool _isAuthorized = false;
  bool _isLoading = true;
  String? _errorMessage;

  MedicalAnalyticsResult? _medical;
  MedicalAnalyticsResult? _previousMedical;
  GeographicAnalyticsResult? _geographic;

  // Raw, unfiltered records for the current/previous period, kept so
  // location-filter changes can recompute in-memory (no new Firestore
  // read needed — only the date range requires a reload).
  List<AnalyticsDiagnosisRecord> _currentRecords = [];
  List<AnalyticsDiagnosisRecord> _previousRecords = [];
  
 LocationFilter _locationFilter = const LocationFilter();

  static const _listSectionKeys = ['illness', 'country', 'state', 'lga', 'phc'];
  final Map<String, TextEditingController> _searchControllers = {
    for (final key in _listSectionKeys) key: TextEditingController(),
  };
  final Map<String, bool> _sortAscending = {
    for (final key in _listSectionKeys) key: false,
  };

  AnalyticsPeriod _period = AnalyticsPeriod.thisMonth;
  DateTime? _customStart;
  DateTime? _customEnd;

  static const _periodLabels = <AnalyticsPeriod, String>{
    AnalyticsPeriod.today: 'Today',
    AnalyticsPeriod.thisWeek: 'This week',
    AnalyticsPeriod.thisMonth: 'This month',
    AnalyticsPeriod.lastMonth: 'Last month',
    AnalyticsPeriod.thisYear: 'This year',
    AnalyticsPeriod.lastYear: 'Last year',
  };

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    for (final controller in _searchControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

    Future<void> _init() async {
    // Fail closed: any error resolving the profile (network, permission,
    // missing document) means NOT authorized, never a hung spinner.
    var authorized = false;
    try {
      final user = await AuthService.instance.fetchCurrentUserProfile();
      authorized = user != null &&
          (user.role == UserRole.director || user.role == UserRole.admin);
    } catch (_) {
      authorized = false;
    }
    if (!mounted) return;
    setState(() => _isAuthorized = authorized);
    if (authorized) {
      await _load();
    } else {
      setState(() => _isLoading = false);
    }
  }

   Future<void> _load() async {
    if (!_isAuthorized) return; // defense in depth: never load data unauthorized
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final range = AnalyticsPeriodCalculator.current(
        _period,
        customStart: _customStart,
        customEnd: _customEnd,
      );
      final previousRange = AnalyticsPeriodCalculator.previous(_period, range);

      final results = await Future.wait([
        DiagnosisAnalyticsService.instance.loadRecords(
          start: range.start,
          end: range.end,
        ),
        DiagnosisAnalyticsService.instance.loadRecords(
          start: previousRange.start,
          end: previousRange.end,
        ),
      ]);

      if (!mounted) return;
      setState(() {
        _currentRecords = results[0];
        _previousRecords = results[1];
        _locationFilter = const LocationFilter(); // new period → clear filter
      });
      _recompute();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not load analytics right now. Pull down to try again.';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

    /// Applies [_locationFilter] to the already-loaded raw records and
  /// recomputes every section — Medical (records, unique patients,
  /// illness breakdown), Geographic, and the illness chart — from
  /// that SAME filtered list, in memory, no Firestore read. No
  /// section is ever computed from the unfiltered [_currentRecords]
  /// directly; [filteredCurrent] is the single source every result
  /// below is derived from, so a filter change updates all of them
  /// together and none can drift out of sync with another.
  void _recompute() {
    final filteredCurrent =
        DiagnosisAnalyticsEngine.applyLocationFilter(_currentRecords, _locationFilter);
    final filteredPrevious =
        DiagnosisAnalyticsEngine.applyLocationFilter(_previousRecords, _locationFilter);
    final medical = DiagnosisAnalyticsEngine.computeMedical(filteredCurrent);
    final previousMedical = DiagnosisAnalyticsEngine.computeMedical(filteredPrevious);
    final geographic = DiagnosisAnalyticsEngine.computeGeographic(filteredCurrent);
    if (!mounted) return;
    setState(() {
      _medical = medical;
      _previousMedical = previousMedical;
      _geographic = geographic;
    });
  }

  /// Options for [level], scoped to whatever's already selected at
  /// the levels above it (cascading). Uses the unfiltered current-
  /// period records as the source so a level's options never depend
  /// on its own or a lower level's current selection.
  List<LocationOption> _optionsFor(LocationLevel level) {
    LocationFilter parentFilter;
    switch (level) {
      case LocationLevel.country:
        parentFilter = const LocationFilter();
        break;
      case LocationLevel.state:
        parentFilter = LocationFilter(countryKey: _locationFilter.countryKey);
        break;
      case LocationLevel.lga:
        parentFilter = LocationFilter(
          countryKey: _locationFilter.countryKey,
          stateKey: _locationFilter.stateKey,
        );
        break;
      case LocationLevel.primaryHealthcareCenter:
        parentFilter = LocationFilter(
          countryKey: _locationFilter.countryKey,
          stateKey: _locationFilter.stateKey,
          lgaKey: _locationFilter.lgaKey,
        );
        break;
    }
    final scoped = DiagnosisAnalyticsEngine.applyLocationFilter(_currentRecords, parentFilter);
    return DiagnosisAnalyticsEngine.optionsFor(scoped, level);
  }

  void _selectLocation(LocationLevel level, String? key) {
    setState(() {
      switch (level) {
        case LocationLevel.country:
          _locationFilter = LocationFilter(countryKey: key); // clears state/lga/phc
          break;
        case LocationLevel.state:
          _locationFilter = LocationFilter(countryKey: _locationFilter.countryKey, stateKey: key);
          break;
        case LocationLevel.lga:
          _locationFilter = LocationFilter(
            countryKey: _locationFilter.countryKey,
            stateKey: _locationFilter.stateKey,
            lgaKey: key,
          );
          break;
        case LocationLevel.primaryHealthcareCenter:
          _locationFilter = LocationFilter(
            countryKey: _locationFilter.countryKey,
            stateKey: _locationFilter.stateKey,
            lgaKey: _locationFilter.lgaKey,
            phcKey: key,
          );
          break;
      }
    });
    _recompute();
  }

  void _clearLocationFilter() {
    setState(() => _locationFilter = const LocationFilter());
    _recompute();
  }

  void _selectPeriod(AnalyticsPeriod period) {
    if (period == _period) return;
    setState(() => _period = period);
    _load();
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      initialDateRange: _customStart != null && _customEnd != null
          ? DateTimeRange(start: _customStart!, end: _customEnd!)
          : DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now),
    );
       if (picked == null) return;
    setState(() {
      _customStart = picked.start;
      // showDateRangePicker returns date-only values (midnight for both
      // ends). Without extending the end to the last moment of that
      // day, any diagnosis recorded after midnight on the selected end
      // day is silently excluded from the query — including the common
      // case of picking the same day as both start and end, which
      // would otherwise return zero records even when diagnoses exist
      // that day.
      _customEnd = DateTime(
        picked.end.year,
        picked.end.month,
        picked.end.day,
        23,
        59,
        59,
        999,
      );
      _period = AnalyticsPeriod.custom;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Analytics'),
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _medical == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primaryOrange));
    }
    if (!_isAuthorized) {
      return _buildMessage(
        icon: Icons.lock_outline_rounded,
        title: 'Not available',
        subtitle: 'Analytics is only available to Director and Admin.',
      );
    }
    if (_errorMessage != null) {
      return _buildMessage(
        icon: Icons.error_outline_rounded,
        title: 'Something went wrong',
        subtitle: _errorMessage!,
        action: TextButton(onPressed: _load, child: const Text('Try again')),
      );
    }
    final medical = _medical;
    final geographic = _geographic;
    if (medical == null || geographic == null) {
      return const SizedBox.shrink();
    }
    if (medical.totalRecords == 0) {
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          _buildPeriodSelector(),
          const SizedBox(height: AppSpacing.md),
          _buildLocationFilters(),
          const SizedBox(height: AppSpacing.xl),
          _buildMessage(
            icon: Icons.inbox_outlined,
            title: 'No diagnosis records for this period',
            subtitle: 'Try a different period or location filter, or check back once more diagnoses are recorded.',
          ),
        ],
      );
    }
    return RefreshIndicator(
      color: AppColors.primaryOrange,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          _buildPeriodSelector(),
          const SizedBox(height: AppSpacing.md),
          _buildLocationFilters(),
          const SizedBox(height: AppSpacing.md),
          _buildStatsRow(medical, _previousMedical),
          const SizedBox(height: AppSpacing.lg),
            if (medical.illnessBreakdown.isNotEmpty) ...[
            _buildIllnessChartSection(medical),
            const SizedBox(height: AppSpacing.lg),
          ],
          _buildListSection(
            sectionKey: 'illness',
            title: 'Illness breakdown',
            rows: medical.illnessBreakdown
                .map((i) => _Row(i.illnessName, i.records, i.uniquePatients, i.percentageOfRecords))
                .toList(),
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildListSection(
            sectionKey: 'country',
            title: 'Geographic — Country',
            rows: geographic.byCountry
                .map((r) => _Row(r.label, r.records, r.uniquePatients, r.percentageOfRecords))
                .toList(),
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildListSection(
            sectionKey: 'state',
            title: 'Geographic — State',
            rows: geographic.byState
                .map((r) => _Row(r.label, r.records, r.uniquePatients, r.percentageOfRecords))
                .toList(),
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildListSection(
            sectionKey: 'lga',
            title: 'Geographic — LGA',
            rows: geographic.byLga
                .map((r) => _Row(r.label, r.records, r.uniquePatients, r.percentageOfRecords))
                .toList(),
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildListSection(
            sectionKey: 'phc',
            title: 'Geographic — Primary Health Care',
            rows: geographic.byPrimaryHealthcareCenter
                .map((r) => _Row(r.label, r.records, r.uniquePatients, r.percentageOfRecords))
                .toList(),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Widget _buildMessage({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? action,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: AppColors.textSecondary),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              style: const TextStyle(
                fontSize: AppTextSize.body,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: AppTextSize.caption,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              const SizedBox(height: AppSpacing.sm),
              action,
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final entry in _periodLabels.entries) ...[
            _buildPeriodChip(entry.value, selected: _period == entry.key, onTap: () => _selectPeriod(entry.key)),
            const SizedBox(width: AppSpacing.xs),
          ],
          _buildPeriodChip(
            _period == AnalyticsPeriod.custom && _customStart != null && _customEnd != null
                ? '${_formatDate(_customStart!)} – ${_formatDate(_customEnd!)}'
                : 'Custom…',
            selected: _period == AnalyticsPeriod.custom,
            onTap: _pickCustomRange,
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodChip(String label, {required bool selected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryOrange : AppColors.surfaceWarm,
          borderRadius: BorderRadius.circular(AppRadius.button),
          border: Border.all(color: selected ? AppColors.primaryOrange : AppColors.divider),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: AppTextSize.caption,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Widget _buildLocationFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _buildSectionHeader('Location filter')),
            if (!_locationFilter.isEmpty)
              TextButton(
                onPressed: _clearLocationFilter,
                child: const Text('Clear'),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            _buildLocationDropdown(
              level: LocationLevel.country,
              hint: 'Country',
              selectedKey: _locationFilter.countryKey,
            ),
            _buildLocationDropdown(
              level: LocationLevel.state,
              hint: 'State',
              selectedKey: _locationFilter.stateKey,
            ),
            _buildLocationDropdown(
              level: LocationLevel.lga,
              hint: 'LGA',
              selectedKey: _locationFilter.lgaKey,
            ),
            _buildLocationDropdown(
              level: LocationLevel.primaryHealthcareCenter,
              hint: 'Primary Health Care',
              selectedKey: _locationFilter.phcKey,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLocationDropdown({
    required LocationLevel level,
    required String hint,
    required String? selectedKey,
  }) {
    final options = _optionsFor(level);
    // Guard against a stale selection no longer present once a
    // parent level changes (e.g. State was cleared when Country
    // changed) — falls back to "All" rather than crashing the
    // dropdown on a missing value.
    final validKey =
        options.any((o) => o.key == selectedKey) ? selectedKey : null;
    return Container(
      constraints: const BoxConstraints(minWidth: 140),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          isDense: true,
          value: validKey,
          hint: Text(hint, style: const TextStyle(fontSize: AppTextSize.caption)),
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text('All $hint', style: const TextStyle(fontSize: AppTextSize.caption)),
            ),
            for (final option in options)
              DropdownMenuItem<String?>(
                value: option.key,
                child: Text(option.label, style: const TextStyle(fontSize: AppTextSize.caption)),
              ),
          ],
          onChanged: (key) => _selectLocation(level, key),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: AppTextSize.screenSubtitle,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildStatsRow(MedicalAnalyticsResult medical, MedicalAnalyticsResult? previous) {
    final stats = <_Stat>[
      _Stat(
        'Diagnosis records',
        '${medical.totalRecords}',
        _delta(medical.totalRecords, previous?.totalRecords),
      ),
      _Stat(
        'Unique patients',
        '${medical.totalUniquePatients}',
        _delta(medical.totalUniquePatients, previous?.totalUniquePatients),
      ),
      _Stat(
        'Distinct illnesses',
        '${medical.illnessBreakdown.length}',
        _delta(medical.illnessBreakdown.length, previous?.illnessBreakdown.length),
      ),
    ];
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: stats.map((s) => _buildStatTile(s)).toList(),
    );
  }

  /// null when there's no previous-period value to compare against
  /// (e.g. previous period had 0 and current also has 0 — no
  /// meaningful ratio) so the tile just omits the delta rather than
  /// showing a fabricated "0%" or "+∞%".
  double? _delta(int current, int? previous) {
    if (previous == null || previous == 0) return null;
    return ((current - previous) / previous) * 100;
  }

  Widget _buildStatTile(_Stat stat) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceWarm,
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            stat.value,
            style: const TextStyle(
              fontSize: AppTextSize.screenTitle,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryOrangeDark,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            stat.label,
            style: const TextStyle(
              fontSize: AppTextSize.caption,
              color: AppColors.textSecondary,
            ),
          ),
          if (stat.delta != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${stat.delta! >= 0 ? '+' : ''}${stat.delta!.toStringAsFixed(0)}% vs previous period',
              style: TextStyle(
                fontSize: AppTextSize.caption,
                fontWeight: FontWeight.w600,
                color: stat.delta! >= 0 ? AppColors.success : AppColors.error,
              ),
            ),
          ],
        ],
      ),
    );
  }

   Widget _buildIllnessChartSection(MedicalAnalyticsResult medical) {
    final count = medical.illnessBreakdown.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Illness Distribution'),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '$count ${count == 1 ? 'illness' : 'illnesses'} · reflects the selected period and location filter',
          style: const TextStyle(fontSize: AppTextSize.caption, color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(AppRadius.input),
            border: Border.all(color: AppColors.divider),
          ),
          child: _IllnessChart(illnessBreakdown: medical.illnessBreakdown),
        ),
      ],
    );
  }

  Widget _buildListSection({
    required String sectionKey,
    required String title,
    required List<_Row> rows,
  }) {
    final controller = _searchControllers[sectionKey]!;
    final ascending = _sortAscending[sectionKey] ?? false;
    final query = controller.text.trim().toLowerCase();

    final filtered = query.isEmpty
        ? List<_Row>.from(rows)
        : rows.where((r) => r.label.toLowerCase().contains(query)).toList();
    filtered.sort(
      (a, b) => ascending ? a.records.compareTo(b.records) : b.records.compareTo(a.records),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _buildSectionHeader(title)),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: ascending ? 'Sorted lowest first' : 'Sorted highest first',
              icon: Icon(
                ascending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                size: 18,
                color: AppColors.textSecondary,
              ),
              onPressed: () => setState(() => _sortAscending[sectionKey] = !ascending),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        TextField(
          controller: controller,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(fontSize: AppTextSize.caption),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Search $title'.replaceFirst('Geographic — ', ''),
            hintStyle: const TextStyle(fontSize: AppTextSize.caption, color: AppColors.textSecondary),
            prefixIcon: const Icon(Icons.search_rounded, size: 18),
            filled: true,
            fillColor: AppColors.inputFill,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.input),
              borderSide: BorderSide(color: AppColors.inputBorder),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _buildCard(
          children: filtered.isEmpty
              ? [_buildRow(title: 'No matches', trailing: '', fraction: 0)]
              : filtered
                  .map((r) => _buildRow(
                        title: r.label,
                        trailing: '${r.records} · ${r.uniquePatients} pt · ${r.percentage.toStringAsFixed(1)}%',
                        fraction: r.percentage / 100,
                      ))
                  .toList(),
        ),
      ],
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildRow({required String title, required String trailing, double fraction = 0}) {
    final clampedFraction = fraction.clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: AppTextSize.body,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                trailing,
                style: const TextStyle(
                  fontSize: AppTextSize.caption,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          if (clampedFraction > 0) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: Container(
                height: 4,
                color: AppColors.divider,
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: clampedFraction,
                  heightFactor: 1,
                  child: Container(color: AppColors.primaryOrange),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Row {
  final String label;
  final int records;
  final int uniquePatients;
  final double percentage;
  const _Row(this.label, this.records, this.uniquePatients, this.percentage);
}

class _Stat {
  final String label;
  final String value;
  final double? delta;
  const _Stat(this.label, this.value, [this.delta]);
}

/// Categorical bar chart — no charting package (none is in
/// pubspec.yaml). One bar per illness from the already-filtered
/// [MedicalAnalyticsResult.illnessBreakdown] (see [_recompute] —
/// same filtered dataset that drives every other section), height
/// scaled to the largest illness's record count. Horizontally
/// scrollable so it stays legible however many distinct illnesses
/// (including free-text "Other" entries) the current period/location
/// selection produces.
class _IllnessChart extends StatelessWidget {
  final List<IllnessBreakdown> illnessBreakdown;
  const _IllnessChart({required this.illnessBreakdown});

  @override
  Widget build(BuildContext context) {
    final illnesses = illnessBreakdown;
    final maxRecords = illnesses.fold<int>(0, (max, i) => i.records > max ? i.records : max);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        height: 150,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final illness in illnesses)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: SizedBox(
                  width: 76,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '${illness.records}',
                        style: const TextStyle(fontSize: 9, color: AppColors.textSecondary),
                      ),
                      Center(
                        child: Container(
                          height: maxRecords == 0
                              ? 2
                              : (illness.records / maxRecords) * 72 + 2,
                          width: 32,
                          decoration: BoxDecoration(
                            color: AppColors.primaryOrange,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        illness.illnessName,
                        style: const TextStyle(fontSize: 9, color: AppColors.textSecondary),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}