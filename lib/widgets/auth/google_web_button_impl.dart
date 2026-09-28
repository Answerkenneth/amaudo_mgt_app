import 'package:flutter/material.dart';
import 'package:google_sign_in_web/web_only.dart' as web_only;

/// Renders Google's own Identity Services sign-in button. This is
/// the officially supported way to let a user initiate sign-in on
/// web with google_sign_in v7+ — authenticate() is intentionally
/// unimplemented on web, so there is no imperative alternative.
Widget buildGoogleRenderedButton() => web_only.renderButton();