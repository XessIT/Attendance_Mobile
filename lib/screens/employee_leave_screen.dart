import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../services/api_service.dart';

class EmployeeLeaveScreen extends StatefulWidget {
  const EmployeeLeaveScreen({super.key});

  @override
  State<EmployeeLeaveScreen> createState() => _EmployeeLeaveScreenState();
}

class _EmployeeLeaveScreenState extends State<EmployeeLeaveScreen> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            child: TabBar(
              labelColor: const Color(0xFF2196F3),
              unselectedLabelColor: Colors.grey,
              indicatorColor: const Color(0xFF2196F3),
              labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              tabs: const [
                Tab(text: 'Apply Leave'),
                Tab(text: 'My Leaves'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                const ApplyLeaveTab(),
                const MyLeavesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TAB 1: APPLY LEAVE (Existing Logic)
// ---------------------------------------------------------------------------
class ApplyLeaveTab extends StatefulWidget {
  const ApplyLeaveTab({super.key});

  @override
  State<ApplyLeaveTab> createState() => _ApplyLeaveTabState();
}

class _ApplyLeaveTabState extends State<ApplyLeaveTab> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  
  String _leaveType = 'Casual';
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  DateTime _focusedDay = DateTime.now();
  bool _isLoading = false;

  // New Fields for Session Management
  String _startDaySession = 'First Half'; // Default: Start of the day
  String _endDaySession = 'Second Half'; // Default: End of the day
  File? _certificateFile;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _pickCertificate() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      setState(() {
        _certificateFile = File(image.path);
      });
    }
  }

  Future<void> _applyLeave() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_rangeStart == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a start date')),
      );
      return;
    }
    
    final effectiveEndDate = _rangeEnd ?? _rangeStart;

    setState(() {
      _isLoading = true;
    });

    try {
      final leaveData = {
        'leaveType': _leaveType,
        'startDate': DateFormat('yyyy-MM-dd').format(_rangeStart!),
        'endDate': DateFormat('yyyy-MM-dd').format(effectiveEndDate!),
        'reason': _reasonController.text.trim(),
        'startDaySession': _startDaySession,
        'endDaySession': _endDaySession,
      };

      await ApiService.applyLeave(leaveData, certificate: _certificateFile);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Leave application submitted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          _reasonController.clear();
          _rangeStart = null;
          _rangeEnd = null;
          _focusedDay = DateTime.now();
          _leaveType = 'Casual';
          _startDaySession = 'First Half';
          _endDaySession = 'Second Half';
          _certificateFile = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}'),
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- LEAVE TYPE ---
                    Text(
                      'Leave Type',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _leaveType,
                          isExpanded: true,
                          items: ['Casual', 'Medical', 'Other'].map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: (newValue) {
                            setState(() {
                              _leaveType = newValue!;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // --- DATE SELECTION ---
                    Text(
                      'Select Dates',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TableCalendar(
                        firstDay: DateTime.now(),
                        lastDay: DateTime(2100),
                        focusedDay: _focusedDay,
                        calendarFormat: CalendarFormat.month,
                        rangeSelectionMode: RangeSelectionMode.toggledOn,
                        rangeStartDay: _rangeStart,
                        rangeEndDay: _rangeEnd,
                        
                        onRangeSelected: (start, end, focusedDay) {
                          setState(() {
                            _rangeStart = start;
                            _rangeEnd = end;
                            _focusedDay = focusedDay;
                          });
                        },
                        onPageChanged: (focusedDay) {
                          _focusedDay = focusedDay;
                        },
                        
                        headerStyle: HeaderStyle(
                          titleCentered: true,
                          formatButtonVisible: false,
                          titleTextStyle: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        calendarStyle: CalendarStyle(
                          todayDecoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                          rangeHighlightColor: const Color(0xFFE3F2FD),
                          rangeStartDecoration: const BoxDecoration(
                            color: Color(0xFF2196F3),
                            shape: BoxShape.circle,
                          ),
                          rangeEndDecoration: const BoxDecoration(
                            color: Color(0xFF2196F3),
                            shape: BoxShape.circle,
                          ),
                          defaultTextStyle: GoogleFonts.poppins(),
                          weekendTextStyle: GoogleFonts.poppins(color: Colors.red[300]),
                        ),
                      ),
                    ),
                    if (_rangeStart != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          _rangeEnd != null
                              ? 'Selected: ${DateFormat('dd MMM').format(_rangeStart!)} - ${DateFormat('dd MMM').format(_rangeEnd!)}'
                              : 'Selected: ${DateFormat('dd MMM').format(_rangeStart!)}',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF2196F3),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    
                    const SizedBox(height: 20),

                    // --- SESSION SELECTION (Visible if dates selected) ---
                    if (_rangeStart != null) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${DateFormat('dd MMM').format(_rangeStart!)} (Start)', 
                                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey[700])),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey[300]!),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _startDaySession,
                                      isExpanded: true,
                                      style: GoogleFonts.poppins(fontSize: 13, color: Colors.black87),
                                      items: ['First Half', 'Second Half'].map((String value) {
                                        return DropdownMenuItem<String>(
                                          value: value,
                                          child: Text(value),
                                        );
                                      }).toList(),
                                      onChanged: (newValue) {
                                        setState(() {
                                          _startDaySession = newValue!;
                                        });
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${DateFormat('dd MMM').format(_rangeEnd ?? _rangeStart!)} (End)', 
                                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey[700])),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey[300]!),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _endDaySession,
                                      isExpanded: true,
                                      style: GoogleFonts.poppins(fontSize: 13, color: Colors.black87),
                                      items: ['First Half', 'Second Half'].map((String value) {
                                        return DropdownMenuItem<String>(
                                          value: value,
                                          child: Text(value),
                                        );
                                      }).toList(),
                                      onChanged: (newValue) {
                                        setState(() {
                                          _endDaySession = newValue!;
                                        });
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Helper text explaining the calculation
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                             Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                             const SizedBox(width: 8),
                             Expanded(
                               child: Text(
                                 _calculateDurationText(),
                                 style: GoogleFonts.poppins(fontSize: 11, color: Colors.blue[900]),
                               ),
                             ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // --- CERTIFICATE UPLOAD (Visible only for Medical Leave) ---
                    if (_leaveType == 'Medical') ...[
                      Row(
                        children: [
                          Icon(Icons.medical_services, size: 16, color: Colors.blue[700]),
                          const SizedBox(width: 8),
                          Text(
                            'Medical Certificate',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _pickCertificate,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: _certificateFile != null ? Colors.green : Colors.blue.withOpacity(0.3),
                              style: BorderStyle.solid,
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            color: _certificateFile != null 
                                ? Colors.green.withOpacity(0.05) 
                                : Colors.blue.withOpacity(0.05),
                          ),
                          child: Column(
                            children: [
                              if (_certificateFile != null) ...[
                                 const Icon(Icons.check_circle_rounded, color: Colors.green, size: 40),
                                 const SizedBox(height: 12),
                                 Text(
                                   'Certificate Attached',
                                   style: GoogleFonts.poppins(
                                     fontSize: 14, 
                                     fontWeight: FontWeight.w600, 
                                     color: Colors.green[700]
                                   ),
                                 ),
                                 const SizedBox(height: 4),
                                 Text(
                                   _certificateFile!.path.split('/').last,
                                   style: GoogleFonts.poppins(fontSize: 12, color: Colors.black54),
                                   textAlign: TextAlign.center,
                                   maxLines: 1,
                                   overflow: TextOverflow.ellipsis,
                                 ),
                                 const SizedBox(height: 12),
                                 SizedBox(
                                   height: 36,
                                   child: TextButton.icon(
                                     onPressed: () {
                                       setState(() {
                                         _certificateFile = null;
                                       });
                                     },
                                     style: TextButton.styleFrom(
                                       backgroundColor: Colors.white,
                                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                       side: BorderSide(color: Colors.red[200]!),
                                     ),
                                     icon: Icon(Icons.delete_outline, size: 18, color: Colors.red[400]),
                                     label: Text('Remove File', style: GoogleFonts.poppins(color: Colors.red[400], fontSize: 13)),
                                   ),
                                 ),
                              ] else ...[
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.add_a_photo_outlined, color: Colors.blue[400], size: 30),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Tap to upload Medical Document',
                                  style: GoogleFonts.poppins(
                                    color: Colors.blue[700], 
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Supports: JPG, PNG',
                                  style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 11),
                                ),
                              ]
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    
                    // --- REASON ---
                    Text(
                      'Reason',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _reasonController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Enter reason for leave...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a reason';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _applyLeave,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2196F3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text(
                                'Submit Application',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _calculateDurationText() {
    if (_rangeStart == null) return '';
    final end = _rangeEnd ?? _rangeStart!;
    int days = end.difference(_rangeStart!).inDays + 1;
    double duration = days.toDouble();
    
    // Adjust start day
    if (_startDaySession == 'Second Half') {
      duration -= 0.5;
    }
    
    // Adjust end day
    if (_endDaySession == 'First Half') {
      duration -= 0.5;
    }
    
    return 'Total Duration: $duration Days';
  }
}



// ---------------------------------------------------------------------------
// TAB 2: MY LEAVES (New Calendar Logic with Filters)
// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------
// TAB 2: MY LEAVES (New Calendar Logic with Filters)
// ---------------------------------------------------------------------------
class MyLeavesTab extends StatefulWidget {
  const MyLeavesTab({super.key});

  @override
  State<MyLeavesTab> createState() => _MyLeavesTabState();
}

class _MyLeavesTabState extends State<MyLeavesTab> {
  bool _isLoading = true;
  List<dynamic> _leaves = [];
  String? _error;

  String _selectedStatus = 'All'; // Filter Status
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  // Map to store leaves for each day for markers
  Map<DateTime, List<dynamic>> _leavesMap = {};
  List<dynamic> _selectedDayLeaves = [];

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadLeaves();
  }

  Future<void> _loadLeaves() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Fetch leaves for the entire year to handle most cases
      final startDate = DateTime(_focusedDay.year, 1, 1);
      final endDate = DateTime(_focusedDay.year, 12, 31);

      final result = await ApiService.getMyLeaves(
        status: _selectedStatus == 'All' ? null : _selectedStatus,
        startDate: startDate,
        endDate: endDate,
      );

      if (mounted) {
        setState(() {
          if (result['data'] is List) {
            _leaves = result['data'];
          } else {
            _leaves = [];
          }

          _processLeavesToMap();
          _updateSelectedDayLeaves();
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

  void _processLeavesToMap() {
    _leavesMap = {};
    for (var leave in _leaves) {
      if (leave is! Map) continue;
      
      try {
        final startDateStr = leave['startDate']?.toString();
        final endDateStr = leave['endDate']?.toString();
        
        if (startDateStr != null && endDateStr != null) {
          DateTime start = DateTime.parse(startDateStr);
          DateTime end = DateTime.parse(endDateStr);

          // Iterate through each day of the leave
          for (int i = 0; i <= end.difference(start).inDays; i++) {
            DateTime day = start.add(Duration(days: i));
            final key = DateTime.utc(day.year, day.month, day.day);
            
            if (_leavesMap[key] == null) {
              _leavesMap[key] = [];
            }
            _leavesMap[key]!.add(leave);
          }
        }
      } catch (e) {
        print('Error processing leave dates: $e');
      }
    }
  }

  void _updateSelectedDayLeaves() {
    if (_selectedDay == null) {
      _selectedDayLeaves = [];
      return;
    }
    
    final key = DateTime.utc(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day);
    _selectedDayLeaves = _leavesMap[key] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // FILTERS SECTION
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          color: Colors.white,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['All', 'Pending', 'Approved', 'Rejected', 'Cancelled']
                  .map((status) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(status),
                          selected: _selectedStatus == status,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedStatus = status;
                              });
                              _loadLeaves();
                            }
                          },
                          
                          // Custom Styling
                          selectedColor: const Color(0xFFE3F2FD),
                          backgroundColor: Colors.white,
                          labelStyle: GoogleFonts.poppins(
                            fontSize: 13,
                            color: _selectedStatus == status
                                ? const Color(0xFF2196F3)
                                : Colors.grey[700],
                            fontWeight: _selectedStatus == status
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: _selectedStatus == status
                                  ? const Color(0xFF2196F3)
                                  : Colors.grey[300]!,
                            ),
                          ),
                          showCheckmark: false,
                        ),
                      ))
                  .toList(),
            ),
          ),
        ),

        // CALENDAR SECTION
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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
                  _updateSelectedDayLeaves();
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
              if (focusedDay.year != _selectedDay?.year) {
                  _loadLeaves();
              }
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
                final key = DateTime.utc(date.year, date.month, date.day);
                final leavesOnDay = _leavesMap[key];
                
                if (leavesOnDay == null || leavesOnDay.isEmpty) return null;
                
                Color markerColor = Colors.grey;
                bool hasApproved = leavesOnDay.any((l) => (l['status'] ?? '').toString().toLowerCase() == 'approved');
                bool hasPending = leavesOnDay.any((l) => (l['status'] ?? '').toString().toLowerCase() == 'pending');
                bool hasRejected = leavesOnDay.any((l) => (l is Map && (l['status'] ?? '').toString().toLowerCase() == 'rejected') || (l is Map && (l['status'] ?? '').toString().toLowerCase() == 'cancelled'));
                
                if (hasApproved) markerColor = Colors.green;
                else if (hasPending) markerColor = Colors.orange;
                else if (hasRejected) markerColor = Colors.red;

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
                const SizedBox(height: 8),
                
                if (_isLoading)
                   const Center(child: CircularProgressIndicator())
                else if (_error != null)
                   Center(child: Text('Error: $_error'))
                else if (_selectedDayLeaves.isEmpty)
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 30),
                            Icon(Icons.event_available, size: 48, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text(
                              'No leaves for this day',
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
                      itemCount: _selectedDayLeaves.length,
                      itemBuilder: (context, index) {
                        final leave = _selectedDayLeaves[index];
                        // Ensure we pass a map or handle nulls
                        if (leave is Map<String, dynamic>) {
                           return _buildLeaveCard(leave);
                        } else if (leave is Map) {
                           return _buildLeaveCard(Map<String, dynamic>.from(leave));
                        }
                        return const SizedBox.shrink(); // fallback
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

  Future<void> _cancelLeave(int leaveId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cancel LeaveRequest', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to cancel this leave request?', style: GoogleFonts.poppins()),
        actions: [
          TextButton(
             onPressed: () => Navigator.of(context).pop(false),
             child: Text('No', style: GoogleFonts.poppins()),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
             style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Yes, Cancel', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      await ApiService.cancelLeave(leaveId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Leave cancelled successfully'), backgroundColor: Colors.green),
        );
        _loadLeaves(); 
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildLeaveCard(Map<String, dynamic> leave) {
    // Defensive extraction
    final status = (leave['status'] ?? 'Pending').toString();
    final leaveType = (leave['leaveType'] ?? 'Leave').toString();
    final startDate = (leave['startDate'] ?? '').toString();
    final endDate = (leave['endDate'] ?? '').toString();
    final reason = (leave['reason'] ?? '').toString();
    final leaveId = leave['id']; // Extract ID
    
    Color statusColor;
    switch (status.toLowerCase()) {
      case 'approved':
        statusColor = Colors.green;
        break;
      case 'rejected':
      case 'cancelled':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.orange;
    }

    // Approver logic - defensive
    String? approverName;
    if (leave['approver'] is Map) {
      approverName = leave['approver']['name']?.toString();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border(
           left: BorderSide(color: statusColor, width: 4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                leaveType,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.date_range, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Text(
                '$startDate  -  $endDate',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          if (reason.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              reason,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          // CANCEL BUTTON
          if (status.toLowerCase() == 'pending' && leaveId != null) ...[
             const SizedBox(height: 16),
             Align(
               alignment: Alignment.centerRight,
               child: SizedBox(
                 width: 100,
                 child: OutlinedButton.icon(
                   onPressed: () => _cancelLeave(leaveId is int ? leaveId : int.parse(leaveId.toString())),
                   icon: const Icon(Icons.cancel_outlined, size: 16, color: Colors.red),
                   label: Text('Cancel', style: GoogleFonts.poppins(color: Colors.red, fontSize: 12)),
                   style: OutlinedButton.styleFrom(
                     side: const BorderSide(color: Colors.red),
                     padding: const EdgeInsets.symmetric(vertical: 8),
                   ),
                 ),
               ),
             ),
          ],
          if (approverName != null) ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.check_circle_outline, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  'Approver: $approverName',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
