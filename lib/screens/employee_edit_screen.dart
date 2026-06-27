import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../models/employee.dart';
import '../models/shift.dart';
import '../providers/employee_provider.dart';
import '../providers/shift_provider.dart';
import '../widgets/premium_app_bar.dart';

class EmployeeEditScreen extends StatefulWidget {
  final Employee employee;

  const EmployeeEditScreen({super.key, required this.employee});

  @override
  State<EmployeeEditScreen> createState() => _EmployeeEditScreenState();
}

class _EmployeeEditScreenState extends State<EmployeeEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _positionController;
  late final TextEditingController _salaryController;
  
  bool _isLoading = false;
  Shift? _selectedShift;
  bool _isActive = true;
  bool _hasCompanyMismatch = false;
  int? _storedCompanyId;
  int? _employeeCompanyId;

  @override
  void initState() {
    super.initState();
    
    // Initialize controllers with current employee data
    _nameController = TextEditingController(text: widget.employee.name);
    _emailController = TextEditingController(text: widget.employee.email);
    _phoneController = TextEditingController(text: widget.employee.phone);
    _positionController = TextEditingController(text: widget.employee.position);
    _salaryController = TextEditingController(text: widget.employee.salary.toString());
    _isActive = widget.employee.isActive;
    
    // Check for company ID mismatch
    _checkCompanyMismatch();
    
    // Load shifts when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<ShiftProvider>().loadShifts();
            if (mounted) {
          final shifts = context.read<ShiftProvider>().shifts;
          debugPrint('🔍 [EDIT SCREEN] Loaded ${shifts.length} shifts');
          debugPrint('🔍 [EDIT SCREEN] Employee Shift: ID=${widget.employee.shiftId}, Name="${widget.employee.shiftName}"');
          
          // Set selected shift if employee has one
          if (widget.employee.shiftId != null || (widget.employee.shiftName != null && widget.employee.shiftName!.isNotEmpty)) {
            try {
              final foundShift = shifts.firstWhere(
                (shift) => 
                  (widget.employee.shiftId != null && shift.id == widget.employee.shiftId) ||
                  (widget.employee.shiftName != null && shift.name.trim().toLowerCase() == widget.employee.shiftName!.trim().toLowerCase()),
              );
              
              setState(() {
                _selectedShift = foundShift;
              });
              debugPrint('✅ [EDIT SCREEN] Matched shift: ${foundShift.name} (ID: ${foundShift.id})');
            } catch (e) {
              debugPrint('❌ [EDIT SCREEN] Shift not found in list: $e');
              // Log available shift names for comparison
              debugPrint('🔍 [EDIT SCREEN] Available shifts: ${shifts.map((s) => '"${s.name}" (ID: ${s.id})').join(', ')}');
            }
          } else {
            debugPrint('⚠️ [EDIT SCREEN] Employee has no shift assigned');
          }
        }
      });
  }
  
  Future<void> _checkCompanyMismatch() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _storedCompanyId = prefs.getInt('company_id');
      _employeeCompanyId = widget.employee.companyId;
      
      if (_employeeCompanyId != null && 
          _storedCompanyId != null && 
          _employeeCompanyId != _storedCompanyId) {
        setState(() {
          _hasCompanyMismatch = true;
        });
      }
    } catch (e) {
      print('Error checking company mismatch: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _positionController.dispose();
    _salaryController.dispose();
    super.dispose();
  }

  Future<void> _updateEmployee() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Create updated employee object
      final updatedEmployee = widget.employee.copyWith(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        position: _positionController.text.trim(),
        salary: double.parse(_salaryController.text.trim()),
        isActive: _isActive,
        shiftName: _selectedShift?.name,
        shiftId: _selectedShift?.id,
      );

      // Update employee via provider
      final success = await context.read<EmployeeProvider>().updateEmployee(updatedEmployee);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  'Employee updated successfully',
                  style: GoogleFonts.poppins(),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        Navigator.of(context).pop(true); // Return true to indicate success
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  'Failed to update employee',
                  style: GoogleFonts.poppins(),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Error: ${e.toString()}',
                    style: GoogleFonts.poppins(),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
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
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: const PremiumAppBar(
        title: 'Edit Employee',
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              // Company Mismatch Warning Banner
              if (_hasCompanyMismatch) ...[
                _buildCompanyMismatchWarning(),
                const SizedBox(height: 16),
              ],
              
              // Header
              Text(
                'Update Employee Information',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF152A4A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Edit the employee details below',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 32),

              // Form Fields
              _buildTextField(
                controller: _nameController,
                label: 'Full Name',
                icon: Icons.person_outline,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter employee name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              _buildTextField(
                controller: _emailController,
                label: 'Email Address (Optional)',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value != null && value.trim().isNotEmpty) {
                    if (!value.contains('@')) {
                      return 'Please enter a valid email';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              _buildTextField(
                controller: _phoneController,
                label: 'Phone Number',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter phone number';
                  }
                  if (value.length < 10) {
                    return 'Please enter a valid phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              _buildTextField(
                controller: _positionController,
                label: 'Department/Position',
                icon: Icons.work_outline,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter department/position';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              _buildTextField(
                controller: _salaryController,
                label: 'Salary (₹)',
                icon: Icons.currency_rupee,
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter salary';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Shift Selector
              _buildShiftSelector(),
              const SizedBox(height: 16),

              // Active Status Switch
              _buildActiveStatusSwitch(),
              const SizedBox(height: 32),

              // Update Button
              _buildUpdateButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: GoogleFonts.poppins(fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(),
        prefixIcon: Icon(icon, color: const Color(0xFF152A4A)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF152A4A), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _buildShiftSelector() {
    return Consumer<ShiftProvider>(
      builder: (context, shiftProvider, child) {
        if (shiftProvider.isLoading) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 16),
                Text(
                  'Loading shifts...',
                  style: GoogleFonts.poppins(),
                ),
              ],
            ),
          );
        }

        if (shiftProvider.error != null) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Text(
              'Error loading shifts: ${shiftProvider.error}',
              style: GoogleFonts.poppins(color: Colors.red.shade700),
            ),
          );
        }

        final shifts = shiftProvider.shifts;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.access_time, color: Color(0xFF152A4A)),
                  const SizedBox(width: 8),
                  Text(
                    'Shift',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (shifts.isEmpty)
                Text(
                  'No shifts available',
                  style: GoogleFonts.poppins(color: Colors.grey),
                )
              else
                DropdownButtonFormField<Shift>(
                  value: _selectedShift,
                  decoration: InputDecoration(
                    hintText: 'Select a shift',
                    hintStyle: GoogleFonts.poppins(color: Colors.grey),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  items: shifts.map((shift) {
                    return DropdownMenuItem<Shift>(
                      value: shift,
                      child: Text(
                        '${shift.name} (${shift.fromTime} - ${shift.toTime})',
                        style: GoogleFonts.poppins(),
                      ),
                    );
                  }).toList(),
                  onChanged: (Shift? value) {
                    setState(() {
                      _selectedShift = value;
                    });
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActiveStatusSwitch() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                _isActive ? Icons.check_circle : Icons.cancel,
                color: _isActive ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Employee Status',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    _isActive ? 'Active' : 'Inactive',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: _isActive ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Switch(
            value: _isActive,
            onChanged: (bool value) {
              setState(() {
                _isActive = value;
              });
            },
            activeTrackColor: Colors.green.shade200,
            activeThumbColor: Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildUpdateButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _updateEmployee,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF152A4A),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 0,
      ),
      child: _isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Text(
              'Update Employee',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
    );
  }

  Widget _buildCompanyMismatchWarning() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade300, width: 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange.shade700,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Company ID Mismatch',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange.shade900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'This employee belongs to a different company (ID: $_employeeCompanyId) than your current session (ID: $_storedCompanyId). The employee will be updated with your current company ID.',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.orange.shade800,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


