import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../utils/auth_utils.dart';
import 'leave_balance_detail_screen.dart';

class LevelApprovalScreen extends StatefulWidget {
  const LevelApprovalScreen({super.key});

  @override
  State<LevelApprovalScreen> createState() => _LevelApprovalScreenState();
}

class _LevelApprovalScreenState extends State<LevelApprovalScreen> {
  List<Map<String, dynamic>> _leaveRequests = [];
  bool _isLoading = true;
  String _selectedStatus = 'Pending';
  int? _currentStaffId;
  String? _currentUserRole;

  @override
  void initState() {
    super.initState();
    _initUser();
    _loadRequests();
  }

  Future<void> _initUser() async {
    final id = await AuthUtils.getCurrentEmployeeId();
    final role = await AuthUtils.getUserRole();
    setState(() {
      _currentStaffId = id;
      _currentUserRole = role?.toLowerCase();
    });
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.getAllLeaveRequests(
        status: _selectedStatus == 'All' ? null : _selectedStatus,
      );
      
      List<dynamic> data = [];
      if (response['data'] is List) {
        data = response['data'];
      } else if (response['leaves'] is List) {
        data = response['leaves'];
      }

      setState(() {
        _leaveRequests = data.map((item) => Map<String, dynamic>.from(item)).toList();
        _isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleApproval(int id, String status) async {
    try {
      await ApiService.approveLeave(id, status);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Request ${status.toLowerCase()} successfully'),
          backgroundColor: status == 'Approved' ? Colors.green : Colors.red,
        ),
      );
      _loadRequests();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        title: Text('Level Approvals', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(onPressed: _loadRequests, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _leaveRequests.isEmpty 
                ? _buildEmptyState()
                : _buildApprovalList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      color: Colors.white,
      child: Row(
        children: ['Pending', 'Approved', 'Rejected', 'All'].map((status) {
          final isSelected = _selectedStatus == status;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(isSelected && status == 'Pending' ? 'To Approve' : status),
              selected: isSelected,
              onSelected: (val) {
                if (val) {
                  setState(() => _selectedStatus = status);
                  _loadRequests();
                }
              },
              selectedColor: const Color(0xFF2196F3).withOpacity(0.1),
              labelStyle: GoogleFonts.poppins(
                fontSize: 12,
                color: isSelected ? const Color(0xFF2196F3) : Colors.grey[600],
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildApprovalList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _leaveRequests.length,
      itemBuilder: (context, index) {
        final request = _leaveRequests[index];
        return _buildRequestRow(request, index + 1);
      },
    );
  }

  Widget _buildRequestRow(Map<String, dynamic> request, int sNo) {
    final employee = request['employee'] ?? {};
    final status = request['status']?.toString() ?? 'Pending';
    final currentLevel = int.tryParse(request['currentLevel']?.toString() ?? '1') ?? 1;
    
    // Status Logic for Hierarchical Levels
    final isFinalized = ['Approved', 'Rejected', 'Cancelled'].contains(status);
    final isPending = !isFinalized; // Includes Pending, L1_Approved, L2_Approved
    
    // Permission Logic (Type-safe comparison)
    final requiredId = request['requiredApproverId']?.toString();
    final myId = _currentStaffId?.toString();
    final isAdmin = _currentUserRole?.contains('admin') ?? false;
    
    // It's my turn if (My ID matches Required ID) OR (I am an Admin)
    final isMyTurn = (requiredId != null && requiredId == myId) || isAdmin;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Left Accent Strip
            Container(
              width: 5,
              decoration: BoxDecoration(
                color: !isFinalized ? Colors.orange : (status == 'Approved' ? Colors.green : Colors.red),
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), bottomLeft: Radius.circular(16)),
              ),
            ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // S.No
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle),
                          child: Center(child: Text('$sNo', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[600]))),
                        ),
                        const SizedBox(width: 12),
                        // Employee Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${employee['employeeId'] ?? '-'}  ${employee['name'] ?? 'Unknown'}',
                                style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black87),
                              ),
                              Text(
                                employee['department'] ?? 'General',
                                style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500]),
                              ),
                            ],
                          ),
                        ),
                        // Level Badge
                        if (!isFinalized) _buildLevelBadge(currentLevel, status),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildInfoColumn('Leave Type', request['leaveType'] ?? '-'),
                        _buildInfoColumn('Dates', '${_formatDate(request['startDate'])} - ${_formatDate(request['endDate'])}'),
                        _buildInfoColumn('Days', '${request['totalDays'] ?? '1.0'}'),
                      ],
                    ),
                    if (!isFinalized && isMyTurn) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildActionButton(
                              onTap: () => _handleApproval(request['id'], 'Rejected'),
                              icon: Icons.close_rounded,
                              label: 'Reject',
                              color: Colors.red[400]!,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildActionButton(
                              onTap: () => _handleApproval(request['id'], 'Approved'),
                              icon: Icons.check_rounded,
                              label: 'Approve',
                              color: Colors.green[500]!,
                            ),
                          ),
                        ],
                      ),
                    ] else if (!isFinalized) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.info_outline, size: 12, color: Colors.grey),
                            const SizedBox(width: 6),
                            Text('Waiting for designated level approver', style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[600], fontStyle: FontStyle.italic)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelBadge(int level, String status) {
    String displayStatus = 'Waiting for L$level';
    if (status == 'Pending' && level == 1) displayStatus = 'Waiting for L1';
    if (status == 'L1_Approved') displayStatus = 'Waiting for L2';
    if (status == 'L2_Approved') displayStatus = 'Waiting for HR/L3';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: Column(
        children: [
          Text(displayStatus, style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.orange[800])),
          Text('Stage: $level', style: GoogleFonts.poppins(fontSize: 7, color: Colors.orange[600])),
        ],
      ),
    );
  }

  Widget _buildInfoColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[500])),
        const SizedBox(height: 2),
        Text(value, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87)),
      ],
    );
  }

  Widget _buildActionButton({required VoidCallback onTap, required IconData icon, required String label, required Color color}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(label, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_turned_in_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text('No requests found', style: TextStyle(fontSize: 16, color: Colors.grey)),
        ],
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return '-';
    try {
      final dt = DateTime.parse(date.toString());
      return DateFormat('dd MMM').format(dt);
    } catch (_) {
      return date.toString();
    }
  }
}
