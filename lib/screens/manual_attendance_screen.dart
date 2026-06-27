import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/employee.dart';
import '../providers/employee_provider.dart';
import '../services/api_service.dart';
import '../widgets/premium_app_bar.dart';

class ManualAttendanceScreen extends StatefulWidget {
  final Employee? employee;

  const ManualAttendanceScreen({super.key, this.employee});

  @override
  State<ManualAttendanceScreen> createState() => _ManualAttendanceScreenState();
}

class _ManualAttendanceScreenState extends State<ManualAttendanceScreen> {
  final _formKey = GlobalKey<FormState>();
  int? _selectedEmployeeId;
  DateTime _selectedDate = DateTime.now();
  String _selectedStatus = 'Present';
  TimeOfDay? _checkInTime;
  TimeOfDay? _checkOutTime;
  final TextEditingController _notesController = TextEditingController();
  bool _isLoading = false;

  final List<String> _statusValues = [
    'Present',
    'Late',
    'Half Day',
    'Leave',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.employee != null) {
      _selectedEmployeeId = widget.employee!.id;
    }
    // Load all employees for the dropdown
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<EmployeeProvider>(context, listen: false).loadEmployees();
      if (_selectedEmployeeId != null) {
        _fetchTodayAttendance(_selectedEmployeeId!);
      }
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime(bool isCheckIn) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isCheckIn
          ? (_checkInTime ?? const TimeOfDay(hour: 9, minute: 0))
          : (_checkOutTime ?? const TimeOfDay(hour: 18, minute: 0)),
    );
    if (picked != null) {
      setState(() {
        if (isCheckIn) {
          _checkInTime = picked;
        } else {
          _checkOutTime = picked;
        }
      });
    }
  }

  String _formatTimeOfDay(TimeOfDay? time) {
    if (time == null) return 'Select Time';
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat('hh:mm a').format(dt);
  }

  TimeOfDay? _parseTimeString(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty || timeStr == '-') return null;
    try {
      // 1. Try parsing formats like "09:45:00 am" or "09:45 am"
      final upperTime = timeStr.trim().toUpperCase();
      if (upperTime.contains('AM') || upperTime.contains('PM')) {
        // Handle "09:45:00 AM" by converting to "09:45 AM"
        String cleanStr = upperTime;
        if (RegExp(r':\d{2}:\d{2}\s').hasMatch(upperTime)) {
          // Format like "09:45:00 AM" -> "09:45 AM"
          final parts = upperTime.split(':');
          if (parts.length >= 3) {
            final lastSpacePart = parts[2].split(' ');
            if (lastSpacePart.length >= 2) {
              cleanStr = "${parts[0]}:${parts[1]} ${lastSpacePart[1]}";
            }
          }
        } else if (RegExp(r':\d{2}\s[AP]M').hasMatch(upperTime)) {
          // Format like "09:45:00 AM" (where :00 is the second)
          final parts = upperTime.split(':');
          if (parts.length >= 2) {
            final lastSpacePart = parts[parts.length-1].split(' ');
            if (lastSpacePart.length >= 2) {
               cleanStr = "${parts[0]}:${parts[1]} ${lastSpacePart[lastSpacePart.length-1]}";
            }
          }
        }

        try {
          final dt = DateFormat('hh:mm a').parse(cleanStr);
          return TimeOfDay(hour: dt.hour, minute: dt.minute);
        } catch (_) {
          // One more try with exactly the incoming string (uppercased)
          try {
            final dt = DateFormat('hh:mm:ss a').parse(upperTime);
            return TimeOfDay(hour: dt.hour, minute: dt.minute);
          } catch (_) {}
        }
      }

      // 2. Try parsing as a full date-time string
      final dt = DateTime.tryParse(timeStr);
      if (dt != null) {
        return TimeOfDay(hour: dt.hour, minute: dt.minute);
      }
      
      // 3. Fallback for simple military HH:mm or HH:mm:ss format
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        return TimeOfDay(
            hour: int.parse(parts[0].trim()), 
            minute: int.parse(parts[1].trim())
        );
      }
    } catch (e) {
      debugPrint('Error parsing time string');
    }
    return null;
  }

  Future<void> _fetchTodayAttendance(int employeeId) async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.getTodayCheckIn(employeeId);
      final data = response['data'] ?? response;

      String? checkInStr =
          data['checkIn'] ?? data['check_in'] ?? data['checkInTime'];
      String? checkOutStr =
          data['checkOut'] ?? data['check_out'] ?? data['checkOutTime'];

      if (mounted) {
        setState(() {
          if (checkInStr != null) _checkInTime = _parseTimeString(checkInStr);
          if (checkOutStr != null) _checkOutTime = _parseTimeString(checkOutStr);
          _isLoading = false;
        });
      }
    } catch (e) {
    print(e);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedEmployeeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an employee')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final Map<String, dynamic> data = {
        'employeeId': _selectedEmployeeId,
        'date': DateFormat('yyyy-MM-dd').format(_selectedDate),
        'status': _selectedStatus,
        'notes': _notesController.text.trim(),
      };

      if (_checkInTime != null) {
        data['checkIn'] = _formatTimeOfDay(_checkInTime);
      }
      if (_checkOutTime != null) {
        data['checkOut'] = _formatTimeOfDay(_checkOutTime);
      }

      final result = await ApiService.addManualAttendance(data);

      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text(result['message'] ?? 'Attendance updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop(true);
        } else {
          throw Exception('Failed to update attendance');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getSelectedEmployeeName(List<Employee> employees) {
    final emp = employees.firstWhere(
      (e) => e.id == _selectedEmployeeId,
      orElse: () => Employee(
          name: 'Unknown',
          phone: '',
          position: '',
          salary: 0,
          faceData: '',
          createdAt: DateTime.now()),
    );
    return '${emp.id} - ${emp.name}';
  }

  void _showEmployeeSearchDialog(List<Employee> employees) {
    String searchText = '';
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final filtered = employees.where((e) {
              if (searchText.isEmpty) return true;
              final query = searchText.toLowerCase();
              return e.name.toLowerCase().contains(query) ||
                  (e.id?.toString() ?? '').contains(query);
            }).toList();

            return AlertDialog(
              title: Text('Select Employee',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold, fontSize: 18)),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  children: [
                    TextField(
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Search by ID or Name...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                      style: GoogleFonts.poppins(fontSize: 14),
                      onChanged: (val) =>
                          setDialogState(() => searchText = val),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Text('No employees found',
                                  style:
                                      GoogleFonts.poppins(color: Colors.grey)))
                          : ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (ctx, i) {
                                final emp = filtered[i];
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: const Color(0xFF152A4A),
                                    child: Text(
                                      emp.name.isNotEmpty
                                          ? emp.name[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  title: Text(emp.name,
                                      style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14)),
                                  subtitle: Text('ID: ${emp.id}',
                                      style: GoogleFonts.poppins(
                                          fontSize: 12, color: Colors.grey)),
                                  onTap: () {
                                    setState(
                                        () => _selectedEmployeeId = emp.id);
                                    Navigator.of(ctx).pop();
                                    _fetchTodayAttendance(emp.id!);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  InputDecoration _buildInputDecoration(String hint, {Widget? prefixIcon, Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 14),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.withOpacity(0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF152A4A), width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: const PremiumAppBar(
        title: 'Manual Attendance',
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Employee Selection
                  Text(
                    'Employee',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14, color: const Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 8),
                  Consumer<EmployeeProvider>(
                    builder: (context, provider, child) {
                      final employees = provider.employees.where((e) => e.isActive).toList();
                      return GestureDetector(
                        onTap: widget.employee != null ? null : () => _showEmployeeSearchDialog(employees),
                        child: AbsorbPointer(
                          child: TextFormField(
                            decoration: _buildInputDecoration(
                              _selectedEmployeeId != null ? _getSelectedEmployeeName(employees) : 'Search by ID or Name',
                              prefixIcon: const Icon(Icons.person_search, color: Color(0xFF152A4A)),
                              suffixIcon: _selectedEmployeeId != null
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 20, color: Colors.grey),
                                      onPressed: widget.employee != null ? null : () => setState(() => _selectedEmployeeId = null),
                                    )
                                  : const Icon(Icons.arrow_drop_down, color: Colors.grey),
                            ),
                            style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF1E293B)),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  // Date Selection
                  Text(
                    'Date',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14, color: const Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _selectDate,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.withOpacity(0.1)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DateFormat('dd-MM-yyyy').format(_selectedDate),
                            style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF1E293B)),
                          ),
                          const Icon(Icons.calendar_today, size: 20, color: Color(0xFF152A4A)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Status Selection
                  Text(
                    'Status',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14, color: const Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedStatus,
                    decoration: _buildInputDecoration('Select Status'),
                    icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
                    items: _statusValues
                        .map((s) => DropdownMenuItem(
                              value: s,
                              child: Text(s, style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF1E293B))),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val == null) return;
                      setState(() {
                        _selectedStatus = val;
                        if (['Holiday', 'Leave', 'Casual Leave', 'Sick Leave', 'Medical Leave'].contains(val)) {
                          _checkInTime = null;
                          _checkOutTime = null;
                        }
                      });
                    },
                  ),
                  if (!['Holiday', 'Leave', 'Casual Leave', 'Sick Leave', 'Medical Leave'].contains(_selectedStatus)) ...[
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Check In',
                                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14, color: const Color(0xFF1E293B)),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey.withOpacity(0.1)),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: InkWell(
                                        onTap: () => _selectTime(true),
                                        borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), bottomLeft: Radius.circular(12)),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.login, size: 18, color: const Color(0xFF152A4A)),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  _formatTimeOfDay(_checkInTime),
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 13,
                                                    color: _checkInTime == null ? Colors.grey : const Color(0xFF1E293B),
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (_checkInTime != null)
                                      InkWell(
                                        onTap: () => setState(() => _checkInTime = null),
                                        child: const Padding(
                                          padding: EdgeInsets.all(8.0),
                                          child: Icon(Icons.close, size: 18, color: Colors.redAccent),
                                        ),
                                      ),
                                  ],
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
                              Text(
                                'Check Out',
                                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14, color: const Color(0xFF1E293B)),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey.withOpacity(0.1)),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: InkWell(
                                        onTap: () => _selectTime(false),
                                        borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), bottomLeft: Radius.circular(12)),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.logout, size: 18, color: Colors.purple),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  _formatTimeOfDay(_checkOutTime),
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 13,
                                                    color: _checkOutTime == null ? Colors.grey : const Color(0xFF1E293B),
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (_checkOutTime != null)
                                      InkWell(
                                        onTap: () => setState(() => _checkOutTime = null),
                                        child: const Padding(
                                          padding: EdgeInsets.all(8.0),
                                          child: Icon(Icons.close, size: 18, color: Colors.redAccent),
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
                  ],
                  const SizedBox(height: 20),

                  // Notes
                  Text(
                    'Notes',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14, color: const Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: _buildInputDecoration('Add notes or reason...'),
                    style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 32),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF152A4A),
                        foregroundColor: Colors.white,
                        elevation: 8,
                        shadowColor: const Color(0xFF152A4A).withOpacity(0.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                          : Text('Submit Attendance', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
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
}

