import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../widgets/amaudo_logo.dart';
import '../../widgets/action_buttons.dart';
import '../../widgets/feature_item.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

 @override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: AppColors.background,
    body: SafeArea(
      child: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(context),
            _buildHeroWithSheet(context),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Column(
        children: [
          const AmaudoLogo(size: 100),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'AMAUDO',
            style: TextStyle(
              fontSize: AppTextSize.wordmark,
              fontWeight: FontWeight.w900,
              color: AppColors.primaryOrange,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'Integrated Community Mental Health Foundation',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          RichText(
            textAlign: TextAlign.center,
            text: const TextSpan(
              style: TextStyle(
                fontSize: AppTextSize.intro,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
              children: [
                TextSpan(
                  text: 'Providing inclusive, compassionate and '
                      'professional mental healthcare for a ',
                ),
                TextSpan(
                  text: 'healthier community.',
                  style: TextStyle(
                    color: AppColors.primaryOrange,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Facility background image with the action sheet anchored to its
  /// bottom edge, matching the reference composition.
 Widget _buildHeroWithSheet(BuildContext context) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(
        width: double.infinity,
        height: MediaQuery.of(context).size.height * 0.32,
        child: ClipRRect(
          child: Image.asset(
            'assets/images/amaudo_facility.jpg',
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
            alignment: const Alignment(0, 0.15),
            filterQuality: FilterQuality.high,
            errorBuilder: (context, error, stackTrace) => Container(
              color: AppColors.surfaceWarm,
              alignment: Alignment.center,
              child: const Icon(
                Icons.image_not_supported_outlined,
                size: 48,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
      _buildActionSheet(context),
    ],
  );
}
  Widget _buildActionSheet(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 24,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PrimaryActionButton(
  title: 'Get Started',
  subtitle: 'Create an account and get started',
  onTap: () => Navigator.of(context).pushNamed('/register'),
),

const SizedBox(height: AppSpacing.md),

SecondaryActionButton(
            title: 'Sign In',
            subtitle: 'Access your existing account',
            onTap: () => Navigator.of(context).pushNamed('/login'),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Row(
            children: [
              Expanded(
                child: FeatureItem(
                  icon: Icons.shield_outlined,
                  title: 'Secure & Private',
                  subtitle: 'Your data is protected\nwith highest security',
                ),
              ),
              _VerticalDivider(),
              Expanded(
                child: FeatureItem(
                  icon: Icons.groups_outlined,
                  title: 'Trusted by Professionals',
                  subtitle: 'Used by doctors, nurses\nand healthcare staff',
                ),
              ),
              _VerticalDivider(),
              Expanded(
                child: FeatureItem(
                  icon: Icons.apartment_outlined,
                  title: 'Across Many Facilities',
                  subtitle: 'Connected primary\nhealthcare network',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          GestureDetector(
            onTap: () => Navigator.of(context).pushNamed('/about'),
            child: RichText(
              text: const TextSpan(
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                children: [
                  TextSpan(text: 'New to Amaudo?  '),
                  TextSpan(
                    text: 'Learn More',
                    style: TextStyle(
                      color: AppColors.primaryOrange,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  const _VerticalDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 46,
      color: AppColors.divider,
    );
  }
}