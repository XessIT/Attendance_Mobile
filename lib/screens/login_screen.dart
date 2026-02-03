import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/link.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../utils/auth_utils.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _mobileNumberController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isCheckingMobile = false;
  List<Map<String, dynamic>> _companies = [];
  int? _selectedCompanyId;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    // Add listener to mobile number field
    _mobileNumberController.addListener(_onMobileNumberChanged);
  }

  @override
  void dispose() {
    _mobileNumberController.removeListener(_onMobileNumberChanged);
    _mobileNumberController.dispose();
    _passwordController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onMobileNumberChanged() {
    // Cancel previous timer
    _debounceTimer?.cancel();
    
    // Clear companies and selected company when mobile number changes
    setState(() {
      _companies = [];
      _selectedCompanyId = null;
    });

    final mobileNumber = _mobileNumberController.text.trim();
    
    // Only call API if mobile number is valid (10 digits)
    if (mobileNumber.length == 10 && RegExp(r'^\d{10}$').hasMatch(mobileNumber)) {
      // Debounce API call by 500ms
      _debounceTimer = Timer(const Duration(milliseconds: 500), () {
        _checkMobileNumber(mobileNumber);
      });
    }
  }

  Future<void> _checkMobileNumber(String mobileNumber) async {
    if (!mounted) return;

    setState(() {
      _isCheckingMobile = true;
    });

    try {
      final result = await ApiService.checkMobile(mobileNumber: mobileNumber);
      
      if (result['success'] == true && mounted) {
        final data = result['data'];
        if (data != null && data['data'] != null && data['data'] is List) {
          final companies = List<Map<String, dynamic>>.from(data['data']);
          setState(() {
            _companies = companies;
            // Auto-select if only one company
            if (companies.length == 1) {
              _selectedCompanyId = companies[0]['id'];
              _storeCompanyId(_selectedCompanyId!);
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        print('Error checking mobile number: $e');
        // Don't show error to user, just clear companies
        setState(() {
          _companies = [];
          _selectedCompanyId = null;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingMobile = false;
        });
      }
    }
  }

  Future<void> _storeCompanyId(int companyId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('company_id', companyId);
      print('✅ Company ID stored: $companyId');
    } catch (e) {
      print('❌ Error storing company ID: $e');
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate company selection if companies are available
    if (_companies.isNotEmpty && _selectedCompanyId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a company'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    // If no companies were fetched, show error
    if (_companies.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a valid mobile number to load companies'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Call the login API with company ID
      final result = await ApiService.loginUserWithCompany(
        companyId: _selectedCompanyId!,
        mobileNumber: _mobileNumberController.text.trim(),
        password: _passwordController.text.trim(),
      );

      print('🔍 Login API Response: $result');

      if (result['success'] == true) {
        // Store the token in local storage
        // Try multiple possible locations in the result
        String? token = result['token'];

        // If not found at top level, check in data nested structure
        if (token == null && result['data'] != null) {
          final data = result['data'];
          if (data is Map) {
            token = data['token'] ?? data['access_token'] ?? data['auth_token'];
          }
        }

        print('🔑 Token from result: $token');

        if (token != null && token.toString().isNotEmpty) {
          final success = await AuthUtils.setToken(token.toString());
          if (success) {
            print('✅ Token stored successfully: ${token.substring(0, token.length > 20 ? 20 : token.length)}...');
            // Verify token was stored
            final storedToken = await AuthUtils.getToken();
            print('🔍 Verification - Stored token exists: ${storedToken != null}');
          } else {
            print('❌ Failed to store token');
          }
        } else {
          print('⚠️ No token found in API response');
          // Show warning but still navigate since login was successful
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Login successful, but token storage failed. Some features may not work properly.'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 3),
              ),
            );
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Login successful!'),
              backgroundColor: Colors.green,
            ),
          );

          // Navigate to home/dashboard
          if (mounted) {
            String? userType;
            try {
              // Try to extract userType from result['data'] -> 'data' -> 'employee' -> 'userType'
              // result['data'] is the API response body
              final apiResponse = result['data'];
              if (apiResponse != null && apiResponse is Map) {
                final innerData = apiResponse['data'];
                if (innerData != null && innerData is Map) {
                  final employee = innerData['employee'];
                  if (employee != null && employee is Map) {
                    userType = employee['userType'];
                  }
                }
              }
            } catch (e) {
              print('Error parsing userType: $e');
            }

            print('👤 User Type: $userType');

            if (userType == 'employee') {
              Navigator.of(context).pushReplacementNamed('/employee-home');
            } else {
              Navigator.of(context).pushReplacementNamed('/home');
            }
          }
        }
      } else {
        throw Exception(result['message'] ?? 'Login failed');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login failed: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF2196F3),
              Color(0xFF1976D2),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 40),

                // Logo/Title Section
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.face_retouching_natural,
                        size: 80,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'InstaMarQ',
                        style: GoogleFonts.poppins(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Face Recognition Attendance System',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.2),

                const SizedBox(height: 40),

                // Login Form
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome Back',
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF2196F3),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Sign in to your account',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Mobile Number Field
                        TextFormField(
                          controller: _mobileNumberController,
                          decoration: InputDecoration(
                            labelText: 'Mobile Number',
                            prefixIcon: const Icon(Icons.phone_outlined),
                            suffixIcon: _isCheckingMobile
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: Padding(
                                      padding: EdgeInsets.all(12.0),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  )
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          keyboardType: TextInputType.phone,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your mobile number';
                            }
                            if (!RegExp(r'^\d{10}$').hasMatch(value.replaceAll(RegExp(r'\s+'), ''))) {
                              return 'Please enter a valid 10-digit mobile number';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        // Company Dropdown Field
                        if (_companies.isNotEmpty)
                          DropdownButtonFormField<int>(
                            value: _selectedCompanyId,
                            decoration: InputDecoration(
                              labelText: 'Company',
                              prefixIcon: const Icon(Icons.business_outlined),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            items: _companies.map((company) {
                              return DropdownMenuItem<int>(
                                value: company['id'],
                                child: Text(
                                  company['companyName'] ?? 'Unknown Company',
                                  style: GoogleFonts.poppins(),
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedCompanyId = value;
                              });
                              if (value != null) {
                                _storeCompanyId(value);
                              }
                            },
                            validator: (value) {
                              if (_companies.isNotEmpty && value == null) {
                                return 'Please select a company';
                              }
                              return null;
                            },
                          ),
                        if (_companies.isNotEmpty) const SizedBox(height: 20),

                        // Password Field
                        TextFormField(
                          controller: _passwordController,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outlined),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          obscureText: _obscurePassword,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your password';
                            }
                            if (value.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        const SizedBox(height: 32),

                        // Login Button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2196F3),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                            child: _isLoading
                                ? const CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.login),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Sign In',
                                        style: GoogleFonts.poppins(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Center(
                          child: Link(
                            uri: Uri.parse('https://xesstechlink.com'),
                            builder: (context, followLink) => InkWell(
                              onTap: followLink,
                              child: Text(
                                'Contact xesstechlink.com',
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFF2196F3),
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn(duration: 600.ms, delay: 200.ms).slideY(begin: 0.1),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
