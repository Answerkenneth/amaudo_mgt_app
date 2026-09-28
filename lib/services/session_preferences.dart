import 'package:shared_preferences/shared_preferences.dart';

class SessionPreferences {
  SessionPreferences._();

  static final SessionPreferences instance = SessionPreferences._();

  static const String _rememberMeKey = 'remember_me';

  Future<void> setRememberMe(bool rememberMe) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_rememberMeKey, rememberMe);
  }

  Future<bool> getRememberMe() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_rememberMeKey) ?? true;
  }
}