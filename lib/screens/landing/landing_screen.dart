import 'dart:ui' show ImageFilter;

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
      body: Stack(
        fit: StackFit.expand,
        children: [
          // GLASS: soft frosted background behind everything (new).
          const _GlassBackground(),
          SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildHeader(context),
                  _buildHeroWithSheet(context),
                ],
              ),
            ),
          ),
        ],
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
    final Size screen = MediaQuery.of(context).size;

    // Phones (<= 700 px wide): exactly as before, edge to edge.
    // Wide screens (Chrome/tablet): still full width, with just a small
    // gap on the left and right of the facility image and the buttons.
    final double side = screen.width > 700 ? 24 : 0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: side),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: screen.height * 0.32,
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
      ),
    );
  }

  Widget _buildActionSheet(BuildContext context) {
    const BorderRadius sheetRadius = BorderRadius.vertical(
      top: Radius.circular(AppRadius.sheet),
    );

    // GLASS: only the surface of the sheet changed (shadow + frosted,
    // translucent white). Padding and all children are exactly as before.
    return DecoratedBox(
      decoration: const BoxDecoration(
        borderRadius: sheetRadius,
        boxShadow: [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 24,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: sheetRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              borderRadius: sheetRadius,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.78),
                  Colors.white.withValues(alpha: 0.62),
                  AppColors.primaryOrange.withValues(alpha: 0.06),
                ],
                stops: const [0.0, 0.6, 1.0],
              ),
            ),
            // Glass edge highlight; painted on top without adding padding,
            // so nothing inside the sheet moves.
            foregroundDecoration: BoxDecoration(
              borderRadius: sheetRadius,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.85),
                width: 1.2,
              ),
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
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
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
          ),
        ),
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

/// GLASS: light, airy backdrop - white to warm white with two very soft
/// Amaudo-orange glows and a faint white highlight. Uses existing palette
/// colours only; ignores touches so it never blocks the UI.
class _GlassBackground extends StatelessWidget {
  const _GlassBackground();

  Widget _glow(Alignment center, double radius, Color color, double alpha) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: center,
          radius: radius,
          colors: [
            color.withValues(alpha: alpha),
            color.withValues(alpha: 0.0),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.background,
                  AppColors.surfaceWarm,
                  AppColors.background,
                ],
                stops: [0.0, 0.55, 1.0],
              ),
            ),
          ),
          _glow(const Alignment(0.9, -0.85), 0.9, AppColors.primaryOrange, 0.10),
          _glow(const Alignment(-0.95, 0.25), 0.8, AppColors.primaryOrange, 0.07),
          _glow(const Alignment(-0.6, -0.95), 0.7, Colors.white, 0.9),
        ],
      ),
    );
  }
}