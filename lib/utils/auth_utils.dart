import 'package:shared_preferences/shared_preferences.dart';

/// Authentication utility class for managing tokens and user type
class AuthUtils {
  static const String _tokenKey = 'auth_token';
  static const String _userTypeKey = 'user_type';

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

  /// Store user type
  static Future<bool> setUserType(String userType) async {
    final prefs = await SharedPreferences.getInstance();
    return await prefs.setString(_userTypeKey, userType);
  }

  /// Alternative method name for testing
  static Future<bool> storeUserType(String userType) async {
    final prefs = await SharedPreferences.getInstance();
    return await prefs.setString(_userTypeKey, userType);
  }

  /// Get stored user type
  static Future<String?> getUserType() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userTypeKey);
  }

  /// Clear authentication token (logout)
  static Future<bool> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userTypeKey); // Also clear user type
    return await prefs.remove(_tokenKey);
  }

  /// Logout user - clear token and perform any additional cleanup
  static Future<void> logout() async {
    await clearToken();
    // Add any additional logout logic here (clear cache, reset providers, etc.)
  }
}
