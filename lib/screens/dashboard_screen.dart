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

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  AttendanceSummary? _attendanceSummary;
  List<dynamic>? _attendanceData;
  @override
  void initState() {
    super.initState();
    _refreshData();
    _checkForAppUpdates();
  }

  Future<void> _refreshData() async {
    try {
      await Provider.of<EmployeeProvider>(context, listen: false).loadEmployees();
      await Provider.of<AttendanceProvider>(context, listen: false).loadAttendance();
      await _loadAttendanceSummary();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error refreshing data: $e')),
        );
      }
    }
  }

  Future<void> _loadAttendanceSummary() async {
    try {
      final now = DateTime.now();
      final startDate = DateFormat('yyyy-MM-dd').format(now);
      final endDate = startDate;
      final data = await ApiService.fetchAttendanceSummary(startDate: startDate, endDate: endDate);
      setState(() {
        _attendanceSummary = AttendanceSummary.fromJson(data);
        _attendanceData = data['data'] as List<dynamic>?;
      });
    } catch (e) {
      // Silently ignore in UI if summary fetch fails; keep existing UI functional
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Section
              _buildWelcomeSection(),
              const SizedBox(height: 24),

              // Quick Actions
              _buildQuickActions(),
              const SizedBox(height: 24),

              // Statistics Cards (source counts from attendance summary API)
              _buildStatisticsCards(),
              const SizedBox(height: 24),

              // Today's Attendance
              _buildTodayAttendance(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome Back!',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Manage your employee attendance with face recognition',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.white.withOpacity(0.9),
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
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                icon: Icons.face,
                title: 'Mark Attendance',
                subtitle: 'Face Recognition',
                color: Colors.green,
                onTap: _handleMarkAttendance,
              ),
            ),
            const SizedBox(width: 16),
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
        const SizedBox(height: 16),
        Row(
          children: [
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
            const SizedBox(width: 16),
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
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: color,
                size: 32,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsCards() {
    return Consumer2<EmployeeProvider, AttendanceProvider>(
      builder: (context, employeeProvider, attendanceProvider, child) {
        // Use the provided employeeProvider
        final totalEmployeesFromList = employeeProvider.employees.length;
         final int summaryTotalEmployees = _attendanceSummary?.totalEmployees ?? totalEmployeesFromList;
         final int summaryLate = _attendanceSummary?.totalLate ?? 0;
         final int summaryAbsent = _attendanceSummary?.totalAbsent ?? 0;
         final int summaryHalfDay = _attendanceSummary?.totalHalfDay ?? 0;
         // Add late check-ins to present count
         final int summaryPresent = (_attendanceSummary?.totalPresent ?? attendanceProvider.todayAttendance.length) + summaryLate;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Statistics',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    title: 'Total Employees',
                    value: summaryTotalEmployees.toString(),
                    icon: Icons.people,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    title: 'Present Today',
                    value: summaryPresent.toString(),
                    icon: Icons.check_circle,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    title: 'Absent',
                    value: summaryAbsent.toString(),
                    icon: Icons.trending_up,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    title: 'Late Check In',
                    value: summaryLate.toString(),
                    icon: Icons.access_time,
                    color: Colors.purple,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    ).animate().fadeIn(delay: 400.ms, duration: 600.ms).slideY(begin: 0.3, duration: 600.ms);
  }

  // Attendance summary UI removed to rely solely on API-driven statistics

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const Spacer(),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey,
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
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: attendanceList.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: Text(
                      'No attendance records for today',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.grey,
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
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.withOpacity(0.2)),
                        borderRadius: BorderRadius.circular(8),
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
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$employeeId • $department',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
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
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  status.toUpperCase(),
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
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
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
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
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasTime ? _formatTime(time) : '-',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
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