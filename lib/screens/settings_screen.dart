import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/shift_provider.dart';
import '../models/shift.dart';
import '../widgets/no_internet_widget.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    // Load shifts when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ShiftProvider>().loadShifts();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.grey[50]!,
              Colors.white,
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // Shift Management Section & Add New Shift Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionHeader('Shift Management'),
                ElevatedButton.icon(
                  onPressed: () => _showShiftDialog(context),
                  icon: const Icon(Icons.add, size: 16, color: Colors.white),
                  label: Text(
                    'Add New',
                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2196F3),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 2,
                    shadowColor: const Color(0xFF2196F3).withOpacity(0.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Existing Shifts List


            Consumer<ShiftProvider>(
              builder: (context, shiftProvider, child) {
                if (shiftProvider.isLoading) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                if (shiftProvider.error != null) {
                  final errorLower = shiftProvider.error!.toLowerCase();
                  final isNetworkError = errorLower.contains('network') || 
                                        errorLower.contains('connection') || 
                                        errorLower.contains('xmlhttprequest');
                  
                  if (isNetworkError) {
                    return NoInternetWidget(onRetry: () => shiftProvider.loadShifts());
                  }

                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          const Icon(Icons.error_outline, size: 48, color: Colors.red),
                          const SizedBox(height: 16),
                          Text(
                            'Error loading shifts',
                            style: GoogleFonts.poppins(fontSize: 14, color: Colors.red),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            shiftProvider.error!,
                            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => shiftProvider.loadShifts(),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (shiftProvider.shifts.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          const Icon(Icons.schedule, size: 48, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(
                            'No shifts configured',
                            style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Add your first shift to get started',
                            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: shiftProvider.shifts.length,
                  itemBuilder: (context, index) {
                    final shift = shiftProvider.shifts[index];
                    return _buildShiftCard(context, shift);
                  },
                );
              },
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2196F3).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF2196F3),
        ),
      ),
    );
  }

  Widget _buildShiftCard(BuildContext context, Shift shift) {
    final isNight = shift.name.toLowerCase().contains('night');
    final primaryColor = isNight ? Colors.indigo : const Color(0xFF2196F3);
    final lightColor = isNight ? Colors.indigo.shade50 : const Color(0xFFE3F2FD);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Left color accent bar
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 6,
              child: Container(color: primaryColor),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: lightColor,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          isNight ? Icons.nights_stay_rounded : Icons.wb_sunny_rounded,
                          color: primaryColor,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              shift.name,
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.schedule, size: 14, color: Colors.grey.shade500),
                                const SizedBox(width: 6),
                                Text(
                                  '${shift.formattedFromTime} - ${shift.formattedToTime}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton(
                        icon: const Icon(Icons.more_vert, color: Colors.grey),
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        color: Colors.white,
                        offset: const Offset(0, 40),
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            height: 48,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 22, color: Color(0xFF2196F3)),
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _showShiftDialog(context, shift: shift);
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 22, color: Color(0xFFF44336)),
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _showDeleteConfirmation(context, shift);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  
                  if (shift.hasGracePeriod) ...[
                    const SizedBox(height: 16),
                    Container(
                      margin: const EdgeInsets.only(left: 60), // Align with text
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.timer_outlined, size: 16, color: Colors.orange.shade700),
                          const SizedBox(width: 6),
                          Text(
                            'Grace: ${shift.formattedGraceFromTime} - ${shift.formattedGraceToTime}',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.orange.shade800,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showShiftDialog(BuildContext context, {Shift? shift}) {
    showDialog(
      context: context,
      builder: (context) => ShiftDialog(shift: shift),
    );
  }


  void _showDeleteConfirmation(BuildContext context, Shift shift) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Shift'),
        content: Text('Are you sure you want to delete "${shift.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              // Show modern loading dialog FIRST, don't pop confirmation dialog yet
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (loadingContext) => Dialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                  backgroundColor: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 40,
                          height: 40,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2196F3)),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Deleting shift...',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Please wait a moment',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
              
              final success = await context.read<ShiftProvider>().deleteShift(shift.id!);
              
              if (mounted) {
                Navigator.of(context).pop(); // Close loading dialog
                Navigator.of(context).pop(); // Close confirmation dialog
                ScaffoldMessenger.of(context).clearSnackBars();
                
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Shift "${shift.name}" deleted successfully'),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete shift "${shift.name}"'),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 3),
                      action: SnackBarAction(
                        label: 'Retry',
                        textColor: Colors.white,
                        onPressed: () => _showDeleteConfirmation(context, shift),
                      ),
                    ),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class ShiftDialog extends StatefulWidget {
  final Shift? shift;

  const ShiftDialog({super.key, this.shift});

  @override
  State<ShiftDialog> createState() => _ShiftDialogState();
}

class _ShiftDialogState extends State<ShiftDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  TimeOfDay? _fromTime;
  TimeOfDay? _toTime;
  TimeOfDay? _graceFromTime;
  TimeOfDay? _graceToTime;
  bool _hasGracePeriod = false;

  TimeOfDay _addMinutesToTimeOfDay(TimeOfDay time, int minutes) {
    int totalMinutes = time.hour * 60 + time.minute + minutes;
    int newHour = (totalMinutes ~/ 60) % 24;
    int newMinute = totalMinutes % 60;
    return TimeOfDay(hour: newHour, minute: newMinute);
  }

  int _getDifferenceInMinutes(TimeOfDay shiftTime, TimeOfDay graceTime) {
    int shiftMinutes = shiftTime.hour * 60 + shiftTime.minute;
    int graceMinutes = graceTime.hour * 60 + graceTime.minute;
    
    if (graceMinutes < shiftMinutes) {
      graceMinutes += 24 * 60; // Handle overnight wrap
    }
    return graceMinutes - shiftMinutes;
  }

  void _validateAndSetGraceTime(TimeOfDay? time, TimeOfDay? shiftTime, bool isFrom) {
    if (time == null) return;
    if (shiftTime == null) {
      setState(() {
        if (isFrom) _graceFromTime = time;
        else _graceToTime = time;
      });
      return;
    }

    int diff = _getDifferenceInMinutes(shiftTime, time);
    if (diff >= 5 && diff <= 30) {
      setState(() {
        if (isFrom) _graceFromTime = time;
        else _graceToTime = time;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Grace Period must be between 5 and 30 minutes after the Shift time.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();

    if (widget.shift != null) {
      _nameController.text = widget.shift!.name;
      _fromTime = Shift.stringToTimeOfDay(widget.shift!.fromTime);
      _toTime = Shift.stringToTimeOfDay(widget.shift!.toTime);
      _hasGracePeriod = widget.shift!.hasGracePeriod;

      if (_hasGracePeriod && widget.shift!.graceFromTime != null) {
        _graceFromTime = Shift.stringToTimeOfDay(widget.shift!.graceFromTime!);
      }
      if (_hasGracePeriod && widget.shift!.graceToTime != null) {
        _graceToTime = Shift.stringToTimeOfDay(widget.shift!.graceToTime!);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 10,
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFF2196F3).withOpacity(0.05),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2196F3).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.schedule, color: Color(0xFF2196F3), size: 20),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      widget.shift == null ? 'Add New Shift' : 'Edit Shift',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF2196F3),
                      ),
                    ),
                  ],
                ),
              ),

              // Form content
              Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Shift Name
                      Text(
                        'Shift Name',
                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _nameController,
                        style: GoogleFonts.poppins(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'e.g. Morning Shift',
                          hintStyle: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade400),
                          prefixIcon: Icon(Icons.business_center, color: Colors.grey.shade500, size: 20),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter shift name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Time fields row
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'From Time',
                                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey.shade700),
                                ),
                                const SizedBox(height: 8),
                                _buildModernTimeField(
                                  value: _fromTime,
                                  onChanged: (time) => setState(() => _fromTime = time),
                                  icon: Icons.play_circle_outline,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'To Time',
                                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey.shade700),
                                ),
                                const SizedBox(height: 8),
                                _buildModernTimeField(
                                  value: _toTime,
                                  onChanged: (time) => setState(() => _toTime = time),
                                  icon: Icons.stop_circle_outlined,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Grace Period Container
                      Container(
                        decoration: BoxDecoration(
                          color: _hasGracePeriod ? const Color(0xFF2196F3).withOpacity(0.03) : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _hasGracePeriod ? const Color(0xFF2196F3).withOpacity(0.2) : Colors.transparent,
                          ),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Enable Grace Period',
                                        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
                                      ),
                                      Text(
                                        'Allow late arrival without penalty',
                                        style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey.shade600),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: _hasGracePeriod,
                                  onChanged: (value) {
                                    setState(() {
                                      _hasGracePeriod = value;
                                      if (value) {
                                        if (_graceFromTime == null && _fromTime != null) {
                                          _graceFromTime = _addMinutesToTimeOfDay(_fromTime!, 5);
                                        }
                                        if (_graceToTime == null && _toTime != null) {
                                          _graceToTime = _addMinutesToTimeOfDay(_toTime!, 5);
                                        }
                                      }
                                    });
                                  },
                                  activeColor: const Color(0xFF2196F3),
                                ),
                              ],
                            ),
                            if (_hasGracePeriod) ...[
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Divider(height: 1),
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Grace From',
                                          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.grey.shade600),
                                        ),
                                        const SizedBox(height: 8),
                                        _buildModernTimeField(
                                          value: _graceFromTime,
                                          onChanged: (time) => _validateAndSetGraceTime(time, _fromTime, true),
                                          icon: Icons.timer_outlined,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Grace To',
                                          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.grey.shade600),
                                        ),
                                        const SizedBox(height: 8),
                                        _buildModernTimeField(
                                          value: _graceToTime,
                                          onChanged: (time) => _validateAndSetGraceTime(time, _toTime, false),
                                          icon: Icons.timer_off_outlined,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                side: BorderSide(color: Colors.grey.shade300),
                              ),
                              child: Text(
                                'Cancel',
                                style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey.shade700),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: _saveShift,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2196F3),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                widget.shift == null ? 'Create Shift' : 'Save Changes',
                                style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernTimeField({
    required TimeOfDay? value,
    required Function(TimeOfDay?) onChanged,
    required IconData icon,
  }) {
    return InkWell(
      onTap: () async {
        final time = await showTimePicker(
          context: context,
          initialTime: value ?? TimeOfDay.now(),
        );
        if (time != null) {
          onChanged(time);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.grey.shade500, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value?.format(context) ?? 'Select time',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: value != null ? FontWeight.w500 : FontWeight.normal,
                  color: value != null ? Colors.black87 : Colors.grey.shade500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  void _saveShift() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_fromTime == null || _toTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both from and to times'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    if (_hasGracePeriod && (_graceFromTime == null || _graceToTime == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both grace from and to times'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    } else if (_hasGracePeriod) {
      int diffFrom = _getDifferenceInMinutes(_fromTime!, _graceFromTime!);
      int diffTo = _getDifferenceInMinutes(_toTime!, _graceToTime!);
      
      if (diffFrom < 5 || diffFrom > 30 || diffTo < 5 || diffTo > 30) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Grace Period must be between 5 and 30 minutes after the Shift time.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }
    }

    final shift = Shift(
      id: widget.shift?.id,
      name: _nameController.text.trim(),
      fromTime: Shift.timeOfDayToString(_fromTime!),
      toTime: Shift.timeOfDayToString(_toTime!),
      hasGracePeriod: _hasGracePeriod,
      graceFromTime: _hasGracePeriod ? Shift.timeOfDayToString(_graceFromTime!) : null,
      graceToTime: _hasGracePeriod ? Shift.timeOfDayToString(_graceToTime!) : null,
    );

    final isUpdate = widget.shift != null;
    
    // Show modern loading dialog FIRST, keep edit dialog open
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (loadingContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2196F3)),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                isUpdate ? 'Updating shift...' : 'Creating shift...',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please wait a moment',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    bool success;
    if (isUpdate) {
      // Update existing shift
      success = await context.read<ShiftProvider>().updateShift(widget.shift!.id!, shift);
    } else {
      // Create new shift
      success = await context.read<ShiftProvider>().createShift(shift);
    }

    if (mounted) {
      Navigator.of(context).pop(); // Close loading dialog
      Navigator.of(context).pop(); // Close edit dialog
      ScaffoldMessenger.of(context).clearSnackBars();

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isUpdate
                  ? 'Shift "${shift.name}" updated successfully'
                  : 'Shift "${shift.name}" created successfully',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isUpdate
                  ? 'Failed to update shift "${shift.name}"'
                  : 'Failed to create shift "${shift.name}"',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _saveShift(),
            ),
          ),
        );
      }
    }
  }
}
