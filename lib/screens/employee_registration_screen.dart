import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../models/employee.dart';
import '../models/shift.dart';
import '../models/department.dart';
import '../providers/employee_provider.dart';
import '../providers/shift_provider.dart';
import '../providers/department_provider.dart';
import '../services/api_service.dart';

class EmployeeRegistrationScreen extends StatefulWidget {
  const EmployeeRegistrationScreen({super.key});

  @override
  State<EmployeeRegistrationScreen> createState() => _EmployeeRegistrationScreenState();
}

class _EmployeeRegistrationScreenState extends State<EmployeeRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _positionController = TextEditingController();
  final _salaryController = TextEditingController();
  
  File? _faceImage;
  bool _isLoading = false;
  bool _isCapturing = false;
  Shift? _selectedShift;
  Department? _selectedDepartment;
  DateTime? _dateOfJoining;
  DateTime? _dateOfBirth;
  late TextEditingController _dateOfJoiningController;
  late TextEditingController _dateOfBirthController;

  @override
  void initState() {
    super.initState();
    // Load shifts and departments when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ShiftProvider>().loadShifts();
      context.read<DepartmentProvider>().loadDepartments();
    });
    _dateOfJoining = DateTime.now();
    _dateOfJoiningController = TextEditingController(
      text: DateFormat('dd MMM yyyy').format(_dateOfJoining!),
    );
    _dateOfBirthController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _positionController.dispose();
    _salaryController.dispose();
    _dateOfJoiningController.dispose();
    _dateOfBirthController.dispose();
    super.dispose();
  }

  Future<void> _captureFaceImage() async {
    setState(() {
      _isCapturing = true;
    });

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _faceImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error capturing image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCapturing = false;
        });
      }
    }
  }

  Future<void> _pickFaceImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _faceImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _registerEmployee() async {
    print('\n🔵 [EMPLOYEE REGISTRATION] Starting registration process...');
    
    if (!_formKey.currentState!.validate()) {
      print('❌ [EMPLOYEE REGISTRATION] Form validation failed');
      return;
    }

    if (_faceImage == null) {
      print('❌ [EMPLOYEE REGISTRATION] No face image selected');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please capture or select a face image'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Create employee object
      final employee = Employee(
        name: _nameController.text.trim(),
        email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        position: _selectedDepartment?.name ?? 'Employee',
        salary: double.parse(_salaryController.text.trim()),
        dateOfJoining: _dateOfJoining,
        dateOfBirth: _dateOfBirth,
        faceData: '', // Will be set after face registration
        createdAt: DateTime.now(),
        shiftId: _selectedShift?.id,
      );

      print('📝 [EMPLOYEE REGISTRATION] Employee object created:');
      print('   Name: ${employee.name}');
      print('   Email: ${employee.email}');
      print('   Phone: ${employee.phone}');
      print('   Position: ${employee.position}');
      print('   Salary: ${employee.salary}');
      print('   Department: ${_selectedDepartment?.name ?? "Not selected"}');
      print('   Shift: ${_selectedShift?.name ?? "Not selected"}');
      print('   Face Image Path: ${_faceImage!.path}');

      // Create employee in database with image upload (new API handles both)
      print('📤 [EMPLOYEE REGISTRATION] Calling createEmployee API with image...');
      final employeeProvider = Provider.of<EmployeeProvider>(context, listen: false);
      final success = await employeeProvider.createEmployee(
        employee, 
        imageFile: _faceImage!,
        shiftName: _selectedShift?.name,
        departmentName: _selectedDepartment?.name,
      );

      print('📥 [EMPLOYEE REGISTRATION] createEmployee returned: $success');

      if (success) {
        print('✅ [EMPLOYEE REGISTRATION] Employee created successfully with image!');

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Employee registered successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Navigate back
          Navigator.of(context).pop();
        }
      } else {
        print('❌ [EMPLOYEE REGISTRATION] createEmployee returned false');
        // Get the actual error message from the provider (already cleaned)
        final errorMessage = employeeProvider.error ?? 'Failed to create employee';
        throw Exception(errorMessage);
      }
    } catch (e, stackTrace) {
      print('❌ [EMPLOYEE REGISTRATION] Exception occurred:');
      print('   Error: $e');
      print('   Stack Trace: $stackTrace');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error registering employee: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
      print('🏁 [EMPLOYEE REGISTRATION] Registration process completed\n');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register Employee'),
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Face Image Section
              _buildFaceImageSection(),
              const SizedBox(height: 24),

              // Personal Information
              _buildPersonalInfoSection(),
              const SizedBox(height: 24),

              // Work Information
              _buildWorkInfoSection(),
              const SizedBox(height: 24),

              // Shift Assignment
              _buildShiftSection(),
              const SizedBox(height: 32),

              // Register Button
              _buildRegisterButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFaceImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Face Image',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        
        // Face image preview
        Container(
          width: double.infinity,
          height: 200,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: _faceImage != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    _faceImage!,
                    fit: BoxFit.cover,
                  ),
                )
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.face,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No face image selected',
                        style: GoogleFonts.poppins(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
        const SizedBox(height: 16),

        // Action buttons
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isCapturing ? null : _captureFaceImage,
                icon: _isCapturing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.camera_alt),
                label: Text(
                  _isCapturing ? 'Capturing...' : 'Capture',
                  style: GoogleFonts.poppins(),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2196F3),
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            /*const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickFaceImage,
                icon: const Icon(Icons.photo_library),
                label: Text(
                  'Gallery',
                  style: GoogleFonts.poppins(),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2196F3),
                  side: const BorderSide(color: Color(0xFF2196F3)),
                ),
              ),
            ),*/
          ],
        ),
      ],
    );
  }

  Widget _buildPersonalInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Personal Information',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),

        // Name field
        TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Full Name',
            prefixIcon: Icon(Icons.person),
          ),
          textCapitalization: TextCapitalization.words,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter full name';
            }
            final trimmedValue = value.trim();
            if (trimmedValue.isEmpty) {
              return 'Please enter full name';
            }
            // Check if first letter is capital
            if (trimmedValue[0] != trimmedValue[0].toUpperCase()) {
              return 'Name must start with a capital letter';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Email field (optional)
        TextFormField(
          controller: _emailController,
          decoration: const InputDecoration(
            labelText: 'Email (Optional)',
            prefixIcon: Icon(Icons.email),
            hintText: 'Enter email address',
          ),
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            // Email is optional, but if provided, it must be valid
            if (value != null && value.trim().isNotEmpty) {
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                return 'Please enter a valid email';
              }
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Phone field
        TextFormField(
          controller: _phoneController,
          decoration: const InputDecoration(
            labelText: 'Phone Number',
            prefixIcon: Icon(Icons.phone),
            hintText: 'Enter 10 digit mobile number',
          ),
          keyboardType: TextInputType.phone,
          maxLength: 10,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter phone number';
            }
            final trimmedValue = value.trim();
            // Check if it contains exactly 10 digits
            if (!RegExp(r'^\d{10}$').hasMatch(trimmedValue)) {
              return 'Phone number must be exactly 10 digits';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildWorkInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Work Information',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),

        // Position field
        Consumer<DepartmentProvider>(
          builder: (context, departmentProvider, child) {
            if (departmentProvider.isLoading) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Loading departments...',
                      style: GoogleFonts.poppins(color: Colors.grey),
                    ),
                  ],
                ),
              );
            }

            if (departmentProvider.error != null) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.red.shade300),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.red.shade50,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Error loading departments',
                        style: GoogleFonts.poppins(color: Colors.red),
                      ),
                    ),
                    TextButton(
                      onPressed: () => departmentProvider.loadDepartments(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            if (departmentProvider.departments.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.orange.shade300),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.orange.shade50,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.orange),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'No departments available. Please contact administrator.',
                        style: GoogleFonts.poppins(
                          color: Colors.orange.shade900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            return DropdownButtonFormField<Department>(
              value: _selectedDepartment,
              decoration: InputDecoration(
                labelText: 'Select Department',
                prefixIcon: const Icon(Icons.business),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              hint: Text(
                'Choose employee department',
                style: GoogleFonts.poppins(color: Colors.grey),
              ),
              items: departmentProvider.departments.map((department) {
                return DropdownMenuItem<Department>(
                  value: department,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        department.name,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      if (department.description != null && department.description!.isNotEmpty)
                        Text(
                          department.description!,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.black,
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (Department? newValue) {
                setState(() {
                  _selectedDepartment = newValue;
                });
              },
              validator: (value) {
                if (value == null) {
                  return 'Please select a department';
                }
                return null;
              },
            );
          },
        ),
        const SizedBox(height: 16),

        // Salary field
        TextFormField(
          controller: _salaryController,
          decoration: const InputDecoration(
            labelText: 'Monthly Salary',
            prefixIcon: Icon(Icons.currency_rupee),
          ),
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter salary';
            }
            if (double.tryParse(value) == null) {
              return 'Please enter a valid number';
            }
            if (double.parse(value) <= 0) {
              return 'Salary must be greater than 0';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        
        // Date of Birth field
        TextFormField(
          controller: _dateOfBirthController,
          readOnly: true,
          decoration: const InputDecoration(
            labelText: 'Date of Birth',
            prefixIcon: Icon(Icons.cake),
            hintText: 'Select date of birth',
          ),
          onTap: () async {
            final DateTime initialDate = _dateOfBirth ?? DateTime.now().subtract(const Duration(days: 365 * 25));
            final DateTime? picked = await showDatePicker(
              context: context,
              initialDate: initialDate,
              firstDate: DateTime(1950),
              lastDate: DateTime.now(),
              helpText: 'Select Date of Birth',
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.light(
                      primary: Color(0xFF2196F3),
                      onPrimary: Colors.white,
                      onSurface: Colors.black,
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (picked != null) {
              setState(() {
                _dateOfBirth = picked;
                _dateOfBirthController.text = DateFormat('dd MMM yyyy').format(picked);
              });
            }
          },
        ),
        const SizedBox(height: 16),
        
        // Date of Joining field
        TextFormField(
          controller: _dateOfJoiningController,
          readOnly: true,
          decoration: const InputDecoration(
            labelText: 'Date of Joining',
            prefixIcon: Icon(Icons.calendar_today),
          ),
          onTap: () async {
            final DateTime initialDate = _dateOfJoining ?? DateTime.now();
            final DateTime? picked = await showDatePicker(
              context: context,
              initialDate: initialDate,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
              helpText: 'Select Date of Joining',
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.light(
                      primary: Color(0xFF2196F3),
                      onPrimary: Colors.white,
                      onSurface: Colors.black,
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (picked != null) {
              setState(() {
                _dateOfJoining = picked;
                _dateOfJoiningController.text = DateFormat('dd MMM yyyy').format(picked);
              });
            }
          },
          validator: (value) {
            if (_dateOfJoining == null) return 'Please select date';
            return null;
          },
        ),
      ],
    );
  }



  Widget _buildShiftSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Shift Assignment',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),

        // Shift dropdown
        Consumer<ShiftProvider>(
          builder: (context, shiftProvider, child) {
            if (shiftProvider.isLoading) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Loading shifts...',
                      style: GoogleFonts.poppins(color: Colors.grey),
                    ),
                  ],
                ),
              );
            }

            if (shiftProvider.error != null) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.red.shade300),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.red.shade50,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Error loading shifts',
                        style: GoogleFonts.poppins(color: Colors.red),
                      ),
                    ),
                    TextButton(
                      onPressed: () => shiftProvider.loadShifts(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            if (shiftProvider.shifts.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.orange.shade300),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.orange.shade50,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.orange),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'No shifts available. Please create shifts in settings first.',
                        style: GoogleFonts.poppins(
                          color: Colors.orange.shade900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            return DropdownButtonFormField<Shift>(
              value: _selectedShift,
              decoration: InputDecoration(
                labelText: 'Select Shift',
                prefixIcon: const Icon(Icons.schedule),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              hint: Text(
                'Choose employee shift',
                style: GoogleFonts.poppins(color: Colors.grey),
              ),
              items: shiftProvider.shifts.map((shift) {
                return DropdownMenuItem<Shift>(
                  value: shift,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        shift.name,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      /*const SizedBox(height: 2),
                      Text(
                        '${shift.formattedFromTime} - ${shift.formattedToTime}',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),*/
                    ],
                  ),
                );
              }).toList(),
              onChanged: (Shift? newValue) {
                setState(() {
                  _selectedShift = newValue;
                });
              },
              validator: (value) {
                // Shift is optional
                return null;
              },
            );
          },
        ),

        // Show selected shift details
        if (_selectedShift != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF2196F3).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFF2196F3).withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.access_time,
                  size: 20,
                  color: Color(0xFF2196F3),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Selected: ${_selectedShift!.name} (${_selectedShift!.formattedFromTime} - ${_selectedShift!.formattedToTime})',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: const Color(0xFF2196F3),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRegisterButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _registerEmployee,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2196F3),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading
            ? const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // const Icon(Icons.person_add),
                  // const SizedBox(width: 8),
                  Text(
                    'Register',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
} 