import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/auth_utils.dart';
import '../services/app_update_service.dart';

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
    await Future.delayed(const Duration(seconds: 2));

    final token = await AuthUtils.getToken();
    debugPrint('🔍 Splash: token present: ${token != null && token.isNotEmpty}');

    if (token == null || token.isEmpty) {
      if (mounted) Navigator.of(context).pushReplacementNamed('/login');
      return;
    }

    // Role from storage or decoded from token (and stored for next time)
    final role = await AuthUtils.getRoleForNavigation();
    debugPrint('🔍 Splash: role: $role');

    if (role == null || role.isEmpty) {
      if (mounted) Navigator.of(context).pushReplacementNamed('/login');
      return;
    }

    if (!mounted) return;
    await _checkForAppUpdates(context);
    if (!mounted) return;

    if (role.toLowerCase() == 'employee') {
      debugPrint('👤 Navigating to employee dashboard');
      Navigator.of(context).pushReplacementNamed('/employee-home');
    } else {
      debugPrint('👨‍💼 Navigating to admin dashboard');
      Navigator.of(context).pushReplacementNamed('/home');
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