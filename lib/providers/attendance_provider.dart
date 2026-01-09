import 'package:flutter/foundation.dart';
import '../models/attendance.dart';
import '../models/employee.dart';
import '../services/api_service.dart';

class AttendanceProvider with ChangeNotifier {
  List<Attendance> _attendance = [];
  bool _isLoading = false;
  String? _error;

  List<Attendance> get attendance => _attendance;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Load attendance records
  Future<void> loadAttendance({
    int? employeeId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    _setLoading(true);
    try {
      _attendance = await ApiService.getAttendance(
        employeeId: employeeId,
        startDate: startDate,
        endDate: endDate,
      );
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  // Mark attendance
  Future<bool> markAttendance(Attendance attendance) async {
    _setLoading(true);
    try {
      final newAttendance = await ApiService.markAttendance(attendance);
      _attendance.add(newAttendance);
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

  // Update attendance
  Future<bool> updateAttendance(Attendance attendance) async {
    _setLoading(true);
    try {
      final updatedAttendance = await ApiService.updateAttendance(attendance);
      final index = _attendance.indexWhere((a) => a.id == attendance.id);
      if (index != -1) {
        _attendance[index] = updatedAttendance;
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

  // Get attendance by employee
  List<Attendance> getAttendanceByEmployee(int employeeId) {
    return _attendance.where((a) => a.employeeId == employeeId).toList();
  }

  // Get attendance by date
  List<Attendance> getAttendanceByDate(DateTime date) {
    return _attendance.where((a) => 
      a.date.year == date.year && 
      a.date.month == date.month && 
      a.date.day == date.day
    ).toList();
  }

  // Get today's attendance
  List<Attendance> get todayAttendance => 
    getAttendanceByDate(DateTime.now());

  // Get attendance statistics
  Map<String, dynamic> getAttendanceStats({
    int? employeeId,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    List<Attendance> filteredAttendance = _attendance;

    if (employeeId != null) {
      filteredAttendance = filteredAttendance.where((a) => a.employeeId == employeeId).toList();
    }

    if (startDate != null) {
      filteredAttendance = filteredAttendance.where((a) => a.date.isAfter(startDate.subtract(const Duration(days: 1)))).toList();
    }

    if (endDate != null) {
      filteredAttendance = filteredAttendance.where((a) => a.date.isBefore(endDate.add(const Duration(days: 1)))).toList();
    }

    final int totalDays = filteredAttendance.length;
    final int presentDays = filteredAttendance.where((a) => a.isPresent).length;
    final int absentDays = filteredAttendance.where((a) => !a.isPresent).length;
    final int lateDays = filteredAttendance.where((a) => a.isLate).length;
    final int halfDays = filteredAttendance.where((a) => a.isHalfDay).length;
    final double totalWorkingHours = filteredAttendance.fold(0.0, (sum, a) => sum + a.totalWorkingHours);

    return {
      'totalDays': totalDays,
      'presentDays': presentDays,
      'absentDays': absentDays,
      'lateDays': lateDays,
      'halfDays': halfDays,
      'totalWorkingHours': totalWorkingHours,
      'attendancePercentage': totalDays > 0 ? (presentDays / totalDays) * 100 : 0.0,
    };
  }

  // Check if employee has attendance for today
  bool hasTodayAttendance(int employeeId) {
    final today = DateTime.now();
    return _attendance.any((a) => 
      a.employeeId == employeeId &&
      a.date.year == today.year &&
      a.date.month == today.month &&
      a.date.day == today.day
    );
  }

  // Get today's attendance for employee
  Attendance? getTodayAttendance(int employeeId) {
    final today = DateTime.now();
    try {
      return _attendance.firstWhere((a) => 
        a.employeeId == employeeId &&
        a.date.year == today.year &&
        a.date.month == today.month &&
        a.date.day == today.day
      );
    } catch (e) {
      return null;
    }
  }

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
    await loadAttendance();
  }
} 