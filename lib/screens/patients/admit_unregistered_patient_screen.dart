import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../models/patient_record_model.dart';
import '../../services/auth_exception.dart';
import '../../services/auth_service.dart';
import '../../services/patient_service.dart';

/// Admits a patient who has NO app account. Creates a standalone
/// patients/{autoId} document only — no Firebase Auth account, no
/// synthetic email/phone, no users/{uid} document.
class AdmitUnregisteredPatientScreen extends StatefulWidget {
  const AdmitUnregisteredPatientScreen({super.key});

  @override
  State<AdmitUnregisteredPatientScreen> createState() =>
      _AdmitUnregisteredPatientScreenState();
}

class _AdmitUnregisteredPatientScreenState
    extends State<AdmitUnregisteredPatientScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _facilityController = TextEditingController();
  final _noteController = TextEditingController();
  AdmissionType _admissionType = AdmissionType.normal;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _facilityController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_isSubmitting) return;
    if (_nameController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please enter the patient\'s full name.');
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
      await PatientService.instance.admitPatientWithoutAccount(
        fullName: _nameController.text.trim(),
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        admittedByUid: currentUser.uid,
        admissionType: _admissionType,
        amaudoFacility: _facilityController.text.trim().isEmpty ? null : _facilityController.text.trim(),
        note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Admit Patient Without Account'),
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
                  child: Text(_errorMessage!, style: const TextStyle(color: AppColors.error)),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  filled: true, fillColor: AppColors.inputFill,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.input), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: 'Phone (optional)',
                  filled: true, fillColor: AppColors.inputFill,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.input), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const Text('Admission Type', style: TextStyle(fontWeight: FontWeight.w700)),
              Row(children: [
                Expanded(child: RadioListTile<AdmissionType>(
                  value: AdmissionType.shortStay, groupValue: _admissionType,
                  onChanged: (v) => setState(() => _admissionType = v!),
                  title: const Text('Short Stay'), contentPadding: EdgeInsets.zero,
                )),
                Expanded(child: RadioListTile<AdmissionType>(
                  value: AdmissionType.normal, groupValue: _admissionType,
                  onChanged: (v) => setState(() => _admissionType = v!),
                  title: const Text('Normal'), contentPadding: EdgeInsets.zero,
                )),
              ]),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _facilityController,
                decoration: InputDecoration(
                  labelText: 'Amaudo Facility (optional)',
                  filled: true, fillColor: AppColors.inputFill,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.input), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _noteController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Admission Note (optional)',
                  filled: true, fillColor: AppColors.inputFill,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.input), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryOrange, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: _isSubmitting ? null : _handleSave,
                  child: _isSubmitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Admit Patient'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}