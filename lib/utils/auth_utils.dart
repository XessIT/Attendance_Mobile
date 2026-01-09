import 'package:shared_preferences/shared_preferences.dart';

class AuthUtils {
  static const String _tokenKey = 'auth_token';

  /// Check if user is authenticated (token exists)
  static Future<bool> isAuthenticated() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    return token != null && token.isNotEmpty;
  }

  /// Get stored authentication token
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  /// Store authentication token
  static Future<bool> setToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    return await prefs.setString(_tokenKey, token);
  }

  /// Clear authentication token (logout)
  static Future<bool> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    return await prefs.remove(_tokenKey);
  }

  /// Logout user - clear token and perform any additional cleanup
  static Future<void> logout() async {
    await clearToken();
    // Add any additional logout logic here (clear cache, reset providers, etc.)
  }
}
