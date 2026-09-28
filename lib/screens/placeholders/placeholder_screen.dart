import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const _PlaceholderScaffold(title: 'About Amaudo');
}

class _PlaceholderScaffold extends StatelessWidget {
  final String title;
  const _PlaceholderScaffold({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: AppColors.primaryOrange,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Text('$title screen — coming soon',
            style: const TextStyle(color: AppColors.textSecondary)),
      ),
    );
  }
}