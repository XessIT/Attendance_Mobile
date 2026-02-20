import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/employee_provider.dart';
import '../models/employee.dart';
import 'employee_registration_screen.dart';
import 'employee_edit_screen.dart';
import 'manual_attendance_screen.dart';

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
      /*appBar: AppBar(
        title: const Text('Employees'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadEmployees,
          ),
        ],
      ),*/
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
                            fontSize: 18,
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

                final employees = employeeProvider.employees;

                if (employees.isEmpty) {
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
                            fontSize: 18,
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
                  onRefresh: _loadEmployees,
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: employeeProvider.employees.length + (employeeProvider.hasNextPage ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index < employeeProvider.employees.length) {
                        final employee = employeeProvider.employees[index];
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
          _loadEmployees(); // Refresh list after registration
        },
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
        child: const Icon(Icons.person_add),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Search field
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search employees...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
                _loadEmployees(); // Trigger server-side search
              },
            ),
          ),
          const SizedBox(width: 12),
          // Filter dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButton<EmployeeFilter>(
              value: _selectedFilter,
              underline: const SizedBox(),
              icon: const Icon(Icons.filter_list),
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
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeCard(Employee employee, int index) {
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
          radius: 30,
          backgroundColor: const Color(0xFF2196F3).withOpacity(0.1),
          child: Text(
            employee.name.substring(0, 1).toUpperCase(),
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2196F3),
            ),
          ),
        ),
        title: Text(
          employee.name,
          style: GoogleFonts.poppins(
            fontSize: 18,
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
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              employee.email ?? 'No email',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '₹${employee.salary.toStringAsFixed(0)}/month',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.green.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleEmployeeAction(value, employee),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Edit'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'view',
              child: Row(
                children: [
                  Icon(Icons.visibility, color: Colors.green),
                  SizedBox(width: 8),
                  Text('View Details'),
                ],
              ),
            ),
            PopupMenuItem(
              value: employee.isActive ? 'deactivate' : 'activate',
              child: Row(
                children: [
                  Icon(
                    employee.isActive ? Icons.block : Icons.check_circle,
                    color: employee.isActive ? Colors.red : Colors.green,
                  ),
                  const SizedBox(width: 8),
                  Text(employee.isActive ? 'Deactivate' : 'Activate'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'manual_attendance',
              child: Row(
                children: [
                  Icon(Icons.add_task, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('Manual Attendance'),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: index * 100)).slideX(begin: 0.3, duration: 600.ms);
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
          _loadEmployees();
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
            _buildDetailRow('Salary', '₹${employee.salary.toStringAsFixed(0)}/month'),
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