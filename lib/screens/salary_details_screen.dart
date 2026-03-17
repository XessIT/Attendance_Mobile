import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';

// Indian currency formatter
String formatIndianCurrency(double amount) {
  final formatter = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );
  return formatter.format(amount);
}

class SalaryDetailsScreen extends StatelessWidget {
  final dynamic employeeData;
  final String employeeName;

  const SalaryDetailsScreen({
    super.key,
    required this.employeeData,
    required this.employeeName,
  });

  @override
  Widget build(BuildContext context) {
    final employee = employeeData['employee'];
    final attendance = employeeData['attendance'];
    final salary = employeeData['salary'];
    final monthlyBreakdown = employeeData['monthlySalaryBreakdown'];

    return Scaffold(
      appBar: AppBar(
        title: Text('$employeeName - Salary Details'),
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Employee Information Card
            _buildSectionCard(
              title: 'Employee Information',
              children: [
                _buildDetailRow('Employee ID', employee['employeeId'].toString()),
                _buildDetailRow('Name', employee['name']),
                _buildDetailRow('Department', employee['department']),
                _buildDetailRow('Shift', employee['shift']),
                _buildDetailRow('Monthly Salary', formatIndianCurrency(double.tryParse(employee['monthlySalary'].toString()) ?? 0.0)),
              ],
            ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.3, duration: 600.ms),
            
            const SizedBox(height: 16),
            
            // Attendance Information Card
            _buildSectionCard(
              title: 'Attendance Information',
              children: [
                _buildDetailRow('Present Days', attendance['presentDays'].toString()),
                _buildDetailRow('Absent Days', attendance['absentDays'].toString()),
                _buildDetailRow('Late Days', attendance['lateDays'].toString()),
                _buildDetailRow('Half Days', attendance['halfDays'].toString()),
                _buildDetailRow('Holiday Days', attendance['holidayDays'].toString()),
                _buildDetailRow('Leave Days', attendance['leaveDays'].toString()),
                _buildDetailRow('Working Days', attendance['workingDays'].toString()),
                _buildDetailRow('Attendance Rate', '${attendance['attendancePercentage']}%'),
              ],
            ).animate().fadeIn(delay: 200.ms, duration: 600.ms).slideY(begin: 0.3, duration: 600.ms),
            
            const SizedBox(height: 16),
            
            // Salary Calculation Card
            _buildSectionCard(
              title: 'Salary Calculation',
              children: [
                _buildDetailRow('Per Day Salary', formatIndianCurrency(double.tryParse(salary['perDaySalary'].toString()) ?? 0.0)),
                _buildDetailRow('Present Days Salary', formatIndianCurrency(double.tryParse(salary['presentDaysSalary'].toString()) ?? 0.0)),
                _buildDetailRow('Late Days Salary', formatIndianCurrency(double.tryParse(salary['lateDaysSalary'].toString()) ?? 0.0)),
                _buildDetailRow('Half Days Salary', formatIndianCurrency(double.tryParse(salary['halfDaysSalary'].toString()) ?? 0.0)),
                _buildDetailRow('Total Earned', formatIndianCurrency(double.tryParse(salary['totalEarnedSalary'].toString()) ?? 0.0)),
                _buildDetailRow('Total Deduction', formatIndianCurrency(double.tryParse(salary['totalDeduction'].toString()) ?? 0.0)),
                const Divider(),
                _buildDetailRow('Net Payable', formatIndianCurrency(double.tryParse(salary['netPayableSalary'].toString()) ?? 0.0), isBold: true),
              ],
            ).animate().fadeIn(delay: 400.ms, duration: 600.ms).slideY(begin: 0.3, duration: 600.ms),
            
            const SizedBox(height: 16),
            
            // Monthly Breakdown Card
            _buildSectionCard(
              title: 'Monthly Breakdown',
              children: [
                _buildDetailRow('Basic Salary', formatIndianCurrency(double.tryParse(monthlyBreakdown['basicSalary'].toString()) ?? 0.0)),
                _buildDetailRow('Allowances', formatIndianCurrency(double.tryParse(monthlyBreakdown['allowances']['total'].toString()) ?? 0.0)),
                _buildDetailRow('Gross Salary', formatIndianCurrency(double.tryParse(monthlyBreakdown['grossSalary'].toString()) ?? 0.0)),
                _buildDetailRow('Deductions', formatIndianCurrency(double.tryParse(monthlyBreakdown['deductions']['total'].toString()) ?? 0.0)),
                _buildDetailRow('Net Salary', formatIndianCurrency(double.tryParse(monthlyBreakdown['netSalary'].toString()) ?? 0.0)),
              ],
            ).animate().fadeIn(delay: 600.ms, duration: 600.ms).slideY(begin: 0.3, duration: 600.ms),
            
            const SizedBox(height: 24),
            
            // Generate Payslip Button
            // SizedBox(
            //   width: double.infinity,
            //   child: ElevatedButton(
            //     onPressed: () => _generatePayslip(context),
            //     style: ElevatedButton.styleFrom(
            //       backgroundColor: const Color(0xFF2196F3),
            //       foregroundColor: Colors.white,
            //       padding: const EdgeInsets.symmetric(vertical: 16),
            //       shape: RoundedRectangleBorder(
            //         borderRadius: BorderRadius.circular(8),
            //       ),
            //     ),
            //     child: Text(
            //       'Generate Payslip',
            //       style: GoogleFonts.poppins(
            //         fontSize: 16,
            //         fontWeight: FontWeight.w600,
            //       ),
            //     ),
            //   ),
            // ).animate().fadeIn(delay: 800.ms, duration: 600.ms).slideY(begin: 0.3, duration: 600.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF2196F3),
              ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: isBold ? const Color(0xFF2196F3) : Colors.black87,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _generatePayslip(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Payslip generation feature coming soon'),
        backgroundColor: Colors.blue,
      ),
    );
  }
}
