import 'package:shared_preferences/shared_preferences.dart';

class SessionData {
  final int userId;
  final String email;
  final String? token;

  SessionData({required this.userId, required this.email, this.token});
}

class SessionService {
  static const _keyUserId = 'session_user_id';
  static const _keyEmail = 'session_email';
  static const _keyToken = 'session_token';

  // Saves authenticated session data for startup auto-restore.
  static Future<void> saveSession({
    required int userId,
    required String email,
    String? token,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyUserId, userId);
    await prefs.setString(_keyEmail, email);
    if (token != null && token.trim().isNotEmpty) {
      await prefs.setString(_keyToken, token);
    } else {
      await prefs.remove(_keyToken);
    }
  }

  // Clears all persisted session keys used by this app.
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyEmail);
    await prefs.remove(_keyToken);
  }

  // Restores session safely; corrupted or incomplete data is auto-cleared.
  static Future<SessionData?> getSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt(_keyUserId);
      final email = prefs.getString(_keyEmail);
      final token = prefs.getString(_keyToken);

      if (userId == null || email == null || email.trim().isEmpty) {
        await clearSession();
        return null;
      }

      final session = SessionData(
        userId: userId,
        email: email.trim(),
        token: token,
      );

      if (!isValidSession(session)) {
        await clearSession();
        return null;
      }

      return session;
    } catch (_) {
      await clearSession();
      return null;
    }
  }

  // Future-ready validity check; can later include token expiry validation.
  static bool isValidSession(SessionData session) {
    if (session.userId <= 0) return false;
    if (session.email.trim().isEmpty) return false;
    if (!session.email.contains('@')) return false;
    return true;
  }
}