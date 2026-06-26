import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../widgets/premium_app_bar.dart';

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
  
  XFile? _faceImage;
  bool _isLoading = false;
  bool _isCapturing = false;
  Shift? _selectedShift;
  Department? _selectedDepartment;
  DateTime? _dateOfJoining;
  DateTime? _dateOfBirth;
  late TextEditingController _dateOfJoiningController;
  late TextEditingController _dateOfBirthController;
  late TextEditingController _passwordController;

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
    _passwordController = TextEditingController(
      text: _generatePasswordFromDate(_dateOfJoining!),
    );
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
    _passwordController.dispose();
    super.dispose();
  }

  String _generatePasswordFromDate(DateTime date) {
    // Format date as YYYYMMDD (numbers only)
    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year$month$day';
  }

  // Remove commas from salary string for parsing
  String _removeCommas(String value) {
    return value.replaceAll(',', '');
  }

  // Format number with commas (Indian numbering system: 1,00,000)
  String _formatNumberWithCommas(String value) {
    // Remove all non-digit characters first
    final digitsOnly = value.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.isEmpty) return '';
    
    // Parse and format with commas using Indian numbering system
    try {
      final number = int.parse(digitsOnly);
      // Format with Indian numbering system (lakhs, crores)
      if (number < 1000) {
        return number.toString();
      } else if (number < 100000) {
        // Format as: 12,345
        final thousands = number ~/ 1000;
        final remainder = number % 1000;
        return '$thousands,${remainder.toString().padLeft(3, '0')}';
      } else {
        // Format as: 1,23,456 (Indian system)
        final crores = number ~/ 10000000;
        final lakhs = (number % 10000000) ~/ 100000;
        final thousands = (number % 100000) ~/ 1000;
        final remainder = number % 1000;
        
        String result = '';
        if (crores > 0) {
          result += '$crores,';
        }
        if (lakhs > 0 || crores > 0) {
          result += '${lakhs.toString().padLeft(2, '0')},';
        }
        result += '${thousands.toString().padLeft(2, '0')},';
        result += remainder.toString().padLeft(3, '0');
        return result;
      }
    } catch (e) {
      return value;
    }
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
          _faceImage = image;
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
          _faceImage = image;
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

  void _clearForm() {
    setState(() {
      _nameController.clear();
      _emailController.clear();
      _phoneController.clear();
      _positionController.clear();
      _salaryController.clear();
      _faceImage = null;
      _selectedShift = null;
      _selectedDepartment = null;
      _dateOfBirth = null;
      _dateOfBirthController.clear();
      
      _dateOfJoining = DateTime.now();
      _dateOfJoiningController.text = DateFormat('dd MMM yyyy').format(_dateOfJoining!);
      _passwordController.text = _generatePasswordFromDate(_dateOfJoining!);
    });
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

    if (_dateOfJoining == null) {
      print('❌ [EMPLOYEE REGISTRATION] Date of joining is not set');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select date of joining'),
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
      // Remove commas from salary before parsing
      final salaryText = _removeCommas(_salaryController.text.trim());
      final employee = Employee(
        name: _nameController.text.trim(),
        email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        position: _selectedDepartment?.name ?? 'Employee',
        salary: double.parse(salaryText),
        dateOfJoining: _dateOfJoining,
        dateOfBirth: _dateOfBirth,
        faceData: '', // Will be set after face registration
        createdAt: DateTime.now(),
        shiftId: _selectedShift?.id,
        departmentId: _selectedDepartment?.id,
      );

      // Generate password from date of joining (YYYYMMDD format)
      final password = _generatePasswordFromDate(_dateOfJoining!);
      print('🔑 [EMPLOYEE REGISTRATION] Generated password: $password');

      print('📝 [EMPLOYEE REGISTRATION] Employee object created:');
      print('   Name: ${employee.name}');
      print('   Email: ${employee.email}');
      print('   Phone: ${employee.phone}');
      print('   Position: ${employee.position}');
      print('   Salary: ${employee.salary}');
      print('   Department: ${_selectedDepartment?.name ?? "Not selected"}');
      print('   Shift: ${_selectedShift?.name ?? "Not selected"}');
      print('   Password: $password');
      print('   Date of Joining: ${_dateOfJoining?.toString() ?? "Not set"}');
      print('   Face Image Path: ${_faceImage!.path}');
      print('   Payloan: ${employee.payloan}');

      // Create employee in database with image upload (new API handles both)
      print('📤 [EMPLOYEE REGISTRATION] Calling createEmployee API with image and password...');
      final employeeProvider = Provider.of<EmployeeProvider>(context, listen: false);
      final success = await employeeProvider.createEmployee(
        employee, 
        imageFile: _faceImage!,
        shiftName: _selectedShift?.name,
        departmentName: _selectedDepartment?.name,
        departmentId: _selectedDepartment?.id,
        password: password,
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
      appBar: const PremiumAppBar(
        title: 'Register Employee',
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

              // Action Buttons
              _buildRegisterButton(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String label, IconData icon, {String? hintText, String? helperText, Color? fillColor, Color? iconColor}) {
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      helperText: helperText,
      labelStyle: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 13),
      prefixIcon: Icon(icon, color: iconColor ?? const Color(0xFF2196F3), size: 20),
      filled: true,
      fillColor: fillColor ?? Colors.grey.shade50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF2196F3), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.red.shade300, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF2196F3).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFF2196F3), size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildFaceImageSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Face Image', Icons.face_retouching_natural),
          const SizedBox(height: 24),
          
          // Circular Face image preview
          Center(
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                shape: BoxShape.circle,
                border: Border.all(
                  color: _faceImage != null ? const Color(0xFF2196F3) : Colors.grey.shade300, 
                  width: 3,
                ),
                boxShadow: [
                  if (_faceImage != null)
                    BoxShadow(
                      color: const Color(0xFF2196F3).withOpacity(0.2),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                ],
              ),
              child: _faceImage != null
                  ? ClipOval(
                      child: kIsWeb
                          ? Image.network(
                              _faceImage!.path,
                              fit: BoxFit.cover,
                              width: 140,
                              height: 140,
                            )
                          : Image.file(
                              File(_faceImage!.path),
                              fit: BoxFit.cover,
                              width: 140,
                              height: 140,
                            ),
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 40,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'No Photo',
                            style: GoogleFonts.poppins(
                              color: Colors.grey.shade500,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 24),
          
          // Action buttons
          if (_faceImage == null)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isCapturing ? null : _captureFaceImage,
                icon: _isCapturing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.camera_alt_outlined),
                label: Text(
                  _isCapturing ? 'Opening Camera...' : 'Open Camera',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2196F3),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _faceImage = null;
                      });
                    },
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: Text(
                      'Remove',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isCapturing ? null : _captureFaceImage,
                    icon: _isCapturing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.camera_alt_outlined, size: 18),
                    label: Text(
                      'Retake',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2196F3),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Personal Information', Icons.person_outline),
          const SizedBox(height: 20),

          // Name field
          TextFormField(
            controller: _nameController,
            decoration: _buildInputDecoration('Full Name', Icons.badge_outlined, hintText: 'Enter full name'),
            textCapitalization: TextCapitalization.words,
            inputFormatters: [
              _CapitalizeWordsInputFormatter(),
            ],
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
          const SizedBox(height: 20),

        // Phone field
        TextFormField(
          controller: _phoneController,
          decoration: _buildInputDecoration('Phone Number', Icons.phone_outlined, hintText: 'Enter 10 digit mobile number'),
          keyboardType: TextInputType.phone,
          maxLength: 10,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
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
        const SizedBox(height: 20),

        // Email field (optional)
        TextFormField(
          controller: _emailController,
          decoration: _buildInputDecoration('Email (Optional)', Icons.email_outlined, hintText: 'Enter email address'),
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
      ],
    ),
    );
  }

  Widget _buildWorkInfoSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Work Information', Icons.work_outline),
          const SizedBox(height: 20),

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
              decoration: _buildInputDecoration('Select Department', Icons.business_outlined, hintText: 'Choose employee department'),
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
        const SizedBox(height: 20),

        // Salary field
        TextFormField(
          controller: _salaryController,
          decoration: _buildInputDecoration('Monthly Salary', Icons.currency_rupee, helperText: 'Enter amount'),
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            IndianCurrencyFormatter(),
          ],
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter salary';
            }
            // Remove commas before parsing
            final numericValue = _removeCommas(value);
            if (double.tryParse(numericValue) == null) {
              return 'Please enter a valid number';
            }
            if (double.parse(numericValue) <= 0) {
              return 'Salary must be greater than 0';
            }
            return null;
          },
        ),
        const SizedBox(height: 20),
        
        // Date of Birth field
        TextFormField(
          controller: _dateOfBirthController,
          readOnly: true,
          decoration: _buildInputDecoration('Date of Birth', Icons.cake_outlined, hintText: 'Select date of birth'),
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
        const SizedBox(height: 20),
        
        // Date of Joining field
        TextFormField(
          controller: _dateOfJoiningController,
          readOnly: true,
          decoration: _buildInputDecoration('Date of Joining', Icons.calendar_today_outlined),
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
                _passwordController.text = _generatePasswordFromDate(picked);
              });
            }
          },
          validator: (value) {
            if (_dateOfJoining == null) return 'Please select date';
            return null;
          },
        ),
        const SizedBox(height: 20),
        
        // Password field (auto-generated from date of joining)
        TextFormField(
          controller: _passwordController,
          readOnly: true,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: const Color(0xFF1565C0)),
          decoration: _buildInputDecoration('Password (Auto-generated)', Icons.lock, helperText: 'Generated from date of joining (YYYYMMDD)', fillColor: const Color(0xFFE3F2FD), iconColor: const Color(0xFF1565C0)),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Password is required';
            }
            return null;
          },
        ),
      ],
    ),
    );
  }



  Widget _buildShiftSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Shift Assignment', Icons.schedule_outlined),
          const SizedBox(height: 20),

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
              decoration: _buildInputDecoration('Select Shift', Icons.schedule_outlined, hintText: 'Choose employee shift'),
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
    ),
    );
  }

  Widget _buildRegisterButton() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _clearForm,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade100,
                foregroundColor: Colors.grey.shade800,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                'Clear',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _registerEmployee,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2196F3),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        strokeWidth: 2.5,
                      ),
                    )
                  : Text(
                      'Register',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class IndianCurrencyFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.selection.baseOffset == 0) {
      return newValue;
    }
    String digitsOnly = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.isEmpty) return newValue.copyWith(text: '');
    
    final formatter = NumberFormat.currency(locale: 'en_IN', symbol: '', decimalDigits: 0);
    String newText = formatter.format(int.parse(digitsOnly)).trim();
    
    return newValue.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}

class _CapitalizeWordsInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      return newValue;
    }
    
    // Capitalize first letter of each word
    String newText = newValue.text;
    List<String> words = newText.split(' ');
    for (int i = 0; i < words.length; i++) {
      if (words[i].isNotEmpty) {
        words[i] = words[i][0].toUpperCase() + words[i].substring(1);
      }
    }
    newText = words.join(' ');
    
    return TextEditingValue(
      text: newText,
      selection: newValue.selection,
    );
  }
}