import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/department.dart';
import '../services/api_service.dart';

class DepartmentProvider with ChangeNotifier {
  List<Department> _departments = [];
  bool _isLoading = false;
  String? _error;

  List<Department> get departments => _departments;
  bool get isLoading => _isLoading;
  String? get error => _error;

  static const String _departmentsKey = 'departments';

  // API Methods

  // Load departments from API
  Future<List<Department>> _loadDepartmentsFromApi() async {
    try {
      debugPrint('🔄 Loading departments from API...');

      final departmentsData = await ApiService.getDepartments();
      final departments = departmentsData.map((json) => Department.fromJson(json)).toList();
      debugPrint('✅ Loaded ${departments.length} departments from API');
      return departments;
    } catch (e) {
      debugPrint('❌ Error loading departments from API: $e');
      rethrow;
    }
  }

  // Load departments from API (with local storage fallback)
  Future<void> loadDepartments() async {
    _setLoading(true);
    try {
      // Try to load from API first
      _departments = await _loadDepartmentsFromApi();
      _error = null;

      // Save to local storage as cache
      await _saveDepartmentsToStorage();
    } catch (e) {
      debugPrint('⚠️ API failed, falling back to local storage: $e');

      // Fallback to local storage
      try {
        final prefs = await SharedPreferences.getInstance();
        final departmentsJson = prefs.getStringList(_departmentsKey) ?? [];

        _departments = departmentsJson.map((jsonString) {
          final Map<String, dynamic> json = jsonDecode(jsonString);
          return Department.fromJson(json);
        }).toList();

        _error = 'Using cached data - ${e.toString()}';
        debugPrint('✅ Loaded ${_departments.length} departments from local storage (fallback)');
      } catch (localError) {
        _error = 'Failed to load departments: ${e.toString()}';
        debugPrint('❌ Error loading departments from both API and local storage: $localError');
      }
    } finally {
      _setLoading(false);
    }
  }

  // Save departments to local storage
  Future<void> _saveDepartmentsToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final departmentsJson = _departments.map((department) => jsonEncode(department.toJson())).toList();
      await prefs.setStringList(_departmentsKey, departmentsJson);
      debugPrint('💾 Saved ${_departments.length} departments to local storage');
    } catch (e) {
      debugPrint('❌ Error saving departments to storage: $e');
      throw e;
    }
  }

  // Get department by ID
  Department? getDepartmentById(int id) {
    try {
      return _departments.firstWhere((department) => department.id == id);
    } catch (e) {
      return null;
    }
  }

  // Clear all departments
  Future<void> clearAllDepartments() async {
    _setLoading(true);
    try {
      _departments.clear();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_departmentsKey);

      _error = null;
      notifyListeners();
      debugPrint('✅ Cleared all departments');
    } catch (e) {
      _error = e.toString();
      debugPrint('❌ Error clearing departments: $e');
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // Refresh departments (alias for loadDepartments)
  Future<void> refresh() async {
    await loadDepartments();
  }
}
