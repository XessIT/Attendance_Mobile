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

  /// Alternative method name for testing/legacy
  static Future<bool> storeUserType(String userType) async {
    return await setUserType(userType);
  }

  /// Get stored user type
  static Future<String?> getUserType() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userTypeKey);
  }

  /// Alias for getUserType to support incoming changes
  static Future<String?> getUserRole() async {
    return await getUserType();
  }

  /// Alias for setUserType to support incoming changes
  static Future<bool> setUserRole(String role) async {
    return await setUserType(role);
  }

  /// Clear authentication token and user data (logout)
  static Future<bool> clearAuthData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userTypeKey);
    return await prefs.remove(_tokenKey);
  }

  /// Legacy method for clearing token
  static Future<bool> clearToken() async {
    return await clearAuthData();
  }

  /// Logout user - clear token and perform any additional cleanup
  static Future<void> logout() async {
    await clearAuthData();
    // Add any additional logout logic here (clear cache, reset providers, etc.)
  }
}
