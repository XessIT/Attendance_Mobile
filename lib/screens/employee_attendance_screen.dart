import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../services/api_service.dart';

class EmployeeAttendanceScreen extends StatefulWidget {
  const EmployeeAttendanceScreen({super.key});

  @override
  State<EmployeeAttendanceScreen> createState() => _EmployeeAttendanceScreenState();
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
                 String dateStr = record['raw_date'] ?? record['date']; // Expecting YYYY-MM-DD ideally
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
                _attendanceMap[key] = (record['status'] ?? '').toString().toLowerCase();
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
    return Column(
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
            ),
            calendarStyle: CalendarStyle(
              outsideDaysVisible: false,
              todayDecoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              selectedDecoration: const BoxDecoration(
                color: Color(0xFF2196F3),
                shape: BoxShape.circle,
              ),
              defaultTextStyle: GoogleFonts.poppins(),
              weekendTextStyle: GoogleFonts.poppins(color: Colors.red[300]),
            ),
            
            // Custom Builders for Markers
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, date, events) {
                // Normalize date to UTC for map lookup
                final key = DateTime.utc(date.year, date.month, date.day);
                final status = _attendanceMap[key];
                
                if (status == null) return null;
                
                Color markerColor;
                if (status == 'present') markerColor = Colors.green;
                else if (status == 'absent') markerColor = Colors.red;
                else if (status == 'late') markerColor = Colors.orange;
                else if (status.contains('half')) markerColor = Colors.purple;
                else return null;

                return Positioned(
                  bottom: 1,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: markerColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                );
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
                Expanded(child: _buildMiniSummaryCard('Present', _reportData!['summary']['present'] ?? 0, Colors.green)),
                const SizedBox(width: 8),
                Expanded(child: _buildMiniSummaryCard('Absent', _reportData!['summary']['absent'] ?? 0, Colors.red)),
                const SizedBox(width: 8),
                Expanded(child: _buildMiniSummaryCard('Late', _reportData!['summary']['late'] ?? 0, Colors.orange)),
                const SizedBox(width: 8),
                Expanded(child: _buildMiniSummaryCard('Half Day', _reportData!['summary']['halfDays'] ?? 0, Colors.purple)),
              ],
            ),
          ),

        // DETAILS SECTION
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
                else if (_selectedDayRecords.isEmpty)
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 30),
                            Icon(Icons.event_note, size: 48, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text(
                              'No records for this day',
                              style: GoogleFonts.poppins(color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      itemCount: _selectedDayRecords.length,
                      itemBuilder: (context, index) {
                        return _buildRecordItem(_selectedDayRecords[index]);
                      },
                    ),
                  ),
              ],
            ),
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
    if (status == 'present') statusColor = Colors.green;
    else if (status == 'absent') statusColor = Colors.red;
    else if (status == 'late') statusColor = Colors.orange;
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                child: _buildTimeDetail('Check In', record['checkIn'], Icons.login, Colors.green),
              ),
              Expanded(
                 child: _buildTimeDetail('Check Out', record['checkOut'], Icons.logout, Colors.red),
              ),
              Expanded(
                 child: _buildTimeDetail('Hours', record['hours'], Icons.timer, Colors.blue),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeDetail(String label, String? value, IconData icon, Color color) {
    final displayValue = value ?? '-';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
           children: [
               Icon(icon, size: 14, color: color),
               const SizedBox(width: 4),
               Text(
                label,
                style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.grey[600],
                ),
                ),
           ]
        ),
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
}
