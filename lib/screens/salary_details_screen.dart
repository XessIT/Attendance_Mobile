import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'attendance_detail_report_screen.dart';

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
  final String? startDate;
  final String? endDate;

  const SalaryDetailsScreen({
    super.key,
    required this.employeeData,
    required this.employeeName,
    this.startDate,
    this.endDate,
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
                Color(0xFF152A4A), // Dark Blue
                Color(0xFF1E293B), // Light Blue
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF152A4A).withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 5),
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
                    valueColor: const Color(0xFF152A4A)),
                _buildDetailRow('Leave Days', attendance['leaveDays'].toString(),
                    valueColor: Colors.purple),
                _buildDetailRow('Working Days', attendance['workingDays'].toString()),
                _buildDetailRow('Attendance Rate', '${attendance['attendancePercentage']}%',
                    isBold: true, valueColor: const Color(0xFF152A4A)),
                
                const Divider(height: 32),
                
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (startDate != null && endDate != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AttendanceDetailReportScreen(
                              employeeId: employee['id'],
                              employeeName: employeeName,
                              startDate: startDate!,
                              endDate: endDate!,
                            ),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.list_alt_rounded),
                    label: const Text('View Full Details'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF152A4A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),
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
                    isBold: true, valueColor: const Color(0xFF020617)),
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
                    isBold: true, valueColor: const Color(0xFF020617)),
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
    return _ExpandableSectionCard(
      title: title,
      children: children,
      icon: icon,
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade500,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.poppins(
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                color: valueColor ?? (isBold ? const Color(0xFF152A4A) : Colors.grey.shade800),
                fontSize: 15,
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF152A4A),
            Color(0xFF152A4A),
            Color(0xFF334155),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF152A4A).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Subtle background decoration
          Positioned(
            right: -20,
            top: -20,
            child: Icon(Icons.account_balance_wallet, size: 120, color: Colors.white.withOpacity(0.1)),
          ),
          Column(
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
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formatIndianCurrency(netSalary),
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: Text(
                      '${attendanceRate.toStringAsFixed(1)}%',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSummaryItem('Present', presentDays.toString(), Icons.check_circle_outline),
                  _buildSummaryItem('Working', workingDays.toString(), Icons.work_outline),
                  _buildSummaryItem('Rate', '${attendanceRate.toStringAsFixed(0)}%', Icons.percent),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.3)),
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.white.withOpacity(0.8),
            fontSize: 12,
            fontWeight: FontWeight.w500,
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
  //             backgroundColor: const Color(0xFF020617),
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
  //             foregroundColor: const Color(0xFF020617),
  //             side: const BorderSide(color: Color(0xFF020617)),
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
        backgroundColor: const Color(0xFF020617),
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
        backgroundColor: const Color(0xFF020617),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

class _ExpandableSectionCard extends StatefulWidget {
  final String title;
  final List<Widget> children;
  final IconData? icon;

  const _ExpandableSectionCard({
    required this.title,
    required this.children,
    this.icon,
  });

  @override
  State<_ExpandableSectionCard> createState() => _ExpandableSectionCardState();
}

class _ExpandableSectionCardState extends State<_ExpandableSectionCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF152A4A).withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            borderRadius: _isExpanded 
                ? const BorderRadius.vertical(top: Radius.circular(20))
                : BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Row(
                children: [
                  if (widget.icon != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF152A4A).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        widget.icon,
                        color: const Color(0xFF152A4A),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  Expanded(
                    child: Text(
                      widget.title,
                      style: GoogleFonts.poppins(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade800,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: Colors.grey.shade500,
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded) ...[
            Container(
              height: 1.5,
              width: double.infinity,
              color: Colors.grey.shade50,
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: widget.children,
              ),
            ),
          ],
        ],
      ),
    );
  }
}


