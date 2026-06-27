import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class CompOffScreen extends StatefulWidget {
  const CompOffScreen({super.key});

  @override
  State<CompOffScreen> createState() => _CompOffScreenState();
}

class _CompOffScreenState extends State<CompOffScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('Compensation Request', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF152A4A),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF152A4A),
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Request Credit'),
            Tab(text: 'My Credits & Leave'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          RequestCreditTab(),
          MyCreditsTab(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TAB 1: REQUEST CREDIT (When you worked extra)
// ---------------------------------------------------------------------------
class RequestCreditTab extends StatefulWidget {
  const RequestCreditTab({super.key});

  @override
  State<RequestCreditTab> createState() => _RequestCreditTabState();
}

class _RequestCreditTabState extends State<RequestCreditTab> {
  final _formKey = GlobalKey<FormState>();
  
  DateTime? _earnedDate;
  String _workType = 'Holiday';
  final _descController = TextEditingController();
  final _creditsController = TextEditingController(text: '1.0');
  
  bool _isLoading = false;

  @override
  void dispose() {
    _descController.dispose();
    _creditsController.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;
    if (_earnedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select earned date')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final data = {
        'earnedDate': DateFormat('yyyy-MM-dd').format(_earnedDate!),
        'workType': _workType,
        'workDescription': _descController.text.trim(),
        'credits': double.tryParse(_creditsController.text) ?? 1.0,
      };

      await ApiService.applyCompOffCredit(data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Credit request submitted successfully!'), backgroundColor: Colors.green),
        );
        // Reset form
        setState(() {
          _earnedDate = null;
          _workType = 'Holiday';
          _descController.clear();
          _creditsController.text = '1.0';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Earned Details', 'When did you work extra?'),
            const SizedBox(height: 16),
            
            // Date Picker
            InkWell(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2023),
                  lastDate: DateTime.now(), // Cannot earn in future
                );
                if (date != null) setState(() => _earnedDate = date);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, color: Color(0xFF152A4A), size: 20),
                    const SizedBox(width: 12),
                     Text(
                      _earnedDate != null ? DateFormat('dd MMM yyyy').format(_earnedDate!) : 'Select Date',
                      style: GoogleFonts.poppins(color: _earnedDate != null ? Colors.black87 : Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Work Type
            DropdownButtonFormField<String>(
              value: _workType,
              decoration: _inputDecoration('Work Type'),
              items: ['Holiday', 'Weekend', 'Overtime'].map((type) {
                return DropdownMenuItem(value: type, child: Text(type, style: GoogleFonts.poppins()));
              }).toList(),
              onChanged: (val) => setState(() => _workType = val!),
            ),
            const SizedBox(height: 16),

            // Credits Input
             TextFormField(
              controller: _creditsController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: _inputDecoration('Credits (Days)').copyWith(
                 helperText: 'e.g. 1.0 for Full Day, 0.5 for Half Day',
              ),
              style: GoogleFonts.poppins(),
              validator: (val) {
                if (val == null || val.isEmpty) return 'Required';
                if (double.tryParse(val) == null) return 'Invalid number';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descController,
              maxLines: 3,
              decoration: _inputDecoration('Description').copyWith(hintText: 'Reason for extra work...'),
              style: GoogleFonts.poppins(),
              validator: (val) => val == null || val.isEmpty ? 'Please enter description' : null,
            ),
            
            const SizedBox(height: 32),
             SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF152A4A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : Text('Submit Request', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.poppins(color: Colors.grey[700]),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF152A4A))),
      filled: true,
      fillColor: Colors.white,
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
        Text(subtitle, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// TAB 2: MY CREDITS & APPLY LEAVE
// ---------------------------------------------------------------------------
class MyCreditsTab extends StatefulWidget {
  const MyCreditsTab({super.key});

  @override
  State<MyCreditsTab> createState() => _MyCreditsTabState();
}

class _MyCreditsTabState extends State<MyCreditsTab> {
  bool _isLoading = true;
  String _balance = '0.0';
  List<dynamic> _requests = [];
  
  // Apply Leave Fields
  DateTime? _leaveDate;
  final _leaveReasonController = TextEditingController();
  final _leaveCreditsController = TextEditingController(text: '1.0');
  bool _isApplyingLeave = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final balanceData = await ApiService.getCompOffBalance();
      final requests = await ApiService.getCompOffCredits();
      
      if (mounted) {
        setState(() {
          _balance = balanceData['availableCredits']?.toString() ?? '0.0';
          _requests = requests;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      print('Error loading comp-off data: $e');
    }
  }

  Future<void> _applyForLeave() async {
     if (_leaveDate == null) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a date')));
       return;
     }

     setState(() => _isApplyingLeave = true);

     try {
       final data = {
         'leaveDate': DateFormat('yyyy-MM-dd').format(_leaveDate!),
         'creditsUsed': double.tryParse(_leaveCreditsController.text) ?? 1.0,
         'reason': _leaveReasonController.text.trim(),
       };
       
       await ApiService.applyCompOffLeave(data);
       
       if (mounted) {
         Navigator.pop(context); // Close dialog
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Leave applied successfully!'), backgroundColor: Colors.green));
         _loadData(); // Refresh balance
         // Reset fields
         _leaveDate = null;
         _leaveReasonController.clear();
       }
     } catch (e) {
       if (mounted) {
         Navigator.pop(context); // Close dialog basically to show error clearly if modal covers
         // Re-show dialog? Or just snackbar.
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red));
       }
     } finally {
       if (mounted) setState(() => _isApplyingLeave = false);
     }
  }

  void _showApplyLeaveDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Use Comp-Off Credit', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Available Balance: $_balance', style: GoogleFonts.poppins(color: Colors.green, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            InkWell(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime(2030),
                );
                if (date != null) setState(() => _leaveDate = date);
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                     Text(_leaveDate != null ? DateFormat('yyyy-MM-dd').format(_leaveDate!) : 'Select Leave Date', style: GoogleFonts.poppins()),
                     const Icon(Icons.calendar_month, size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _leaveCreditsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Credits to Use', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _leaveReasonController,
              decoration: const InputDecoration(labelText: 'Reason', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: _isApplyingLeave ? null : _applyForLeave, 
            child: _isApplyingLeave ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Apply'),
          ),
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Balance Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF152A4A), Color(0xFF334155)]),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: const Color(0xFF152A4A).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Current Balance', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text('$_balance Days', style: GoogleFonts.poppins(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                  ],
                ),
                ElevatedButton(
                  onPressed: _showApplyLeaveDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Color(0xFF152A4A),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: const Text('Use Credit'),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          Text('Credit Request History', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          
          if (_requests.isEmpty)
             Padding(
               padding: const EdgeInsets.only(top: 40),
               child: Center(child: Text('No history found', style: GoogleFonts.poppins(color: Colors.grey))),
             )
          else
            ..._requests.map((req) => _buildRequestCard(req)).toList(),
        ],
      ),
    );
  }

  Widget _buildRequestCard(dynamic req) {
    // Handling data safely from dynamic map
    final date = req['earnedDate'] ?? '-';
    final credits = req['credits'] ?? '0';
    final status = req['status'] ?? 'Unknown';
    final type = req['workType'] ?? 'Holiday';

    Color statusColor = Colors.orange;
    if (status == 'Approved') statusColor = Colors.green;
    if (status == 'Rejected') statusColor = Colors.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(type, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15)),
              Text('Earned: $date', style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 12)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$credits Credits', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(status, style: GoogleFonts.poppins(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


