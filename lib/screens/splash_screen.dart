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
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Simulate loading time
    await Future.delayed(const Duration(seconds: 2));

    // Check if user is authenticated
    final isAuthenticated = await AuthUtils.isAuthenticated();
    final token = await AuthUtils.getToken();
    final userType = await AuthUtils.getUserType();

    debugPrint('🔍 Token check on app start:');
    debugPrint('   - isAuthenticated: $isAuthenticated');
    debugPrint('   - token: ${token != null ? "${token.substring(0, token.length > 10 ? 10 : token.length)}..." : "null"}');
    debugPrint('   - userType: $userType');

    if (isAuthenticated) {
      // Token exists, navigate to appropriate screen based on user type
      debugPrint('✅ User authenticated, navigating based on user type: $userType');

      // Load initial data for authenticated user (only for admin)
      if (userType != 'employee') {
        try {
          await Provider.of<EmployeeProvider>(context, listen: false).loadEmployees();
          await Provider.of<AttendanceProvider>(context, listen: false).loadAttendance();
        } catch (e) {
          // Handle error silently for now
          debugPrint('Error loading initial data: $e');
        }
      }

      if (mounted) {
        // Navigate to appropriate screen based on user type
        if (userType == 'employee') {
          debugPrint('👤 Navigating to employee home screen');
          Navigator.of(context).pushReplacementNamed('/employee-home');
        } else {
          debugPrint('👔 Navigating to admin home screen');
          Navigator.of(context).pushReplacementNamed('/home');
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