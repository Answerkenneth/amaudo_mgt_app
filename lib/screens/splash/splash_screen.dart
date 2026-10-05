import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../widgets/amaudo_logo.dart';

/// Startup sequence: full-screen background image with the Amaudo logo and
/// foundation name at the top center, and the headline + description at the
/// bottom. The logo fades/scales in, the text follows, a brief pause, then a
/// smooth fade into the existing AuthGate flow (which itself decides
/// Landing vs. authenticated Home - unchanged by this screen).
///
/// Portrait screens (phones) use the portrait artwork; landscape screens
/// (Chrome/desktop/tablets held sideways) use the landscape artwork.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const String _portraitAsset =
      'assets/images/Gemini_Generated_Image_11udii11udii11ud.jpg';
  static const String _landscapeAsset =
      'assets/images/Gemini_Generated_Image_gfk8olgfk8olgfk8.jpg';

  // Artwork pixel sizes, used to keep the brain in view when cropping.
  static const Size _portraitSize = Size(720, 1440);
  static const Size _landscapeSize = Size(1376, 768);

  late final AnimationController _controller;

  late final Animation<double> _logoOpacity;
  late final Animation<double> _logoScale;
  late final Animation<double> _nameOpacity;
  late final Animation<double> _exitOpacity;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    );

    // Logo: fade + gentle scale-in over the first fifth.
    _logoOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.21, curve: Curves.easeOut),
    );
    _logoScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.21, curve: Curves.easeOutBack),
      ),
    );

    // Foundation name, headline and description: fade in just after the
    // logo settles.
    _nameOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.19, 0.36, curve: Curves.easeOut),
    );

    // Whole screen fades out at the very end, into AuthGate.
    _exitOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.89, 1.0, curve: Curves.easeIn),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        Navigator.of(context).pushReplacementNamed('/');
      }
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Vertical alignment for a `BoxFit.cover` image so the glowing brain
  /// stays in view whatever the screen shape.
  /// [brainCenter] = brain's vertical centre as a fraction of the image
  /// height; [brainTarget] = where on screen (fraction) it should land.
  double _alignY({
    required Size screen,
    required Size image,
    required double brainCenter,
    required double brainTarget,
  }) {
    final double scale =
        math.max(screen.width / image.width, screen.height / image.height);
    final double scaledH = image.height * scale;
    final double overflow = scaledH - screen.height;
    if (overflow <= 1) return 0; // image already fits the height exactly
    final double offset =
        brainCenter * scaledH - brainTarget * screen.height;
    return (2 * offset / overflow - 1).clamp(-1.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double sw = constraints.maxWidth;
          final double sh = constraints.maxHeight;
          final bool wide = sw > sh;
          final Size screen = Size(sw, sh);

          final double alignY = wide
              ? _alignY(
                  screen: screen,
                  image: _landscapeSize,
                  brainCenter: 0.40,
                  brainTarget: 0.55,
                )
              : _alignY(
                  screen: screen,
                  image: _portraitSize,
                  brainCenter: 0.45,
                  brainTarget: 0.46,
                );

          // Static layers: built once, not rebuilt on every animation tick.
          final Widget backdrop = Stack(
            fit: StackFit.expand,
            children: [
              // Full-screen background, cropped to fill on any device.
              Image.asset(
                wide ? _landscapeAsset : _portraitAsset,
                fit: BoxFit.cover,
                alignment: Alignment(0, alignY),
                filterQuality: FilterQuality.high,
                errorBuilder: (context, error, stackTrace) =>
                    const ColoredBox(color: AppColors.surfaceWarm),
              ),
              // Soft fade at the top so the (unaltered) logo reads cleanly,
              // and a dark fade at the bottom for the white text.
              IgnorePointer(child: _Scrims(wide: wide)),
            ],
          );

          return AnimatedBuilder(
            animation: _controller,
            child: backdrop,
            builder: (context, backdropChild) {
              return Opacity(
                opacity: 1.0 - _exitOpacity.value,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    backdropChild!,
                    SafeArea(
                      child: LayoutBuilder(
                        builder: (context, box) {
                          final double w = box.maxWidth;
                          final double logoSize =
                              (w * 0.5).clamp(140.0, 220.0);
                          final double headlineSize =
                              (w * 0.08).clamp(24.0, 44.0);
                          final double minHeight =
                              box.maxHeight < 460 ? 460 : box.maxHeight;

                          return SingleChildScrollView(
                            physics: const NeverScrollableScrollPhysics(),
                            child: SizedBox(
                              height: minHeight,
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(
                                  wide ? AppSpacing.xxl : AppSpacing.lg,
                                  AppSpacing.md,
                                  wide ? AppSpacing.xxl : AppSpacing.lg,
                                  AppSpacing.xl,
                                ),
                                child: Column(
                                  children: [
                                    // Logo + foundation name: top center.
                                    Opacity(
                                      opacity: _logoOpacity.value,
                                      child: Transform.scale(
                                        scale: _logoScale.value,
                                        child: AmaudoLogo(size: logoSize),
                                      ),
                                    ),
                                    Opacity(
                                      opacity: _nameOpacity.value,
                                      child: const Text(
                                        'Amaudo Integrated Community\n'
                                        'Mental Health Foundation',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: AppTextSize.caption,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    // Headline + description: bottom left.
                                    Opacity(
                                      opacity: _nameOpacity.value,
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxWidth: 560,
                                          ),
                                          child: _BottomText(
                                            headlineSize: headlineSize,
                                          ),
                                        ),
                                      ),
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
              );
            },
          );
        },
      ),
    );
  }
}

class _Scrims extends StatelessWidget {
  const _Scrims({required this.wide});

  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.background.withValues(alpha: 0.95),
                AppColors.background.withValues(alpha: 0.80),
                AppColors.background.withValues(alpha: 0.0),
              ],
              // Shorter on landscape so the brain isn't washed out.
              stops: wide ? const [0.0, 0.14, 0.28] : const [0.0, 0.22, 0.4],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.0),
                Colors.black.withValues(alpha: 0.78),
              ],
              stops: wide ? const [0.55, 1.0] : const [0.6, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}

class _BottomText extends StatelessWidget {
  const _BottomText({required this.headlineSize});

  final double headlineSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Better Minds.\nHealthier Communities.',
          style: TextStyle(
            fontSize: headlineSize,
            fontWeight: FontWeight.w800,
            height: 1.15,
            color: AppColors.background,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        const Text.rich(
          TextSpan(
            style: TextStyle(
              fontSize: AppTextSize.screenSubtitle,
              color: AppColors.background,
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
    );
  }
}