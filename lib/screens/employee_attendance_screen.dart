import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../services/api_service.dart';
import '../widgets/no_internet_widget.dart';

class EmployeeAttendanceScreen extends StatefulWidget {
  const EmployeeAttendanceScreen({super.key});

  @override
  State<EmployeeAttendanceScreen> createState() =>
      _EmployeeAttendanceScreenState();
}

class _EmployeeAttendanceScreenState extends State<EmployeeAttendanceScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _reportData;
  String? _error;

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  // Map to store attendance status for each day
  Map<DateTime, String> _attendanceMap = {};
  List<dynamic> _selectedDayRecords = [];

  String _readRecordTime(Map<String, dynamic> record, List<String> keys) {
    for (final key in keys) {
      final value = record[key];
      if (value != null &&
          value.toString().isNotEmpty &&
          value.toString() != '-') {
        return value.toString();
      }
    }
    return '-';
  }

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Load data for the current focused month
      final startDate = DateTime(_focusedDay.year, _focusedDay.month, 1);
      final endDate = DateTime(_focusedDay.year, _focusedDay.month + 1, 0);

      final data = await ApiService.getEmployeeAttendanceReport(
        startDate: startDate,
        endDate: endDate,
        status: 'All', // Fetch all statuses
      );

      if (mounted) {
        setState(() {
          if (data['data'] != null) {
            _reportData = data['data'];
          } else {
            _reportData = data;
          }

          // Process records into attendance map
          _attendanceMap = {};
          final List records = _reportData?['records'] ?? [];
          for (var record in records) {
            if (record['date'] != null) {
              // Parse date string (assuming 'YYYY-MM-DD' or similar format that DateTime.parse handles,
              // or match format from API)
              // The API commonly returns formatted date strings, we might need to be careful.
              // Let's assume the API returns 'DD-MM-YYYY' or similar based on previous context,
              // but DateTime.parse likes 'YYYY-MM-DD'.
              // We'll try to parse safely.

              try {
                // If the date is 'Fri, 10 Jan 2026', we need to parse it or use the raw ISO date if available.
                // Assuming record has a standard date field or we parse 'date'.
                // Let's try to parse flexible.
                DateTime? date;
                // If the API returns a 'raw_date' or similar ISO string Use that.
                // If not, try parsing the display date.
                // For now, let's look for a parsable format.
                // If ApiService logic formats it, ideally we want "YYYY-MM-DD".
                // Let's try to parse the 'date' string if it looks like one, or rely on index.

                // Simplest: Check if the record has an ISO date.
                // If not, we might need to rely on the fact that records are for the requested range.

                // Let's assume standard ISO for parsing or a parsable string.
                // NOTE: The previous UI just displayed text.
                // We will try standard parsing first.
                String dateStr = record['raw_date'] ??
                    record['date']; // Expecting YYYY-MM-DD ideally
                // If format is "10-01-2026", convert to "2026-01-10"
                if (dateStr.contains('-')) {
                  var parts = dateStr.split('-');
                  if (parts[0].length == 2 && parts[2].length == 4) {
                    dateStr = '${parts[2]}-${parts[1]}-${parts[0]}';
                  }
                }

                date = DateTime.parse(dateStr);

                // key needs to be normalized to UTC midnight for TableCalendar matches usually
                final key = DateTime.utc(date.year, date.month, date.day);
                _attendanceMap[key] =
                    (record['status'] ?? '').toString().toLowerCase();
              } catch (e) {
                print('Error parsing date for record: $record');
              }
            }
          }

          _updateSelectedDayRecords();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  void _updateSelectedDayRecords() {
    if (_selectedDay == null || _reportData == null) {
      _selectedDayRecords = [];
      return;
    }

    final records = _reportData?['records'] as List? ?? [];
    _selectedDayRecords = records.where((record) {
      try {
        String dateStr = record['raw_date'] ?? record['date'];
        if (dateStr.contains('-')) {
          var parts = dateStr.split('-');
          if (parts[0].length == 2 && parts[2].length == 4) {
            dateStr = '${parts[2]}-${parts[1]}-${parts[0]}';
          }
        }
        final date = DateTime.parse(dateStr);
        return isSameDay(date, _selectedDay);
      } catch (e) {
        return false;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // CALENDAR SECTION
          Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TableCalendar(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,

              selectedDayPredicate: (day) {
                return isSameDay(_selectedDay, day);
              },
              onDaySelected: (selectedDay, focusedDay) {
                if (!isSameDay(_selectedDay, selectedDay)) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                    _updateSelectedDayRecords();
                  });
                }
              },
              onFormatChanged: (format) {
                if (_calendarFormat != format) {
                  setState(() {
                    _calendarFormat = format;
                  });
                }
              },
              onPageChanged: (focusedDay) {
                _focusedDay = focusedDay;
                _loadReport(); // Reload data for the new month
              },

              // Calendar Style
              headerStyle: HeaderStyle(
                titleCentered: true,
                formatButtonVisible: false,
                titleTextStyle: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                rightChevronIcon: const Icon(Icons.chevron_right),
                leftChevronIcon: const Icon(Icons.chevron_left),
                headerPadding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                formatButtonDecoration: BoxDecoration(
                  color: const Color(0xFF152A4A),
                  borderRadius: BorderRadius.circular(12),
                ),
                formatButtonTextStyle: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
                headerMargin: const EdgeInsets.only(bottom: 16),
                leftChevronPadding: const EdgeInsets.only(left: 16),
                rightChevronPadding: const EdgeInsets.only(right: 16),
              ),
              calendarStyle: CalendarStyle(
                outsideDaysVisible: false,
                todayDecoration: BoxDecoration(
                  color: const Color(0xFF152A4A).withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                selectedDecoration: const BoxDecoration(
                  color: Color(0xFF152A4A),
                  shape: BoxShape.circle,
                ),
                defaultTextStyle: GoogleFonts.poppins(),
                weekendTextStyle: GoogleFonts.poppins(color: Colors.red[300]),
              ),

              // Custom Builders for enhanced highlighting
              calendarBuilders: CalendarBuilders(
                headerTitleBuilder: (context, day) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        DateFormat('MMMM yyyy').format(day),
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _showLegendDialog(),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF152A4A).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            Icons.info_outline,
                            size: 18,
                            color: const Color(0xFF152A4A),
                          ),
                        ),
                      ),
                    ],
                  );
                },
                defaultBuilder: (context, day, focusedDay) {
                  // Normalize date to UTC for map lookup
                  final key = DateTime.utc(day.year, day.month, day.day);
                  final status = _attendanceMap[key];

                  if (status == null) {
                    return null;
                  }

                  Color backgroundColor;
                  Color textColor;
                  IconData? statusIcon;

                  if (status == 'present') {
                    backgroundColor = Colors.green.withOpacity(0.15);
                    textColor = Colors.green;
                    statusIcon = Icons.check_circle;
                  } else if (status == 'absent') {
                    backgroundColor = Colors.red.withOpacity(0.15);
                    textColor = Colors.red;
                    statusIcon = Icons.cancel;
                  } else if (status == 'late') {
                    backgroundColor = Colors.orange.withOpacity(0.15);
                    textColor = Colors.orange;
                    statusIcon = Icons.access_time;
                  } else if (status != null && status.contains('half')) {
                    backgroundColor = Colors.purple.withOpacity(0.15);
                    textColor = Colors.purple;
                    statusIcon = Icons.remove_circle;
                  } else {
                    return null;
                  }

                  return Container(
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: textColor.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Text(
                            '${day.day}',
                            style: GoogleFonts.poppins(
                              color: textColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: Icon(
                            statusIcon,
                            size: 12,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                  );
                },

                todayBuilder: (context, day, focusedDay) {
                  // Normalize date to UTC for map lookup
                  final key = DateTime.utc(day.year, day.month, day.day);
                  final status = _attendanceMap[key];

                  Color backgroundColor = const Color(0xFF152A4A).withOpacity(0.3);
                  Color textColor = const Color(0xFF152A4A);
                  IconData? statusIcon;
                  FontWeight fontWeight = FontWeight.bold;

                  if (status == null) {
                    // Return default today styling if no status
                    return Container(
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: backgroundColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: textColor,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '${day.day}',
                          style: GoogleFonts.poppins(
                            color: textColor,
                            fontWeight: fontWeight,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    );
                  }

                  if (status == 'present') {
                    backgroundColor = Colors.green.withOpacity(0.3);
                    textColor = Colors.green;
                    statusIcon = Icons.check_circle;
                  } else if (status == 'absent') {
                    backgroundColor = Colors.red.withOpacity(0.3);
                    textColor = Colors.red;
                    statusIcon = Icons.cancel;
                  } else if (status == 'late') {
                    backgroundColor = Colors.orange.withOpacity(0.3);
                    textColor = Colors.orange;
                    statusIcon = Icons.access_time;
                  } else if (status != null && status.contains('half')) {
                    backgroundColor = Colors.purple.withOpacity(0.3);
                    textColor = Colors.purple;
                    statusIcon = Icons.remove_circle;
                  }

                  return Container(
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: textColor,
                        width: 2,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Text(
                            '${day.day}',
                            style: GoogleFonts.poppins(
                              color: textColor,
                              fontWeight: fontWeight,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (statusIcon != null)
                          Positioned(
                            top: 2,
                            right: 2,
                            child: Icon(
                              statusIcon,
                              size: 12,
                              color: textColor,
                            ),
                          ),
                      ],
                    ),
                  );
                },

                selectedBuilder: (context, day, focusedDay) {
                  // Normalize date to UTC for map lookup
                  final key = DateTime.utc(day.year, day.month, day.day);
                  final status = _attendanceMap[key];

                  Color backgroundColor = const Color(0xFF152A4A);
                  Color textColor = Colors.white;
                  IconData? statusIcon;

                  if (status == null) {
                    // Return default selected styling if no status
                    return Container(
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: backgroundColor,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: backgroundColor.withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          '${day.day}',
                          style: GoogleFonts.poppins(
                            color: textColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    );
                  }

                  if (status == 'present') {
                    backgroundColor = Colors.green;
                    statusIcon = Icons.check_circle;
                  } else if (status == 'absent') {
                    backgroundColor = Colors.red;
                    statusIcon = Icons.cancel;
                  } else if (status == 'late') {
                    backgroundColor = Colors.orange;
                    statusIcon = Icons.access_time;
                  } else if (status != null && status.contains('half')) {
                    backgroundColor = Colors.purple;
                    statusIcon = Icons.remove_circle;
                  }

                  return Container(
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: backgroundColor.withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Text(
                            '${day.day}',
                            style: GoogleFonts.poppins(
                              color: textColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (statusIcon != null)
                          Positioned(
                            top: 2,
                            right: 2,
                            child: Icon(
                              statusIcon,
                              size: 12,
                              color: textColor,
                            ),
                          ),
                      ],
                    ),
                  );
                },

                // Keep the marker builder as fallback for any days not handled above
                markerBuilder: (context, date, events) {
                  // This is now handled by the builders above, so return null
                  return null;
                },
              ),
            ),
          ),

          // SUMMARY SECTION
          if (_reportData != null)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                      child: _buildMiniSummaryCard(
                          'Present',
                          _reportData!['summary']['present'] ?? 0,
                          Colors.green)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _buildMiniSummaryCard('Absent',
                          _reportData!['summary']['absent'] ?? 0, Colors.red)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _buildMiniSummaryCard('Late',
                          _reportData!['summary']['late'] ?? 0, Colors.orange)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _buildMiniSummaryCard(
                          'Half Day',
                          _reportData!['summary']['halfDays'] ?? 0,
                          Colors.purple)),
                ],
              ),
            ),

          // DETAILS SECTION
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(30),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  offset: Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _selectedDay != null
                          ? DateFormat('EEEE, d MMMM').format(_selectedDay!)
                          : 'Select a Day',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (_error != null)
                  _buildErrorUI()
                else if (_selectedDayRecords.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 30),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.event_note,
                              size: 48, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text(
                            'No records for this day',
                            style: GoogleFonts.poppins(color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Column(
                    children: _selectedDayRecords
                        .map((record) => _buildRecordItem(record))
                        .toList(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showLegendDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Attendance Legend',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Color codes for attendance status:',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16.0,
              runSpacing: 12.0,
              children: [
                _buildLegendItem('Present', Colors.green, Icons.check_circle),
                _buildLegendItem('Absent', Colors.red, Icons.cancel),
                _buildLegendItem('Late', Colors.orange, Icons.access_time),
                _buildLegendItem(
                    'Half Day', Colors.purple, Icons.remove_circle),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Tap any day in the calendar to see detailed attendance information.',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey[500],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Got it!',
              style: GoogleFonts.poppins(
                color: const Color(0xFF152A4A),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: color.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            size: 12,
            color: color,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildMiniSummaryCard(String label, dynamic value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value.toString(),
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordItem(Map<String, dynamic> record) {
    final status = (record['status'] ?? '').toString().toLowerCase();
    Color statusColor = Colors.grey;
    if (status == 'present')
      statusColor = Colors.green;
    else if (status == 'absent')
      statusColor = Colors.red;
    else if (status == 'late')
      statusColor = Colors.orange;
    else if (status.contains('half')) statusColor = Colors.purple;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50], // Slightly different bg inside white container
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Status',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  (record['status'] ?? '').toString().toUpperCase(),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildTimeDetail(
                  'Check In',
                  _readRecordTime(record,
                      ['checkIn', 'check_in', 'checkInTime', 'check_in_time']),
                  Icons.login,
                  Colors.green,
                ),
              ),
              Expanded(
                child: _buildTimeDetail(
                  'Check Out',
                  _readRecordTime(record, [
                    'checkOut',
                    'check_out',
                    'checkOutTime',
                    'check_out_time'
                  ]),
                  Icons.logout,
                  Colors.red,
                ),
              ),
              Expanded(
                child: _buildTimeDetail(
                    'Hours', record['hours'], Icons.timer, const Color(0xFF152A4A)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeDetail(
      String label, String? value, IconData icon, Color color) {
    final displayValue = value ?? '-';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: Colors.grey[600],
            ),
          ),
        ]),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 0), // Already aligned nicely
          child: Text(
            displayValue,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorUI() {
    final isNetworkError = _error!.toLowerCase().contains('network') ||
        _error!.toLowerCase().contains('connection') ||
        _error!.toLowerCase().contains('xmlhttprequest');

    if (isNetworkError) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: NoInternetWidget(onRetry: _loadReport),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              'Error: $_error',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: Colors.red[600]),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadReport,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

