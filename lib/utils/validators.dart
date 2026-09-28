/// Pure, reusable field validators and normalizers. No UI or Firebase
/// logic here. Normalizers are shared by registration and login so
/// the exact same canonical form is always used for index lookups.
class Validators {
  Validators._();

  static final RegExp _emailRegex =
      RegExp(r'^[\w\.\-]+@([\w\-]+\.)+[\w\-]{2,}$');

  // E.164: leading +, 7–15 digits, first digit 1–9.
  static final RegExp _e164Regex = RegExp(r'^\+[1-9]\d{6,14}$');

  /// Normalizes a phone number to E.164 form so registration and
  /// login always resolve to the same phoneIndex key.
  static String normalizePhone(String value) {
    var v = value.trim();
    v = v.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (v.isEmpty) return v;

    if (v.startsWith('+')) {
      return v;
    }

    if (v.startsWith('00')) {
      return '+${v.substring(2)}';
    }

    if (v.length == 11 &&
        v.startsWith('0') &&
        RegExp(r'^\d{11}$').hasMatch(v)) {
      return '+234${v.substring(1)}';
    }

    return v;
  }

  static String normalizeEmail(String value) {
    return value.trim().toLowerCase();
  }

  static String? fullName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Full name is required';
    if (v.length < 2) return 'Enter your full name';
    if (!v.contains(' ')) return 'Enter your first and last name';
    return null;
  }

  /// Required phone number, used at registration. Accepts either
  /// full E.164 (+2348012345678) or Nigerian local format
  /// (08012345678) — both normalize to the same stored value.
  static String? phone(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return 'Phone number is required';

    final normalized = normalizePhone(raw);
    if (!_e164Regex.hasMatch(normalized)) {
      return 'Enter a valid phone number, e.g. 08012345678 or '
          '+2348012345678';
    }
    return null;
  }

  /// Optional email, used at registration. Empty is valid.
  static String? emailOptional(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    if (!_emailRegex.hasMatch(v)) return 'Enter a valid email address';
    return null;
  }

  /// Login identifier — accepts either a phone number (E.164 or
  /// Nigerian local format) or an email, and validates according to
  /// which one it looks like.
  static String? loginIdentifier(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter your phone number or email';
    if (v.contains('@')) {
      if (!_emailRegex.hasMatch(v)) return 'Enter a valid email address';
    } else {
      final normalized = normalizePhone(v);
      if (!_e164Regex.hasMatch(normalized)) {
        return 'Enter a valid phone number, e.g. 08012345678 or '
            '+2348012345678';
      }
    }
    return null;
  }

  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Password is required';
    if (v.length < 8) return 'Password must be at least 8 characters';
    if (!RegExp(r'[A-Za-z]').hasMatch(v)) {
      return 'Password must include a letter';
    }
    if (!RegExp(r'\d').hasMatch(v)) {
      return 'Password must include a number';
    }
    return null;
  }

  static String? confirmPassword(String? value, String original) {
    final v = value ?? '';
    if (v.isEmpty) return 'Confirm your password';
    if (v != original) return 'Passwords do not match';
    return null;
  }

  static String? customRole(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Please specify your role';
    if (v.length < 2) return 'Enter a valid role';
    return null;
  }

  /// Generic required-field validator for location/workplace fields,
  /// parameterized by a human-readable field name for the message.
  static String? requiredField(String? value, String fieldLabel) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return '$fieldLabel is required';
    return null;
  }
}