import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../services/api_service.dart';
import '../utils/auth_utils.dart';
import '../models/leave_balance.dart';
import '../widgets/no_internet_widget.dart';
import 'leave_balance_detail_screen.dart';

class EmployeeLeaveScreen extends StatefulWidget {
  final int initialTab;
  const EmployeeLeaveScreen({super.key, this.initialTab = 0});

  @override
  State<EmployeeLeaveScreen> createState() => _EmployeeLeaveScreenState();
}

class _EmployeeLeaveScreenState extends State<EmployeeLeaveScreen> {
  @override
  Widget build(BuildContext context) {
    final bool isSmallDevice = MediaQuery.of(context).size.width < 380;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        title: Text('Leave & Permission', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: DefaultTabController(
        length: 4,
        initialIndex: widget.initialTab,
        child: Column(
          children: [
            Container(
              color: Colors.white,
              child: TabBar(
                labelColor: const Color(0xFF152A4A),
                unselectedLabelColor: Colors.grey,
                indicatorColor: const Color(0xFF152A4A),
                labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: isSmallDevice ? 12 : 14),
                tabs: [
                  const Tab(text: 'Apply Leave'),
                  const Tab(text: 'Permission'),
                  const Tab(text: 'My History'),
                  const Tab(text: 'Balance'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  const ApplyLeaveTab(),
                  const ApplyPermissionTab(),
                  const MyLeavesTab(),
                  const LeaveBalanceTab(),
                ],
              ),
            ),
          ],
        ),
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
                          items: ['Casual', 'Medical', 'Permission', 'Other'].map((String value) {
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
                            color: const Color(0xFF152A4A).withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                          rangeHighlightColor: const Color(0xFFE3F2FD),
                          rangeStartDecoration: const BoxDecoration(
                            color: Color(0xFF152A4A),
                            shape: BoxShape.circle,
                          ),
                          rangeEndDecoration: const BoxDecoration(
                            color: Color(0xFF152A4A),
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
                            color: const Color(0xFF152A4A),
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
                          color: const Color(0xFF152A4A).withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                             Icon(Icons.info_outline, size: 16, color: Color(0xFF152A4A)),
                             const SizedBox(width: 8),
                             Expanded(
                               child: Text(
                                 _calculateDurationText(),
                                 style: GoogleFonts.poppins(fontSize: 11, color: Color(0xFF152A4A)),
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
                          Icon(Icons.medical_services, size: 16, color: Color(0xFF152A4A)),
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
                              color: _certificateFile != null ? Colors.green : const Color(0xFF152A4A).withOpacity(0.3),
                              style: BorderStyle.solid,
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            color: _certificateFile != null 
                                ? Colors.green.withOpacity(0.05) 
                                : const Color(0xFF152A4A).withOpacity(0.05),
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
                                  child: Icon(Icons.add_a_photo_outlined, color: Color(0x990F172A), size: 30),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Tap to upload Medical Document',
                                  style: GoogleFonts.poppins(
                                    color: Color(0xFF152A4A), 
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
                          backgroundColor: const Color(0xFF152A4A),
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
                                ? const Color(0xFF152A4A)
                                : Colors.grey[700],
                            fontWeight: _selectedStatus == status
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: _selectedStatus == status
                                  ? const Color(0xFF152A4A)
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
                final key = DateTime.utc(day.year, day.month, day.day);
                final leavesOnDay = _leavesMap[key];
                
                if (leavesOnDay == null || leavesOnDay.isEmpty) {
                  return null;
                }
                
                Color backgroundColor;
                Color textColor;
                IconData? statusIcon;
                
                bool hasApproved = leavesOnDay.any((l) => (l['status'] ?? '').toString().toLowerCase() == 'approved');
                bool hasPending = leavesOnDay.any((l) => (l['status'] ?? '').toString().toLowerCase() == 'pending');
                bool hasRejected = leavesOnDay.any((l) => (l is Map && (l['status'] ?? '').toString().toLowerCase() == 'rejected') || (l is Map && (l['status'] ?? '').toString().toLowerCase() == 'cancelled'));
                
                if (hasApproved) {
                  backgroundColor = Colors.red.withOpacity(0.15);
                  textColor = Colors.red;
                  statusIcon = Icons.check_circle;
                } else if (hasPending) {
                  backgroundColor = Colors.red.withOpacity(0.25);
                  textColor = Colors.red.shade700;
                  statusIcon = Icons.hourglass_empty;
                } else if (hasRejected) {
                  backgroundColor = Colors.red.withOpacity(0.15);
                  textColor = Colors.red;
                  statusIcon = Icons.cancel;
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
                final key = DateTime.utc(day.year, day.month, day.day);
                final leavesOnDay = _leavesMap[key];
                
                Color backgroundColor = const Color(0xFF152A4A).withOpacity(0.3);
                Color textColor = const Color(0xFF152A4A);
                IconData? statusIcon;
                FontWeight fontWeight = FontWeight.bold;
                
                if (leavesOnDay != null && leavesOnDay.isNotEmpty) {
                  bool hasApproved = leavesOnDay.any((l) => (l['status'] ?? '').toString().toLowerCase() == 'approved');
                  bool hasPending = leavesOnDay.any((l) => (l['status'] ?? '').toString().toLowerCase() == 'pending');
                  bool hasRejected = leavesOnDay.any((l) => (l is Map && (l['status'] ?? '').toString().toLowerCase() == 'rejected') || (l is Map && (l['status'] ?? '').toString().toLowerCase() == 'cancelled'));
                  
                  if (hasApproved) {
                    backgroundColor = Colors.red.withOpacity(0.3);
                    textColor = Colors.red;
                    statusIcon = Icons.check_circle;
                  } else if (hasPending) {
                    backgroundColor = Colors.red.withOpacity(0.35);
                    textColor = Colors.red.shade700;
                    statusIcon = Icons.hourglass_empty;
                  } else if (hasRejected) {
                    backgroundColor = Colors.red.withOpacity(0.3);
                    textColor = Colors.red;
                    statusIcon = Icons.cancel;
                  }
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
                final key = DateTime.utc(day.year, day.month, day.day);
                final leavesOnDay = _leavesMap[key];
                
                Color backgroundColor = const Color(0xFF152A4A);
                Color textColor = Colors.white;
                IconData? statusIcon;
                
                if (leavesOnDay != null && leavesOnDay.isNotEmpty) {
                  bool hasApproved = leavesOnDay.any((l) => (l['status'] ?? '').toString().toLowerCase() == 'approved');
                  bool hasPending = leavesOnDay.any((l) => (l['status'] ?? '').toString().toLowerCase() == 'pending');
                  bool hasRejected = leavesOnDay.any((l) => (l is Map && (l['status'] ?? '').toString().toLowerCase() == 'rejected') || (l is Map && (l['status'] ?? '').toString().toLowerCase() == 'cancelled'));
                  
                  if (hasApproved) {
                    backgroundColor = Colors.red;
                    statusIcon = Icons.check_circle;
                  } else if (hasPending) {
                    backgroundColor = Colors.red.shade700;
                    statusIcon = Icons.hourglass_empty;
                  } else if (hasRejected) {
                    backgroundColor = Colors.red;
                    statusIcon = Icons.cancel;
                  }
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
                   _buildErrorUI()
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

  void _showLegendDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Leave Status Legend',
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
              'Color codes for leave status:',
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
                _buildLegendItem('Approved', Colors.red, Icons.check_circle),
                _buildLegendItem('Pending', Colors.red.shade700, Icons.hourglass_empty),
                _buildLegendItem('Rejected', Colors.red, Icons.cancel),
                _buildLegendItem('Cancelled', Colors.red, Icons.block),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Tap any day in the calendar to see detailed leave information.',
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
          ],),
        ],]
      ),
    );
  }

  Widget _buildErrorUI() {
    final isNetworkError = _error!.toLowerCase().contains('network') ||
        _error!.toLowerCase().contains('connection') ||
        _error!.toLowerCase().contains('xmlhttprequest');

    if (isNetworkError) {
      return Center(
        child: NoInternetWidget(onRetry: _loadLeaves),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
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
            onPressed: _loadLeaves,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TAB 3: LEAVE BALANCE
// ---------------------------------------------------------------------------
class LeaveBalanceTab extends StatefulWidget {
  const LeaveBalanceTab({super.key});

  @override
  State<LeaveBalanceTab> createState() => _LeaveBalanceTabState();
}

class _LeaveBalanceTabState extends State<LeaveBalanceTab> {
  LeaveBalanceResponse? _leaveBalanceResponse;
  bool _isLoading = true;
  String? _error;
  int? _selectedEmployeeId;
  String? _employeeName;
  List<dynamic> _employees = [];
  bool _isLoadingEmployees = false;

  @override
  void initState() {
    super.initState();
    _loadEmployeesAndUserType();
  }

  Future<void> _loadEmployeesAndUserType() async {
    // Check user type first
    final token = await AuthUtils.getToken();
    if (token != null) {
      final userType = AuthUtils.getRoleFromToken(token);
      print('User Type: $userType');
      
      if (userType != 'employee') {
        // For staff/admin users, load employees list
        _loadEmployees();
      } else {
        // For employee users, load their own balance directly
        _loadLeaveBalance();
      }
    } else {
      setState(() {
        _error = 'Authentication token not found';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadEmployees() async {
    try {
      setState(() {
        _isLoadingEmployees = true;
      });

      // Load employees list
      final response = await ApiService.getEmployees();
      if (response['employees'] != null) {
        setState(() {
          _employees = response['employees'];
          _isLoadingEmployees = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load employees: ${e.toString()}';
        _isLoadingEmployees = false;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadLeaveBalance() async {
    if (_selectedEmployeeId == null) return;

    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Call getLeaveBalance with selected employee ID for staff users
      final response = await ApiService.getLeaveBalance(_selectedEmployeeId);
      
      if (mounted) {
        setState(() {
          _leaveBalanceResponse = response;
          _employeeName = response.data.employee.name;
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

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? _buildLoadingState()
        : _error != null
            ? _buildErrorState()
            : _buildContent();
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
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
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF152A4A).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF152A4A)),
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  _isLoadingEmployees 
                    ? 'Loading Employees...'
                    : 'Loading Leave Balance...',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isLoadingEmployees 
                    ? 'Fetching employee list'
                    : 'Fetching your leave information',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    final isNetworkError = _error!.toLowerCase().contains('network') ||
        _error!.toLowerCase().contains('connection') ||
        _error!.toLowerCase().contains('xmlhttprequest');

    if (isNetworkError) {
      return Center(
        child: NoInternetWidget(
          onRetry: () {
            if (_employees.isNotEmpty) {
              _loadEmployees();
            } else {
              _loadLeaveBalance();
            }
          },
        ),
      );
    }

    return Center(
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(24),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: Colors.red,
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Error Loading Leave Balance',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF152A4A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'An unknown error occurred',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF152A4A),
                    const Color(0xFF152A4A),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    // For staff users, reload employees list
                    if (_employees.isNotEmpty) {
                      _loadEmployees();
                    } else {
                      _loadLeaveBalance();
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: const Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Try Again',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Employee Selector for Staff Users
          if (_employees.isNotEmpty) _buildEmployeeSelector(),
          if (_employees.isNotEmpty) const SizedBox(height: 20),
          
          // Employee Info Card
          _buildEmployeeInfoCard(),
          const SizedBox(height: 20),
          
          // Leave Balance Cards
          if (_leaveBalanceResponse != null)
            ..._leaveBalanceResponse!.data.leaveBalances.map((balance) {
              return _buildLeaveBalanceCard(balance);
            }).toList(),
          
          // View Details Button
          const SizedBox(height: 24),
          // Container(
          //   width: double.infinity,
          //   height: 50,
          //   decoration: BoxDecoration(
          //     gradient: LinearGradient(
          //       begin: Alignment.topLeft,
          //       end: Alignment.bottomRight,
          //       colors: [
          //         const Color(0xFF152A4A),
          //         const Color(0xFF152A4A),
          //       ],
          //     ),
          //     borderRadius: BorderRadius.circular(12),
          //   ),
          //   child: Material(
          //     color: Colors.transparent,
          //     child: InkWell(
          //       onTap: () {
          //         if (_employeeId != null && _employeeName != null) {
          //           Navigator.push(
          //             context,
          //             MaterialPageRoute(
          //               builder: (context) => LeaveBalanceDetailScreen(
          //                 employeeId: _employeeId.toString(),
          //                 employeeName: _employeeName!,
          //                 department: 'Employee',
          //               ),
          //             ),
          //           );
          //         }
          //       },
          //       borderRadius: BorderRadius.circular(12),
          //       child: const Center(
          //         child: Row(
          //           mainAxisAlignment: MainAxisAlignment.center,
          //           children: [
          //             Icon(Icons.visibility_rounded, color: Colors.white, size: 20),
          //             SizedBox(width: 8),
          //             Text(
          //               'View Detailed Balance',
          //               style: TextStyle(
          //                 color: Colors.white,
          //                 fontWeight: FontWeight.w600,
          //                 fontSize: 16,
          //               ),
          //             ),
          //           ],
          //         ),
          //       ),
          //     ),
          //   ),
          // ),
        ],
      ),
    );
  }

  Widget _buildEmployeeInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF152A4A).withOpacity(0.1),
            const Color(0xFF152A4A).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF152A4A).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF152A4A),
                      const Color(0xFF152A4A),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Leave Balance Summary',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF152A4A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _employeeName ?? 'Employee',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      'From: ${_getFirstDayOfMonth(_leaveBalanceResponse?.data.period?.year ?? DateTime.now().year, _leaveBalanceResponse?.data.period?.month ?? DateTime.now().month)} To: ${_getLastDayOfMonth(_leaveBalanceResponse?.data.period?.year ?? DateTime.now().year, _leaveBalanceResponse?.data.period?.month ?? DateTime.now().month)}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLeaveBalanceCard(LeaveBalance balance) {
    final isPaid = balance.isPaid;
    final isUncapped = balance.isUncapped;
    final isHoliday = balance.leaveType.toLowerCase().contains('holiday');
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPaid ? Colors.green.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                // Container(
                //   padding: const EdgeInsets.all(12),
                //   decoration: BoxDecoration(
                //     color: isPaid ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                //     borderRadius: BorderRadius.circular(12),
                //   ),
                //   child: Icon(
                //     isPaid ? Icons.paid_rounded : Icons.money_off_rounded,
                //     size: 24,
                //     color: isPaid ? Colors.green[700] : Colors.grey[600],
                //   ),
                // ),
               // const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        balance.leaveType,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[900],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isPaid ? Colors.green[50] : Colors.grey[100],
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isPaid ? 'PAID' : 'UNPAID',
                              style: GoogleFonts.poppins(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: isPaid ? Colors.green[700] : Colors.grey[600],
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          if (isUncapped)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Color(0x1A0F172A),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'UNCAPPED',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF152A4A),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          if (isHoliday)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange[50],
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'HOLIDAY',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.orange[700],
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Monthly Stats
            if (balance.monthlyAllowance != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Color(0x1A0F172A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Monthly Balance',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey[900],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMiniStat(
                            'Allowance',
                            balance.monthlyAllowanceText,
                            Icons.calendar_today_rounded,
                            const Color(0xFF152A4A),
                          ),
                        ),
                        Expanded(
                          child: _buildMiniStat(
                            'Used',
                            isHoliday ? balance.usedThisMonth.toString() : _formatValueForDisplay(balance.usedThisMonth.toString()),
                            Icons.remove_circle_rounded,
                            Colors.orange,
                          ),
                        ),
                        Expanded(
                          child: _buildMiniStat(
                            'Remaining',
                            balance.remainingThisMonthText,
                            Icons.check_circle_rounded,
                            Colors.green,
                            isHighlighted: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            
            // Yearly Stats
            if (balance.yearlyAllowance != null)
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.purple[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Yearly Balance',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey[900],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMiniStat(
                            'Allowance',
                            balance.yearlyAllowanceText,
                            Icons.event_rounded,
                            Colors.purple,
                          ),
                        ),
                        Expanded(
                          child: _buildMiniStat(
                            'Used',
                            isHoliday ? balance.usedThisYear.toString() : _formatValueForDisplay(balance.usedThisYear.toString()),
                            Icons.remove_circle_rounded,
                            Colors.orange,
                          ),
                        ),
                        Expanded(
                          child: _buildMiniStat(
                            'Remaining',
                            balance.remainingThisYearText,
                            Icons.check_circle_rounded,
                            Colors.green,
                            isHighlighted: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, IconData icon, Color color, {bool isHighlighted = false}) {
    // Remove time display for holiday-related values
    String displayValue = value;
    if (label.toLowerCase().contains('used') && value.contains(':')) {
      // If it's a "used" field and contains time format, remove time part
      displayValue = value.split(' ')[0]; // Take only the date part
    }
    
    return Column(
      children: [
        Icon(
          icon,
          size: 20,
          color: color,
        ),
        const SizedBox(height: 8),
        Text(
          displayValue,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: isHighlighted ? FontWeight.w800 : FontWeight.w700,
            color: isHighlighted ? Colors.green[700] : Colors.grey[800],
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 9,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildEmployeeSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.people_outline_rounded, size: 20, color: Color(0xFF152A4A)),
              const SizedBox(width: 8),
              Text(
                'Select Employee',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _selectedEmployeeId,
                isExpanded: true,
                hint: Text(
                  'Choose an employee...',
                  style: GoogleFonts.poppins(color: Colors.grey[600]),
                ),
                items: _employees.where((employee) => employee.id != null).map((employee) {
                  return DropdownMenuItem<int>(
                    value: employee.id!,
                    child: Text(
                      employee.name ?? 'Unknown',
                      style: GoogleFonts.poppins(color: Colors.black87),
                    ),
                  );
                }).toList(),
                onChanged: (employeeId) {
                  print('🔥 Dropdown onChanged triggered! employeeId: $employeeId');
                  if (employeeId != null) {
                    print('🔥 Employee selected, calling auto-fill...');
                    setState(() {
                      _selectedEmployeeId = employeeId;
                      _leaveBalanceResponse = null; // Reset balance when employee changes
                      _error = null;
                    });
                    _loadLeaveBalance();
                    _autoFillAttendance(employeeId); // Auto-fill attendance when employee is selected
                  } else {
                    print('🔥 EmployeeId is null, not calling auto-fill');
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Auto-fill attendance logic
  Future<void> _autoFillAttendance(int employeeId) async {
    print('🚀 _autoFillAttendance method called! employeeId: $employeeId');
    try {
      print('🕐 Auto-filling attendance for employee ID: $employeeId');
      
      final response = await ApiService.getOrCreateAttendance(employeeId);
      
      if (response['success'] == true && response['data'] != null) {
        final attendance = response['data']['attendance'];
        print('✅ Attendance auto-filled successfully');
        print('Status: ${attendance['status']}');
        print('Check In: ${attendance['checkInTime']}');
        print('Check Out: ${attendance['checkOutTime']}');
        
        // You can show a snackbar or update UI to show attendance status
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Attendance ${attendance['status']} for selected employee'),
              backgroundColor: attendance['status'] == 'Checked Out' ? Colors.green : const Color(0xFF152A4A),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error auto-filling attendance: $e');
      // Don't show error to user, just log it since this is background operation
    }
  }

  // Helper method to format dates
  String _getFormattedDate(String dateString) {
    try {
      final DateTime date = DateTime.parse(dateString);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (e) {
      return dateString; // Return original if parsing fails
    }
  }

  // Helper method to get first day of month
  String _getFirstDayOfMonth(int year, int month) {
    final DateTime firstDay = DateTime(year, month, 1);
    return '${firstDay.day.toString().padLeft(2, '0')}/${firstDay.month.toString().padLeft(2, '0')}/${firstDay.year}';
  }

  // Helper method to get last day of month
  String _getLastDayOfMonth(int year, int month) {
    final DateTime lastDay = DateTime(year, month + 1, 0); // Last day of current month
    return '${lastDay.day.toString().padLeft(2, '0')}/${lastDay.month.toString().padLeft(2, '0')}/${lastDay.year}';
  }

  // Helper method to format values for display (remove time info)
  String _formatValueForDisplay(String value) {
    // If value contains time format (HH:MM), remove it
    if (value.contains(':')) {
      return value.split(' ')[0]; // Take only the date/number part
    }
    return value;
  }
}

class ApplyPermissionTab extends StatefulWidget {
  const ApplyPermissionTab({super.key});

  @override
  State<ApplyPermissionTab> createState() => _ApplyPermissionTabState();
}

class _ApplyPermissionTabState extends State<ApplyPermissionTab> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 11, minute: 0);
  bool _isLoading = false;

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context, bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
          final endHour = (_startTime.hour + 2) % 24;
          _endTime = TimeOfDay(hour: endHour, minute: _startTime.minute);
        } else {
          _endTime = picked;
        }
      });
    }
  }

  double _calculateDuration() {
    final start = _startTime.hour + (_startTime.minute / 60);
    final end = _endTime.hour + (_endTime.minute / 60);
    double duration = end - start;
    if (duration < 0) duration += 24;
    return duration;
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final startTimeStr = '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}:00';
      final endTimeStr = '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}:00';
      
      final leaveData = {
        'leaveType': 'Permission',
        'startDate': dateStr,
        'endDate': dateStr,
        'startTime': startTimeStr,
        'endTime': endTimeStr,
        'durationHours': _calculateDuration(),
        'reason': _reasonController.text.trim(),
      };

      await ApiService.applyLeave(leaveData);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permission submitted successfully'), backgroundColor: Colors.green));
        _reasonController.clear();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Apply Permission', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF020617))),
            const SizedBox(height: 24),
            _buildTile(label: 'Date', value: DateFormat('dd MMM yyyy').format(_selectedDate), icon: Icons.calendar_today, onTap: () => _selectDate(context)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildTile(label: 'Start Time', value: _startTime.format(context), icon: Icons.access_time, onTap: () => _selectTime(context, true))),
                const SizedBox(width: 16),
                Expanded(child: _buildTile(label: 'End Time', value: _endTime.format(context), icon: Icons.access_time_filled, onTap: () => _selectTime(context, false))),
              ],
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _reasonController,
              maxLines: 3,
              decoration: InputDecoration(hintText: 'Enter reason...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitRequest,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF152A4A), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : Text('Submit Request', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTile({required String label, required String value, required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Icon(icon, size: 16, color: Colors.grey[600]), const SizedBox(width: 8), Text(label, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[600]))]),
            const SizedBox(height: 4),
            Text(value, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}


