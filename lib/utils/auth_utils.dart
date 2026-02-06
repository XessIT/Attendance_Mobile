import 'package:shared_preferences/shared_preferences.dart';

class AuthUtils {
  static const String _tokenKey = 'auth_token';
  static const String _userRoleKey = 'user_role';

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

  /// Get user role
  static Future<String?> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userRoleKey);
  }

  /// Set user role
  static Future<bool> setUserRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    return await prefs.setString(_userRoleKey, role);
  }

  /// Clear authentication token and user role (logout)
  static Future<bool> clearAuthData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userRoleKey);
    return true;
  }

  /// Logout user - clear token and perform any additional cleanup
  static Future<void> logout() async {
    await clearAuthData();
    // Add any additional logout logic here (clear cache, reset providers, etc.)
  }
}
