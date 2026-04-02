import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'providers/employee_provider.dart';
import 'providers/attendance_provider.dart';
import 'providers/shift_provider.dart';
import 'providers/department_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/registration_screen.dart';
import 'screens/home_screen.dart';
import 'screens/employee_home_screen.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Firebase differently for web vs mobile
  try {
    if (kIsWeb) {
      // For web, initialize with options
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: "AIzaSyBzGgXe2YuR46u2m3O7N5H1o8Q8v3v8Y00",
          appId: "1:123456789012:web:1234567890abcdef",
          messagingSenderId: "123456789012",
          projectId: "test-project",
          authDomain: "test-project.firebaseapp.com",
          storageBucket: "test-project.appspot.com",
        ),
      );
    } else {
      // For mobile, use default initialization
      await Firebase.initializeApp();
    }

    // Initialize Notification Service
    await NotificationService().initialize();
  } catch (e) {
    // If Firebase initialization fails, continue without it (for development purposes)
    debugPrint('Firebase initialization failed: $e');
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => EmployeeProvider()),
        ChangeNotifierProvider(create: (_) => AttendanceProvider()),
        ChangeNotifierProvider(create: (_) => ShiftProvider()),
        ChangeNotifierProvider(create: (_) => DepartmentProvider()),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'Face Recognition Attendance',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF2196F3),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          textTheme: GoogleFonts.poppinsTextTheme(),
          appBarTheme: AppBarTheme(
            backgroundColor: const Color(0xFF2196F3),
            foregroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
            titleTextStyle: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2196F3),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF2196F3), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        initialRoute: '/splash',
        routes: {
          '/splash': (context) => const SplashScreen(),
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const RegistrationScreen(),
          '/home': (context) => HomeScreen(),
          '/employee-home': (context) => EmployeeHomeScreen(),
        },
      ),
    );
  }
}
//leas