import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../widgets/amaudo_logo.dart';

/// Real About Amaudo screen, replacing the previous placeholder.
/// Content reflects Amaudo's publicly available organizational
/// information (founding, mission, programmes) rather than invented
/// facts, and reuses the existing Amaudo logo/design system.
class AboutAmaudoScreen extends StatelessWidget {
  const AboutAmaudoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: const Text(
          'About Amaudo',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Column(
                  children: [
                    const AmaudoLogo(size: 88),
                    const SizedBox(height: AppSpacing.sm),
                    const Text(
                      'AMAUDO',
                      style: TextStyle(
                        fontSize: AppTextSize.wordmark - 8,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primaryOrange,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Integrated Community Mental Health Foundation',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              _SectionHeading('Our Story'),
              const SizedBox(height: AppSpacing.sm),
              const _BodyText(
                'Amaudo was founded in 1989 by Rosalind Colwill in response '
                'to the growing number of people with severe mental illness '
                'left homeless on the streets of southeast Nigeria — often '
                'due to stigma, harmful cultural beliefs, and a lack of '
                'information and resources.\n\n'
                'What began as a single residential centre at Itumbauzo, in '
                'Bende Local Government Area of Abia State, has grown over '
                'more than three decades into a wider network of care '
                'across the region.',
              ),
              const SizedBox(height: AppSpacing.lg),
              _SectionHeading('Our Mission'),
              const SizedBox(height: AppSpacing.sm),
              const _BodyText(
                'Amaudo offers a safe haven for people with severe mental '
                'illness — a place to heal, be treated with dignity, and '
                'work toward a positive future. Rehabilitation combines '
                'counselling, medication, and skills training, with a goal '
                'of reintegration: helping residents build transferable '
                'skills and, where possible, reunite with their families '
                'and communities.\n\n'
                'Alongside residential care, Amaudo works to raise '
                'community awareness of mental health, reduce stigma and '
                'discrimination, and advocate for the basic rights of '
                'people living with mental illness.',
              ),
              const SizedBox(height: AppSpacing.lg),
              _SectionHeading('Community Mental Health Programme'),
              const SizedBox(height: AppSpacing.sm),
              const _BodyText(
                'Beyond the residential centre, Amaudo runs a Community '
                'Mental Health Programme built around a growing network of '
                'nurse-led clinics spanning multiple states in southeast '
                'Nigeria, delivered in partnership with state governments '
                'and local stakeholders. The programme brings affordable, '
                'accessible mental health care directly into communities, '
                'reaching thousands of people who would otherwise struggle '
                'to access treatment.\n\n'
                'Amaudo also provides clinical placements to student '
                'nurses from across the region each year, helping build '
                'the next generation of community mental health workers.',
              ),
              const SizedBox(height: AppSpacing.lg),
              _SectionHeading('Working Together'),
              const SizedBox(height: AppSpacing.sm),
              const _BodyText(
                'Amaudo UK, established in 2000, supports this work from '
                'abroad, alongside partnerships with the Abia State '
                'Government and other local and international '
                'stakeholders. In Nigeria, Amaudo is led by its Director, '
                'Rev. Kenneth Nwaubani.',
              ),
              const SizedBox(height: AppSpacing.xl),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.orangeTint,
                  borderRadius: BorderRadius.circular(AppRadius.button),
                ),
                child: const Text(
                  'This Amaudo app supports the Foundation\'s day-to-day '
                  'community mental health work — connecting patients, '
                  'nurses, doctors, and staff across Amaudo\'s care network.',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final String text;
  const _SectionHeading(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _BodyText extends StatelessWidget {
  final String text;
  const _BodyText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: AppTextSize.body,
        color: AppColors.textSecondary,
        height: 1.5,
      ),
    );
  }
}