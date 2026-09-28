import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'core/constants/app_colors.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/auth_gate.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/admin_recovery_screen.dart';
import 'screens/about/about_amaudo_screen.dart';
import 'services/session_preferences.dart';
import 'services/navigation_service.dart';
import 'firebase_options.dart';

/// Required by FCM to handle a message while the app is backgrounded
/// or fully closed. A message that carries a `notification` payload
/// is shown in the system tray automatically without any code here;
/// this only needs to exist and be registered below.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform,
);

  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  if (!kIsWeb) {
    final rememberMe = await SessionPreferences.instance.getRememberMe();
    if (!rememberMe) {
      await FirebaseAuth.instance.signOut();
    }
  }

  runApp(const AmaudoApp());
}

class AmaudoApp extends StatelessWidget {
  const AmaudoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Amaudo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primaryOrange,
          primary: AppColors.primaryOrange,
        ),
        fontFamily: 'Roboto',
      ),
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/': (context) => const AuthGate(),
        '/register': (context) => const RegisterScreen(),
        '/login': (context) => const LoginScreen(),
        '/about': (context) => const AboutAmaudoScreen(),
        '/admin-recovery': (context) => const AdminRecoveryScreen(),
      },
    );
  }
}