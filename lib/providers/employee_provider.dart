import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/employee.dart';
import '../services/api_service.dart';

class EmployeeProvider with ChangeNotifier {
  List<Employee> _employees = [];
  bool _isLoading = false;
  String? _error;

  List<Employee> get employees => _employees;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Load all employees
  Future<void> loadEmployees() async {
    _setLoading(true);
    try {
      _employees = await ApiService.getEmployees();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  // Create new employee
  Future<bool> createEmployee(Employee employee, {File? imageFile, String? shiftName}) async {
    _setLoading(true);
    try {
      print('📦 [EMPLOYEE PROVIDER] Creating employee via API...');
      final newEmployee = await ApiService.createEmployee(employee, imageFile: imageFile, shiftName: shiftName);
      
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
             employee.email.toLowerCase().contains(query.toLowerCase()) ||
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

  // Refresh data
  Future<void> refresh() async {
    await loadEmployees();
  }
} 