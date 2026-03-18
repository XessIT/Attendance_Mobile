import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/link.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
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
    
    // Only call API if mobile number is valid (10 digits and starts with 6-9)
    if (mobileNumber.length == 10 && RegExp(r'^[6789]\d{9}$').hasMatch(mobileNumber)) {
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
   /* if (_companies.isEmpty) {
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
    }*/
    setState(() {
      _isLoading = true;
    });

    try {
      Map<String, dynamic> result;
      
      // Use different login methods based on whether companies are available
      if (_companies.isNotEmpty) {
        print('🏢 Companies found - Using login with company API');
        result = await ApiService.loginUserWithCompany(
          companyId: _selectedCompanyId!,
          mobileNumber: _mobileNumberController.text.trim(),
          password: _passwordController.text.trim(),
        );
        print('🔍 Using loginUserWithCompany API');
      } else {
        print('📱 No companies found - Using direct login API');
        // No companies found - use general login (for employees)
        result = await ApiService.loginUser(
          mobileNumber: _mobileNumberController.text.trim(),
          password: _passwordController.text.trim(),
        );
        print('🔍 Using loginUser API (no companies)');
      }
 
       print('🔍 Login API Response: $result');

      if (result['success'] == true) {
        // Get token from response
        String? token = result['token'];
        if (token == null && result['data'] != null && result['data'] is Map) {
          final data = result['data'] as Map;
          token = data['token']?.toString() ?? data['access_token']?.toString() ?? data['auth_token']?.toString();
        }

        if (token == null || token.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Login successful but no token received. Please try again.'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 3),
              ),
            );
          }
          return;
        }

        // Store token in secure storage
        await AuthUtils.setToken(token);
        print('✅ Token stored in secure storage');

        // Get role from JWT token (single source of truth), fallback to response
        String? role = AuthUtils.getRoleFromToken(token);
        if (role == null || role.isEmpty) {
          try {
            final data = result['data'];
            if (data is Map) {
              final inner = data['data'];
              if (inner is Map && inner['employee'] is Map) {
                role = (inner['employee'] as Map)['userType']?.toString();
              }
              role ??= data['userType']?.toString();
            }
          } catch (_) {}
          role ??= 'employee';
        }
        await AuthUtils.setUserType(role);
        print('👤 Role stored: $role');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Login successful!'),
              backgroundColor: Colors.green,
            ),
          );

          try {
            await _updateFcmToken();
          } catch (e) {
            debugPrint('⚠️ FCM token update failed: $e');
          }

          // Navigate by role (same logic as splash screen)
          if (role.toLowerCase() == 'employee') {
            Navigator.of(context).pushReplacementNamed('/employee-home');
          } else {
            Navigator.of(context).pushReplacementNamed('/home');
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

  Future<void> _updateFcmToken() async {
    debugPrint('========================================');
    debugPrint('🔔 FCM TOKEN UPDATE STARTED');
    debugPrint('========================================');
    
    try {
      debugPrint('📱 Attempting to get FCM token...');
      
      // Get FCM token
      final fcmToken = await FirebaseMessaging.instance.getToken();
      
      debugPrint('📱 FCM Token result: ${fcmToken != null ? "Token received" : "null"}');
      
      if (fcmToken != null && fcmToken.isNotEmpty) {
        debugPrint('✅ FCM Token retrieved: ${fcmToken.substring(0, fcmToken.length > 20 ? 20 : fcmToken.length)}...');
        debugPrint('📤 Sending FCM token to server...');
        
        // Call API to update FCM token
        final result = await ApiService.updateFcmToken(fcmToken: fcmToken);
        
        if (result['success'] == true) {
          debugPrint('✅ FCM token updated on server successfully');
        } else {
          debugPrint('⚠️ FCM token update returned unsuccessful response: $result');
        }
      } else {
        debugPrint('⚠️ FCM token is null or empty - skipping update');
      }
    } catch (e, stackTrace) {
      // Don't block login flow if FCM token update fails
      debugPrint('❌ Error updating FCM token: $e');
      debugPrint('Stack trace: $stackTrace');
      // Rethrow to be caught by the outer try-catch
      rethrow;
    } finally {
      debugPrint('========================================');
      debugPrint('🔔 FCM TOKEN UPDATE COMPLETED');
      debugPrint('========================================');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF667EEA),
              const Color(0xFF764BA2),
              const Color(0xFF2196F3),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Animated background elements
            _buildAnimatedBackground(),
            
            // Main content
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const SizedBox(height: 40),

                // Logo/Title Section
                Hero(
                  tag: 'app_logo',
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.face_retouching_natural,
                            size: 60,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'InstaMarQ',
                          style: GoogleFonts.poppins(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Face Recognition Attendance',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.9),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn(duration: 800.ms).scale(begin: const Offset(0.8, 0.8)),

                const SizedBox(height: 30),

                // Login Form
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 30,
                        offset: const Offset(0, 15),
                      ),
                      BoxShadow(
                        color: const Color(0xFF667EEA).withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 5),
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
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1A202C),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Sign in to continue to your account',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Mobile Number Field
                        TextFormField(
                          controller: _mobileNumberController,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                          decoration: InputDecoration(
                            labelText: 'Mobile Number',
                            labelStyle: GoogleFonts.poppins(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                            prefixIcon: Container(
                              padding: const EdgeInsets.all(12),
                              child: const Icon(
                                Icons.phone_outlined,
                                color: Color(0xFF667EEA),
                              ),
                            ),
                            suffixIcon: _isCheckingMobile
                                ? Container(
                                    padding: const EdgeInsets.all(16),
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          const Color(0xFF667EEA),
                                        ),
                                      ),
                                    ),
                                  )
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: Colors.grey[300]!,
                                width: 1,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: Colors.grey[300]!,
                                width: 1,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: Color(0xFF667EEA),
                                width: 2,
                              ),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: Colors.red,
                                width: 1,
                              ),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 16,
                            ),
                          ),
                          keyboardType: TextInputType.phone,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your mobile number';
                            }
                            
                            // Check if it's exactly 10 digits
                            if (value.length != 10) {
                              return 'Please enter a valid 10-digit mobile number';
                            }
                            
                            // Check if it starts with valid Indian mobile number prefixes
                            if (!RegExp(r'^[6789]').hasMatch(value)) {
                              return 'Mobile number must start with 6, 7, 8, or 9';
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
                              labelStyle: GoogleFonts.poppins(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                              prefixIcon: Container(
                                padding: const EdgeInsets.all(12),
                                child: const Icon(
                                  Icons.business_outlined,
                                  color: Color(0xFF667EEA),
                                ),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                  width: 1,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                  width: 1,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                  color: Color(0xFF667EEA),
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 16,
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
                            labelStyle: GoogleFonts.poppins(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                            prefixIcon: Container(
                              padding: const EdgeInsets.all(12),
                              child: const Icon(
                                Icons.lock_outlined,
                                color: Color(0xFF667EEA),
                              ),
                            ),
                            suffixIcon: Container(
                              padding: const EdgeInsets.all(12),
                              child: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: Colors.grey[600],
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: Colors.grey[300]!,
                                width: 1,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: Colors.grey[300]!,
                                width: 1,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: Color(0xFF667EEA),
                                width: 2,
                              ),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: Colors.red,
                                width: 1,
                              ),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 16,
                            ),
                          ),
                          obscureText: _obscurePassword,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.black87,
                          ),
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
                          height: 60,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF667EEA),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 24,
                              ),
                            ).copyWith(
                              overlayColor: WidgetStateProperty.resolveWith<Color?>(
                                (Set<WidgetState> states) {
                                  if (states.contains(WidgetState.pressed)) {
                                    return const Color(0xFF5A67D8).withOpacity(0.2);
                                  }
                                  if (states.contains(WidgetState.hovered)) {
                                    return const Color(0xFF5A67D8).withOpacity(0.1);
                                  }
                                  return null;
                                },
                              ),
                            ),
                            child: _isLoading
                                ? SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor: const AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.login_rounded,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Sign In',
                                        style: GoogleFonts.poppins(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF667EEA).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Link(
                              uri: Uri.parse('https://xesstechlink.com'),
                              builder: (context, followLink) => InkWell(
                                onTap: followLink,
                                borderRadius: BorderRadius.circular(20),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  child: Text(
                                    'Contact xesstechlink.com',
                                    style: GoogleFonts.poppins(
                                      color: const Color(0xFF667EEA),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn(duration: 600.ms, delay: 200.ms).slideY(begin: 0.1),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ],
    ),)
  );
}

// Animated background widget
Widget _buildAnimatedBackground() {
  return Stack(
    children: [
      // Floating circles
      Positioned(
        top: -50,
        left: -50,
        child: _buildFloatingCircle(
          const Color(0xFFFFFFFF).withOpacity(0.1),
          120,
          const Duration(seconds: 20),
        ),
      ),
      Positioned(
        top: 100,
        right: -30,
        child: _buildFloatingCircle(
          const Color(0xFFFFFFFF).withOpacity(0.08),
          80,
          const Duration(seconds: 15),
        ),
      ),
      Positioned(
        bottom: 200,
        left: -20,
        child: _buildFloatingCircle(
          const Color(0xFFFFFFFF).withOpacity(0.06),
          100,
          const Duration(seconds: 25),
        ),
      ),
      Positioned(
        bottom: -40,
        right: 100,
        child: _buildFloatingCircle(
          const Color(0xFFFFFFFF).withOpacity(0.1),
          60,
          const Duration(seconds: 18),
        ),
      ),
      
      // Moving dots pattern
      Positioned.fill(
        child: _buildMovingDots(),
      ),
    ],
  );
}

// Floating circle widget
Widget _buildFloatingCircle(Color color, double size, Duration duration) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
    ),
  ).animate(
    onPlay: (controller) => controller.repeat(),
  ).moveY(
    begin: -20,
    end: 20,
    duration: duration,
    curve: Curves.easeInOut,
  ).moveX(
    begin: -10,
    end: 10,
    duration: Duration(milliseconds: duration.inMilliseconds ~/ 2),
    curve: Curves.easeInOut,
  ).fade(
    begin: 0.3,
    end: 0.8,
    duration: Duration(milliseconds: duration.inMilliseconds ~/ 3),
    curve: Curves.easeInOut,
  );
}

// Moving dots pattern
Widget _buildMovingDots() {
  return Stack(
    children: List.generate(15, (index) {
      final random = index * 137; // Simple pseudo-random seed
      final size = 2.0 + (random % 4);
      final opacity = 0.1 + (random % 3) * 0.1;
      final duration = 10 + (random % 10);
      
      return Positioned(
        top: (random % 600).toDouble(),
        left: (random % 400).toDouble(),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(opacity),
            shape: BoxShape.circle,
          ),
        ),
      ).animate(
        onPlay: (controller) => controller.repeat(),
      ).fade(
        begin: 0.0,
        end: 1.0,
        duration: Duration(seconds: duration),
        curve: Curves.easeInOut,
      ).scale(
        begin: const Offset(0.5, 0.5),
        end: const Offset(1.5, 1.5),
        duration: Duration(seconds: duration),
        curve: Curves.easeInOut,
      );
    }),
  );
}
}
