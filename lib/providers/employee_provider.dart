import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/employee.dart';
import '../services/api_service.dart';

class EmployeeProvider with ChangeNotifier {
  List<Employee> _employees = [];
  bool _isLoading = false;
  bool _isMoreLoading = false;
  String? _error;

  // Pagination state
  int _currentPage = 1;
  int _totalPages = 1;
  bool _hasNextPage = false;
  final int _limit = 10;

  List<Employee> get employees => _employees;
  bool get isLoading => _isLoading;
  bool get isMoreLoading => _isMoreLoading;
  String? get error => _error;
  bool get hasNextPage => _hasNextPage;

  // Load initial employees
  Future<void> loadEmployees({String? search, String? department, String? status}) async {
    _setLoading(true);
    _currentPage = 1;
    try {
      final result = await ApiService.getEmployees(
        page: _currentPage,
        limit: _limit,
        search: search,
        department: department,
        status: status,
      );
      
      _employees = List<Employee>.from(result['employees']);
      final pagination = result['pagination'];
      
      if (pagination != null) {
        _totalPages = pagination['totalPages'] ?? 1;
        _hasNextPage = pagination['hasNextPage'] ?? false;
      } else {
        _totalPages = 1;
        _hasNextPage = false;
      }
      
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  // Load more employees for infinite scrolling
  Future<void> loadMoreEmployees({String? search, String? department, String? status}) async {
    if (_isMoreLoading || !_hasNextPage) return;

    _setMoreLoading(true);
    try {
      _currentPage++;
      final result = await ApiService.getEmployees(
        page: _currentPage,
        limit: _limit,
        search: search,
        department: department,
        status: status,
      );
      
      final List<Employee> newEmployees = List<Employee>.from(result['employees']);
      _employees.addAll(newEmployees);
      
      final pagination = result['pagination'];
      if (pagination != null) {
        _totalPages = pagination['totalPages'] ?? 1;
        _hasNextPage = pagination['hasNextPage'] ?? false;
      } else {
        _hasNextPage = false;
      }
      
      _error = null;
    } catch (e) {
      _error = e.toString();
      _currentPage--; // Revert page on error
    } finally {
      _setMoreLoading(false);
    }
  }

  // Create new employee
  Future<bool> createEmployee(Employee employee, {File? imageFile, String? shiftName, String? departmentName, String? password}) async {
    _setLoading(true);
    try {
      print('📦 [EMPLOYEE PROVIDER] Creating employee via API...');
      final newEmployee = await ApiService.createEmployee(employee, imageFile: imageFile, shiftName: shiftName, departmentName: departmentName, password: password);
      
      print('📦 [EMPLOYEE PROVIDER] Employee received from API:');
      print('   ID: ${newEmployee.id}');
      print('   Name: ${newEmployee.name}');
      print('   Email: ${newEmployee.email}');
      
      _employees.add(newEmployee);
      print('📦 [EMPLOYEE PROVIDER] Employee added to local list. Total employees: ${_employees.length}');
      
      _error = null;
      notifyListeners();
      print('📦 [EMPLOYEE PROVIDER] Notified listeners');
      return true;
    } catch (e, stackTrace) {
      print('❌ [EMPLOYEE PROVIDER] Error creating employee:');
      print('   Error: $e');
      print('   Stack: $stackTrace');
      // Extract clean error message (remove "Exception: " prefix if present)
      String errorMsg = e.toString();
      if (errorMsg.startsWith('Exception: ')) {
        errorMsg = errorMsg.substring(11);
      }
      _error = errorMsg;
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Update employee
  Future<bool> updateEmployee(Employee employee) async {
    _setLoading(true);
    try {
      final updatedEmployee = await ApiService.updateEmployee(employee);
      final index = _employees.indexWhere((e) => e.id == employee.id);
      if (index != -1) {
        _employees[index] = updatedEmployee;
      }
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Delete employee
  Future<bool> deleteEmployee(int id) async {
    _setLoading(true);
    try {
      final success = await ApiService.deleteEmployee(id);
      if (success) {
        _employees.removeWhere((e) => e.id == id);
      }
      _error = null;
      notifyListeners();
      return success;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Toggle employee active status (activate/deactivate)
  Future<bool> toggleEmployeeStatus(Employee employee) async {
    _setLoading(true);
    try {
      final updatedEmployee = employee.isActive
          ? await ApiService.deactivateEmployee(employee.id!)
          : await ApiService.activateEmployee(employee.id!);
      
      final index = _employees.indexWhere((e) => e.id == employee.id);
      if (index != -1) {
        _employees[index] = updatedEmployee;
      }
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Get employee by ID
  Employee? getEmployeeById(int id) {
    try {
      return _employees.firstWhere((e) => e.id == id);
    } catch (e) {
      return null;
    }
  }

  // Search employees
  List<Employee> searchEmployees(String query) {
    if (query.isEmpty) return _employees;
    
    return _employees.where((employee) {
      return employee.name.toLowerCase().contains(query.toLowerCase()) ||
             (employee.email?.toLowerCase() ?? '').contains(query.toLowerCase()) ||
             employee.position.toLowerCase().contains(query.toLowerCase());
    }).toList();
  }

  // Get active employees
  List<Employee> get activeEmployees => 
    _employees.where((e) => e.isActive).toList();

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // Set loading state for more items
  void _setMoreLoading(bool loading) {
    _isMoreLoading = loading;
    notifyListeners();
  }

  // Refresh data
  Future<void> refresh() async {
    await loadEmployees();
  }
} 