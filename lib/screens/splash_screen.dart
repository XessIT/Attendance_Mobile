import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/employee_provider.dart';
import '../providers/attendance_provider.dart';
import '../utils/auth_utils.dart';
import '../services/api_service.dart';
import '../services/app_update_service.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _startApp();
  }

  // Check for app updates
  Future<void> _checkForAppUpdates(BuildContext context) async {
    try {
      final updateInfo = await AppUpdateService.checkForUpdate(context: context);
      
      if (updateInfo != null && updateInfo['updateAvailable'] == true) {
        if (mounted) {
          await AppUpdateService.showUpdateDialog(
            context: context,
            isForceUpdate: updateInfo['isForceUpdate'] ?? false,
            newVersion: updateInfo['newVersion'] ?? '',
            releaseNotes: updateInfo['releaseNotes'] ?? 'Bug fixes and performance improvements',
            appStoreUrl: updateInfo['downloadUrl'] ?? '',
            appSize: updateInfo['appSize'],
            currentVersion: updateInfo['currentVersion'],
          );
        }
      }
    } catch (e) {
      debugPrint('Error checking for app updates: $e');
    }
  }

  Future<void> _startApp() async {
    // Simulate loading time
    await Future.delayed(const Duration(seconds: 2));

    // Check if user is authenticated
    final isAuthenticated = await AuthUtils.isAuthenticated();
    final token = await AuthUtils.getToken();
    final storedUserType = await AuthUtils.getUserType();

    debugPrint('🔍 Token check on app start:');
    debugPrint('   - isAuthenticated: $isAuthenticated');
    debugPrint('   - token: ${token != null ? "${token.substring(0, token.length > 10 ? 10 : token.length)}..." : "null"}');
    debugPrint('   - storedUserType: $storedUserType');

    if (isAuthenticated && token != null) {
      String? userType = storedUserType;
      
      // If no stored user type, try to extract from JWT token
      if (userType == null) {
        try {
          userType = _extractUserTypeFromToken(token);
          debugPrint('   - extractedUserType: $userType');
          
          // Store extracted user type for future use
          if (userType != null) {
            await AuthUtils.storeUserType(userType);
            debugPrint('✅ Stored extracted user type: $userType');
          }
        } catch (e) {
          debugPrint('❌ Error extracting user type from token: $e');
        }
      }

      if (userType != null) {
        // Token and user type exist, navigate based on user type
        debugPrint('✅ User authenticated with type: $userType');

        // Load initial data for authenticated user
        try {
          await Provider.of<EmployeeProvider>(context, listen: false).loadEmployees();
          await Provider.of<AttendanceProvider>(context, listen: false).loadAttendance();
        } catch (e) {
          // Handle error silently for now
          debugPrint('Error loading initial data: $e');
        }
        if (mounted) {
          // Check for app updates before navigating
          await _checkForAppUpdates(context);
          
          if (mounted) {
            if (userType.toLowerCase() == 'employee') {
              debugPrint('👤 Navigating to employee home screen');
              Navigator.of(context).pushReplacementNamed('/employee-home');
            } else {
              debugPrint('👨‍💼 Navigating to admin home screen');
              Navigator.of(context).pushReplacementNamed('/home');
            }
          }
        }
      } else {
        // Token exists but no user type found, navigate to login to re-authenticate
        debugPrint('⚠️ Token exists but no user type found, navigating to login');
        
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/login');
        }
    } else {
      // No token, check if we need to call login directly
      debugPrint('❌ No token found, checking mobile number...');

      try {
        // Attempt to check mobile number
        final mobileNumber = "9123456789"; // This should be retrieved from somewhere, using a default for now
        final response = await ApiService.checkMobile(mobileNumber: mobileNumber);

        debugPrint('📱 Check mobile response: $response');

        // Check if the response indicates "No companies found"
        if (response['data'] != null &&
            response['data'] is Map &&
            response['data']['success'] == true &&
            response['data']['message'] != null &&
            response['data']['message'].toString().contains('No companies found')) {

          debugPrint('🏢 No companies found for this mobile number, calling login API directly...');

          // Call login API directly with default credentials
          final loginResponse = await ApiService.loginUser(
            mobileNumber: mobileNumber,
            password: "admin123", // Default password as per the curl example
          );

          debugPrint('🔐 Login response: $loginResponse');

          if (loginResponse['success'] == true && loginResponse['token'] != null) {
            // Save the token and navigate to home
            await AuthUtils.setToken(loginResponse['token']);

            debugPrint('✅ Direct login successful, navigating to home screen');

            // Load initial data for authenticated user
            try {
              await Provider.of<EmployeeProvider>(context, listen: false).loadEmployees();
              await Provider.of<AttendanceProvider>(context, listen: false).loadAttendance();
            } catch (e) {
              // Handle error silently for now
              debugPrint('Error loading initial data: $e');
            }

            if (mounted) {
              Navigator.of(context).pushReplacementNamed('/home');
            }
            return; // Exit early since we've handled the direct login
          }
        }
      } catch (e) {
        debugPrint('⚠️ Error during mobile check or direct login: $e');
        // Continue to regular login flow if there's an error
      }

      // Navigate to login screen if no direct login was performed
      debugPrint('➡️ Navigating to login screen');

      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }

  String? _extractUserTypeFromToken(String token) {
    try {
      // JWT tokens have 3 parts separated by dots: header.payload.signature
      final parts = token.split('.');
      if (parts.length != 3) {
        debugPrint('❌ Invalid JWT token format');
        return null;
      }

      // Decode the payload (middle part)
      final payload = parts[1];
      
      // Base64 decode the payload
      String normalizedPayload = payload;
      while (normalizedPayload.length % 4 != 0) {
        normalizedPayload += '=';
      }
      
      final decodedBytes = const Base64Decoder().convert(normalizedPayload);
      final decodedPayload = utf8.decode(decodedBytes);
      
      // Parse the JSON payload
      final payloadMap = json.decode(decodedPayload) as Map<String, dynamic>;
      
      // Extract userType
      final userType = payloadMap['userType'];
      debugPrint('🔍 JWT Payload: $decodedPayload');
      debugPrint('🔍 Extracted userType: $userType');
      
      return userType?.toString();
    } catch (e) {
      debugPrint('❌ Error decoding JWT token: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2196F3),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App Icon
            Container(
              width: 120,
              height: 120,
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
              child: const Icon(
                Icons.face,
                size: 60,
                color: Color(0xFF2196F3),
              ),
            )
                .animate()
                .fadeIn(duration: 600.ms)
                .scale(begin: const Offset(0.8, 0.8), duration: 600.ms),

            const SizedBox(height: 32),

            // App Title
            Text(
              'Face Recognition',
              style: GoogleFonts.poppins(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            )
                .animate()
                .fadeIn(delay: 300.ms, duration: 600.ms)
                .slideY(begin: 0.3, duration: 600.ms),

            Text(
              'Attendance System',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w400,
                color: Colors.white.withOpacity(0.9),
              ),
            )
                .animate()
                .fadeIn(delay: 600.ms, duration: 600.ms)
                .slideY(begin: 0.3, duration: 600.ms),

            const SizedBox(height: 80),

            // Loading indicator
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              strokeWidth: 3,
            )
                .animate()
                .fadeIn(delay: 900.ms, duration: 600.ms),

            const SizedBox(height: 24),

            Text(
              'Loading...',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.white.withOpacity(0.8),
              ),
            )
                .animate()
                .fadeIn(delay: 1200.ms, duration: 600.ms),
          ],
        ),
      ),
    );
  }
} 