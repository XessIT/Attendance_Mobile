import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../providers/employee_provider.dart';
import '../providers/attendance_provider.dart';
import '../models/salary.dart';
import '../models/employee.dart';
import '../services/api_service.dart';
import '../widgets/no_internet_widget.dart';
import 'salary_details_screen.dart';

// Indian currency formatter
String formatIndianCurrency(double amount) {
  final formatter = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );
  return formatter.format(amount);
}

class SalaryScreen extends StatefulWidget {
  const SalaryScreen({super.key});

  @override
  State<SalaryScreen> createState() => _SalaryScreenState();
}

class _SalaryScreenState extends State<SalaryScreen> {
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  int? _selectedEmployeeId;
  Map<String, dynamic>? _salaryCalculationResult;
  bool _isLoading = false;
  String _searchQuery = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadCachedSalaryData();
    _loadSalaryData();
  }

  Future<void> _loadCachedSalaryData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'salary_data_${_selectedYear}_$_selectedMonth';
      final cachedData = prefs.getString(cacheKey);
      
      if (cachedData != null) {
        final decodedData = json.decode(cachedData);
        print('========================================');
        print('LOADED CACHED SALARY DATA');
        print('Cache Key: $cacheKey');
        print('========================================');
        
        if (mounted) {
          setState(() {
            _salaryCalculationResult = decodedData;
          });
        }
      }
    } catch (e) {
      print('Error loading cached data: $e');
    }
  }

  Future<void> _saveSalaryDataLocally(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'salary_data_${_selectedYear}_$_selectedMonth';
      await prefs.setString(cacheKey, json.encode(data));
      
      print('========================================');
      print('SAVED SALARY DATA TO CACHE');
      print('Cache Key: $cacheKey');
      print('========================================');
    } catch (e) {
      print('Error saving data to cache: $e');
    }
  }

  Future<void> _loadSalaryData() async {
    if (_isLoading) return; // Prevent multiple simultaneous calls
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final startDate = DateFormat('yyyy-MM-dd').format(DateTime(_selectedYear, _selectedMonth, 1));
      final endDate = DateFormat('yyyy-MM-dd').format(DateTime(_selectedYear, _selectedMonth + 1, 0));

      print('========================================');
      print('FETCHING FRESH SALARY DATA');
      print('Start Date: $startDate');
      print('End Date: $endDate');
      print('========================================');

      final result = await ApiService.calculateAllSalaries(
        startDate: startDate,
        endDate: endDate,
      );

      print('========================================');
      print('FRESH SALARY DATA LOADED SUCCESSFULLY');
      print('Response Type: ${result.runtimeType}');
      print('Response Keys: ${result.keys.toList()}');
      print('========================================');

      // Save fresh data to cache
      await _saveSalaryDataLocally(result);

      // Update UI with fresh data
      if (mounted) {
        setState(() {
          _salaryCalculationResult = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('========================================');
      print('ERROR LOADING FRESH SALARY DATA');
      print('Error Type: ${e.runtimeType}');
      print('Error Message: $e');
      print('========================================');
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
      
      // Don't show error snackbar on auto-load, just log it
      // Cached data will still be displayed if available
    }
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

  void _showEmployeeFilterDialog() {
    final employees = Provider.of<EmployeeProvider>(context, listen: false).employees;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                // gradient: LinearGradient(
                //   begin: Alignment.topLeft,
                //   end: Alignment.bottomRight,
                //   colors: [
                //     const Color(0xFF2196F3),
                //     const Color(0xFF1976D2),
                //   ],
                // ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.filter_list_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Filter by Employee',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
            const SizedBox(height: 8),
            Text(
              'Select employee to filter',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _selectedEmployeeId == null ? const Color(0xFF2196F3) : Colors.grey[300]!,
                  width: _selectedEmployeeId == null ? 2 : 1,
                ),
                color: _selectedEmployeeId == null ? const Color(0xFF2196F3).withOpacity(0.1) : Colors.white,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedEmployeeId = null;
                    });
                    Navigator.pop(context);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _selectedEmployeeId == null ? const Color(0xFF2196F3) : Colors.transparent,
                            border: Border.all(
                              color: _selectedEmployeeId == null ? const Color(0xFF2196F3) : Colors.grey[400]!,
                              width: 2,
                            ),
                          ),
                          child: _selectedEmployeeId == null
                              ? const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 12,
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'All Employees',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: _selectedEmployeeId == null ? FontWeight.w600 : FontWeight.w500,
                              color: _selectedEmployeeId == null ? const Color(0xFF2196F3) : Colors.grey[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            ...employees.map((employee) {
              final isSelected = _selectedEmployeeId == employee.id;
              
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF2196F3) : Colors.grey[300]!,
                    width: isSelected ? 2 : 1,
                  ),
                  color: isSelected ? const Color(0xFF2196F3).withOpacity(0.1) : Colors.white,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedEmployeeId = employee.id;
                      });
                      Navigator.pop(context);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected ? const Color(0xFF2196F3) : Colors.transparent,
                              border: Border.all(
                                color: isSelected ? const Color(0xFF2196F3) : Colors.grey[400]!,
                                width: 2,
                              ),
                            ),
                            child: isSelected
                                ? const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 12,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              employee.name,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                color: isSelected ? const Color(0xFF2196F3) : Colors.grey[700],
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2196F3).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              employee.position ?? 'General',
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF2196F3),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16, bottom: 16, left: 16),
            width: double.infinity,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.grey[200]!,
                  Colors.grey[300]!,
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(12),
                child: Center(
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(
      //   title: const Text('Salary Management'),
      //   actions: [
      //     IconButton(
      //       icon: const Icon(Icons.refresh),
      //       onPressed: () {
      //         _loadData();
      //         _loadSalaryData();
      //       },
      //       tooltip: 'Refresh Data',
      //     ),
      //   ],
      // ),
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
    );
  }

  void _showMonthYearPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.white,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Select Period',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                        color: Colors.grey.shade600,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Year',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: 5,
                      separatorBuilder: (context, index) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final year = DateTime.now().year - 2 + index;
                        final isSelected = _selectedYear == year;
                        return InkWell(
                          onTap: () {
                            setState(() {
                              _selectedYear = year;
                              _salaryCalculationResult = null;
                            });
                            setModalState(() {});
                            _loadCachedSalaryData();
                            _loadSalaryData();
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF2196F3) : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected ? const Color(0xFF2196F3) : Colors.grey.shade300,
                              ),
                            ),
                            child: Text(
                              year.toString(),
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                color: isSelected ? Colors.white : Colors.grey.shade800,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Month',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 2.5,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: 12,
                    itemBuilder: (context, index) {
                      final monthNum = index + 1;
                      final isSelected = _selectedMonth == monthNum;
                      final monthName = DateFormat('MMM').format(DateTime(2024, monthNum));
                      return InkWell(
                        onTap: () {
                          setState(() {
                            _selectedMonth = monthNum;
                            _salaryCalculationResult = null;
                          });
                          setModalState(() {});
                          _loadCachedSalaryData();
                          _loadSalaryData();
                          Navigator.pop(context); // Close after selecting month
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF2196F3) : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF2196F3) : Colors.grey.shade200,
                            ),
                          ),
                          child: Text(
                            monthName,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              color: isSelected ? Colors.white : Colors.grey.shade700,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterSection() {
    return Container(
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 8),
            // Month and Year selector
            InkWell(
              onTap: _showMonthYearPicker,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF2196F3), width: 1.2),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month, color: Color(0xFF2196F3), size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${DateFormat('MMMM').format(DateTime(2024, _selectedMonth))} $_selectedYear',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ),
                    Icon(Icons.edit_calendar, color: const Color(0xFF2196F3), size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Search and Filter Bar
            Consumer<EmployeeProvider>(
              builder: (context, employeeProvider, child) {
                return TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by employee name...',
                    hintStyle: GoogleFonts.poppins(
                      color: Colors.grey[500],
                      fontSize: 14,
                    ),
                    prefixIcon: Container(
                      padding: const EdgeInsets.all(12),
                      child: Icon(
                        Icons.search_rounded,
                        color: Colors.grey[600],
                        size: 20,
                      ),
                    ),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: _selectedEmployeeId != null 
                                ? Colors.orange.withOpacity(0.1)
                                : Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            icon: Icon(
                              Icons.filter_list_rounded,
                              color: _selectedEmployeeId != null 
                                  ? Colors.orange[700]
                                  : Colors.grey[600],
                              size: 20,
                            ),
                            onPressed: _showEmployeeFilterDialog,
                            tooltip: 'Filter',
                          ),
                        ),
                        if (_searchQuery.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: IconButton(
                              icon: Icon(
                                Icons.clear_rounded,
                                color: Colors.grey[600],
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                              tooltip: 'Clear search',
                            ),
                          ),
                      ],
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF2196F3), width: 1.5),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, 
                      vertical: 14,
                    ),
                  ),
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[800],
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                );
              },
            ),
            
            // Filter Chips
            if (_selectedEmployeeId != null || _searchQuery.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    if (_selectedEmployeeId != null)
                      Consumer<EmployeeProvider>(
                        builder: (context, employeeProvider, child) {
                          final employee = employeeProvider.employees.firstWhere(
                            (emp) => emp.id == _selectedEmployeeId,
                            orElse: () => employeeProvider.employees.first,
                          );
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange[50],
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.orange[200]!),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.filter_list_rounded,
                                  size: 14,
                                  color: Colors.orange[700],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  employee.name,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.orange[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedEmployeeId = null;
                                    });
                                  },
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 14,
                                    color: Colors.orange[700],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    if (_searchQuery.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.search_rounded,
                              size: 14,
                              color: Colors.blue[700],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _searchQuery.length > 15 
                                  ? '${_searchQuery.substring(0, 15)}...'
                                  : _searchQuery,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.blue[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                              child: Icon(
                                Icons.close_rounded,
                                size: 14,
                                color: Colors.blue[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalaryOverview() {
    if (_salaryCalculationResult == null) {
      // Show loading state instead of local calculations
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: _buildOverviewCard(
                title: 'Total Employees',
                value: '--',
                color: Colors.blue,
                icon: Icons.people,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildOverviewCard(
                title: 'Total Payroll',
                value: '--',
                color: Colors.green,
                icon: Icons.work,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildOverviewCard(
                title: 'Calculated',
                value: '--',
                color: Colors.purple,
                icon: Icons.calculate,
              ),
            ),
          ],
        ),
      );
    }

    // Display data from API response
    final summary = _salaryCalculationResult!['data']['summary'];
    final totalEmployees = summary['totalEmployees'] ?? 0;
    final totalPayroll = double.tryParse(summary['totalCompanyPayroll'].toString()) ?? 0.0;
    final employeesWithSalary = summary['employeesWithSalary'] ?? 0;

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
              title: 'Total Payroll',
              value: formatIndianCurrency(totalPayroll),
              color: Colors.green,
              icon: Icons.account_balance_wallet,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildOverviewCard(
              title: 'Calculated',
              value: employeesWithSalary.toString(),
              color: Colors.purple,
              icon: Icons.calculate,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewCard({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: color,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSalaryList() {
    if (_error != null && _salaryCalculationResult == null) {
      final isNetworkError = _error!.toLowerCase().contains('network') ||
          _error!.toLowerCase().contains('connection') ||
          _error!.toLowerCase().contains('xmlhttprequest');

      if (isNetworkError) {
        return NoInternetWidget(
          onRetry: () {
            _loadData();
            _loadSalaryData();
          },
        );
      }

      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              'Error loading salary data',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                _loadData();
                _loadSalaryData();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_salaryCalculationResult == null) {
      // Show loading state instead of local calculations
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: const Color(0xFF2196F3),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading salary data...',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Fetching calculations from server',
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    // Display data from API response
    final employees = _salaryCalculationResult!['data']['employees'] as List<dynamic>;
    
    // Filter by selected employee and search query
    var filteredEmployees = employees.where((emp) {
      final employee = emp['employee'];
      // Employee filter
      final employeeMatch = _selectedEmployeeId == null ||
          employee['id'] == _selectedEmployeeId;
      
      // Search filter
      final searchMatch = _searchQuery.isEmpty ||
          employee['name']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) == true;
      
      return employeeMatch && searchMatch;
    }).toList();

    if (filteredEmployees.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.work_outline,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No salary data found',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try refreshing or changing the selected period',
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredEmployees.length,
      itemBuilder: (context, index) {
        final employeeData = filteredEmployees[index];
        return _buildApiSalaryCard(employeeData, index);
      },
    );
  }

  Widget _buildApiSalaryCard(dynamic employeeData, int index) {
    final employee = employeeData['employee'];
    final attendance = employeeData['attendance'];
    final salary = employeeData['salary'];
    
    final name = employee['name'] ?? 'Unknown';
    final department = employee['department'] ?? 'Unknown';
    final monthlySalary = double.tryParse(employee['monthlySalary'].toString()) ?? 0.0;
    final presentDays = attendance['presentDays'] ?? 0;
    final workingDays = attendance['workingDays'] ?? 1;
    final attendancePercentage = attendance['attendancePercentage'] ?? 0.0;
    final netPayableSalary = double.tryParse(salary['netPayableSalary'].toString()) ?? 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 6,
              child: Container(color: const Color(0xFF2196F3)),
            ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(15),
                onTap: () => _showApiSalaryDetails(employeeData),
                child: Padding(
                  padding: const EdgeInsets.only(left: 22, right: 16, top: 16, bottom: 16),
                  child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFF2196F3).withOpacity(0.1),
                  child: Text(
                    name.substring(0, 1).toUpperCase(),
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2196F3),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        department,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Base: ${formatIndianCurrency(monthlySalary)} | Present: $presentDays/$workingDays days',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade400,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: attendancePercentage / 100,
                          minHeight: 3,
                          backgroundColor: Colors.grey.shade100,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            attendancePercentage >= 90 ? const Color(0xFF4CAF50) : 
                            attendancePercentage >= 75 ? const Color(0xFFFF9800) : const Color(0xFFF44336),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatIndianCurrency(netPayableSalary),
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF2196F3),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${attendancePercentage.toStringAsFixed(1)}%',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: index * 100)).slideX(begin: 0.3, duration: 600.ms);
  }

  Widget _buildSalaryCard(Employee employee, Map<String, dynamic> stats, double calculatedSalary, int index) {
    final attendancePercentage = stats['attendancePercentage'];
    final workingDays = stats['totalDays'];
    final presentDays = stats['presentDays'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 6,
              child: Container(color: const Color(0xFF2196F3)),
            ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(15),
                onTap: () => _showSalaryDetails(employee, stats, calculatedSalary),
                child: Padding(
                  padding: const EdgeInsets.only(left: 22, right: 16, top: 16, bottom: 16),
                  child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 24,
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
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        employee.name,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        employee.position,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Base: ${formatIndianCurrency(employee.salary)} | Present: $presentDays/$workingDays days',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade400,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: attendancePercentage / 100,
                          minHeight: 3,
                          backgroundColor: Colors.grey.shade100,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            attendancePercentage >= 90 ? const Color(0xFF4CAF50) : 
                            attendancePercentage >= 75 ? const Color(0xFFFF9800) : const Color(0xFFF44336),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatIndianCurrency(calculatedSalary),
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF2196F3),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${attendancePercentage.toStringAsFixed(1)}%',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
          ],
        ),
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
              _buildDetailRow('Base Salary', formatIndianCurrency(baseSalary)),
              _buildDetailRow('Present Days', presentDays.toString()),
              _buildDetailRow('Absent Days', absentDays.toString()),
              _buildDetailRow('Late Days', lateDays.toString()),
              _buildDetailRow('Half Days', halfDays.toString()),
              _buildDetailRow('Working Hours', '${totalWorkingHours.toStringAsFixed(1)}h'),
              _buildDetailRow('Attendance Rate', '${attendancePercentage.toStringAsFixed(1)}%'),
              const Divider(),
              _buildDetailRow('Calculated Salary', formatIndianCurrency(calculatedSalary), isBold: true),
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

  void _showApiSalaryDetails(dynamic employeeData) {
    final employee = employeeData['employee'];
    final employeeName = employee['name'] ?? 'Unknown';
    
    final startDate = DateFormat('yyyy-MM-dd').format(DateTime(_selectedYear, _selectedMonth, 1));
    final endDate = DateFormat('yyyy-MM-dd').format(DateTime(_selectedYear, _selectedMonth + 1, 0));
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SalaryDetailsScreen(
          employeeData: employeeData,
          employeeName: employeeName,
          startDate: startDate,
          endDate: endDate,
        ),
      ),
    );
  }

  void _generatePayslipFromApi(dynamic employeeData) {
    // TODO: Implement payslip generation from API data
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Payslip generation feature coming soon'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  Future<void> _calculateSalaries() async {
    // Show confirmation dialog
    final shouldCalculate = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Calculate All Salaries'),
        content: Text(
          'This will calculate salaries for all employees from ${DateFormat('yyyy-MM-dd').format(DateTime(_selectedYear, _selectedMonth, 1))} to ${DateFormat('yyyy-MM-dd').format(DateTime(_selectedYear, _selectedMonth + 1, 0))}. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2196F3),
              foregroundColor: Colors.white,
            ),
            child: const Text('Calculate'),
          ),
        ],
      ),
    );

    if (shouldCalculate == true) {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Calculating salaries...'),
            ],
          ),
        ),
      );

      try {
        final startDate = DateFormat('yyyy-MM-dd').format(DateTime(_selectedYear, _selectedMonth, 1));
        final endDate = DateFormat('yyyy-MM-dd').format(DateTime(_selectedYear, _selectedMonth + 1, 0));

        print('========================================');
        print('SALARY CALCULATION - STARTING');
        print('Start Date: $startDate');
        print('End Date: $endDate');
        print('========================================');

        final result = await ApiService.calculateAllSalaries(
          startDate: startDate,
          endDate: endDate,
        );

        print('========================================');
        print('SALARY CALCULATION - RESPONSE RECEIVED');
        print('Response Type: ${result.runtimeType}');
        print('Response Keys: ${result.keys.toList()}');
        print('Full Response: $result');
        print('========================================');

        // Close loading dialog
        if (mounted) {
          Navigator.of(context).pop();
        }

        // Store the result and update UI
        if (mounted) {
          setState(() {
            _salaryCalculationResult = result;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result['message'] ?? 'Salaries calculated successfully for ${result['count'] ?? 'all'} employees',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );

          // Refresh data
          _loadData();
        }
      } catch (e) {
        print('========================================');
        print('SALARY CALCULATION - ERROR OCCURRED');
        print('Error Type: ${e.runtimeType}');
        print('Error Message: $e');
        print('========================================');

        // Close loading dialog
        if (mounted) {
          Navigator.of(context).pop();
        }

        // Show error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error calculating salaries: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }
}