import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../services/api_service.dart';

class AttendanceDetailReportScreen extends StatefulWidget {
  final int employeeId;
  final String employeeName;
  final String startDate;
  final String endDate;

  const AttendanceDetailReportScreen({
    super.key,
    required this.employeeId,
    required this.employeeName,
    required this.startDate,
    required this.endDate,
  });

  @override
  State<AttendanceDetailReportScreen> createState() => _AttendanceDetailReportScreenState();
}

class _AttendanceDetailReportScreenState extends State<AttendanceDetailReportScreen> {
  bool _isLoading = true;
  List<dynamic> _details = [];
  String? _error;

  late String _currentStartDate = widget.startDate;
  late String _currentEndDate = widget.endDate;

  // For triple tap detection
  final Map<int, int> _tapCounts = {};
  final Map<int, Timer?> _tapTimers = {};

  @override
  void dispose() {
    for (var timer in _tapTimers.values) {
      timer?.cancel();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fetchReport();
  }

  Future<void> _fetchReport() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await ApiService.fetchEmployeeFullReport(
        startDate: _currentStartDate,
        endDate: _currentEndDate,
        employeeId: widget.employeeId,
      );

      if (response['success'] == true) {
        setState(() {
          _details = response['dayWiseDetails'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = response['message'] ?? 'Failed to fetch report';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF1976D2),
                Color(0xFF2196F3),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2196F3).withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text(
              'Daily Attendance - ${widget.employeeName}',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _fetchReport,
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          _buildDateFilter(),
          if (!_isLoading && _error == null && _details.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 8),
              child: _buildAttendanceSummary(),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildErrorUI()
                    : _buildReportTable(),
          ),
        ],
      ),
    );
  }

  Widget _buildDateFilter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      color: Colors.grey.shade50,
      child: Row(
        children: [
          Expanded(
            child: _buildDateButton('From', _currentStartDate, true),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildDateButton('To', _currentEndDate, false),
          ),
        ],
      ),
    );
  }

  Widget _buildDateButton(String label, String dateStr, bool isStart) {
    return InkWell(
      onTap: () => _selectDate(context, isStart),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2196F3).withOpacity(0.4), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2196F3).withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: const Color(0xFF2196F3),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDate(dateStr),
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade800,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2196F3).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.calendar_month_rounded, size: 14, color: Color(0xFF2196F3)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final DateTime initialDate = DateTime.parse(isStart ? _currentStartDate : _currentEndDate);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF2196F3),
              onPrimary: Colors.white,
              onSurface: Colors.black87,
              surface: Colors.white,
            ),
            dialogBackgroundColor: Colors.white,
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF2196F3),
                textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ),
            datePickerTheme: DatePickerThemeData(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              headerBackgroundColor: const Color(0xFF2196F3),
              headerForegroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              headerHeadlineStyle: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
              headerHelpStyle: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              dayStyle: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              weekdayStyle: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
              yearStyle: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        final dateStr = DateFormat('yyyy-MM-dd').format(picked);
        if (isStart) {
          _currentStartDate = dateStr;
        } else {
          _currentEndDate = dateStr;
        }
      });
      _fetchReport();
    }
  }

  Widget _buildErrorUI() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 60, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            _error!,
            style: GoogleFonts.poppins(color: Colors.grey[700]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _fetchReport,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildReportTable() {
    if (_details.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_note, size: 60, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No attendance records found for this period.',
              style: GoogleFonts.poppins(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return Container(
      color: Colors.grey.shade50,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _details.length,
        itemBuilder: (context, index) {
          return _buildDataRowCard(_details[index], index);
        },
      ),
    );
  }

  Widget _buildAttendanceSummary() {
    int presentDays = 0;
    int absentDays = 0;
    int lateDays = 0;
    int halfDays = 0;
    int holidayDays = 0;
    int leaveDays = 0;

    for (var record in _details) {
      String status = (record['status'] ?? '').toString().toLowerCase();
      if (status.contains('present')) presentDays++;
      else if (status.contains('absent')) absentDays++;
      else if (status.contains('late')) lateDays++;
      else if (status.contains('half')) halfDays++;
      else if (status.contains('holiday')) holidayDays++;
      else if (status.contains('leave')) leaveDays++;
    }

    int workingDays = presentDays + absentDays + lateDays + halfDays + leaveDays;
    double attendanceRate = workingDays > 0 ? ((presentDays + lateDays + (halfDays * 0.5)) / workingDays) * 100 : 0;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _buildSummaryCard('Present', presentDays.toString(), const Color(0xFF4CAF50), Icons.check_circle_outline),
          _buildSummaryCard('Absent', absentDays.toString(), Colors.red, Icons.cancel_outlined),
          _buildSummaryCard('Late', lateDays.toString(), Colors.orange, Icons.schedule),
          _buildSummaryCard('Half Day', halfDays.toString(), Colors.amber, Icons.timelapse),
          _buildSummaryCard('Holiday', holidayDays.toString(), Colors.blue, Icons.event_available),
          _buildSummaryCard('Leave', leaveDays.toString(), Colors.purple, Icons.directions_walk),
          _buildSummaryCard('Rate', '${attendanceRate.toStringAsFixed(1)}%', const Color(0xFF2196F3), Icons.pie_chart_outline),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, Color color, IconData icon) {
    return Container(
      width: 105,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2), width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Icon(icon, color: color, size: 16),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDataRowCard(dynamic record, int index) {
    final status = (record['status'] ?? '').toString();
    final date = _formatDate(record['date']);
    final checkIn = record['checkIn'] ?? '--:--';
    final checkOut = record['checkOut'] ?? '--:--';
    final workHrs = record['workHours']?.toString() ?? '0';
    final shift = record['shift']?.toString() ?? '-';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100, width: 1.5),
      ),
      child: _wrapWithTripleTap(
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Header row: Date and Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2196F3).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.calendar_today, color: Color(0xFF2196F3), size: 16),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        date,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                  _buildStatusBadge(status),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                height: 1,
                color: Colors.grey.shade100,
              ),
              const SizedBox(height: 16),
              // Details grid
              Row(
                children: [
                  Expanded(
                    child: _buildDetailItem(Icons.login_rounded, 'Check In', checkIn, Colors.green),
                  ),
                  Expanded(
                    child: _buildDetailItem(Icons.logout_rounded, 'Check Out', checkOut, Colors.orange),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildDetailItem(Icons.timer_outlined, 'Work Hrs', '$workHrs hrs', const Color(0xFF2196F3)),
                  ),
                  Expanded(
                    child: _buildDetailItem(Icons.work_outline, 'Shift', shift, Colors.purple),
                  ),
                ],
              ),
            ],
          ),
        ),
        record,
        index,
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade500,
              ),
            ),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _wrapWithTripleTap(Widget child, dynamic record, int index) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        _tapCounts[index] = (_tapCounts[index] ?? 0) + 1;
        _tapTimers[index]?.cancel();

        if (_tapCounts[index] == 3) {
          _tapCounts[index] = 0;
          _showEditDialog(record);
        } else {
          _tapTimers[index] = Timer(const Duration(milliseconds: 500), () {
            _tapCounts[index] = 0;
          });
        }
      },
      child: child,
    );
  }

  void _showEditDialog(dynamic record) async {
    final String dateStr = record['date'];
    final String currentCheckIn = record['checkIn'] ?? '-';
    final String currentCheckOut = record['checkOut'] ?? '-';
    final String currentStatus = record['status'] ?? 'Present';

    TimeOfDay? checkInTime = _parseTime(currentCheckIn);
    TimeOfDay? checkOutTime = _parseTime(currentCheckOut);
    String selectedStatus = currentStatus;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            'Edit Attendance - ${DateFormat('dd/MM/yyyy').format(DateTime.parse(dateStr))}',
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text('Check-In', style: GoogleFonts.poppins(fontSize: 14)),
                subtitle: Text(checkInTime?.format(context) ?? 'Select Time',
                    style: GoogleFonts.poppins(fontSize: 14, color: Colors.blue)),
                trailing: const Icon(Icons.access_time),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: checkInTime ?? const TimeOfDay(hour: 9, minute: 0),
                  );
                  if (picked != null) setDialogState(() => checkInTime = picked);
                },
              ),
              ListTile(
                title: Text('Check-Out', style: GoogleFonts.poppins(fontSize: 14)),
                subtitle: Text(checkOutTime?.format(context) ?? 'Select Time',
                    style: GoogleFonts.poppins(fontSize: 14, color: Colors.blue)),
                trailing: const Icon(Icons.access_time),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: checkOutTime ?? const TimeOfDay(hour: 18, minute: 0),
                  );
                  if (picked != null) setDialogState(() => checkOutTime = picked);
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedStatus,
                decoration: InputDecoration(
                  labelText: 'Status',
                  labelStyle: GoogleFonts.poppins(fontSize: 14),
                  border: const OutlineInputBorder(),
                ),
                items: ['Present', 'Absent', 'Half Day', 'Late', 'Holiday']
                    .map((s) => DropdownMenuItem(value: s, child: Text(s, style: GoogleFonts.poppins(fontSize: 14))))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => selectedStatus = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: GoogleFonts.poppins()),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                _updateAttendance(dateStr, checkInTime, checkOutTime, selectedStatus);
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0)),
              child: Text('Save', style: GoogleFonts.poppins(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  TimeOfDay? _parseTime(String timeStr) {
    if (timeStr == '-' || timeStr.isEmpty) return null;
    try {
      // Expecting format like "09:54:00 am"
      final parts = timeStr.split(' ');
      final timeParts = parts[0].split(':');
      int hour = int.parse(timeParts[0]);
      int minute = int.parse(timeParts[1]);
      
      if (parts.length > 1) {
        final ampm = parts[1].toLowerCase();
        if (ampm == 'pm' && hour < 12) hour += 12;
        if (ampm == 'am' && hour == 12) hour = 0;
      }
      return TimeOfDay(hour: hour, minute: minute);
    } catch (e) {
      return null;
    }
  }

  Future<void> _updateAttendance(String date, TimeOfDay? checkIn, TimeOfDay? checkOut, String status) async {
    setState(() => _isLoading = true);
    try {
      final Map<String, dynamic> data = {
        'employeeId': widget.employeeId,
        'date': date,
        'status': status,
      };

      if (checkIn != null) {
        final now = DateTime.now();
        final dt = DateTime(now.year, now.month, now.day, checkIn.hour, checkIn.minute);
        data['checkIn'] = DateFormat('hh:mm a').format(dt).toLowerCase();
      }

      if (checkOut != null) {
        final now = DateTime.now();
        final dt = DateTime(now.year, now.month, now.day, checkOut.hour, checkOut.minute);
        data['checkOut'] = DateFormat('hh:mm a').format(dt).toLowerCase();
      }

      final result = await ApiService.addManualAttendance(data);
      if (result['success'] == true) {
        _fetchReport(); // Refresh data
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attendance updated successfully'), backgroundColor: Colors.green),
        );
      } else {
        throw Exception(result['message'] ?? 'Failed to update');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
      setState(() => _isLoading = false);
    }
  }

  Widget _buildStatusBadge(String status) {
    Color bgColor;
    Color textColor;

    switch (status.toLowerCase()) {
      case 'present':
        bgColor = Colors.green[100]!;
        textColor = Colors.green[800]!;
        break;
      case 'absent':
        bgColor = Colors.red[100]!;
        textColor = Colors.red[800]!;
        break;
      case 'holiday':
        bgColor = Colors.blue[100]!;
        textColor = Colors.blue[800]!;
        break;
      case 'half day':
        bgColor = Colors.amber[100]!;
        textColor = Colors.amber[800]!;
        break;
      case 'late':
        bgColor = Colors.orange[100]!;
        textColor = Colors.orange[800]!;
        break;
      default:
        bgColor = Colors.grey[200]!;
        textColor = Colors.grey[800]!;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }
}

class _ExpandableSectionCard extends StatefulWidget {
  final String title;
  final List<Widget> children;
  final IconData? icon;

  const _ExpandableSectionCard({
    required this.title,
    required this.children,
    this.icon,
  });

  @override
  State<_ExpandableSectionCard> createState() => _ExpandableSectionCardState();
}

class _ExpandableSectionCardState extends State<_ExpandableSectionCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2196F3).withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            borderRadius: _isExpanded 
                ? const BorderRadius.vertical(top: Radius.circular(20))
                : BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Row(
                children: [
                  if (widget.icon != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2196F3).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        widget.icon,
                        color: const Color(0xFF2196F3),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  Expanded(
                    child: Text(
                      widget.title,
                      style: GoogleFonts.poppins(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade800,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: Colors.grey.shade500,
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded) ...[
            Container(
              height: 1.5,
              width: double.infinity,
              color: Colors.grey.shade50,
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: widget.children,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
