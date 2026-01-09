import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../providers/attendance_provider.dart';
import '../models/attendance.dart';

class FaceAttendanceScreen extends StatefulWidget {
  const FaceAttendanceScreen({super.key});

  @override
  State<FaceAttendanceScreen> createState() => _FaceAttendanceScreenState();
}

class _FaceAttendanceScreenState extends State<FaceAttendanceScreen> {
  bool _isProcessing = false;
  String _status = 'Ready to capture face for attendance';
  File? _capturedImage;
  String _locationStatus = 'Checking location...';

  @override
  void initState() {
    super.initState();
    setState(() {
      _status = 'Ready to capture face for attendance';
    });
    _checkLocationStatus();
  }

  Future<void> _checkLocationStatus() async {
    try {
      final hasPermission = await LocationService.hasLocationPermission();
      if (hasPermission) {
        final location = await LocationService.getCurrentLocation();
        if (location != null) {
          setState(() {
            _locationStatus = 'Location: ${location['latitude']!.toStringAsFixed(4)}, ${location['longitude']!.toStringAsFixed(4)}';
          });
        } else {
          setState(() {
            _locationStatus = 'Location unavailable';
          });
        }
      } else {
        // Try to request permission
        final permissionGranted = await LocationService.requestLocationPermission();
        if (permissionGranted) {
          // Permission granted, try to get location again
          final location = await LocationService.getCurrentLocation();
          if (location != null) {
            setState(() {
              _locationStatus = 'Location: ${location['latitude']!.toStringAsFixed(4)}, ${location['longitude']!.toStringAsFixed(4)}';
            });
          } else {
            setState(() {
              _locationStatus = 'Location unavailable';
            });
          }
        } else {
          setState(() {
            _locationStatus = 'Location permission required';
          });
        }
      }
    } catch (e) {
      setState(() {
        _locationStatus = 'Location error';
      });
    }
  }

  Future<void> _requestLocationPermission() async {
    setState(() {
      _locationStatus = 'Requesting permission...';
    });
    
    try {
      final permissionGranted = await LocationService.requestLocationPermission();
      if (permissionGranted) {
        // Permission granted, try to get location
        final location = await LocationService.getCurrentLocation();
        if (location != null) {
          setState(() {
            _locationStatus = 'Location: ${location['latitude']!.toStringAsFixed(4)}, ${location['longitude']!.toStringAsFixed(4)}';
          });
        } else {
          setState(() {
            _locationStatus = 'Location unavailable';
          });
        }
      } else {
        setState(() {
          _locationStatus = 'Location permission denied';
        });
        
        // Show dialog explaining why location is needed
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Location Permission Required'),
              content: const Text(
                'Location access is required to mark attendance with location data. '
                'Please enable location permissions in your device settings to continue.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    LocationService.openAppSettings(); // Open app settings
                  },
                  child: const Text('Open Settings'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _locationStatus = 'Location permission error';
      });
    }
  }

  Future<void> _captureAndRecognize() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _status = 'Capturing image...';
    });

    try {
      // Capture image from camera
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 80,
      );

      if (image == null) {
        throw Exception('No image captured');
      }

      final File imageFile = File(image.path);

      setState(() {
        _capturedImage = imageFile;
        _status = 'Processing face recognition and marking attendance...';
      });

      // Mark attendance using the new API endpoint
      await _markAttendanceWithImage(imageFile);
    } catch (e) {
      setState(() {
        _status = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
      });
      
      // Show error dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Attendance Failed'),
            content: Text(e.toString().replaceAll('Exception: ', '')),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _pickImageAndRecognize() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _status = 'Selecting image...';
    });

    try {
      // Pick image from gallery
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image == null) {
        throw Exception('No image selected');
      }

      final File imageFile = File(image.path);

      setState(() {
        _capturedImage = imageFile;
        _status = 'Processing face recognition and marking attendance...';
      });

      // Mark attendance using the new API endpoint
      await _markAttendanceWithImage(imageFile);
    } catch (e) {
      setState(() {
        _status = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
      });
      
      // Show error dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Attendance Failed'),
            content: Text(e.toString().replaceAll('Exception: ', '')),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _markAttendanceWithImage(File imageFile) async {
    try {
      // Call the new API endpoint to mark attendance with image
      final Map<String, dynamic> result = await ApiService.markAttendanceWithImage(imageFile);
      
      if (result['success'] == true) {
        // Extract employee information from response
        final String employeeName = result['employee_name'] ?? 
                                    result['name'] ?? 
                                    result['employee']?['name'] ?? 
                                    'Employee';
        final String? attendanceType = result['attendance_type'] ?? 
                                        result['type'] ?? 
                                        result['action'];
        final String message = result['message'] ?? 
                              'Attendance successfully recorded for $employeeName';
        
        setState(() {
          _status = message;
        });

        // Refresh attendance list
        await Provider.of<AttendanceProvider>(context, listen: false).refresh();

        // Show success dialog
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Attendance Marked'),
              content: Text(message),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      } else {
        throw Exception(result['message'] ?? result['error'] ?? 'Failed to mark attendance');
      }
    } catch (e) {
      setState(() {
        _status = 'Error marking attendance: ${e.toString().replaceAll('Exception: ', '')}';
      });
      rethrow; // Re-throw to be caught by the calling function
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Face Attendance'),
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _status = 'Ready to capture face for attendance';
                _capturedImage = null;
                _locationStatus = 'Checking location...';
              });
              _checkLocationStatus();
            },
            tooltip: 'Reset',
          ),
        ],
      ),
      body: Column(
        children: [
          // Status bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: _isProcessing ? Colors.orange : Colors.green,
            child: Text(
              _status,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          // Location status bar
          GestureDetector(
            onTap: _locationStatus.contains('permission required') ? _requestLocationPermission : null,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: _locationStatus.contains('permission required') ? Colors.red[400] : 
                     _locationStatus.contains('error') || _locationStatus.contains('unavailable') ? Colors.orange[400] : Colors.blue[400],
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _locationStatus.contains('permission required') ? Icons.location_disabled :
                    _locationStatus.contains('error') || _locationStatus.contains('unavailable') ? Icons.location_off :
                    Icons.location_on,
                    size: 16,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _locationStatus.contains('permission required') 
                          ? 'Tap to grant location permission' 
                          : _locationStatus,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  if (_locationStatus.contains('permission required'))
                    const Icon(
                      Icons.arrow_forward_ios,
                      size: 12,
                      color: Colors.white,
                    ),
                ],
              ),
            ),
          ),

          // Image preview area
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF2196F3), width: 3),
                color: Colors.grey[100],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: _capturedImage != null
                    ? Stack(
                        children: [
                          // Captured image
                          Image.file(
                            _capturedImage!,
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                          ),
                          
                          // Processing overlay
                          if (_isProcessing)
                            Container(
                              color: Colors.black.withOpacity(0.5),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ),
                            ),
                        ],
                      )
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.camera_alt,
                              size: 80,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No image captured',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Use the buttons below to capture or select an image',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),

          // Instructions
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  'Instructions',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '1. Ensure good lighting\n'
                  '2. Look directly at the camera\n'
                  '3. Capture or select a clear face image\n'
                  '4. The system will automatically recognize and mark attendance',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          // Action buttons
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Capture button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: !_isProcessing ? _captureAndRecognize : null,
                    icon: const Icon(Icons.camera_alt),
                    label: Text(
                      'Capture from Camera',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
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

              ],
            ),
          ),
        ],
      ),
    );
  }
} 