import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../services/auth_service.dart';
import 'landing/landing_screen.dart';
import 'shell/app_shell.dart';

/// Root widget that decides which screen to show based on Firebase
/// auth state. Reacts to authStateChanges — screens push here via
/// pushNamedAndRemoveUntil('/', ...) after successful auth or sign out.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.instance.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: CircularProgressIndicator(
                color: AppColors.primaryOrange,
              ),
            ),
          );
        }

        final user = snapshot.data;
        if (user != null) {
          return const AppShell();
        }
        return const LandingScreen();
      },
    );
  }
}