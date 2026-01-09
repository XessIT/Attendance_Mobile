import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../providers/employee_provider.dart';
import '../providers/attendance_provider.dart';
import '../models/salary.dart';
import '../models/employee.dart';

class SalaryScreen extends StatefulWidget {
  const SalaryScreen({super.key});

  @override
  State<SalaryScreen> createState() => _SalaryScreenState();
}

class _SalaryScreenState extends State<SalaryScreen> {
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  int? _selectedEmployeeId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      await Provider.of<EmployeeProvider>(context, listen: false).loadEmployees();
      await Provider.of<AttendanceProvider>(context, listen: false).loadAttendance();
    } catch (e) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Salary Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filters
          _buildFilterSection(),
          
          // Salary overview
          _buildSalaryOverview(),
          
          // Salary list
          Expanded(
            child: _buildSalaryList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _calculateSalaries,
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.calculate),
        label: Text(
          'Calculate Salaries',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Month and Year selector
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _selectedMonth,
                  decoration: const InputDecoration(
                    labelText: 'Month',
                    prefixIcon: Icon(Icons.calendar_month),
                  ),
                  items: List.generate(12, (index) => DropdownMenuItem(
                    value: index + 1,
                    child: Text(DateFormat('MMMM').format(DateTime(2024, index + 1))),
                  )),
                  onChanged: (value) {
                    setState(() {
                      _selectedMonth = value!;
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _selectedYear,
                  decoration: const InputDecoration(
                    labelText: 'Year',
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  items: List.generate(5, (index) {
                    final year = DateTime.now().year - 2 + index;
                    return DropdownMenuItem(
                      value: year,
                      child: Text(year.toString()),
                    );
                  }),
                  onChanged: (value) {
                    setState(() {
                      _selectedYear = value!;
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Employee filter
          Consumer<EmployeeProvider>(
            builder: (context, employeeProvider, child) {
              final employees = employeeProvider.employees;
              
              return DropdownButtonFormField<int>(
                value: _selectedEmployeeId,
                decoration: const InputDecoration(
                  labelText: 'Filter by Employee',
                  prefixIcon: Icon(Icons.person),
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('All Employees'),
                  ),
                  ...employees.map((employee) => DropdownMenuItem(
                    value: employee.id,
                    child: Text(employee.name),
                  )),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedEmployeeId = value;
                  });
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSalaryOverview() {
    return Consumer2<EmployeeProvider, AttendanceProvider>(
      builder: (context, employeeProvider, attendanceProvider, child) {
        final employees = _selectedEmployeeId != null
            ? employeeProvider.employees.where((e) => e.id == _selectedEmployeeId).toList()
            : employeeProvider.employees;

        double totalSalary = 0;
        double totalPaid = 0;
        int totalEmployees = employees.length;

        for (final employee in employees) {
          final stats = attendanceProvider.getAttendanceStats(
            employeeId: employee.id,
            startDate: DateTime(_selectedYear, _selectedMonth, 1),
            endDate: DateTime(_selectedYear, _selectedMonth + 1, 0),
          );

          final calculatedSalary = _calculateEmployeeSalary(employee, stats);
          totalSalary += calculatedSalary;
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: _buildOverviewCard(
                  title: 'Total Employees',
                  value: totalEmployees.toString(),
                  color: Colors.blue,
                  icon: Icons.people,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildOverviewCard(
                  title: 'Total Salary',
                  value: '₹${totalSalary.toStringAsFixed(0)}',
                  color: Colors.green,
                  icon: Icons.attach_money,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildOverviewCard(
                  title: 'Paid',
                  value: '₹${totalPaid.toStringAsFixed(0)}',
                  color: Colors.orange,
                  icon: Icons.payment,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOverviewCard({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSalaryList() {
    return Consumer2<EmployeeProvider, AttendanceProvider>(
      builder: (context, employeeProvider, attendanceProvider, child) {
        final employees = _selectedEmployeeId != null
            ? employeeProvider.employees.where((e) => e.id == _selectedEmployeeId).toList()
            : employeeProvider.employees;

        if (employees.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.attach_money,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'No employees found',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add employees to calculate salaries',
                  style: GoogleFonts.poppins(
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: employees.length,
          itemBuilder: (context, index) {
            final employee = employees[index];
            final stats = attendanceProvider.getAttendanceStats(
              employeeId: employee.id,
              startDate: DateTime(_selectedYear, _selectedMonth, 1),
              endDate: DateTime(_selectedYear, _selectedMonth + 1, 0),
            );
            
            final calculatedSalary = _calculateEmployeeSalary(employee, stats);
            
            return _buildSalaryCard(employee, stats, calculatedSalary, index);
          },
        );
      },
    );
  }

  Widget _buildSalaryCard(Employee employee, Map<String, dynamic> stats, double calculatedSalary, int index) {
    final attendancePercentage = stats['attendancePercentage'];
    final workingDays = stats['totalDays'];
    final presentDays = stats['presentDays'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          radius: 25,
          backgroundColor: const Color(0xFF2196F3).withOpacity(0.1),
          child: Text(
            employee.name.substring(0, 1).toUpperCase(),
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2196F3),
            ),
          ),
        ),
        title: Text(
          employee.name,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              employee.position,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Base: ₹${employee.salary.toStringAsFixed(0)} | Present: $presentDays/$workingDays days',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: attendancePercentage / 100,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                attendancePercentage >= 90 ? Colors.green : 
                attendancePercentage >= 75 ? Colors.orange : Colors.red,
              ),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '₹${calculatedSalary.toStringAsFixed(0)}',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF2196F3),
              ),
            ),
            Text(
              '${attendancePercentage.toStringAsFixed(1)}%',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        onTap: () => _showSalaryDetails(employee, stats, calculatedSalary),
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: index * 100)).slideX(begin: 0.3, duration: 600.ms);
  }

  double _calculateEmployeeSalary(Employee employee, Map<String, dynamic> stats) {
    final double baseSalary = employee.salary;
    final int presentDays = stats['presentDays'];
    final int lateDays = stats['lateDays'];
    final int halfDays = stats['halfDays'];
    final int totalDays = stats['totalDays'];
    
    if (totalDays == 0) return 0;

    final double dailySalary = baseSalary / 30; // Assuming 30 days per month
    final double presentDaySalary = presentDays * dailySalary;
    final double lateDaySalary = lateDays * (dailySalary * 0.8); // 20% deduction for late
    final double halfDaySalary = halfDays * (dailySalary * 0.5); // 50% for half day

    return presentDaySalary + lateDaySalary + halfDaySalary;
  }

  void _showSalaryDetails(Employee employee, Map<String, dynamic> stats, double calculatedSalary) {
    final double baseSalary = employee.salary;
    final int presentDays = stats['presentDays'];
    final int absentDays = stats['absentDays'];
    final int lateDays = stats['lateDays'];
    final int halfDays = stats['halfDays'];
    final double totalWorkingHours = stats['totalWorkingHours'];
    final double attendancePercentage = stats['attendancePercentage'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${employee.name} - Salary Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Base Salary', '₹${baseSalary.toStringAsFixed(0)}'),
              _buildDetailRow('Present Days', presentDays.toString()),
              _buildDetailRow('Absent Days', absentDays.toString()),
              _buildDetailRow('Late Days', lateDays.toString()),
              _buildDetailRow('Half Days', halfDays.toString()),
              _buildDetailRow('Working Hours', '${totalWorkingHours.toStringAsFixed(1)}h'),
              _buildDetailRow('Attendance Rate', '${attendancePercentage.toStringAsFixed(1)}%'),
              const Divider(),
              _buildDetailRow('Calculated Salary', '₹${calculatedSalary.toStringAsFixed(0)}', isBold: true),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () => _generatePayslip(employee, stats, calculatedSalary),
            child: const Text('Generate Payslip'),
          ),
        ],
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
            width: 120,
            child: Text(
              '$label:',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: isBold ? const Color(0xFF2196F3) : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _generatePayslip(Employee employee, Map<String, dynamic> stats, double calculatedSalary) {
    // TODO: Implement payslip generation
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Payslip generation feature coming soon'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  Future<void> _calculateSalaries() async {
    // TODO: Implement bulk salary calculation
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Bulk salary calculation feature coming soon'),
        backgroundColor: Colors.blue,
      ),
    );
  }
} 