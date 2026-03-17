import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../models/employee.dart';

class LocalStorageService {
  static const String _employeesKey = 'cached_employees';
  static const String _employeesTimestampKey = 'employees_timestamp';
  static const String _attendanceReportKeyPrefix = 'attendance_report_';
  static const String _attendanceReportTimestampKeyPrefix = 'attendance_report_timestamp_';
  static const String _filteredEmployeesPrefix = 'filtered_employees_';
  static const String _filteredEmployeesTimestampPrefix = 'filtered_employees_timestamp_';
  
  // Cache duration in minutes
  static const int _employeeCacheDuration = 30; // 30 minutes
  static const int _attendanceCacheDuration = 10; // 10 minutes
  static const int _filteredCacheDuration = 5; // 5 minutes for filtered data

  // Employee Data Caching
  static Future<void> cacheEmployees(List<Employee> employees) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Convert employees to JSON
      final List<Map<String, dynamic>> employeesJson = 
          employees.map((employee) => employee.toJson()).toList();
      
      // Save to local storage
      await prefs.setString(_employeesKey, jsonEncode(employeesJson));
      await prefs.setString(_employeesTimestampKey, DateTime.now().toIso8601String());
      
      print('✅ Cached ${employees.length} employees locally');
    } catch (e) {
      print('❌ Error caching employees: $e');
    }
  }

  static Future<List<Employee>?> getCachedEmployees() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Check if cache exists and is valid
      final employeesData = prefs.getString(_employeesKey);
      final timestamp = prefs.getString(_employeesTimestampKey);
      
      if (employeesData == null || timestamp == null) {
        print('📭 No cached employee data found');
        return null;
      }
      
      // Check if cache is expired
      final cacheTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final isExpired = now.difference(cacheTime).inMinutes > _employeeCacheDuration;
      
      if (isExpired) {
        print('⏰ Employee cache expired (${now.difference(cacheTime).inMinutes} minutes old)');
        await clearEmployeeCache();
        return null;
      }
      
      // Parse and return cached data
      final List<dynamic> employeesJson = jsonDecode(employeesData);
      final List<Employee> employees = employeesJson
          .map((json) => Employee.fromJson(json as Map<String, dynamic>))
          .toList();
      
      print('✅ Loaded ${employees.length} employees from cache (${now.difference(cacheTime).inMinutes} minutes old)');
      return employees;
    } catch (e) {
      print('❌ Error loading cached employees: $e');
      return null;
    }
  }

  static Future<void> clearEmployeeCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_employeesKey);
      await prefs.remove(_employeesTimestampKey);
      print('🗑️ Cleared employee cache');
    } catch (e) {
      print('❌ Error clearing employee cache: $e');
    }
  }

  // Attendance Report Caching
  static Future<void> cacheAttendanceReport(DateTime date, Map<String, dynamic> reportData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dateKey = DateFormat('yyyy-MM-dd').format(date);
      
      // Save report data
      await prefs.setString(
        '$_attendanceReportKeyPrefix$dateKey', 
        jsonEncode(reportData)
      );
      
      // Save timestamp
      await prefs.setString(
        '$_attendanceReportTimestampKeyPrefix$dateKey', 
        DateTime.now().toIso8601String()
      );
      
      final dayWiseDetails = reportData['dayWiseDetails'] as List<dynamic>? ?? [];
      print('✅ Cached attendance report for $dateKey (${dayWiseDetails.length} records)');
    } catch (e) {
      print('❌ Error caching attendance report: $e');
    }
  }

  static Future<Map<String, dynamic>?> getCachedAttendanceReport(DateTime date) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dateKey = DateFormat('yyyy-MM-dd').format(date);
      
      // Check if cache exists
      final reportData = prefs.getString('$_attendanceReportKeyPrefix$dateKey');
      final timestamp = prefs.getString('$_attendanceReportTimestampKeyPrefix$dateKey');
      
      if (reportData == null || timestamp == null) {
        print('📭 No cached attendance report found for $dateKey');
        return null;
      }
      
      // Check if cache is expired
      final cacheTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final isExpired = now.difference(cacheTime).inMinutes > _attendanceCacheDuration;
      
      // For today's data, use shorter cache duration
      final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
      final actualCacheDuration = isToday ? 5 : _attendanceCacheDuration; // 5 minutes for today
      
      if (now.difference(cacheTime).inMinutes > actualCacheDuration) {
        print('⏰ Attendance cache expired for $dateKey (${now.difference(cacheTime).inMinutes} minutes old)');
        await clearAttendanceReportCache(date);
        return null;
      }
      
      // Parse and return cached data
      final Map<String, dynamic> parsedData = jsonDecode(reportData);
      final dayWiseDetails = parsedData['dayWiseDetails'] as List<dynamic>? ?? [];
      print('✅ Loaded attendance report for $dateKey from cache (${dayWiseDetails.length} records, ${now.difference(cacheTime).inMinutes} minutes old)');
      
      return parsedData;
    } catch (e) {
      print('❌ Error loading cached attendance report: $e');
      return null;
    }
  }

  static Future<void> clearAttendanceReportCache(DateTime date) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dateKey = DateFormat('yyyy-MM-dd').format(date);
      
      await prefs.remove('$_attendanceReportKeyPrefix$dateKey');
      await prefs.remove('$_attendanceReportTimestampKeyPrefix$dateKey');
      print('🗑️ Cleared attendance report cache for $dateKey');
    } catch (e) {
      print('❌ Error clearing attendance report cache: $e');
    }
  }

  static Future<void> clearAllAttendanceReportCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      for (final key in keys) {
        if (key.startsWith(_attendanceReportKeyPrefix) || 
            key.startsWith(_attendanceReportTimestampKeyPrefix)) {
          await prefs.remove(key);
        }
      }
      print('🗑️ Cleared all attendance report cache');
    } catch (e) {
      print('❌ Error clearing all attendance report cache: $e');
    }
  }

  static Future<void> clearAllCache() async {
    await clearEmployeeCache();
    await clearAllAttendanceReportCache();
    await clearAllFilteredEmployeeCache();
    print('🗑️ Cleared all cached data');
  }

  // Cache management utilities
  static Future<bool> isEmployeeCacheValid() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getString(_employeesTimestampKey);
      
      if (timestamp == null) return false;
      
      final cacheTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      return now.difference(cacheTime).inMinutes <= _employeeCacheDuration;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> isAttendanceReportCacheValid(DateTime date) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dateKey = DateFormat('yyyy-MM-dd').format(date);
      final timestamp = prefs.getString('$_attendanceReportTimestampKeyPrefix$dateKey');
      
      if (timestamp == null) return false;
      
      final cacheTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
      final actualCacheDuration = isToday ? 5 : _attendanceCacheDuration;
      
      return now.difference(cacheTime).inMinutes <= actualCacheDuration;
    } catch (e) {
      return false;
    }
  }

  // Get cache info for debugging
  static Future<Map<String, dynamic>> getCacheInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final employeeTimestamp = prefs.getString(_employeesTimestampKey);
      
      Map<String, dynamic> info = {
        'employeeCacheExists': employeeTimestamp != null,
        'employeeCacheAge': employeeTimestamp != null 
            ? DateTime.now().difference(DateTime.parse(employeeTimestamp)).inMinutes
            : null,
        'attendanceReportCacheCount': 0,
        'filteredCacheCount': 0,
      };
      
      // Count attendance report caches
      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith(_attendanceReportTimestampKeyPrefix)) {
          info['attendanceReportCacheCount'] = (info['attendanceReportCacheCount'] as int) + 1;
        } else if (key.startsWith(_filteredEmployeesTimestampPrefix)) {
          info['filteredCacheCount'] = (info['filteredCacheCount'] as int) + 1;
        }
      }
      
      return info;
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  // Filtered Employee Data Caching
  static Future<void> cacheFilteredEmployees(String search, String? status, List<Employee> employees) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = _generateFilterCacheKey(search, status);
      
      // Convert employees to JSON
      final List<Map<String, dynamic>> employeesJson = 
          employees.map((employee) => employee.toJson()).toList();
      
      // Save to local storage
      await prefs.setString('$_filteredEmployeesPrefix$cacheKey', jsonEncode(employeesJson));
      await prefs.setString('$_filteredEmployeesTimestampPrefix$cacheKey', DateTime.now().toIso8601String());
      
      print('✅ Cached ${employees.length} filtered employees locally (search: "$search", status: $status)');
    } catch (e) {
      print('❌ Error caching filtered employees: $e');
    }
  }

  static Future<List<Employee>?> getCachedFilteredEmployees(String search, String? status) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = _generateFilterCacheKey(search, status);
      
      // Check if cache exists and is valid
      final employeesData = prefs.getString('$_filteredEmployeesPrefix$cacheKey');
      final timestamp = prefs.getString('$_filteredEmployeesTimestampPrefix$cacheKey');
      
      if (employeesData == null || timestamp == null) {
        print('📭 No cached filtered employee data found for (search: "$search", status: $status)');
        return null;
      }
      
      // Check if cache is expired
      final cacheTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final isExpired = now.difference(cacheTime).inMinutes > _filteredCacheDuration;
      
      if (isExpired) {
        print('⏰ Filtered employee cache expired for (search: "$search", status: $status) (${now.difference(cacheTime).inMinutes} minutes old)');
        await clearFilteredEmployeeCache(search, status);
        return null;
      }
      
      // Parse and return cached data
      final List<dynamic> employeesJson = jsonDecode(employeesData);
      final List<Employee> employees = employeesJson
          .map((json) => Employee.fromJson(json as Map<String, dynamic>))
          .toList();
      
      print('✅ Loaded ${employees.length} filtered employees from cache (search: "$search", status: $status, ${now.difference(cacheTime).inMinutes} minutes old)');
      return employees;
    } catch (e) {
      print('❌ Error loading cached filtered employees: $e');
      return null;
    }
  }

  static Future<void> clearFilteredEmployeeCache(String search, String? status) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = _generateFilterCacheKey(search, status);
      
      await prefs.remove('$_filteredEmployeesPrefix$cacheKey');
      await prefs.remove('$_filteredEmployeesTimestampPrefix$cacheKey');
      print('🗑️ Cleared filtered employee cache for (search: "$search", status: $status)');
    } catch (e) {
      print('❌ Error clearing filtered employee cache: $e');
    }
  }

  static Future<void> clearAllFilteredEmployeeCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      for (final key in keys) {
        if (key.startsWith(_filteredEmployeesPrefix) || 
            key.startsWith(_filteredEmployeesTimestampPrefix)) {
          await prefs.remove(key);
        }
      }
      print('🗑️ Cleared all filtered employee cache');
    } catch (e) {
      print('❌ Error clearing all filtered employee cache: $e');
    }
  }

  static String _generateFilterCacheKey(String search, String? status) {
    final searchKey = search.toLowerCase().trim();
    final statusKey = status?.toLowerCase() ?? 'all';
    return '${searchKey}_$statusKey';
  }

  // Client-side search/filter for instant results
  static List<Employee> filterEmployeesLocally(List<Employee> employees, String search, String? status) {
    List<Employee> filtered = List.from(employees);
    
    // Apply status filter
    if (status != null && status.isNotEmpty) {
      if (status.toLowerCase() == 'active') {
        filtered = filtered.where((e) => e.isActive).toList();
      } else if (status.toLowerCase() == 'inactive') {
        filtered = filtered.where((e) => !e.isActive).toList();
      }
    }
    
    // Apply search filter
    if (search.isNotEmpty) {
      final searchLower = search.toLowerCase();
      filtered = filtered.where((employee) {
        return employee.name.toLowerCase().contains(searchLower) ||
               (employee.email?.toLowerCase().contains(searchLower) ?? false) ||
               employee.position.toLowerCase().contains(searchLower) ||
               employee.phone.toLowerCase().contains(searchLower);
      }).toList();
    }
    
    return filtered;
  }
}
