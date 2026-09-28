import 'package:shared_preferences/shared_preferences.dart';
import 'local_notification_service.dart';

/// Manages the profile-completion reminder lifecycle without ever
/// creating duplicate schedules. A single SharedPreferences flag
/// tracks "reminder currently scheduled" per user, so app restarts
/// don't re-schedule on top of an existing one — reschedule is only
/// a cancel+reschedule of the SAME deterministic notification ID
/// either way, but the flag avoids redundant plugin calls.
class ProfileReminderService {
  ProfileReminderService._internal();
  static final ProfileReminderService instance =
      ProfileReminderService._internal();

  static const String _flagPrefix = 'amaudo_profile_reminder_active_';
  static const String _reminderKeyPrefix = 'profile_completion_';

  String _reminderKey(String uid) => '$_reminderKeyPrefix$uid';

  /// Call after login/registration and whenever profile completion
  /// state might have changed. Idempotent: scheduling when already
  /// scheduled just re-confirms the same daily time slot; never
  /// creates a second reminder.
  Future<void> syncForUser({
    required String uid,
    required bool profileCompleted,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final flagKey = '$_flagPrefix$uid';

    if (profileCompleted) {
      if (prefs.getBool(flagKey) == true) {
        await LocalNotificationService.instance.cancel(_reminderKey(uid));
        await prefs.setBool(flagKey, false);
      }
      return;
    }

    // Not completed — ensure exactly one daily reminder is scheduled.
    await LocalNotificationService.instance.scheduleDaily(
      key: _reminderKey(uid),
      title: 'Complete your Amaudo profile',
      body: 'Please complete your Amaudo profile to continue.',
      hour: 10,
      minute: 0,
    );
    await prefs.setBool(flagKey, true);
  }

  Future<void> cancelForUser(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await LocalNotificationService.instance.cancel(_reminderKey(uid));
    await prefs.setBool('$_flagPrefix$uid', false);
  }
}