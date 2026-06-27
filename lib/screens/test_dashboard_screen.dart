import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TestDashboardScreen extends StatefulWidget {
  const TestDashboardScreen({super.key});

  @override
  State<TestDashboardScreen> createState() => _TestDashboardScreenState();
}

class _TestDashboardScreenState extends State<TestDashboardScreen> {
  @override
  void initState() {
    super.initState();
    debugPrint('🧪 [TEST DASHBOARD] initState called');
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('🧪 [TEST DASHBOARD] Build method called');
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Test Dashboard',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF152A4A),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.dashboard,
              size: 100,
              color: Color(0xFF152A4A),
            ),
            const SizedBox(height: 20),
            Text(
              'Test Dashboard Working!',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'If you can see this, the UI is working fine.',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                debugPrint('🧪 [TEST DASHBOARD] Button pressed');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Test button working!'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF152A4A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: Text(
                'Test Button',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

