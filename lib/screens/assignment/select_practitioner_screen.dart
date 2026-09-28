import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../models/user_model.dart';
import '../../services/practitioner_directory_service.dart';

class SelectPractitionerScreen extends StatefulWidget {
  const SelectPractitionerScreen({super.key});

  @override
  State<SelectPractitionerScreen> createState() =>
      _SelectPractitionerScreenState();
}

class _SelectPractitionerScreenState extends State<SelectPractitionerScreen> {
  List<UserModel> _practitioners = [];
  bool _isLoading = true;
  String? _errorMessage;
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
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final items = await PractitionerDirectoryService.instance.fetchPractitioners();
      if (!mounted) return;
      setState(() => _practitioners = items);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<UserModel> get _filtered {
    if (_query.trim().isEmpty) return _practitioners;
    final q = _query.trim().toLowerCase();
    return _practitioners.where((p) {
      final fields = [
        p.fullName,
        p.displayRole,
        p.workplace ?? '',
        p.workLocation ?? '',
        p.state ?? '',
        p.localGovernmentArea ?? '',
        p.country ?? '',
        p.phone ?? '',
      ].map((s) => s.toLowerCase());
      return fields.any((f) => f.contains(q));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Select Practitioner'),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primaryOrange),
              )
            : _errorMessage != null
                ? Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Text(_errorMessage!,
                        style: const TextStyle(color: AppColors.error)),
                  )
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (v) => setState(() => _query = v),
                          decoration: InputDecoration(
                            hintText: 'Search by name, role, facility, or location',
                            prefixIcon: const Icon(Icons.search_rounded),
                            filled: true,
                            fillColor: AppColors.inputFill,
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.input),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: _filtered.isEmpty
                            ? const Center(
                                child: Text(
                                  'No matching doctors or nurses found.',
                                  style: TextStyle(color: AppColors.textSecondary),
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                  AppSpacing.lg,
                                  0,
                                  AppSpacing.lg,
                                  AppSpacing.lg,
                                ),
                                itemCount: _filtered.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: AppSpacing.sm),
                                itemBuilder: (context, index) {
                                  final p = _filtered[index];
                                                                  final isUnconfiguredChp =
                                      p.role == UserRole.chp &&
                                      (p.chpClinicalRole != 'doctor' && p.chpClinicalRole != 'nurse');
                                  return Material(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(AppRadius.button),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(AppRadius.button),
                                      onTap: isUnconfiguredChp
                                          ? null
                                          : () => Navigator.of(context).pop(p),
                                      child: Container(
                                        padding: const EdgeInsets.all(AppSpacing.md),
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(AppRadius.button),
                                          border: Border.all(color: AppColors.divider),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(p.fullName,
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    color: AppColors.textPrimary)),
                                                                                      const SizedBox(height: 2),
                                            Text(p.displayRole,
                                                style: const TextStyle(
                                                    color: AppColors.textSecondary)),
                                            if (isUnconfiguredChp)
                                              const Padding(
                                                padding: EdgeInsets.only(top: 2),
                                                child: Text(
                                                  'No clinical role configured — cannot be assigned',
                                                  style: TextStyle(
                                                    color: AppColors.error,
                                                    fontSize: AppTextSize.caption,
                                                  ),
                                                ),
                                              ),
                                            if (p.workplace != null)
                                              Text('Facility: ${p.workplace}',
                                                  style: const TextStyle(
                                                      color: AppColors.textSecondary,
                                                      fontSize: AppTextSize.caption + 1)),
                                            if (p.state != null)
                                              Text(
                                                [p.localGovernmentArea, p.state, p.country]
                                                    .whereType<String>()
                                                    .join(', '),
                                                style: const TextStyle(
                                                    color: AppColors.textSecondary,
                                                    fontSize: AppTextSize.caption + 1),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
      ),
    );
  }
}