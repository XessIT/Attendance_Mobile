import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../models/employee.dart';
import '../providers/attendance_provider.dart';
import '../providers/employee_provider.dart';
import '../models/attendance.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../services/local_storage_service.dart';
import 'face_attendance_screen_new.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  DateTime _selectedDate = DateTime.now();
  int? _selectedEmployeeId;
  Map<String, dynamic>? _reportData;
  bool _isLoading = false;
  bool _isReportLoading = false;
  String? _error;
  DateTime? _lastReportDate;
  String _searchQuery = '';
  String _selectedStatus = 'All';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Load employees and report data in parallel for better performance
      // Note: We don't need AttendanceProvider.loadAttendance() since we use fetchEmployeeFullReport
      await Future.wait([
        Provider.of<EmployeeProvider>(context, listen: false).loadEmployees(),
        _loadFullReport(),
      ]);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadFullReport() async {
    // Try to load from cache first
    final cachedReport = await LocalStorageService.getCachedAttendanceReport(_selectedDate);
    if (cachedReport != null) {
      if (mounted) {
        setState(() {
          _reportData = cachedReport;
          _lastReportDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
        });
      }
      print('✅ Loaded attendance report from local cache');
      return;
    }

    setState(() {
      _isReportLoading = true;
    });

    try {
      final startDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final endDate = startDate;
      final data = await ApiService.fetchEmployeeFullReport(
        startDate: startDate,
        endDate: endDate,
      );
      
      // Cache the fetched data
      await LocalStorageService.cacheAttendanceReport(_selectedDate, data);
      
      if (mounted) {
        setState(() {
          _reportData = data;
          _lastReportDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
        });
      }
      print('✅ Loaded and cached attendance report from API');
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
      print('❌ Error loading attendance report: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isReportLoading = false;
        });
      }
    }
  }

  Future<void> _handleMarkAttendance() async {
    // 1. Check Location Permission
    bool hasPermission = await LocationService.hasLocationPermission();
    if (!hasPermission) {
      bool permissionGranted = await LocationService.requestLocationPermission();
      if (!permissionGranted) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Location Permission Required'),
              content: const Text(
                'Location access is required to mark attendance. '
                'Please enable location permissions in your device settings.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    LocationService.openAppSettings();
                  },
                  child: const Text('Open Settings'),
                ),
              ],
            ),
          );
        }
        return;
      }
    }

    // 2. Open Camera
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 80,
      );

      if (image == null) return; // User cancelled

      // 3. Mark Attendance
      if (mounted) {
        // Show loading dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(child: CircularProgressIndicator()),
        );

        try {
          final File imageFile = File(image.path);
          final result = await ApiService.markAttendanceWithImage(imageFile);

          if (mounted) {
            Navigator.of(context).pop(); // Close loading dialog
            
            if (result['success'] == true) {
              final String message = result['message'] ?? 'Attendance marked successfully';
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(message),
                  backgroundColor: Colors.green,
                ),
              );
              // Refresh only report data, not full reload
              await LocalStorageService.clearAttendanceReportCache(_selectedDate);
              await _loadFullReport();
            } else {
              throw Exception(result['message'] ?? 'Failed to mark attendance');
            }
          }
        } catch (e) {
          if (mounted) {
            Navigator.of(context).pop(); // Close loading dialog
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Camera Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _selectDate() async {
    final DateTime? newDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (newDate != null) {
      setState(() {
        _selectedDate = newDate;
      });
      await _loadFullReport();
    }
  }

  void _showEmployeeFilterDialog() async {
    final employees = Provider.of<EmployeeProvider>(context, listen: false).employees;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF2196F3),
                    const Color(0xFF1976D2),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.filter_list_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Filter by Employee',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Text(
              'Select employee to filter',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _selectedEmployeeId == null ? const Color(0xFF2196F3) : Colors.grey[300]!,
                  width: _selectedEmployeeId == null ? 2 : 1,
                ),
                color: _selectedEmployeeId == null ? const Color(0xFF2196F3).withOpacity(0.1) : Colors.white,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedEmployeeId = null;
                    });
                    Navigator.pop(context);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _selectedEmployeeId == null ? const Color(0xFF2196F3) : Colors.transparent,
                            border: Border.all(
                              color: _selectedEmployeeId == null ? const Color(0xFF2196F3) : Colors.grey[400]!,
                              width: 2,
                            ),
                          ),
                          child: _selectedEmployeeId == null
                              ? const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 12,
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'All Employees',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: _selectedEmployeeId == null ? FontWeight.w600 : FontWeight.w500,
                              color: _selectedEmployeeId == null ? const Color(0xFF2196F3) : Colors.grey[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            ...employees.map((employee) {
              final isSelected = _selectedEmployeeId == employee.id;
              
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF2196F3) : Colors.grey[300]!,
                    width: isSelected ? 2 : 1,
                  ),
                  color: isSelected ? const Color(0xFF2196F3).withOpacity(0.1) : Colors.white,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedEmployeeId = employee.id;
                      });
                      Navigator.pop(context);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected ? const Color(0xFF2196F3) : Colors.transparent,
                              border: Border.all(
                                color: isSelected ? const Color(0xFF2196F3) : Colors.grey[400]!,
                                width: 2,
                              ),
                            ),
                            child: isSelected
                                ? const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 12,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              employee.name,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                color: isSelected ? const Color(0xFF2196F3) : Colors.grey[700],
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2196F3).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              employee.position ?? 'General',
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF2196F3),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16, bottom: 16, left: 16),
            width: double.infinity,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.grey[200]!,
                  Colors.grey[300]!,
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(12),
                child: Center(
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _reportData == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                      const SizedBox(height: 16),
                      Text(
                        'Error loading data',
                        style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          _error!,
                          style: GoogleFonts.poppins(color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _loadData,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Quick actions and filters
                    _buildHeaderSection(),
                    
                    // Statistics
                    _buildStatisticsSection(),
                    
                    // Attendance list
                    Expanded(
                      child: _buildAttendanceList(),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const FaceAttendanceScreen(shouldLoop: true),
            ),
          );
        },
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.face),
        label: Text(
          'Mark Attendance',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      // decoration: BoxDecoration(
      //   gradient: LinearGradient(
      //     begin: Alignment.topCenter,
      //     end: Alignment.bottomCenter,
      //     colors: [
      //       const Color(0xFF2196F3),
      //       const Color(0xFF1976D2),
      //       Colors.white,
      //     ],
      //     stops: const [0.0, 0.3, 1.0],
      //   ),
      // ),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 8),
            // Date selector
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _selectDate,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Container(
                          //   padding: const EdgeInsets.all(8),
                          //   child: const Icon(Icons.calendar_today, color: Color(0xFF2196F3), size: 20),
                          // ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              DateFormat('EEEE, MMMM d, y').format(_selectedDate),
                              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[800]),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.today, color: Color(0xFF2196F3), size: 20),
                              onPressed: () async {
                                setState(() {
                                  _selectedDate = DateTime.now();
                                });
                                await _loadFullReport();
                              },
                              tooltip: 'Today',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Search and Filter Bar
            Consumer<EmployeeProvider>(
              builder: (context, employeeProvider, child) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search by employee name...',
                      hintStyle: GoogleFonts.poppins(
                        color: Colors.grey[500],
                        fontSize: 14,
                      ),
                      prefixIcon: Container(
                        padding: const EdgeInsets.all(12),
                        child: Icon(
                          Icons.search_rounded,
                          color: Colors.grey[600],
                          size: 20,
                        ),
                      ),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: _selectedEmployeeId != null 
                                  ? Colors.orange.withOpacity(0.1)
                                  : Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: IconButton(
                              icon: Icon(
                                Icons.filter_list_rounded,
                                color: _selectedEmployeeId != null 
                                    ? Colors.orange[700]
                                    : Colors.grey[600],
                                size: 20,
                              ),
                              onPressed: _showEmployeeFilterDialog,
                              tooltip: 'Filter',
                            ),
                          ),
                          if (_searchQuery.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: IconButton(
                                icon: Icon(
                                  Icons.clear_rounded,
                                  color: Colors.grey[600],
                                  size: 20,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _searchQuery = '';
                                  });
                                },
                                tooltip: 'Clear search',
                              ),
                            ),
                        ],
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, 
                        vertical: 14,
                      ),
                    ),
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[800],
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                );
              },
            ),
            
            // Filter Chips
            if (_selectedEmployeeId != null || _searchQuery.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    if (_selectedEmployeeId != null)
                      Consumer<EmployeeProvider>(
                        builder: (context, employeeProvider, child) {
                          final employee = employeeProvider.employees.firstWhere(
                            (emp) => emp.id == _selectedEmployeeId,
                            orElse: () => employeeProvider.employees.first,
                          );
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange[50],
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.orange[200]!),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.filter_list_rounded,
                                  size: 14,
                                  color: Colors.orange[700],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  employee.name,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.orange[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedEmployeeId = null;
                                    });
                                  },
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 14,
                                    color: Colors.orange[700],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    if (_searchQuery.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.search_rounded,
                              size: 14,
                              color: Colors.blue[700],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _searchQuery.length > 15 
                                  ? '${_searchQuery.substring(0, 15)}...'
                                  : _searchQuery,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.blue[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                              child: Icon(
                                Icons.close_rounded,
                                size: 14,
                                color: Colors.blue[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsSection() {
    if (_isReportLoading && _reportData == null) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        height: 120,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final dayWiseDetails = _reportData?['dayWiseDetails'] as List<dynamic>? ?? [];
    
    // Filter by employee if selected and by search query
    var filteredDetails = dayWiseDetails.where((detail) {
      // Employee filter
      final employeeMatch = _selectedEmployeeId == null ||
          detail['employeeId']?.toString() == _selectedEmployeeId.toString();
      
      // Search filter
      final searchMatch = _searchQuery.isEmpty ||
          detail['employeeName']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) == true;
      
      return employeeMatch && searchMatch;
    }).toList();
    
    // Calculate counts from dayWiseDetails for accurate statistics
    int present = 0;
    int absent = 0;
    int late = 0;
    int halfDay = 0;
    
    for (var detail in filteredDetails) {
      final status = (detail['status'] as String? ?? '').toLowerCase();
      final isHalfDayFlag = detail['isHalfDay'] as bool? ?? false;
      
      if (status == 'present') {
        present++;
      } else if (status == 'absent') {
        absent++;
      } else if (status == 'late') {
        late++;
      }
      
      if (isHalfDayFlag) {
        halfDay++;
      }
    }
    
    // Include late in present count (late employees are also present)
    final int totalPresent = present + late;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              title: 'Present',
              value: totalPresent.toString(),
              color: Colors.green,
              icon: Icons.check_circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              title: 'Absent',
              value: absent.toString(),
              color: Colors.red,
              icon: Icons.cancel,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              title: 'Late',
              value: late.toString(),
              color: Colors.orange,
              icon: Icons.schedule,
            ),
          ),
          if (halfDay > 0) ...[
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                title: 'Half Day',
                value: halfDay.toString(),
                color: Colors.blue,
                icon: Icons.schedule,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 9,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceList() {
    if (_isReportLoading && _reportData == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    final dayWiseDetails = _reportData?['dayWiseDetails'] as List<dynamic>? ?? [];
    
    // Filter by employee if selected and by search query
    var filteredDetails = dayWiseDetails.where((detail) {
      // Employee filter
      final employeeMatch = _selectedEmployeeId == null ||
          detail['employeeId']?.toString() == _selectedEmployeeId.toString();
      
      // Search filter
      final searchMatch = _searchQuery.isEmpty ||
          detail['employeeName']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) == true;
      
      return employeeMatch && searchMatch;
    }).toList();

    if (filteredDetails.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.access_time,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No attendance records',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No attendance records found for ${DateFormat('MMMM d, y').format(_selectedDate)}',
              style: GoogleFonts.poppins(
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await LocalStorageService.clearAttendanceReportCache(_selectedDate);
        await _loadFullReport();
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filteredDetails.length,
        itemBuilder: (context, index) {
          final detail = filteredDetails[index] as Map<String, dynamic>;
          return _buildEnhancedAttendanceCard(detail, index);
        },
      ),
    );
  }

  Widget _buildEnhancedAttendanceCard(Map<String, dynamic> detail, int index) {
    final employeeName = detail['employeeName'] ?? 'Unknown';
    final employeeId = detail['employeeId'] ?? '';
    final department = detail['department'] ?? '';
    final status = detail['status']?.toString().toLowerCase() ?? 'absent';
    final checkIn = detail['checkIn']?.toString() ?? '-';
    final checkOut = detail['checkOut']?.toString() ?? '-';
    final workHours = detail['workHours'] ?? 0;
    final otHours = detail['otHours'] ?? 0;
    final lateMinutes = detail['lateMinutes'] ?? 0;
    final shiftName = detail['shiftName'] ?? '';
    final shiftTimings = detail['shiftTimings'] as Map<String, dynamic>?;
    final dayOfWeek = detail['dayOfWeek'] ?? '';
    final isHoliday = detail['isHoliday'] ?? false;
    final holidayName = detail['holidayName'];
    final isHalfDay = detail['isHalfDay'] ?? false;

    final statusColor = _getStatusColor(status);
    final statusIcon = _getStatusIcon(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _showEnhancedAttendanceDetails(detail),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row with employee info and status
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: statusColor.withOpacity(0.1),
                    child: Icon(
                      statusIcon,
                      color: statusColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          employeeName,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.badge, size: 12, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text(
                              employeeId,
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Icon(Icons.business, size: 12, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text(
                              department,
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: GoogleFonts.poppins(
                        fontSize: 8,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Check-in and Check-out times
              Row(
                children: [
                  Expanded(
                    child: _buildTimeCard(
                      icon: Icons.login,
                      label: 'Check In',
                      time: checkIn,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTimeCard(
                      icon: Icons.logout,
                      label: 'Check Out',
                      time: checkOut,
                      color: Colors.purple,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Additional info row
              Row(
                children: [
                  if (shiftName.isNotEmpty) ...[
                    Expanded(
                      child: _buildInfoChip(
                        icon: Icons.schedule,
                        label: shiftName,
                        color: Colors.indigo,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (workHours > 0) ...[
                    Expanded(
                      child: _buildInfoChip(
                        icon: Icons.access_time,
                        label: '${workHours.toStringAsFixed(1)}h',
                        color: Colors.teal,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (lateMinutes > 0)
                    Expanded(
                      child: _buildInfoChip(
                        icon: Icons.warning,
                        label: '${lateMinutes}m late',
                        color: Colors.orange,
                      ),
                    ),
                ],
              ),
              
              // Holiday or Half Day indicator
              if (isHoliday && holidayName != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.celebration, size: 14, color: Colors.amber.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'Holiday: $holidayName',
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          color: Colors.amber.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (isHalfDay) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.schedule, size: 14, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'Half Day',
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: index * 100)).slideX(begin: 0.3, duration: 600.ms);
  }

  Widget _buildTimeCard({
    required IconData icon,
    required String label,
    required String time,
    required Color color,
  }) {
    final hasTime = time != '-' && time.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 8,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasTime ? _formatTime(time) : 'Not available',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: hasTime ? color : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 8,
                color: color,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(String timeString) {
    if (timeString == '-' || timeString.isEmpty) {
      return 'Not available';
    }
    try {
      final parts = timeString.split(':');
      if (parts.length >= 2) {
        final hour = int.parse(parts[0]);
        final minute = parts[1];
        final period = hour >= 12 ? 'PM' : 'AM';
        final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
        return '$displayHour:$minute $period';
      }
      return timeString;
    } catch (e) {
      return timeString;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'present':
        return Colors.green;
      case 'absent':
        return Colors.red;
      case 'late':
        return Colors.orange;
      case 'half-day':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'present':
        return Icons.check_circle;
      case 'absent':
        return Icons.cancel;
      case 'late':
        return Icons.schedule;
      case 'half-day':
        return Icons.access_time;
      default:
        return Icons.help;
    }
  }

  void _showEnhancedAttendanceDetails(Map<String, dynamic> detail) {
    final employeeName = detail['employeeName'] ?? 'Unknown';
    final employeeId = detail['employeeId'] ?? '';
    final department = detail['department'] ?? '';
    final date = detail['date'] ?? '';
    final dayOfWeek = detail['dayOfWeek'] ?? '';
    final status = detail['status'] ?? '';
    final checkIn = detail['checkIn'] ?? '-';
    final checkOut = detail['checkOut'] ?? '-';
    final workHours = detail['workHours'] ?? 0;
    final otHours = detail['otHours'] ?? 0;
    final lateMinutes = detail['lateMinutes'] ?? 0;
    final shiftName = detail['shiftName'] ?? '';
    final shiftTimings = detail['shiftTimings'] as Map<String, dynamic>?;
    final isHoliday = detail['isHoliday'] ?? false;
    final holidayName = detail['holidayName'];
    final isHalfDay = detail['isHalfDay'] ?? false;
    final leaveType = detail['leaveType'];
    final leaveStatus = detail['leaveStatus'];

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: _getStatusColor(status.toString().toLowerCase()).withOpacity(0.1),
                        child: Icon(
                          _getStatusIcon(status.toString().toLowerCase()),
                          color: _getStatusColor(status.toString().toLowerCase()),
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              employeeName,
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '$employeeId • $department',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Date and Status
                  _buildDetailRow('Date', '$dayOfWeek, ${DateFormat('MMMM d, y').format(DateTime.parse(date))}'),
                  _buildDetailRow('Status', status.toString().toUpperCase()),
                  
                  const Divider(height: 32),
                  
                  // Timing Information
                  Text(
                    'Timing Information',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow('Check In', checkIn != '-' ? _formatTime(checkIn) : 'Not available'),
                  _buildDetailRow('Check Out', checkOut != '-' ? _formatTime(checkOut) : 'Not available'),
                  if (workHours > 0)
                    _buildDetailRow('Work Hours', '${workHours.toStringAsFixed(1)} hours'),
                  if (otHours > 0)
                    _buildDetailRow('OT Hours', '${otHours.toStringAsFixed(1)} hours'),
                  if (lateMinutes > 0)
                    _buildDetailRow('Late Minutes', '$lateMinutes minutes'),
                  
                  const Divider(height: 32),
                  
                  // Shift Information
                  if (shiftName.isNotEmpty) ...[
                    Text(
                      'Shift Information',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow('Shift Name', shiftName),
                    if (shiftTimings != null) ...[
                      _buildDetailRow('From Time', shiftTimings['fromTime'] ?? '-'),
                      _buildDetailRow('To Time', shiftTimings['toTime'] ?? '-'),
                    ],
                    const Divider(height: 32),
                  ],
                  
                  // Additional Information
                  if (isHoliday || isHalfDay || leaveType != null) ...[
                    Text(
                      'Additional Information',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (isHoliday && holidayName != null)
                      _buildDetailRow('Holiday', holidayName),
                    if (isHalfDay)
                      _buildDetailRow('Half Day', 'Yes'),
                    if (leaveType != null)
                      _buildDetailRow('Leave Type', leaveType),
                    if (leaveStatus != null)
                      _buildDetailRow('Leave Status', leaveStatus),
                  ],
                  
                  const SizedBox(height: 24),
                  
                  // Close button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2196F3),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Close',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(),
            ),
          ),
        ],
      ),
    );
  }
}
