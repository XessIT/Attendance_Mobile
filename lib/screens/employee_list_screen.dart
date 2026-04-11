import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../providers/employee_provider.dart';
import '../models/employee.dart';
import '../services/local_storage_service.dart';
import 'employee_registration_screen.dart';
import 'employee_edit_screen.dart';
import 'manual_attendance_screen.dart';
import '../widgets/no_internet_widget.dart';

// Indian currency formatter
String formatIndianCurrency(double amount) {
  final formatter = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );
  return formatter.format(amount);
}

enum EmployeeFilter { active, inactive, all }

class EmployeeListScreen extends StatefulWidget {
  const EmployeeListScreen({super.key});

  @override
  State<EmployeeListScreen> createState() => _EmployeeListScreenState();
}

class _EmployeeListScreenState extends State<EmployeeListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';
  EmployeeFilter _selectedFilter = EmployeeFilter.active;
  bool _isSearching = false;
  List<Employee> _instantSearchResults = [];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadEmployees();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      final employeeProvider = Provider.of<EmployeeProvider>(context, listen: false);
      if (!employeeProvider.isMoreLoading && employeeProvider.hasNextPage) {
        _loadMoreEmployees();
      }
    }
  }

  Future<void> _loadEmployees() async {
    try {
      String? status;
      if (_selectedFilter == EmployeeFilter.active) status = 'active';
      if (_selectedFilter == EmployeeFilter.inactive) status = 'inactive';

      await Provider.of<EmployeeProvider>(context, listen: false).loadEmployees(
        search: _searchQuery.isEmpty ? null : _searchQuery,
        status: status,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading employees: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Instant search using cached data
  void _performInstantSearch(String query) {
    if (query.isEmpty) {
      setState(() {
        _instantSearchResults = [];
        _isSearching = false;
      });
      // If query is empty but filter is applied, still load filtered data
      _loadEmployees();
      return;
    }

    setState(() {
      _isSearching = true;
    });

    // Get status for filtering
    String? status;
    if (_selectedFilter == EmployeeFilter.active) status = 'active';
    if (_selectedFilter == EmployeeFilter.inactive) status = 'inactive';

    // Perform client-side search for instant results
    final employeeProvider = Provider.of<EmployeeProvider>(context, listen: false);
    final results = employeeProvider.searchEmployeesLocally(query, status: status);
    
    setState(() {
      _instantSearchResults = results;
      _isSearching = false;
    });

    // Trigger server search in background for updated results
    _loadEmployees();
  }

  // Apply filter without search
  void _applyFilter() {
    setState(() {
      _isSearching = false;
      _instantSearchResults = [];
    });
    _loadEmployees();
  }

  Future<void> _loadMoreEmployees() async {
    try {
      String? status;
      if (_selectedFilter == EmployeeFilter.active) status = 'active';
      if (_selectedFilter == EmployeeFilter.inactive) status = 'inactive';

      await Provider.of<EmployeeProvider>(context, listen: false).loadMoreEmployees(
        search: _searchQuery.isEmpty ? null : _searchQuery,
        status: status,
      );
    } catch (e) {
      // Error handled in provider
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Search bar
          _buildSearchBar(),
          
          // Employee list
          Expanded(
            child: Consumer<EmployeeProvider>(
              builder: (context, employeeProvider, child) {
                if (employeeProvider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (employeeProvider.error != null) {
                  final errorLower = employeeProvider.error!.toLowerCase();
                  final isNetworkError = errorLower.contains('network') || 
                                        errorLower.contains('connection') || 
                                        errorLower.contains('xmlhttprequest');
                  
                  if (isNetworkError) {
                    return NoInternetWidget(onRetry: _loadEmployees);
                  }

                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading employees',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          employeeProvider.error!,
                          style: GoogleFonts.poppins(
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadEmployees,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                final employees = _getDisplayedEmployees(employeeProvider.employees);

                if (employees.isEmpty && !employeeProvider.isLoading) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _searchQuery.isEmpty ? Icons.people_outline : Icons.search_off,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty ? 'No employees found' : 'No matching employees',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _searchQuery.isEmpty 
                              ? 'Add your first employee to get started'
                              : 'Try adjusting your search terms',
                          style: GoogleFonts.poppins(
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    String? status;
                    if (_selectedFilter == EmployeeFilter.active) status = 'active';
                    if (_selectedFilter == EmployeeFilter.inactive) status = 'inactive';
                    
                    await Provider.of<EmployeeProvider>(context, listen: false)
                        .refresh(search: _searchQuery.isEmpty ? null : _searchQuery, status: status);
                  },
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: employees.length + (employeeProvider.hasNextPage ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index < employees.length) {
                        final employee = employees[index];
                        return _buildEmployeeCard(employee, index);
                      } else {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: employeeProvider.isMoreLoading
                                ? const CircularProgressIndicator()
                                : const SizedBox.shrink(),
                          ),
                        );
                      }
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const EmployeeRegistrationScreen(),
            ),
          );
          // Refresh list with current filter
          String? status;
          if (_selectedFilter == EmployeeFilter.active) status = 'active';
          if (_selectedFilter == EmployeeFilter.inactive) status = 'inactive';
          
          await Provider.of<EmployeeProvider>(context, listen: false)
              .refresh(search: _searchQuery.isEmpty ? null : _searchQuery, status: status);
        },
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
        child: const Icon(Icons.person_add),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Search field and filter
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: GoogleFonts.poppins(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search employees...',
                    hintStyle: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade500),
                    prefixIcon: Icon(Icons.search, size: 20, color: Colors.grey.shade600),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                                _isSearching = false;
                                _instantSearchResults = [];
                              });
                              _applyFilter();
                            },
                          )
                        : null,
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
                      borderSide: const BorderSide(color: Color(0xFF2196F3), width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                    _performInstantSearch(value);
                  },
                ),
              ),
              const SizedBox(width: 8),
              // Filter dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButton<EmployeeFilter>(
                  value: _selectedFilter,
                  underline: const SizedBox(),
                  icon: Icon(Icons.filter_list, size: 18, color: Colors.grey.shade600),
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.black87),
                  items: const [
                    DropdownMenuItem(
                      value: EmployeeFilter.active,
                      child: Text('Active'),
                    ),
                    DropdownMenuItem(
                      value: EmployeeFilter.inactive,
                      child: Text('Inactive'),
                    ),
                    DropdownMenuItem(
                      value: EmployeeFilter.all,
                      child: Text('All'),
                    ),
                  ],
                  onChanged: (EmployeeFilter? value) {
                    if (value != null) {
                      setState(() {
                        _selectedFilter = value;
                      });
                      if (_searchQuery.isEmpty) {
                        _applyFilter();
                      } else {
                        _performInstantSearch(_searchQuery);
                      }
                    }
                  },
                ),
              ),
            ],
          ),
          
          // Filter chips
          if (_searchQuery.isNotEmpty || _selectedFilter != EmployeeFilter.active)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  if (_searchQuery.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2196F3).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search, size: 12, color: const Color(0xFF2196F3)),
                          const SizedBox(width: 4),
                          Text(
                            _searchQuery,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: const Color(0xFF2196F3),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                                _isSearching = false;
                                _instantSearchResults = [];
                              });
                              _applyFilter();
                            },
                            child: Icon(Icons.close, size: 12, color: const Color(0xFF2196F3)),
                          ),
                        ],
                      ),
                    ),
                  if (_searchQuery.isNotEmpty && _selectedFilter != EmployeeFilter.active)
                    const SizedBox(width: 8),
                  if (_selectedFilter != EmployeeFilter.active)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.filter_list, size: 12, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(
                            _selectedFilter.name,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedFilter = EmployeeFilter.active;
                              });
                              _applyFilter();
                            },
                            child: Icon(Icons.close, size: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  List<Employee> _getDisplayedEmployees(List<Employee> employees) {
    // If we're searching, use instant search results
    if (_isSearching || _searchQuery.isNotEmpty) {
      return _instantSearchResults.isNotEmpty ? _instantSearchResults : employees;
    }
    
    // If no search but filter is applied, filter locally for instant results
    if (_selectedFilter != EmployeeFilter.all) {
      String? status;
      if (_selectedFilter == EmployeeFilter.active) status = 'active';
      if (_selectedFilter == EmployeeFilter.inactive) status = 'inactive';
      
      return LocalStorageService.filterEmployeesLocally(employees, '', status);
    }
    
    return employees;
  }

  Widget _buildEmployeeCard(Employee employee, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: Colors.grey.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _handleEmployeeAction('view', employee),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Avatar
              Hero(
                tag: 'employee_${employee.id}',
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: employee.isActive 
                      ? const Color(0xFF2196F3).withOpacity(0.1)
                      : Colors.grey.withOpacity(0.1),
                  child: Text(
                    employee.name.substring(0, 1).toUpperCase(),
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: employee.isActive 
                          ? const Color(0xFF2196F3)
                          : Colors.grey.shade600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              
              // Employee info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            employee.name,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Status badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: employee.isActive 
                                ? Colors.green.withOpacity(0.1)
                                : Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            employee.isActive ? 'Active' : 'Inactive',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: employee.isActive ? Colors.green : Colors.red,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      employee.position,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.email_outlined,
                          size: 12,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            employee.email ?? 'No email',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        // Icon(
                        //   Icons.,
                        //   size: 12,
                        //   color: Colors.green.shade600,
                        // ),
                        const SizedBox(width: 4),
                        Text(
                          formatIndianCurrency(employee.salary),
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.green.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '/month',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: Colors.green.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // More options button
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  size: 18,
                  color: Colors.grey.shade600,
                ),
                padding: EdgeInsets.zero,
                onSelected: (value) => _handleEmployeeAction(value, employee),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'edit',
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 16, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text(
                          'Edit',
                          style: GoogleFonts.poppins(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'view',
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        Icon(Icons.visibility_outlined, size: 16, color: Colors.green),
                        const SizedBox(width: 8),
                        Text(
                          'View Details',
                          style: GoogleFonts.poppins(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: employee.isActive ? 'deactivate' : 'activate',
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        Icon(
                          employee.isActive ? Icons.block_outlined : Icons.check_circle_outline,
                          size: 16,
                          color: employee.isActive ? Colors.red : Colors.green,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          employee.isActive ? 'Deactivate' : 'Activate',
                          style: GoogleFonts.poppins(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'manual_attendance',
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        Icon(Icons.add_task_outlined, size: 16, color: Colors.orange),
                        const SizedBox(width: 8),
                        Text(
                          'Manual Attendance',
                          style: GoogleFonts.poppins(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: index * 50)).slideX(begin: 0.2, duration: 400.ms);
  }

  void _handleEmployeeAction(String action, Employee employee) async {
    switch (action) {
      case 'edit':
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EmployeeEditScreen(employee: employee),
          ),
        );
        // Refresh list if edit was successful
        if (result == true) {
          String? status;
          if (_selectedFilter == EmployeeFilter.active) status = 'active';
          if (_selectedFilter == EmployeeFilter.inactive) status = 'inactive';
          
          await Provider.of<EmployeeProvider>(context, listen: false)
              .refresh(search: _searchQuery.isEmpty ? null : _searchQuery, status: status);
        }
        break;
      
      case 'view':
        _showEmployeeDetails(employee);
        break;
      
      case 'activate':
      case 'deactivate':
        await _toggleEmployeeStatus(employee);
        break;
      
      case 'delete':
        await _deleteEmployee(employee);
        break;
      
      case 'manual_attendance':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ManualAttendanceScreen(employee: employee)),
        );
        break;
    }
  }

  void _showEmployeeDetails(Employee employee) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(employee.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Email', employee.email ?? 'Not provided'),
            _buildDetailRow('Phone', employee.phone),
            _buildDetailRow('Position', employee.position),
            _buildDetailRow('Salary', '${formatIndianCurrency(employee.salary)}/month'),
            _buildDetailRow('Status', employee.isActive ? 'Active' : 'Inactive'),
            _buildDetailRow('Joined', _formatDate(employee.createdAt)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
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
              style: GoogleFonts.poppins(),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _toggleEmployeeStatus(Employee employee) async {
    try {
      final success = await Provider.of<EmployeeProvider>(context, listen: false)
          .toggleEmployeeStatus(employee);
      
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Employee ${employee.isActive ? 'deactivated' : 'activated'} successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to update employee status'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating employee: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteEmployee(Employee employee) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Employee'),
        content: Text('Are you sure you want to delete ${employee.name}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await Provider.of<EmployeeProvider>(context, listen: false)
            .deleteEmployee(employee.id!);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Employee deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting employee: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
} 