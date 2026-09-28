import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../models/patient_record_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/dashboard_stats_service.dart';
import '../../services/patient_service.dart';
import 'user_detail_screen.dart';
class DirectorDataScreen extends StatefulWidget {
  const DirectorDataScreen({super.key});

  @override
  State<DirectorDataScreen> createState() => _DirectorDataScreenState();
}

class _DirectorDataScreenState extends State<DirectorDataScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Amaudo Data'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppColors.primaryOrange,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primaryOrange,
          tabs: const [
            Tab(text: 'Total Users'),
            Tab(text: 'Patients'),
            Tab(text: 'Admissions'),
            Tab(text: 'Discharged'),
            Tab(text: 'Doctors'),
            Tab(text: 'Nurses'),
            Tab(text: 'Staff'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _UserListTab(title: 'Total Users'),
          _PatientListTab(title: 'Patients'),
          _PatientStatusListTab(
            title: 'Admissions',
            status: PatientStatus.admitted,
          ),
          _PatientStatusListTab(
            title: 'Discharged',
            status: PatientStatus.discharged,
          ),
          _UserListTab(title: 'Doctors', roles: ['doctor']),
          _UserListTab(title: 'Nurses', roles: ['nurse']),
          _UserListTab(title: 'Staff', roles: ['staff', 'other']),
        ],
      ),
    );
  }
}

class _UserListTab extends StatefulWidget {
  final String title;
  final List<String>? roles;

  const _UserListTab({required this.title, this.roles});

  @override
  State<_UserListTab> createState() => _UserListTabState();
}

class _UserListTabState extends State<_UserListTab> {
  List<UserModel> _items = [];
  int? _count;
  bool _loading = true;
  String? _error;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final count = widget.roles == null
          ? await DashboardStatsService.instance.countAllUsers()
          : (await Future.wait(
              widget.roles!.map(
                (role) => DashboardStatsService.instance
                    .countUsersByRoleValue(role),
              ),
            ))
              .fold<int>(0, (sum, value) => sum + value);

      final users = widget.roles == null
          ? await AuthService.instance.fetchAllUsersBounded()
          : <UserModel>[
              for (final role in widget.roles!)
                ...await AuthService.instance.fetchUsersByRole(role),
            ];

      if (!mounted) return;

      setState(() {
        _count = count;
        _items = users;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<UserModel> get _filtered {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _items;
    return _items.where((user) {
      return user.fullName.toLowerCase().contains(query) ||
          (user.phone ?? '').toLowerCase().contains(query) ||
          user.displayRole.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryOrange),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error!,
              style: const TextStyle(color: AppColors.error),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: _load,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text(
            '${widget.title}: ${_count ?? _items.length}',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              hintText: 'Search by name, phone or role',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: AppColors.inputFill,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.input),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (_filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Text(
                'No records found',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          else
                       ..._filtered.map(
              (user) => InkWell(
                borderRadius: BorderRadius.circular(AppRadius.button),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => UserDetailScreen(
                      uid: user.uid,
                      initialUser: user,
                    ),
                  ),
                ),
                child: Container(
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
                      user.fullName,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      user.displayRole,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (user.phone != null)
                      Text(
                        user.phone!,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: AppTextSize.caption + 1,
                        ),
                      ),
                  ],
                ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PatientListTab extends StatefulWidget {
  final String title;

  const _PatientListTab({required this.title});

  @override
  State<_PatientListTab> createState() => _PatientListTabState();
}

class _PatientListTabState extends State<_PatientListTab> {
  List<PatientListItem> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final page =
          await PatientService.instance.fetchAllPatients(limit: 200);

      if (!mounted) return;

      setState(() => _items = page.items);
    } catch (_) {
      if (!mounted) return;

      setState(
        () => _error = 'Something went wrong. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryOrange),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error!,
              style: const TextStyle(color: AppColors.error),
            ),
            TextButton(
              onPressed: _load,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return _PatientItemsView(
      title: widget.title,
      items: _items,
      onRefresh: _load,
    );
  }
}

class _PatientStatusListTab extends StatefulWidget {
  final String title;
  final PatientStatus status;

  const _PatientStatusListTab({
    required this.title,
    required this.status,
  });

  @override
  State<_PatientStatusListTab> createState() =>
      _PatientStatusListTabState();
}

class _PatientStatusListTabState extends State<_PatientStatusListTab> {
  List<PatientListItem> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final items = await PatientService.instance.fetchPatientsByStatus(
        status: widget.status,
      );

      if (!mounted) return;

      setState(() => _items = items);
    } catch (_) {
      if (!mounted) return;

      setState(
        () => _error = 'Something went wrong. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryOrange),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error!,
              style: const TextStyle(color: AppColors.error),
            ),
            TextButton(
              onPressed: _load,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return _PatientItemsView(
      title: widget.title,
      items: _items,
      onRefresh: _load,
    );
  }
}

class _PatientItemsView extends StatelessWidget {
  final String title;
  final List<PatientListItem> items;
  final Future<void> Function() onRefresh;

  const _PatientItemsView({
    required this.title,
    required this.items,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text(
            '$title: ${items.length}',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Text(
                'No records found',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          else
                      ...items.map(
              (item) => InkWell(
                borderRadius: BorderRadius.circular(AppRadius.button),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => UserDetailScreen(
                      uid: item.uid,
                      initialRecord: item.record,
                    ),
                  ),
                ),
                child: Container(
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
                      item.fullName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (item.phone != null)
                      Text(
                        item.phone!,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    if (item.record != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.record!.status.label,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (item.record!.admissionDate != null)
                        Text(
                          'Admission: ${item.record!.admissionDate!.toLocal()}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                                           if (item.record!.dischargeDate != null)
                        Text(
                          'Discharge: ${item.record!.dischargeDate!.toLocal()}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      if (item.record!.amaudoFacility != null)
                        Text(
                          'Facility: ${item.record!.amaudoFacility}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ],
                ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}