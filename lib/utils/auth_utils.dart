import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Authentication utility class for managing tokens and user type.
/// Token and user type are stored in Flutter Secure Storage.
class AuthUtils {
  static const String _tokenKey = 'auth_token';
  static const String _userTypeKey = 'user_type';

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  /// Check if user is authenticated (token exists)
  static Future<bool> isAuthenticated() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// Get stored authentication token from secure storage
  static Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  /// Store authentication token in secure storage
  static Future<bool> setToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
    return true;
  }

  /// Store user type (role) in secure storage
  static Future<bool> setUserType(String userType) async {
    await _storage.write(key: _userTypeKey, value: userType);
    return true;
  }

  /// Alternative method name for testing/legacy
  static Future<bool> storeUserType(String userType) async {
    return await setUserType(userType);
  }

  /// Get stored user type from secure storage
  static Future<String?> getUserType() async {
    return await _storage.read(key: _userTypeKey);
  }

  /// Alias for getUserType
  static Future<String?> getUserRole() async {
    return await getUserType();
  }

  /// Alias for setUserType
  static Future<bool> setUserRole(String role) async {
    return await setUserType(role);
  }

  /// Decode JWT payload and return userType (or role) from token.
  /// Returns null if token is invalid or claim is missing.
  static String? getRoleFromToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;

      String payload = parts[1];
      while (payload.length % 4 != 0) {
        payload += '=';
      }
      final decoded = utf8.decode(base64Url.decode(payload));
      final map = json.decode(decoded) as Map<String, dynamic>;
      final userType = map['userType'] ?? map['role'];
      return userType?.toString();
    } catch (_) {
      return null;
    }
  }

  /// Decode JWT payload and return employee ID from token.
  /// Returns null if token is invalid or claim is missing.
  static int? getEmployeeIdFromToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;

      String payload = parts[1];
      while (payload.length % 4 != 0) {
        payload += '=';
      }
      final decoded = utf8.decode(base64Url.decode(payload));
      final map = json.decode(decoded) as Map<String, dynamic>;
      
      // Try multiple possible employee ID fields
      final employeeId = map['employeeId'] ?? 
                        map['employeeID'] ?? 
                        map['id'] ?? 
                        map['userId'] ?? 
                        map['user_id'];
      
      if (employeeId != null) {
        if (employeeId is int) {
          return employeeId;
        } else if (employeeId is String) {
          return int.tryParse(employeeId);
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Get role for navigation: from storage first, then decode from token.
  static Future<String?> getRoleForNavigation() async {
    String? role = await getUserType();
    if (role != null && role.isNotEmpty) return role;
    final token = await getToken();
    if (token == null) return null;
    role = getRoleFromToken(token);
    if (role != null) await setUserType(role);
    return role;
  }

  /// Get current employee ID from JWT token.
  /// Returns null if token is invalid or employee ID is missing.
  static Future<int?> getCurrentEmployeeId() async {
    final token = await getToken();
    if (token == null) return null;
    return getEmployeeIdFromToken(token);
  }

  /// Clear authentication token and user data (logout)
  static Future<bool> clearAuthData() async {
    await _storage.delete(key: _userTypeKey);
    await _storage.delete(key: _tokenKey);
    return true;
  }

  static Future<bool> clearToken() async {
    return await clearAuthData();
  }

  static Future<void> logout() async {
    await clearAuthData();
  }
}
