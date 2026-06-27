import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/employee_provider.dart';
import '../providers/attendance_provider.dart';
import '../utils/auth_utils.dart';
import '../utils/biometric_auth_service.dart';
import '../widgets/custom_bottom_nav_bar.dart';
import '../widgets/premium_app_bar.dart';
import 'dashboard_screen.dart';
import 'test_dashboard_screen.dart';
import 'employee_list_screen.dart';
import 'attendance_screen.dart';
import 'salary_screen.dart';
import 'settings_screen.dart';
import 'face_attendance_screen_new.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final List<Widget> _screens = [
    const DashboardScreen(), // Back to original dashboard with fixes
    const EmployeeListScreen(),
    const AttendanceScreen(),
    const SalaryScreen(),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
    _initAnimations();
    // Start animation immediately so the first screen is visible
    _animationController.forward(from: 0.0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          showEnableFingerprintOfferIfNeeded(context);
        }
      });
    });
  }

  Future<void> _openFingerprintOptions() async {
    await showFingerprintLoginOptionsDialog(context);
  }

  void _initAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _navigateToPage(int index) {
    if (_currentIndex != index) {
      setState(() {
        _currentIndex = index;
      });
      _animationController.forward(from: 0.0);
    }
  }

  Future<void> _loadData() async {
    try {
      debugPrint('🏠 [HOME SCREEN] Loading initial data...');
      await Provider.of<EmployeeProvider>(context, listen: false).loadEmployees();
      debugPrint('✅ [HOME SCREEN] Employees loaded');
      await Provider.of<AttendanceProvider>(context, listen: false).loadAttendance();
      debugPrint('✅ [HOME SCREEN] Attendance loaded');
      debugPrint('✅ [HOME SCREEN] Initial data loading completed');
    } catch (e) {
      debugPrint('❌ [HOME SCREEN] Error loading initial data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _logout() async {
    // Show confirmation dialog
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.rectangle,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10.0,
                offset: Offset(0.0, 10.0),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.logout,
                  color: Colors.red,
                  size: 28,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Log Out',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Are you sure you want to log out?',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      autofocus: true,
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Log Out',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (shouldLogout == true) {
      // Clear token and logout
      await AuthUtils.logout();

      if (mounted) {
        // Navigate back to login screen
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PremiumAppBar(
        title: 'InstaMarQ',
        titleWidget: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset(
                'assets/icons/app_icon_cropped.png',
                width: 26,
                height: 26,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 10),
            const Text('InstaMarQ'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.fingerprint),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FaceAttendanceScreen(shouldLoop: true),
                ),
              );
            },
            tooltip: 'Mark Attendance',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, 0.1),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            ),
          );
        },
        child: _screens[_currentIndex],
      ),
      bottomNavigationBar: CustomAnimatedBottomBar(
        containerHeight: 80,
        backgroundColor: Colors.white,
        selectedIndex: _currentIndex,
        showElevation: true,
        itemCornerRadius: 24,
        curve: Curves.easeInOut,
        containerPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        onItemSelected: _navigateToPage,
        items: <BottomNavyBarItem>[
          BottomNavyBarItem(
            icon: Icons.dashboard,
            title: Text(
              'Dashboard',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            activeColor: const Color(0xFF152A4A),
            inactiveColor: const Color(0xFF152A4A),
            textAlign: TextAlign.center,
          ),
          BottomNavyBarItem(
            icon: Icons.people,
            title: Text(
              'Employees',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            activeColor: const Color(0xFF152A4A),
            inactiveColor: const Color(0xFF152A4A),
            textAlign: TextAlign.center,
          ),
          BottomNavyBarItem(
            icon: Icons.access_time,
            title: Text(
              'Attendance',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            activeColor: const Color(0xFF152A4A),
            inactiveColor: const Color(0xFF152A4A),
            textAlign: TextAlign.center,
          ),
          BottomNavyBarItem(
            icon: Icons.work_outline,
            title: Text(
              'Salary',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            activeColor: const Color(0xFF152A4A),
            inactiveColor: const Color(0xFF152A4A),
            textAlign: TextAlign.center,
          ),
          BottomNavyBarItem(
            icon: Icons.settings,
            title: Text(
              'Shift',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            activeColor: const Color(0xFF152A4A),
            inactiveColor: const Color(0xFF152A4A),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

