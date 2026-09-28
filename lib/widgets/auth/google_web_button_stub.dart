import 'package:flutter/material.dart';

/// Non-web platforms never call this in practice (login_screen.dart
/// only reaches for it behind a kIsWeb check) — it exists purely so
/// the conditional export in google_web_button.dart has a safe
/// default that compiles everywhere.
Widget buildGoogleRenderedButton() => const SizedBox.shrink();