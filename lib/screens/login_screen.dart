import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/link.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/api_service.dart';
import '../services/local_storage_service.dart';
import '../utils/auth_utils.dart';
import '../utils/biometric_auth_service.dart';

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
  final BiometricAuthService _biometric = BiometricAuthService();
  bool _isBiometricAvailable = false;
  bool _isBiometricSupported = false;
  bool _isBiometricLoading = false;
  bool _hasAttemptedAutoBiometric = false;

  @override
  void initState() {
    super.initState();
    // Add listener to mobile number field
    _mobileNumberController.addListener(_onMobileNumberChanged);
    _initializeBiometricAuth();
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

  Future<void> _initializeBiometricAuth() async {
    try {
      final supported = await _biometric.isSupported();
      final enabled = await _biometric.isEnabled();
      final hasCreds = await _biometric.hasStoredCredentials();
      if (!mounted) return;
      setState(() {
        _isBiometricSupported = supported;
        _isBiometricAvailable = supported && enabled && hasCreds;
        _hasAttemptedAutoBiometric = false;
      });
      if (_isBiometricAvailable) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _triggerAutoBiometricLogin();
          }
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isBiometricSupported = false;
        _isBiometricAvailable = false;
      });
    }
  }

  Future<void> _triggerAutoBiometricLogin() async {
    if (_hasAttemptedAutoBiometric ||
        !_isBiometricAvailable ||
        _isLoading ||
        _isBiometricLoading) {
      return;
    }
    _hasAttemptedAutoBiometric = true;
    await _loginWithBiometrics(showErrorSnackBar: false);
  }

  Future<void> _loginWithBiometrics({bool showErrorSnackBar = true}) async {
    if (_isLoading || _isBiometricLoading) return;

    setState(() {
      _isBiometricLoading = true;
    });

    try {
      final authenticated = await _biometric.authenticate(
        reason: 'Authenticate to sign in',
      );

      if (!authenticated) return;

      final creds = await _biometric.readCredentials();
      if (creds.mobile.isEmpty || creds.password.isEmpty) {
        throw Exception('No saved login details found for biometric sign in');
      }

      await _performLogin(
        mobileNumber: creds.mobile,
        password: creds.password,
        companyId: creds.companyId,
        saveBiometricCredentials: false,
      );
    } catch (e) {
      if (!mounted) return;
      if (showErrorSnackBar) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Biometric sign in failed: ${e.toString().replaceAll('Exception: ', '')}',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBiometricLoading = false;
        });
      }
    }
  }

  Future<void> _performLogin({
    required String mobileNumber,
    required String password,
    int? companyId,
    required bool saveBiometricCredentials,
  }) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Clear any existing cache before starting a new session to prevent data overlap
      await LocalStorageService.clearAllCache();
      Map<String, dynamic> result;

      if (companyId != null) {
        print('🏢 Company selected - Using login with company API');
        result = await ApiService.loginUserWithCompany(
          companyId: companyId,
          mobileNumber: mobileNumber,
          password: password,
        );
        print('🔍 Using loginUserWithCompany API');
      } else {
        print('📱 No company selected - Using direct login API');
        result = await ApiService.loginUser(
          mobileNumber: mobileNumber,
          password: password,
        );
        print('🔍 Using loginUser API (no companies)');
      }

      print('🔍 Login API Response: $result');

      if (result['success'] == true) {
        String? token = result['token'];
        if (token == null && result['data'] != null && result['data'] is Map) {
          final data = result['data'] as Map;
          token = data['token']?.toString() ??
              data['access_token']?.toString() ??
              data['auth_token']?.toString();
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

        await AuthUtils.setToken(token);
        print('✅ Token stored in secure storage');

        String? refreshToken = result['refreshToken'];
        if (refreshToken != null && refreshToken.isNotEmpty) {
          await AuthUtils.setRefreshToken(refreshToken);
          print('✅ Refresh Token stored in secure storage');
        }

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

        if (saveBiometricCredentials) {
          await _biometric.storeCredentials(
            mobileNumber: mobileNumber,
            password: password,
            companyId: companyId,
          );
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Login successful!',
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              backgroundColor: Colors.green.shade600,
              behavior: SnackBarBehavior.floating,
              margin: EdgeInsets.only(
                bottom: MediaQuery.of(context).size.height - 170 > 0 
                    ? MediaQuery.of(context).size.height - 170 
                    : 0,
                right: 20,
                left: MediaQuery.of(context).size.width > 240 
                    ? MediaQuery.of(context).size.width - 220 
                    : 20,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              duration: const Duration(seconds: 3),
              elevation: 4,
            ),
          );

          try {
            await _updateFcmToken();
          } catch (e) {
            debugPrint('⚠️ FCM token update failed: $e');
          }

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
    await _performLogin(
      mobileNumber: _mobileNumberController.text.trim(),
      password: _passwordController.text.trim(),
      companyId: _selectedCompanyId,
      // Always store last successful credentials securely.
      // Biometric login can be enabled later from Home via dialog.
      saveBiometricCredentials: true,
    );
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
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Top Wavy Header
            ClipPath(
              clipper: HeaderWaveClipper(),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.40,
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF020617), Color(0xFF152A4A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        height: 90,
                        width: 90,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Gradient Ring
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFF3B82F6),
                                  width: 6,
                                ),
                              ),
                            ),
                            // Person Icon
                            const Icon(
                              Icons.person,
                              size: 56,
                              color: Colors.white,
                            ),
                            // Checkmark Overlap
                            Positioned(
                              bottom: -2,
                              right: -2,
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Color(0xFF152A4A), // Match the new background
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(2),
                                child: const Icon(
                                  Icons.check_circle,
                                  color: Color(0xFF3B82F6),
                                  size: 32,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'INSTAMARQ',
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 2.0,
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
            
            // Form Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Text(
                      'Welcome back !',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.2),
                    const SizedBox(height: 32),

                    // Mobile Number Field
                    _buildInputField(
                      controller: _mobileNumberController,
                      hintText: 'Mobile Number',
                      icon: Icons.smartphone,
                      isChecking: _isCheckingMobile,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return 'Please enter your mobile number';
                        if (value.length != 10) return 'Please enter a valid 10-digit mobile number';
                        if (!RegExp(r'^[6789]').hasMatch(value)) return 'Mobile number must start with 6, 7, 8, or 9';
                        return null;
                      },
                    ).animate().fadeIn(duration: 600.ms, delay: 200.ms).slideY(begin: 0.2),
                    const SizedBox(height: 16),

                    // Company Dropdown Field
                    if (_companies.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: _inputDecoration(),
                        child: DropdownButtonFormField<int>(
                          value: _selectedCompanyId,
                          decoration: InputDecoration(
                            hintText: 'Company',
                            hintStyle: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 14),
                            prefixIcon: const Icon(Icons.business_outlined, color: Color(0xFF334155)),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                          ),
                          items: _companies.map((company) {
                            return DropdownMenuItem<int>(
                              value: company['id'],
                              child: Text(company['companyName'] ?? 'Unknown Company', style: GoogleFonts.poppins()),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedCompanyId = value;
                            });
                            if (value != null) _storeCompanyId(value);
                          },
                          validator: (value) {
                            if (_companies.isNotEmpty && value == null) return 'Please select a company';
                            return null;
                          },
                        ),
                      ).animate().fadeIn(duration: 600.ms, delay: 250.ms).slideY(begin: 0.2),

                    // Password Field
                    _buildInputField(
                      controller: _passwordController,
                      hintText: 'Password',
                      icon: Icons.lock_outline,
                      obscureText: _obscurePassword,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                          color: Colors.grey[400],
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return 'Please enter your password';
                        if (value.length != 6) return 'Password must be exactly 6 digits';
                        return null;
                      },
                    ).animate().fadeIn(duration: 600.ms, delay: 300.ms).slideY(begin: 0.2),
                    const SizedBox(height: 16),
                    
                    const SizedBox(height: 32),

                    // Login Button
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: OutlinedButton(
                        onPressed: _isLoading ? null : _login,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF152A4A), width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF152A4A)),
                                ),
                              )
                            : Text(
                                'Login',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF152A4A),
                                ),
                              ),
                      ),
                    ).animate().fadeIn(duration: 600.ms, delay: 400.ms).slideY(begin: 0.2),
                    
                    const SizedBox(height: 24),



                    // Footer
                    Center(
                      child: Link(
                        uri: Uri.parse('https://xesstechlink.com'),
                        builder: (context, followLink) => InkWell(
                          onTap: followLink,
                          child: Text(
                            'Powered by xesstechlink.in',
                            style: GoogleFonts.poppins(
                              color: Colors.grey[400],
                              fontWeight: FontWeight.w500,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                    ).animate().fadeIn(duration: 600.ms, delay: 800.ms).slideY(begin: 0.2),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  BoxDecoration _inputDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(30),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF152A4A).withOpacity(0.08),
          blurRadius: 20,
          offset: const Offset(0, 10),
        ),
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool isChecking = false,
    bool obscureText = false,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    Widget? suffixIcon,
  }) {
    return Container(
      decoration: _inputDecoration(),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        validator: validator,
        style: GoogleFonts.poppins(
          fontSize: 14,
          color: Colors.black87,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: GoogleFonts.poppins(
            color: Colors.grey[400],
            fontSize: 14,
          ),
          prefixIcon: Container(
            padding: const EdgeInsets.all(16),
            child: Icon(
              icon,
              color: const Color(0xFF334155),
            ),
          ),
          suffixIcon: isChecking
              ? Container(
                  padding: const EdgeInsets.all(16),
                  child: const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF020617)),
                    ),
                  ),
                )
              : suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 18,
            horizontal: 20,
          ),
        ),
      ),
    );
  }
}


class HeaderWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    path.lineTo(0, size.height - 60);

    var firstControlPoint = Offset(size.width / 4, size.height);
    var firstEndPoint = Offset(size.width / 2.25, size.height - 30);
    path.quadraticBezierTo(firstControlPoint.dx, firstControlPoint.dy, firstEndPoint.dx, firstEndPoint.dy);

    var secondControlPoint = Offset(size.width - (size.width / 3.25), size.height - 105);
    var secondEndPoint = Offset(size.width, size.height - 40);
    path.quadraticBezierTo(secondControlPoint.dx, secondControlPoint.dy, secondEndPoint.dx, secondEndPoint.dy);

    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}


