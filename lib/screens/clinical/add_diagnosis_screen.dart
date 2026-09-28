import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../models/diagnosis_model.dart';
import '../../services/auth_exception.dart';
import '../../services/auth_service.dart';
import '../../services/diagnosis_service.dart';
import '../../models/user_model.dart';

class AddDiagnosisScreen extends StatefulWidget {
  final String patientUid;
  final String encounterId;

  const AddDiagnosisScreen({
    super.key,
    required this.patientUid,
    required this.encounterId,
  });

  @override
  State<AddDiagnosisScreen> createState() => _AddDiagnosisScreenState();
}

class _AddDiagnosisScreenState extends State<AddDiagnosisScreen> {
  final _otherController = TextEditingController();
  final _descriptionController = TextEditingController();
  DiagnosisCategory? _selectedCategory;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _otherController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_isSubmitting) return;
    if (_selectedCategory == null) {
      setState(() => _errorMessage = 'Please select a diagnosis.');
      return;
    }
    if (_selectedCategory == DiagnosisCategory.other &&
        _otherController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please describe the illness.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final currentUser = await AuthService.instance.fetchCurrentUserProfile();
      if (currentUser == null) {
        throw const AuthException('You must be signed in to do this.');
      }

      await DiagnosisService.instance.createDiagnosis(
        patientUid: widget.patientUid,
        encounterId: widget.encounterId,
        diagnosedByUid: currentUser.uid,
        diagnosedByRole: currentUser.role.storageValue,
        category: _selectedCategory!,
        otherIllnessText: _selectedCategory == DiagnosisCategory.other
            ? _otherController.text.trim()
            : null,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
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

  static const List<DiagnosisCategory> _clinicalOptions = [
    DiagnosisCategory.anxietyDisorders,
    DiagnosisCategory.depressiveDisorders,
    DiagnosisCategory.adhd,
    DiagnosisCategory.ptsd,
    DiagnosisCategory.schizophrenia,
    DiagnosisCategory.bipolarDisorders,
    DiagnosisCategory.bpd,
    DiagnosisCategory.epilepsy,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Add Diagnosis'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
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
              const Text('Diagnosis', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpacing.xs),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.inputFill,
                  borderRadius: BorderRadius.circular(AppRadius.input),
                  border: Border.all(color: AppColors.inputBorder),
                ),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: DropdownButtonHideUnderline(
                  child: DropdownButtonFormField<DiagnosisCategory>(
                    initialValue: _selectedCategory,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: AppColors.textSecondary),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 14),
                    ),
                    hint: const Text('Select a diagnosis',
                        style: TextStyle(color: AppColors.placeholderText)),
                    items: [
                      ..._clinicalOptions.map((c) => DropdownMenuItem(
                            value: c,
                            child: Text(c.label),
                          )),
                      DropdownMenuItem(
                        value: DiagnosisCategory.other,
                        child: Text(DiagnosisCategory.other.label),
                      ),
                    ],
                    onChanged: (value) => setState(() => _selectedCategory = value),
                  ),
                ),
              ),
              if (_selectedCategory == DiagnosisCategory.other) ...[
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _otherController,
                  decoration: InputDecoration(
                    labelText: 'Describe the illness',
                    filled: true,
                    fillColor: AppColors.inputFill,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.input),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Description (optional)',
                  filled: true,
                  fillColor: AppColors.inputFill,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.input),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _isSubmitting ? null : _handleSave,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Save Diagnosis'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}