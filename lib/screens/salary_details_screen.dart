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
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF1565C0), // Dark Blue
                Color(0xFF42A5F5), // Light Blue
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: false,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ClipRRect(
                //   borderRadius: BorderRadius.circular(6),
                //   child: Image.asset(
                //     'assets/icons/app_icon_cropped.png',
                //     width: 26,
                //     height: 26,
                //     fit: BoxFit.cover,
                //   ),
                // ),
                const SizedBox(width: 10),
                Text(
                  '$employeeName - Salary Details',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            foregroundColor: Colors.white,
            // actions: [
            //   Container(
            //     margin: const EdgeInsets.only(right: 8),
            //     decoration: BoxDecoration(
            //       color: Colors.white.withOpacity(0.2),
            //       borderRadius: BorderRadius.circular(12),
            //     ),
            //     child: IconButton(
            //       icon: const Icon(Icons.download_outlined, color: Colors.white),
            //       onPressed: () => _generatePayslip(context),
            //       tooltip: 'Download Payslip',
            //     ),
            //   ),
            //   IconButton(
            //     icon: const Icon(Icons.share_outlined),
            //     onPressed: () => _shareSalaryDetails(context),
            //     tooltip: 'Share Details',
            //   ),
            // ],
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.grey.shade50,
              Colors.white,
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary Card
              _buildSummaryCard(
                netSalary: double.tryParse(monthlyBreakdown['netSalary'].toString()) ?? 0.0,
                attendanceRate: double.tryParse(attendance['attendancePercentage'].toString()) ?? 0.0,
                workingDays: attendance['workingDays'],
                presentDays: attendance['presentDays'],
              ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.3, duration: 600.ms),
              
              const SizedBox(height: 20),
            // Employee Information Card
            _buildSectionCard(
              title: 'Employee Information',
              icon: Icons.person_outline,
              children: [
                _buildDetailRow('Employee ID', employee['employeeId'].toString()),
                _buildDetailRow('Name', employee['name']),
                _buildDetailRow('Department', employee['department']),
                _buildDetailRow('Shift', employee['shift']),
                _buildDetailRow('Monthly Salary', formatIndianCurrency(double.tryParse(employee['monthlySalary'].toString()) ?? 0.0)),
              ],
            ).animate().fadeIn(delay: 200.ms, duration: 600.ms).slideY(begin: 0.3, duration: 600.ms),
            
            const SizedBox(height: 16),
            
            // Attendance Information Card
            _buildSectionCard(
              title: 'Attendance Information',
              icon: Icons.calendar_today_outlined,
              children: [
                _buildDetailRow('Present Days', attendance['presentDays'].toString(),
                    valueColor: const Color(0xFF4CAF50)),
                _buildDetailRow('Absent Days', attendance['absentDays'].toString(),
                    valueColor: Colors.red),
                _buildDetailRow('Late Days', attendance['lateDays'].toString(),
                    valueColor: Colors.orange),
                _buildDetailRow('Half Days', attendance['halfDays'].toString(),
                    valueColor: Colors.amber),
                _buildDetailRow('Holiday Days', attendance['holidayDays'].toString(),
                    valueColor: Colors.blue),
                _buildDetailRow('Leave Days', attendance['leaveDays'].toString(),
                    valueColor: Colors.purple),
                _buildDetailRow('Working Days', attendance['workingDays'].toString()),
                _buildDetailRow('Attendance Rate', '${attendance['attendancePercentage']}%',
                    isBold: true, valueColor: const Color(0xFF2196F3)),
              ],
            ).animate().fadeIn(delay: 300.ms, duration: 600.ms).slideY(begin: 0.3, duration: 600.ms),
            
            const SizedBox(height: 16),
            
            // Salary Calculation Card
            _buildSectionCard(
              title: 'Salary Calculation',
              icon: Icons.calculate_outlined,
              children: [
                _buildDetailRow('Per Day Salary', formatIndianCurrency(double.tryParse(salary['perDaySalary'].toString()) ?? 0.0)),
                _buildDetailRow('Present Days Salary', formatIndianCurrency(double.tryParse(salary['presentDaysSalary'].toString()) ?? 0.0),
                    valueColor: const Color(0xFF4CAF50)),
                _buildDetailRow('Late Days Salary', formatIndianCurrency(double.tryParse(salary['lateDaysSalary'].toString()) ?? 0.0),
                    valueColor: Colors.orange),
                _buildDetailRow('Half Days Salary', formatIndianCurrency(double.tryParse(salary['halfDaysSalary'].toString()) ?? 0.0),
                    valueColor: Colors.amber),
                _buildDetailRow('Total Earned', formatIndianCurrency(double.tryParse(salary['totalEarnedSalary'].toString()) ?? 0.0),
                    isBold: true, valueColor: const Color(0xFF4CAF50)),
                _buildDetailRow('Total Deduction', formatIndianCurrency(double.tryParse(salary['totalDeduction'].toString()) ?? 0.0),
                    isBold: true, valueColor: Colors.red),
                const Divider(height: 24),
                _buildDetailRow('Net Payable', formatIndianCurrency(double.tryParse(salary['netPayableSalary'].toString()) ?? 0.0), 
                    isBold: true, valueColor: const Color(0xFF1565C0)),
              ],
            ).animate().fadeIn(delay: 400.ms, duration: 600.ms).slideY(begin: 0.3, duration: 600.ms),
            
            const SizedBox(height: 16),
            
            // Monthly Breakdown Card
            _buildSectionCard(
              title: 'Monthly Breakdown',
              icon: Icons.account_balance_wallet_outlined,
              children: [
                _buildDetailRow('Basic Salary', formatIndianCurrency(double.tryParse(monthlyBreakdown['basicSalary'].toString()) ?? 0.0)),
                _buildDetailRow('Allowances', formatIndianCurrency(double.tryParse(monthlyBreakdown['allowances']['total'].toString()) ?? 0.0),
                    valueColor: const Color(0xFF4CAF50)),
                _buildDetailRow('Gross Salary', formatIndianCurrency(double.tryParse(monthlyBreakdown['grossSalary'].toString()) ?? 0.0),
                    isBold: true),
                _buildDetailRow('Deductions', formatIndianCurrency(double.tryParse(monthlyBreakdown['deductions']['total'].toString()) ?? 0.0),
                    valueColor: Colors.red),
                _buildDetailRow('Net Salary', formatIndianCurrency(double.tryParse(monthlyBreakdown['netSalary'].toString()) ?? 0.0),
                    isBold: true, valueColor: const Color(0xFF1565C0)),
              ],
            ).animate().fadeIn(delay: 500.ms, duration: 600.ms).slideY(begin: 0.3, duration: 600.ms),
            
            const SizedBox(height: 24),
            
            // Action Buttons
            // _buildActionButtons().animate().fadeIn(delay: 600.ms, duration: 600.ms).slideY(begin: 0.3, duration: 600.ms),
            
            const SizedBox(height: 20),
          ],
        ),
      ),)
    );
  }

  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
    IconData? icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.grey.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1565C0).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      icon,
                      color: const Color(0xFF1565C0),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1565C0),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
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
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                color: valueColor ?? (isBold ? const Color(0xFF1565C0) : Colors.black87),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required double netSalary,
    required double attendanceRate,
    required int workingDays,
    required int presentDays,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1565C0),
            Color(0xFF42A5F5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Net Salary',
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatIndianCurrency(netSalary),
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${attendanceRate.toStringAsFixed(1)}%',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem('Present', presentDays.toString(), Colors.green),
              _buildSummaryItem('Working', workingDays.toString(), Colors.blue),
              _buildSummaryItem('Rate', '${attendanceRate.toStringAsFixed(0)}%', Colors.orange),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  // Widget _buildActionButtons() {
  //   return Row(
  //     children: [
  //       Expanded(
  //         child: ElevatedButton.icon(
  //           onPressed: () => _generatePayslip(context),
  //           icon: const Icon(Icons.download, size: 18),
  //           label: Text(
  //             'Download Payslip',
  //             style: GoogleFonts.poppins(
  //               fontSize: 14,
  //               fontWeight: FontWeight.w600,
  //             ),
  //           ),
  //           style: ElevatedButton.styleFrom(
  //             backgroundColor: const Color(0xFF1565C0),
  //             foregroundColor: Colors.white,
  //             padding: const EdgeInsets.symmetric(vertical: 14),
  //             shape: RoundedRectangleBorder(
  //               borderRadius: BorderRadius.circular(12),
  //             ),
  //             elevation: 2,
  //           ),
  //         ),
  //       ),
  //       const SizedBox(width: 12),
  //       Expanded(
  //         child: ElevatedButton.icon(
  //           onPressed: () => _shareSalaryDetails(context),
  //           icon: const Icon(Icons.share, size: 18),
  //           label: Text(
  //             'Share Details',
  //             style: GoogleFonts.poppins(
  //               fontSize: 14,
  //               fontWeight: FontWeight.w600,
  //             ),
  //           ),
  //           style: ElevatedButton.styleFrom(
  //             backgroundColor: Colors.white,
  //             foregroundColor: const Color(0xFF1565C0),
  //             side: const BorderSide(color: Color(0xFF1565C0)),
  //             padding: const EdgeInsets.symmetric(vertical: 14),
  //             shape: RoundedRectangleBorder(
  //               borderRadius: BorderRadius.circular(12),
  //             ),
  //             elevation: 0,
  //           ),
  //         ),
  //       ),
  //     ],
  //   );
  // }

  void _generatePayslip(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Payslip download started...',
          style: GoogleFonts.poppins(),
        ),
        backgroundColor: const Color(0xFF1565C0),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  void _shareSalaryDetails(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Share functionality coming soon!',
          style: GoogleFonts.poppins(),
        ),
        backgroundColor: const Color(0xFF1565C0),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
