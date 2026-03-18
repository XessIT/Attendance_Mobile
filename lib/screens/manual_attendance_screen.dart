import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/employee.dart';
import '../providers/employee_provider.dart';
import '../services/api_service.dart';

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
    'Absent',
    'Late',
    'Half Day',
    'Holiday',
    'Leave',
    'Casual Leave',
    'Sick Leave',
    'Medical Leave',
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
    return DateFormat('HH:mm').format(dt);
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
              content: Text(result['message'] ?? 'Attendance updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop(true);
        } else {
          throw Exception(result['error'] ?? 'Failed to update attendance');
        }
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getSelectedEmployeeName(List<Employee> employees) {
    final emp = employees.firstWhere(
      (e) => e.id == _selectedEmployeeId,
      orElse: () => Employee(name: 'Unknown', phone: '', position: '', salary: 0, faceData: '', createdAt: DateTime.now()),
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
              title: Text('Select Employee', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18)),
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
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      style: GoogleFonts.poppins(fontSize: 14),
                      onChanged: (val) => setDialogState(() => searchText = val),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(child: Text('No employees found', style: GoogleFonts.poppins(color: Colors.grey)))
                          : ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (ctx, i) {
                                final emp = filtered[i];
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: const Color(0xFF2196F3),
                                    child: Text(
                                      emp.name.isNotEmpty ? emp.name[0].toUpperCase() : '?',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  title: Text(emp.name, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                                  subtitle: Text('ID: ${emp.id}', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                                  onTap: () {
                                    setState(() => _selectedEmployeeId = emp.id);
                                    Navigator.of(ctx).pop();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF1565C0), // Dark Blue
                Color(0xFF42A5F5), // Light Blue
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: false,
            title: Text(
              'Manual Attendance',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            foregroundColor: Colors.white,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Employee Selection
                Text(
                  'Employee',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Consumer<EmployeeProvider>(
                  builder: (context, provider, child) {
                    final employees = provider.employees.where((e) => e.isActive).toList();
                    return GestureDetector(
                      onTap: widget.employee != null ? null : () => _showEmployeeSearchDialog(employees),
                      child: AbsorbPointer(
                        child: TextFormField(
                          decoration: InputDecoration(
                            hintText: _selectedEmployeeId != null
                                ? _getSelectedEmployeeName(employees)
                                : 'Search by ID or Name',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            prefixIcon: const Icon(Icons.person_search, color: Color(0xFF2196F3)),
                            suffixIcon: _selectedEmployeeId != null
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 20),
                                    onPressed: widget.employee != null ? null : () => setState(() => _selectedEmployeeId = null),
                                  )
                                : const Icon(Icons.arrow_drop_down),
                          ),
                          style: GoogleFonts.poppins(fontSize: 14),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Date Selection
                Text(
                  'Date',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _selectDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(DateFormat('yyyy-MM-dd').format(_selectedDate),
                            style: GoogleFonts.poppins(fontSize: 14)),
                        const Icon(Icons.calendar_today, size: 20, color: Color(0xFF2196F3)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Status Selection
                Text(
                  'Status',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedStatus,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: _statusValues.map((s) => DropdownMenuItem(
                    value: s,
                    child: Text(s, style: GoogleFonts.poppins(fontSize: 14)),
                  )).toList(),
                  onChanged: (val) => setState(() => _selectedStatus = val!),
                ),
                const SizedBox(height: 16),

                // Time Selection
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Check In',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () => _selectTime(true),
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(8),
                                      bottomLeft: Radius.circular(8),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.access_time, size: 18, color: Colors.blue),
                                          const SizedBox(width: 8),
                                          Text(
                                            _formatTimeOfDay(_checkInTime),
                                            style: GoogleFonts.poppins(
                                              fontSize: 14,
                                              color: _checkInTime == null ? Colors.grey : Colors.black87,
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
                                      child: Icon(Icons.close, size: 18, color: Colors.red),
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
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () => _selectTime(false),
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(8),
                                      bottomLeft: Radius.circular(8),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.access_time, size: 18, color: Colors.purple),
                                          const SizedBox(width: 8),
                                          Text(
                                            _formatTimeOfDay(_checkOutTime),
                                            style: GoogleFonts.poppins(
                                              fontSize: 14,
                                              color: _checkOutTime == null ? Colors.grey : Colors.black87,
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
                                      child: Icon(Icons.close, size: 18, color: Colors.red),
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
                const SizedBox(height: 16),

                // Notes
                Text(
                  'Notes',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Add notes or reason...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  style: GoogleFonts.poppins(fontSize: 14),
                ),
                const SizedBox(height: 32),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2196F3),
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading 
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                        : Text('Submit Attendance', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
