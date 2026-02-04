import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class ApproveLeaveScreen extends StatefulWidget {
  const ApproveLeaveScreen({super.key});

  @override
  State<ApproveLeaveScreen> createState() => _ApproveLeaveScreenState();
}

class _ApproveLeaveScreenState extends State<ApproveLeaveScreen> {
  List<Map<String, dynamic>> _leaveRequests = [];
  List<Map<String, dynamic>> _filteredLeaveRequests = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedStatus = 'All';

  @override
  void initState() {
    super.initState();
    _loadLeaveRequests();
  }

  Future<void> _loadLeaveRequests() async {
    setState(() => _isLoading = true);
    try {
      // Try to fetch all leave requests (admin endpoint)
      final response = await ApiService.getAllLeaveRequests();
      // Handle different response structures
      List<dynamic> data = [];
      if (response['data'] != null) {
        if (response['data'] is List) {
          data = response['data'];
        } else if (response['data'] is Map) {
          data = [response['data']];
        }
      } else if (response['leaves'] != null) {
        if (response['leaves'] is List) {
          data = response['leaves'];
        } else if (response['leaves'] is Map) {
          data = [response['leaves']];
        }
      } else if (response is List) {
        data = response as List;
      } else if (response is Map) {
        data = [response];
      }
      
      setState(() {
        _leaveRequests = data.map((item) {
          final leaveItem = Map<String, dynamic>.from(item);
          // Extract employee info from nested employee object if available
          if (leaveItem['employee'] is Map) {
            final employee = leaveItem['employee'] as Map<String, dynamic>;
            leaveItem['name'] = employee['name'] ?? leaveItem['name'];
            leaveItem['department'] = employee['department'] ?? leaveItem['department'];
          }
          return leaveItem;
        }).toList();
        _filteredLeaveRequests = _leaveRequests;
        _isLoading = false;
      });
    } catch (e) {
      // If API endpoint doesn't exist, use mock data for now
      print('Error loading leave requests: $e');
      setState(() {
        _leaveRequests = _getMockLeaveRequests();
        _filteredLeaveRequests = _leaveRequests;
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _getMockLeaveRequests() {
    return [
      {
        'id': 93,
        'employeeId': 181,
        'leaveType': 'Leave',
        'startDate': '2026-02-04',
        'endDate': '2026-02-04',
        'durationHours': '8.00',
        'reason': 'Half Day Post Lunch - Personal',
        'status': 'Approved',
        'employee': {
          'id': 181,
          'name': 'Arshaf',
          'employeeId': '181',
          'department': 'Development'
        }
      },
      {
        'id': 92,
        'employeeId': 182,
        'leaveType': 'Leave',
        'startDate': '2026-02-05',
        'endDate': '2026-02-05',
        'durationHours': '8.00',
        'reason': 'Religious Festival',
        'status': 'Approved',
        'employee': {
          'id': 182,
          'name': 'Nirmalraj',
          'employeeId': '182',
          'department': 'Development'
        }
      },
    ];
  }

  void _filterLeaveRequests() {
    setState(() {
      _filteredLeaveRequests = _leaveRequests.where((leave) {
        final nameMatch = leave['name']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) ?? false;
        final statusMatch = _selectedStatus == 'All' || 
            (leave['status']?.toString().toLowerCase() == _selectedStatus.toLowerCase());
        return nameMatch && statusMatch;
      }).toList();
    });
  }

  void _showLeaveDetails(Map<String, dynamic> leave) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Leave Details',
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow('Employee ID', leave['employeeId']?.toString() ?? '-'),
                    _buildDetailRow('Name', leave['name']?.toString() ?? '-'),
                    _buildDetailRow('Department', leave['department']?.toString() ?? '-'),
                    _buildDetailRow('Leave Type', leave['leaveType']?.toString() ?? '-'),
                    _buildDetailRow('Start Date', _formatDate(leave['startDate']?.toString())),
                    _buildDetailRow('End Date', _formatDate(leave['endDate']?.toString())),
                    _buildDetailRow('Days', leave['durationHours']?.toString() ?? leave['days']?.toString() ?? '-'),
                    _buildDetailRow('Status', leave['status']?.toString() ?? '-', 
                      statusColor: _getStatusColor(leave['status']?.toString() ?? '')),
                    _buildDetailRow('Reason', leave['reason']?.toString() ?? '-', isReason: true),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            if (leave['status']?.toString().toLowerCase() == 'pending')
              Column(
                children: [
                  const Divider(),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _handleApproval(leave['id'], 'Rejected'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            'Reject',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _handleApproval(leave['id'], 'Approved'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            'Approve',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? statusColor, bool isReason = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          if (isReason)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[800],
                ),
              ),
            )
          else
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: statusColor ?? Colors.grey[900],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _handleApproval(int leaveId, String status) async {
    try {
      // Call API to approve/reject leave
      await ApiService.approveLeave(leaveId, status);
      if (mounted) {
        Navigator.pop(context); // Close bottom sheet
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Leave $status successfully'),
            backgroundColor: status == 'Approved' ? Colors.green : Colors.red,
          ),
        );
        _loadLeaveRequests();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return '-';
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (e) {
      return dateString;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Approve Leave',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search and Filter Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                // Search Bar
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by Name...',
                    hintStyle: GoogleFonts.poppins(color: Colors.grey),
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.filter_list, color: Colors.grey),
                          onPressed: _showFilterDialog,
                        ),
                        IconButton(
                          icon: const Icon(Icons.more_vert, color: Colors.grey),
                          onPressed: () {},
                        ),
                      ],
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  style: GoogleFonts.poppins(),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                      _filterLeaveRequests();
                    });
                  },
                ),
              ],
            ),
          ),
          // Leave Requests List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredLeaveRequests.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'No leave requests found',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadLeaveRequests,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredLeaveRequests.length,
                          itemBuilder: (context, index) {
                            final leave = _filteredLeaveRequests[index];
                            return _buildLeaveCard(leave, index + 1);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaveCard(Map<String, dynamic> leave, int serialNumber) {
    final status = leave['status']?.toString() ?? 'Pending';
    final statusColor = _getStatusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showLeaveDetails(leave),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  children: [
                    // Serial Number
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2196F3).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          serialNumber.toString(),
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF2196F3),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Employee Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            leave['name']?.toString() ?? '-',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[900],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'ID: ${leave['employeeId']?.toString() ?? '-'} • ${leave['department']?.toString() ?? '-'}',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        status,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),
                // Leave Details Row
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoItem(
                        'Leave Type',
                        leave['leaveType']?.toString() ?? '-',
                        Icons.event_note,
                      ),
                    ),
                    Container(width: 1, height: 40, color: Colors.grey[300]),
                    Expanded(
                      child: _buildInfoItem(
                        'Hours',
                        leave['durationHours']?.toString() ?? leave['days']?.toString() ?? '-',
                        Icons.calendar_today,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoItem(
                        'Start Date',
                        _formatDate(leave['startDate']?.toString()),
                        Icons.play_arrow,
                      ),
                    ),
                    Container(width: 1, height: 40, color: Colors.grey[300]),
                    Expanded(
                      child: _buildInfoItem(
                        'End Date',
                        _formatDate(leave['endDate']?.toString()),
                        Icons.stop,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Action Buttons
                if (leave['status']?.toString().toLowerCase() == 'pending')
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _handleApproval(leave['id'], 'Rejected'),
                          icon: const Icon(Icons.close, size: 16),
                          label: Text(
                            'Reject',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _handleApproval(leave['id'], 'Approved'),
                          icon: const Icon(Icons.check, size: 16),
                          label: Text(
                            'Approve',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.visibility, color: Colors.blue, size: 20),
                          onPressed: () => _showLeaveDetails(leave),
                        ),
                      ),
                    ],
                  )
                else
                  // View Button for non-pending leaves
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.visibility, color: Colors.blue, size: 20),
                        onPressed: () => _showLeaveDetails(leave),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[900],
          ),
        ),
      ],
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Filter by Status',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['All', 'Pending', 'Approved', 'Rejected'].map((status) {
            return RadioListTile<String>(
              title: Text(status, style: GoogleFonts.poppins()),
              value: status,
              groupValue: _selectedStatus,
              onChanged: (value) {
                setState(() {
                  _selectedStatus = value!;
                  _filterLeaveRequests();
                });
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }
}

