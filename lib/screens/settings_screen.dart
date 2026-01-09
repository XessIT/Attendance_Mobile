import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/shift_provider.dart';
import '../models/shift.dart';

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
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFF2196F3),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Shift Management Section
            _buildSectionHeader('Shift Management'),
            const SizedBox(height: 16),

            // Add New Shift Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () => _showShiftDialog(context),
                icon: const Icon(Icons.add),
                label: Text(
                  'Add New Shift',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2196F3),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Existing Shifts List
            _buildSectionHeader('Current Shifts'),
            const SizedBox(height: 16),

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
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          const Icon(Icons.error_outline, size: 48, color: Colors.red),
                          const SizedBox(height: 16),
                          Text(
                            'Error loading shifts',
                            style: GoogleFonts.poppins(fontSize: 16, color: Colors.red),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            shiftProvider.error!,
                            style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey),
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
                            style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Add your first shift to get started',
                            style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey),
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
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF2196F3),
      ),
    );
  }

  Widget _buildShiftCard(BuildContext context, Shift shift) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  shift.name,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2196F3),
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _showShiftDialog(context, shift: shift);
                    } else if (value == 'delete') {
                      _showDeleteConfirmation(context, shift);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 20),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red, size: 20),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Shift Time
            Row(
              children: [
                const Icon(Icons.access_time, size: 20, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  '${shift.formattedFromTime} - ${shift.formattedToTime}',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),

            // Grace Period
            if (shift.hasGracePeriod) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.timer, size: 20, color: Colors.orange),
                  const SizedBox(width: 8),
                  Text(
                    'Grace: ${shift.formattedGraceFromTime} - ${shift.formattedGraceToTime}',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.orange[700],
                    ),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.timer_off, size: 20, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    'No grace period',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ],
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
              Navigator.of(context).pop(); // Close dialog
              
              // Show loading indicator
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        SizedBox(width: 16),
                        Text('Deleting shift...'),
                      ],
                    ),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
              
              final success = await context.read<ShiftProvider>().deleteShift(shift.id!);
              
              if (mounted) {
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
        borderRadius: BorderRadius.circular(16),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.shift == null ? 'Add New Shift' : 'Edit Shift',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2196F3),
                ),
              ),
              const SizedBox(height: 24),

              // Shift Name
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Shift Name',
                  prefixIcon: const Icon(Icons.business_center),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter shift name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // From Time
              _buildTimeField(
                label: 'From Time',
                value: _fromTime,
                onChanged: (time) => setState(() => _fromTime = time),
                icon: Icons.play_arrow,
              ),
              const SizedBox(height: 20),

              // To Time
              _buildTimeField(
                label: 'To Time',
                value: _toTime,
                onChanged: (time) => setState(() => _toTime = time),
                icon: Icons.stop,
              ),
              const SizedBox(height: 20),

              // Grace Period Toggle
              SwitchListTile(
                title: Text(
                  'Enable Grace Period',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  'Allow late arrival within grace period',
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                ),
                value: _hasGracePeriod,
                onChanged: (value) => setState(() => _hasGracePeriod = value),
                activeColor: const Color(0xFF2196F3),
              ),

              // Grace Time Fields
              if (_hasGracePeriod) ...[
                const SizedBox(height: 20),
                _buildTimeField(
                  label: 'Grace From Time',
                  value: _graceFromTime,
                  onChanged: (time) => setState(() => _graceFromTime = time),
                  icon: Icons.timer,
                ),
                const SizedBox(height: 20),
                _buildTimeField(
                  label: 'Grace To Time',
                  value: _graceToTime,
                  onChanged: (time) => setState(() => _graceToTime = time),
                  icon: Icons.timer_off,
                ),
              ],

              const SizedBox(height: 32),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.poppins(color: Colors.grey),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _saveShift,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2196F3),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: Text(
                      widget.shift == null ? 'Add Shift' : 'Update Shift',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeField({
    required String label,
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
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          value?.format(context) ?? 'Select time',
          style: GoogleFonts.poppins(
            fontSize: 16,
            color: value != null ? Colors.black : Colors.grey,
          ),
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
    Navigator.of(context).pop(); // Close dialog

    // Show loading indicator
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(width: 16),
              Text(isUpdate ? 'Updating shift...' : 'Creating shift...'),
            ],
          ),
          duration: const Duration(seconds: 10),
        ),
      );
    }

    bool success;
    if (isUpdate) {
      // Update existing shift
      success = await context.read<ShiftProvider>().updateShift(widget.shift!.id!, shift);
    } else {
      // Create new shift
      success = await context.read<ShiftProvider>().createShift(shift);
    }

    if (mounted) {
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
