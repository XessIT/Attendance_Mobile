import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/employee_provider.dart';
import '../providers/attendance_provider.dart';
import '../utils/auth_utils.dart';
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
          if (userType == 'employee') {
            debugPrint('👤 Navigating to employee home screen');
            Navigator.of(context).pushReplacementNamed('/employee-home');
          } else {
            debugPrint('👨‍💼 Navigating to admin home screen');
            Navigator.of(context).pushReplacementNamed('/home');
          }
        }
      } else {
        // Token exists but no user type found, navigate to login to re-authenticate
        debugPrint('⚠️ Token exists but no user type found, navigating to login');
        
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/login');
        }
      }
    } else {
      // No token, navigate to login screen
      debugPrint('❌ No token found, navigating to login screen');

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