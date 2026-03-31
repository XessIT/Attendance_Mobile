import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/employee_provider.dart';
import '../providers/attendance_provider.dart';
import 'employee_registration_screen.dart';
import 'comp_off_screen.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../services/app_update_service.dart';
import '../models/attendance_summary.dart';
import 'face_attendance_screen_new.dart';
import 'approve_leave_screen.dart';
import 'manual_attendance_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  AttendanceSummary? _attendanceSummary;
  List<dynamic>? _attendanceData;
  bool _isLoading = true;
  String? _error;
  bool _hasData = false;

  @override
  void initState() {
    super.initState();
    debugPrint(' [DASHBOARD] initState called');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint(' [DASHBOARD] PostFrame callback executing');
      _refreshData();
      _checkForAppUpdates();
    });
  }

  Future<void> _refreshData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      debugPrint(' [DASHBOARD] Starting data refresh...');
      
      // Load employees first with timeout and error handling
      debugPrint(' [DASHBOARD] Loading employees...');
      try {
        await Provider.of<EmployeeProvider>(context, listen: false).loadEmployees()
            .timeout(const Duration(seconds: 30));
        debugPrint(' [DASHBOARD] Employees loaded successfully');
      } catch (e) {
        debugPrint(' [DASHBOARD] Error loading employees: $e');
        // Continue even if employees fail to load
      }

      // Load attendance with timeout and error handling
      debugPrint(' [DASHBOARD] Loading attendance...');
      try {
        await Provider.of<AttendanceProvider>(context, listen: false).loadAttendance()
            .timeout(const Duration(seconds: 30));
        debugPrint(' [DASHBOARD] Attendance loaded successfully');
      } catch (e) {
        debugPrint(' [DASHBOARD] Error loading attendance: $e');
        // Continue even if attendance fails to load
      }

      // Load attendance summary with timeout and error handling
      debugPrint(' [DASHBOARD] Loading attendance summary...');
      try {
        await _loadAttendanceSummary().timeout(const Duration(seconds: 30));
        debugPrint(' [DASHBOARD] Attendance summary loaded');
      } catch (e) {
        debugPrint(' [DASHBOARD] Error loading attendance summary: $e');
        // Continue even if summary fails to load
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasData = true;
          _error = null;
        });
        debugPrint(' [DASHBOARD] Dashboard data refresh completed successfully');
      }
    } catch (e) {
      debugPrint(' [DASHBOARD] Data refresh error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
          _hasData = false;
        });

        // Show error in snackbar but don't block UI
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: ${e.toString()}'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _refreshData,
            ),
          ),
        );
      }
    }
  }

  Future<void> _loadAttendanceSummary() async {
    try {
      debugPrint(' [DASHBOARD] Fetching attendance summary...');
      final now = DateTime.now();
      final startDate = DateFormat('yyyy-MM-dd').format(now);
      final endDate = startDate;
      final data = await ApiService.fetchAttendanceSummary(startDate: startDate, endDate: endDate);

      if (mounted && data != null) {
        setState(() {
          _attendanceSummary = AttendanceSummary.fromJson(data);
          _attendanceData = data['data'] as List<dynamic>?;
        });
        debugPrint(' [DASHBOARD] Attendance summary loaded successfully');
      } else {
        debugPrint(' [DASHBOARD] Attendance summary data is null');
      }
    } catch (e) {
      debugPrint(' [DASHBOARD] Error loading attendance summary: $e');
      // Don't set state on error, just log it
      // The dashboard should still work even without summary data
    }
  }

  // Check for app updates
  Future<void> _checkForAppUpdates() async {
    try {
      final updateInfo = await AppUpdateService.checkForUpdate(context: context);

      if (updateInfo != null && updateInfo['updateAvailable'] == true) {
        if (mounted) {
          await AppUpdateService.showUpdateDialog(
            context: context,
            isForceUpdate: updateInfo['isForceUpdate'] ?? false,
            newVersion: updateInfo['newVersion'] ?? '',
            releaseNotes: updateInfo['releaseNotes'] ?? 'Bug fixes and performance improvements',
            appStoreUrl: updateInfo['downloadUrl'] ?? '',
            appSize: updateInfo['appSize'],
            currentVersion: updateInfo['currentVersion'],
          );
        }
      }
    } catch (e) {
      debugPrint('Error checking for app updates: $e');
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
              // Refresh dashboard data
              _refreshData();
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

  Future<void> _navigateToManualAttendanceScreen() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ManualAttendanceScreen(),
      ),
    );
    if (result == true) {
      _refreshData();
    }
  }

  Future<void> _navigateToFaceAttendanceScreen() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const FaceAttendanceScreen(shouldLoop: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('🏠 [DASHBOARD] Build method called');
    debugPrint('🏠 [DASHBOARD] _isLoading: $_isLoading, _hasData: $_hasData, _error: $_error');
    
    // Show loading indicator while data is being fetched
    if (_isLoading && !_hasData) {
      debugPrint('🏠 [DASHBOARD] Showing loading state');
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                color: Color(0xFF2196F3),
              ),
              const SizedBox(height: 16),
              Text(
                'Loading Dashboard...',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Show error state if there's an error and no data
    if (_error != null && !_hasData) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'Unable to load dashboard',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _refreshData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2196F3),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  ),
                  child: Text(
                    'Retry',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _error = null;
                      _hasData = true; // Force show dashboard with limited data
                    });
                  },
                  child: Text(
                    'Show Dashboard Anyway',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF2196F3),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Show main dashboard content
    debugPrint('🏠 [DASHBOARD] Showing main dashboard content');
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: const Color(0xFF2196F3),
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Welcome Section
                  _buildWelcomeSection(),
                  const SizedBox(height: 24),

                  // Quick Actions
                  _buildQuickActions(),
                  const SizedBox(height: 24),

                  // Statistics Cards
                  _buildStatisticsCards(),
                  const SizedBox(height: 24),

                  // Today's Attendance
                  _buildTodayAttendance(),
                  const SizedBox(height: 20),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF667EEA),
            const Color(0xFF764BA2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667EEA).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.waving_hand,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome Back!',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now()),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Manage your employee attendance with advanced face recognition technology',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.white.withOpacity(0.9),
              height: 1.4,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.3, duration: 600.ms);
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                icon: Icons.edit_calendar,
                title: 'Manual Attendance',
                subtitle: 'Add Manually',
                color: Colors.green,
                onTap: _navigateToManualAttendanceScreen,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                icon: Icons.person_add,
                title: 'Add Employee',
                subtitle: 'Register New',
                color: Colors.orange,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const EmployeeRegistrationScreen(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                icon: Icons.check_circle_outline,
                title: 'Approve Leave',
                subtitle: 'Review Requests',
                color: Colors.teal,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ApproveLeaveScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                icon: Icons.timelapse,
                title: 'Compensatory Off',
                subtitle: 'Request Credit/Leave',
                color: Colors.purple,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CompOffScreen(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                icon: Icons.face,
                title: 'Face Attendance',
                subtitle: 'Face Recognition',
                color: Colors.orange.shade700,
                onTap: _navigateToFaceAttendanceScreen,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(child: SizedBox()), // Placeholder for empty slot
          ],
        ),
      ],
    ).animate().fadeIn(delay: 200.ms, duration: 600.ms).slideY(begin: 0.3, duration: 600.ms);
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(
            color: Colors.grey.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color.withOpacity(0.1),
                    color.withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1E293B),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: const Color(0xFF64748B),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsCards() {
    return Consumer2<EmployeeProvider, AttendanceProvider>(
      builder: (context, employeeProvider, attendanceProvider, child) {
        debugPrint('🏠 [DASHBOARD] Building statistics cards');

        try {
          // Use the provided employeeProvider with null safety
          final totalEmployeesFromList = employeeProvider?.employees?.length ?? 0;
          final int summaryTotalEmployees = _attendanceSummary?.totalEmployees ?? totalEmployeesFromList;
          final int summaryLate = _attendanceSummary?.totalLate ?? 0;
          final int summaryAbsent = _attendanceSummary?.totalAbsent ?? 0;
          final int summaryHalfDay = _attendanceSummary?.totalHalfDay ?? 0;

          // Add late check-ins to present count with null safety
          final todayAttendanceLength = attendanceProvider?.todayAttendance?.length ?? 0;
          final int summaryPresent = (_attendanceSummary?.totalPresent ?? todayAttendanceLength) + summaryLate;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Statistics',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              // New Statistics UI - Horizontal Scroll Cards
              SizedBox(
                height: 130,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _buildModernStatCard(
                      title: 'Total Employees',
                      value: summaryTotalEmployees.toString(),
                      icon: Icons.people,
                      color: Colors.blue,
                      percentage: null,
                    ),
                    const SizedBox(width: 12),
                    _buildModernStatCard(
                      title: 'Present Today',
                      value: summaryPresent.toString(),
                      icon: Icons.check_circle,
                      color: Colors.green,
                      percentage: summaryTotalEmployees > 0 ? (summaryPresent / summaryTotalEmployees * 100).round() : null,
                    ),
                    const SizedBox(width: 12),
                    _buildModernStatCard(
                      title: 'Absent',
                      value: summaryAbsent.toString(),
                      icon: Icons.trending_up,
                      color: Colors.orange,
                      percentage: summaryTotalEmployees > 0 ? (summaryAbsent / summaryTotalEmployees * 100).round() : null,
                    ),
                    const SizedBox(width: 12),
                    _buildModernStatCard(
                      title: 'Late Check In',
                      value: summaryLate.toString(),
                      icon: Icons.access_time,
                      color: Colors.purple,
                      percentage: summaryTotalEmployees > 0 ? (summaryLate / summaryTotalEmployees * 100).round() : null,
                    ),
                  ],
                ),
              ),
            ],
          );
        } catch (e) {
          debugPrint('🏠 [DASHBOARD] Error in statistics cards: $e');
          // Return a fallback UI if there's an error
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Statistics',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                height: 130,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Text('Unable to load statistics'),
                ),
              ),
            ],
          );
        }
      },
    ).animate().fadeIn(delay: 400.ms, duration: 600.ms).slideY(begin: 0.3, duration: 600.ms);
  }

  Widget _buildModernStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    int? percentage,
  }) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.1),
            color.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
              ),
              const Spacer(),
              if (percentage != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$percentage%',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayAttendance() {
    final attendanceList = _attendanceData ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Today\'s Attendance',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(
              color: Colors.grey.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: attendanceList.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: Text(
                      'No attendance records for today',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: attendanceList.length,
                  itemBuilder: (context, index) {
                    final employee = attendanceList[index] as Map<String, dynamic>;
                    final name = employee['name'] ?? 'Unknown';
                    final employeeId = employee['employeeId'] ?? '';
                    final department = employee['department'] ?? '';
                    final details = employee['details'] as List<dynamic>? ?? [];
                    
                    // Get the first detail (today's attendance)
                    final todayDetail = details.isNotEmpty ? details[0] as Map<String, dynamic>? : null;
                    final status = todayDetail?['status']?.toString().toLowerCase() ?? 'absent';
                    final checkIn = todayDetail?['checkIn']?.toString() ?? '-';
                    final checkOut = todayDetail?['checkOut']?.toString() ?? '-';
                    
                    // Determine status color
                    Color statusColor;
                    IconData statusIcon;
                    if (status == 'present') {
                      statusColor = Colors.green;
                      statusIcon = Icons.check_circle;
                    } else if (status == 'late') {
                      statusColor = Colors.orange;
                      statusIcon = Icons.access_time;
                    } else if (status == 'absent') {
                      statusColor = Colors.red;
                      statusIcon = Icons.cancel;
                    } else if (status == 'halfday') {
                      statusColor = Colors.blue;
                      statusIcon = Icons.schedule;
                    } else {
                      statusColor = Colors.grey;
                      statusIcon = Icons.help_outline;
                    }
                    
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: statusColor.withOpacity(0.1),
                                child: Icon(
                                  statusIcon,
                                  color: statusColor,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$employeeId • $department',
                                      style: GoogleFonts.poppins(
                                        fontSize: 10,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: statusColor.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
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
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _buildTimeInfo(
                                  icon: Icons.login,
                                  label: 'Check In',
                                  time: checkIn,
                                  color: Colors.blue,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildTimeInfo(
                                  icon: Icons.logout,
                                  label: 'Check Out',
                                  time: checkOut,
                                  color: Colors.purple,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    ).animate().fadeIn(delay: 600.ms, duration: 600.ms).slideY(begin: 0.3, duration: 600.ms);
  }

  Widget _buildTimeInfo({
    required IconData icon,
    required String label,
    required String time,
    required Color color,
  }) {
    final hasTime = time != '-' && time.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.1),
            color.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasTime ? _formatTime(time) : '-',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
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

  String _formatTime(String timeString) {
    if (timeString == '-' || timeString.isEmpty) {
      return '-';
    }
    try {
      // Handle time format like "11:08:04" or "14:35:18"
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




} 