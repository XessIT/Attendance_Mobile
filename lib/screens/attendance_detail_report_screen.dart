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
        startDate: widget.startDate,
        endDate: widget.endDate,
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
                Color(0xFF1565C0),
                Color(0xFF42A5F5),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorUI()
              : _buildReportTable(),
    );
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

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: MaterialStateProperty.all(Colors.grey[100]),
          columnSpacing: 24,
          columns: [
            _buildTableHeader('Date'),
            _buildTableHeader('Check-In'),
            _buildTableHeader('Check-out'),
            _buildTableHeader('Work Hr'),
            _buildTableHeader('Status'),
            _buildTableHeader('Shift'),
          ],
          rows: _details.map((record) => _buildDataRow(record)).toList(),
        ),
      ),
    );
  }

  DataColumn _buildTableHeader(String label) {
    return DataColumn(
      label: Text(
        label,
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.bold,
          color: const Color(0xFF1565C0),
          fontSize: 13,
        ),
      ),
    );
  }

  DataRow _buildDataRow(dynamic record) {
    final status = (record['status'] ?? '').toString();
    final int recordIndex = _details.indexOf(record);

    return DataRow(
      cells: [
        DataCell(_wrapWithTripleTap(
          Text(
            _formatDate(record['date']),
            style: GoogleFonts.poppins(fontSize: 12),
          ),
          record,
          recordIndex,
        )),
        DataCell(_wrapWithTripleTap(
          Text(
            record['checkIn'] ?? '-',
            style: GoogleFonts.poppins(fontSize: 12),
          ),
          record,
          recordIndex,
        )),
        DataCell(_wrapWithTripleTap(
          Text(
            record['checkOut'] ?? '-',
            style: GoogleFonts.poppins(fontSize: 12),
          ),
          record,
          recordIndex,
        )),
        DataCell(_wrapWithTripleTap(
          Text(
            record['workHours']?.toString() ?? '-',
            style: GoogleFonts.poppins(fontSize: 12),
          ),
          record,
          recordIndex,
        )),
        DataCell(_wrapWithTripleTap(_buildStatusBadge(status), record, recordIndex)),
        DataCell(_wrapWithTripleTap(
          Text(
            record['shift']?.toString() ?? '-',
            style: GoogleFonts.poppins(fontSize: 12),
          ),
          record,
          recordIndex,
        )),
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
