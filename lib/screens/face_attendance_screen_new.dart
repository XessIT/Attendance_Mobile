import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../providers/attendance_provider.dart';
import '../models/attendance.dart';

class FaceAttendanceScreen extends StatefulWidget {
  final bool shouldLoop;
  
  const FaceAttendanceScreen({super.key, this.shouldLoop = true});

  @override
  State<FaceAttendanceScreen> createState() => _FaceAttendanceScreenState();
}

class _FaceAttendanceScreenState extends State<FaceAttendanceScreen> {
  bool _isProcessing = false;
  String _status = 'Ready to capture face for attendance';
  File? _capturedImage;
  String _locationStatus = 'Checking location...';
  Map<String, double>? _cachedLocation;
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;

  @override
  void initState() {
    super.initState();
    _isActive = true;
    setState(() {
      _status = 'Initializing attendance...';
    });
    _checkLocationStatus();
    _initializeCamera();
    
    // Auto-start face recognition after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _captureAndRecognize();
      }
    });
    
    // Test snackbar after 3 seconds to verify it's working
    // Future.delayed(const Duration(seconds: 3), () {
    //   if (mounted) {
    //     ScaffoldMessenger.of(context).showSnackBar(
    //       SnackBar(
    //         content: Text('Test: Snackbar is working!'),
    //         backgroundColor: Colors.blue,
    //         duration: const Duration(seconds: 2),
    //       ),
    //     );
    //   }
    // });
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
    } catch (e) {
      print('Camera initialization error: $e');
      _cameras = [];
    }
  }

  @override
  void dispose() {
    _isActive = false; // ❌ stop loop
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _checkLocationStatus() async {
    try {
      final hasPermission = await LocationService.hasLocationPermission();
      if (hasPermission) {
        final location = await LocationService.getCurrentLocation();
        if (location != null) {
          _cachedLocation = location; // Cache location for later use
          if (mounted) {
            setState(() {
              _locationStatus = 'Location: ${location['latitude']!.toStringAsFixed(4)}, ${location['longitude']!.toStringAsFixed(4)}';
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _locationStatus = 'Location unavailable';
            });
          }
        }
      } else {
        // Try to request permission
        final permissionGranted = await LocationService.requestLocationPermission();
        if (permissionGranted) {
          // Permission granted, try to get location again
          final location = await LocationService.getCurrentLocation();
          if (location != null) {
            _cachedLocation = location; // Cache location for later use
            if (mounted) {
              setState(() {
                _locationStatus = 'Location: ${location['latitude']!.toStringAsFixed(4)}, ${location['longitude']!.toStringAsFixed(4)}';
              });
            }
          } else {
            if (mounted) {
              setState(() {
                _locationStatus = 'Location unavailable';
              });
            }
          }
        } else {
          if (mounted) {
            setState(() {
              _locationStatus = 'Location permission required';
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _locationStatus = 'Location error';
        });
      }
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
          if (mounted) {
            setState(() {
              _locationStatus = 'Location: ${location['latitude']!.toStringAsFixed(4)}, ${location['longitude']!.toStringAsFixed(4)}';
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _locationStatus = 'Location unavailable';
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _locationStatus = 'Location permission denied';
          });
        }
        
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
      if (mounted) {
        setState(() {
          _locationStatus = 'Location permission error';
        });
      }
    }
  }

  Future<void> _captureAndRecognize() async {
    if (_isProcessing || !_isActive) return;

    // Always use direct camera capture - get cameras if not already loaded
    if (_cameras == null || _cameras!.isEmpty) {
      try {
        _cameras = await availableCameras();
      } catch (e) {
        print('Error getting cameras: $e');
        if (mounted) {
          setState(() {
            _isProcessing = false;
            _status = 'Camera not available';
          });
        }
        return;
      }
    }

    // Find front camera
    CameraDescription? frontCamera;
    for (var camera in _cameras!) {
      if (camera.lensDirection == CameraLensDirection.front) {
        frontCamera = camera;
        break;
      }
    }
    
    // Fallback to back camera if front not available
    if (frontCamera == null && _cameras!.isNotEmpty) {
      frontCamera = _cameras!.first;
    }
    
    if (frontCamera != null) {
      // Navigate to camera screen that auto-captures
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CameraCaptureScreen(camera: frontCamera!),
        ),
      );
      
      if (result != null && result is File) {
        // Process the captured image
        if (mounted) {
          await _processCapturedImage(result);
        }
      } else {
        // User cancelled or error - reset silently
        if (mounted) {
          setState(() {
            _isProcessing = false;
            _status = 'Ready to capture face for attendance';
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _status = 'No camera available';
        });
      }
    }
  }

  bool _isActive = true;

  Future<void> _processCapturedImage(File imageFile) async {
    if (!mounted) return;
    
    setState(() {
      _isProcessing = true;
      _capturedImage = imageFile;
      _status = 'Checking face...';
    });

    try {
      // ✅ STEP 1: Detect face locally
      final hasFace = await _detectFace(imageFile);

      if (!hasFace) {
        if (mounted) {
          setState(() {
            _isProcessing = false;
            _status = 'Face not detected, scanning...';
            _capturedImage = null;
          });
        }

        // ❌ Don't call API, just continue scanning silently
        if (mounted && widget.shouldLoop) {
          Future.delayed(const Duration(milliseconds: 300), () {
            _captureAndRecognize();
          });
        }

        return; // 🚫 STOP HERE
      }

      // ✅ STEP 2: Face detected → proceed
      if (mounted) {
        setState(() {
          _status = 'Face detected. Processing attendance...';
        });
      }

      final finalImageFile = await _compressImage(imageFile);

      // ✅ CALL API ONLY HERE
      await _markAttendanceWithImage(finalImageFile);

      // 🔁 Loop again
      if (mounted && widget.shouldLoop) {
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) _captureAndRecognize();
        });
      }

    } catch (e) {
      if (mounted) {
        setState(() {
          _status = 'Error: ${e.toString()}';
          _isProcessing = false;
          _capturedImage = null;
        });
      }

      if (mounted && widget.shouldLoop) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) _captureAndRecognize();
        });
      }
    }
  }

  Future<void> _captureWithImagePicker() async {
    setState(() {
      _isProcessing = true;
      _status = 'Capturing image...';
    });

    try {
      // Fallback to ImagePicker if direct camera capture fails
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 80, // Increased from 40 to 80 for better face detection
      );

      if (image == null) {
        // User cancelled - silently reset without error
        if (mounted) {
          setState(() {
            _isProcessing = false;
            _status = 'Ready to capture face for attendance';
          });
        }
        return;
      }

      File imageFile = File(image.path);
      
      // Process the captured image with face detection
      await _processCapturedImage(imageFile);
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
          _isProcessing = false;
          _capturedImage = null; // Clear the captured image on error
        });
      }
      
      // Show error snackbar instead of dialog (auto-dismisses)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _pickImageAndRecognize() async {
    if (_isProcessing) return;

    if (mounted) {
      setState(() {
        _isProcessing = true;
        _status = 'Selecting image...';
      });
    }

    try {
      // Pick image from gallery with lower quality for faster upload
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80, // Increased from 40 to 80 for better face detection
      );

      if (image == null) {
        // User cancelled - silently reset without error
        if (mounted) {
          setState(() {
            _isProcessing = false;
            _status = 'Ready to capture face for attendance';
          });
        }
        return;
      }

      File imageFile = File(image.path);
      
      // Process the selected image with face detection
      await _processCapturedImage(imageFile);
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
          _isProcessing = false;
          _capturedImage = null; // Clear the captured image on error
        });
      }
      
      // Show error snackbar instead of dialog (auto-dismisses)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<bool> _detectFace(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);

    final faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.fast,
        enableContours: false,
        enableLandmarks: false,
      ),
    );

    final faces = await faceDetector.processImage(inputImage);

    faceDetector.close();

    return faces.isNotEmpty;
  }

  Future<File> _compressImage(File imageFile) async {
    try {
      // Check file size first - skip compression if already small (< 500KB)
      final fileSize = await imageFile.length();
      if (fileSize < 500 * 1024) {
        return imageFile; // File is already small enough, skip compression
      }

      // Read image bytes
      final Uint8List imageBytes = await imageFile.readAsBytes();
      
      // Decode image
      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) {
        return imageFile; // Return original if decode fails
      }

      // Resize image if too large (increased from 600px to 800px for better face detail)
      if (image.width > 800) {
        final ratio = 800 / image.width;
        image = img.copyResize(
          image,
          width: 800,
          height: (image.height * ratio).round(),
        );
      }

      // Compress image (increased quality from 60% to 85% for better face detection)
      final compressedBytes = img.encodeJpg(image, quality: 85);

      // Save to temporary file
      final tempDir = await getTemporaryDirectory();
      final compressedFile = File('${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await compressedFile.writeAsBytes(compressedBytes);

      return compressedFile;
    } catch (e) {
      print('Image compression error: $e');
      return imageFile; // Return original if compression fails
    }
  }

  Future<void> _markAttendanceWithImage(File imageFile) async {
    try {
      // Use cached location if available, otherwise pass null (API will handle it)
      // Call the new API endpoint to mark attendance with image
      final Map<String, dynamic> result = await ApiService.markAttendanceWithImage(
        imageFile,
        cachedLocation: _cachedLocation,
      );

      // Debug logging to understand response structure
      print('🔍 API Response Debug:');
      print('   Full response: $result');
      print('   Success field: ${result['success']}');
      print('   Status field: ${result['status']}');
      print('   Message field: ${result['message']}');

      // Check for successful response - more robust check
      final bool isSuccess = result['success'] == true ||
                           result['status'] == 'success' ||
                           result['status'] == 'ok' ||
                           (result['message'] != null && result['message']!.toString().toLowerCase().contains('success'));

      print('   Is success detected: $isSuccess');

      if (isSuccess) {
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

        if (mounted) {
          setState(() {
            _status = message;
            _isProcessing = false;
          });
        }

        // Show success snackbar instead of dialog (auto-dismisses)
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(message),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          });
        }

        // Refresh attendance list in the background (don't wait for it)
        Provider.of<AttendanceProvider>(context, listen: false).refresh().catchError((e) {
          // Silently handle refresh errors - attendance is already marked
        });
      } else {
        throw Exception(result['message'] ?? result['error'] ?? 'Failed to mark attendance');
      }
    } catch (e) {
      print('🔍 Error in _markAttendanceWithImage: $e');
      if (mounted) {
        setState(() {
          _status = 'Error marking attendance: ${e.toString().replaceAll('Exception: ', '')}';
        });
      }
      
      // Show error snackbar here as well
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(e.toString().replaceAll('Exception: ', '')),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        });
      }
      
      rethrow; // Re-throw to be caught by the calling function
    }
  }

  void _showGuideDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF2196F3).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.info_outline,
                color: Color(0xFF2196F3),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Face Recognition Guide',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF2196F3),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Follow these simple steps for successful face recognition:',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              ...List.generate(4, (index) {
                final instructions = [
                  {'icon': Icons.lightbulb_outline, 'text': 'Ensure good lighting conditions', 'detail': 'Face should be clearly visible without shadows'},
                  {'icon': Icons.face, 'text': 'Look directly at camera', 'detail': 'Keep your face straight and centered'},
                  {'icon': Icons.camera_enhance, 'text': 'Keep face clearly visible', 'detail': 'Remove glasses, masks, or obstructions'},
                  {'icon': Icons.check_circle_outline, 'text': 'System auto-recognizes & marks', 'detail': 'Attendance will be marked automatically'},
                ];
                final item = instructions[index];
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Icon with subtle background
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2196F3).withOpacity(0.08),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF2196F3).withOpacity(0.15),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          item['icon'] as IconData,
                          color: const Color(0xFF2196F3),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      
                      // Instruction text
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${index + 1}. ${item['text']}',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.grey[800],
                                fontWeight: FontWeight.w600,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item['detail'] as String,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w400,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Got it!',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF2196F3),
              ),
            ),
          ),
        ],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          //   decoration: BoxDecoration(
          //     gradient: LinearGradient(
          //       colors: _isProcessing
          //         ? [Colors.orange[400]!, Colors.orange[600]!]
          //         : _status.contains('Error') || _status.contains('failed')
          //           ? [Colors.red[400]!, Colors.red[600]!]
          //           : [Colors.green[400]!, Colors.green[600]!],
          //       begin: Alignment.topLeft,
          //       end: Alignment.bottomRight,
          //     ),
          //     boxShadow: [
          //       BoxShadow(
          //         color: (_isProcessing ? Colors.orange : Colors.green).withOpacity(0.3),
          //         blurRadius: 8,
          //         offset: const Offset(0, 4),
          //       ),
          //     ],
          //   ),
          //   child: Row(
          //     children: [
          //       // Animated status icon
          //       TweenAnimationBuilder<double>(
          //         duration: const Duration(seconds: 1),
          //         tween: Tween(begin: 0, end: 1),
          //         builder: (context, value, child) {
          //           return Transform.rotate(
          //             angle: _isProcessing ? value * 6.28 : 0,
          //             child: Icon(
          //               _isProcessing
          //                 ? Icons.refresh
          //                 : _status.contains('Error') || _status.contains('failed')
          //                   ? Icons.error_outline
          //                   : Icons.check_circle_outline,
          //               color: Colors.white,
          //               size: 24,
          //             ),
          //           );
          //         },
          //       ),
          //       const SizedBox(width: 12),
          //       // Status text
          //       Expanded(
          //         child: Text(
          //           _status,
          //           style: GoogleFonts.poppins(
          //             fontSize: 16,
          //             fontWeight: FontWeight.w600,
          //             color: Colors.white,
          //           ),
          //         ),
          //       ),
          //       // Processing indicator
          //       if (_isProcessing)
          //         SizedBox(
          //           width: 20,
          //           height: 20,
          //           child: CircularProgressIndicator(
          //             strokeWidth: 2,
          //             valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
          //           ),
          //         ),
          //     ],
          //   ),
          // ),

          // Enhanced Location status bar with gradient
          GestureDetector(
            onTap: _locationStatus.contains('permission required') ? _requestLocationPermission : null,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _locationStatus.contains('permission required') 
                    ? [Colors.red[400]!, Colors.red[600]!]
                    : _locationStatus.contains('error') || _locationStatus.contains('unavailable') 
                      ? [Colors.orange[400]!, Colors.orange[600]!]
                      : [Colors.blue[400]!, Colors.blue[600]!],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (_locationStatus.contains('permission required') ? Colors.red : 
                           _locationStatus.contains('error') || _locationStatus.contains('unavailable') ? Colors.orange : 
                           Colors.blue).withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated location icon
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 500),
                    tween: Tween(begin: 0, end: 1),
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: 0.8 + (value * 0.2),
                        child: Icon(
                          _locationStatus.contains('permission required') ? Icons.location_disabled :
                          _locationStatus.contains('error') || _locationStatus.contains('unavailable') ? Icons.location_off :
                          Icons.location_on,
                          size: 18,
                          color: Colors.white,
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 10),
                  // Location text
                  Expanded(
                    child: Text(
                      _locationStatus.contains('permission required') 
                          ? 'Tap to grant location permission' 
                          : _locationStatus,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  // Arrow icon for permission required
                  if (_locationStatus.contains('permission required'))
                    TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 800),
                      tween: Tween(begin: 0, end: 1),
                      builder: (context, value, child) {
                        return Transform.translate(
                          offset: Offset(value * 3, 0),
                          child: const Icon(
                            Icons.arrow_forward_ios,
                            size: 12,
                            color: Colors.white,
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),

          // Enhanced Image preview area - full width without box
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: AspectRatio(
                aspectRatio: 1.0,
                child: _capturedImage != null
                    ? Stack(
                        children: [
                          // Captured image in perfect circle shape - no container box
                          CircleAvatar(
                            child: Image.file(
                              _capturedImage!,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          
                          // Enhanced processing overlay with animation
                          if (_isProcessing)
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.black.withOpacity(0.6),
                                    Colors.black.withOpacity(0.4),
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // Animated processing indicator
                                    TweenAnimationBuilder<double>(
                                      duration: const Duration(seconds: 1),
                                      tween: Tween(begin: 0, end: 1),
                                      builder: (context, value, child) {
                                        return Transform.scale(
                                          scale: 0.8 + (value * 0.2),
                                          child: SizedBox(
                                            width: 60,
                                            height: 60,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 4,
                                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                              backgroundColor: Colors.white.withOpacity(0.3),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 20),
                                    Text(
                                      'Processing...',
                                      style: GoogleFonts.poppins(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      )
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Animated camera icon - cleaner design
                            TweenAnimationBuilder<double>(
                              duration: const Duration(seconds: 2),
                              tween: Tween(begin: 0, end: 1),
                              builder: (context, value, child) {
                                return Transform.scale(
                                  scale: 0.8 + (value * 0.2),
                                  child: Container(
                                    padding: const EdgeInsets.all(40),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFF2196F3).withOpacity(0.08),
                                      border: Border.all(
                                        color: const Color(0xFF2196F3).withOpacity(0.2),
                                        width: 1,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.camera_alt_outlined,
                                      size: 100,
                                      color: const Color(0xFF2196F3),
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 32),
                            Text(
                              'Ready for Face Recognition',
                              style: GoogleFonts.poppins(
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF2196F3),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Face recognition will start automatically',
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w400,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),

          // Info icon for guide
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.only(bottom: 30),
            child: Center(
              child: GestureDetector(
                onTap: _showGuideDialog,
                child: Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2196F3).withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF2196F3).withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.info_outline,
                    color: Color(0xFF2196F3),
                    size: 28,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Camera capture screen that auto-captures without confirmation
class CameraCaptureScreen extends StatefulWidget {
  final CameraDescription camera;

  const CameraCaptureScreen({super.key, required this.camera});

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen> {
  CameraController? _controller;
  bool _isCapturing = false;
  bool _hasCaptured = false;
  FaceDetector? _faceDetector;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.high, // Changed from low to high for better face detection
      enableAudio: false,
    );

    try {
      await _controller!.initialize();
      _faceDetector = FaceDetector(
        options: FaceDetectorOptions(
          performanceMode: FaceDetectorMode.fast,
          enableContours: false,
          enableLandmarks: false,
        ),
      );
      setState(() {}); // Rebuild to show camera preview
      
      // Wait 2 seconds to show the camera preview with face circle before auto-capturing
      await Future.delayed(const Duration(seconds: 2));
      
      // Keep camera open and capture continuously until face is detected
      if (mounted && !_hasCaptured) {
        _startAutoCaptureLoop();
      }
    } catch (e) {
      print('Camera initialization error: $e');
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  Future<void> _startAutoCaptureLoop() async {
    if (_controller == null || !_controller!.value.isInitialized || _isCapturing) {
      return;
    }

    _isCapturing = true;
    try {
      while (mounted && !_hasCaptured) {
        try {
          final XFile image = await _controller!.takePicture();
          final file = File(image.path);
          final hasFace = await _detectFaceInCamera(file);

          if (hasFace) {
            _hasCaptured = true;
            if (mounted) {
              Navigator.pop(context, file);
            }
            return;
          }
        } catch (e) {
          print('Auto capture attempt failed: $e');
        }

        // Small delay before trying the next frame
        await Future.delayed(const Duration(milliseconds: 400));
      }
    } finally {
      _isCapturing = false;
    }
  }

  Future<bool> _detectFaceInCamera(File imageFile) async {
    if (_faceDetector == null) return false;
    final inputImage = InputImage.fromFile(imageFile);
    final faces = await _faceDetector!.processImage(inputImage);
    return faces.isNotEmpty;
  }

  Future<void> _captureFromStream() async {
    if (_controller == null || !_controller!.value.isInitialized || _hasCaptured) {
      return;
    }

    _hasCaptured = true;
    _isCapturing = true;

    try {
      CameraImage? capturedFrame;
      
      // Start image stream and capture first frame
      await _controller!.startImageStream((CameraImage image) {
        if (!_isCapturing || capturedFrame != null) {
          _controller!.stopImageStream();
          return;
        }
        capturedFrame = image;
        _controller!.stopImageStream();
        _saveFrameAsImage(capturedFrame!);
      });

      // Wait briefly for frame capture (reduced delay for faster capture)
      await Future.delayed(const Duration(milliseconds: 100));
      
      // If stream didn't capture, fallback to takePicture
      if (capturedFrame == null) {
        _controller!.stopImageStream();
        await _fallbackCapture();
      }
    } catch (e) {
      print('Stream capture error: $e');
      try {
        await _fallbackCapture();
      } catch (e2) {
        if (mounted) {
          Navigator.pop(context);
        }
      }
    }
  }

  Future<void> _saveFrameAsImage(CameraImage cameraImage) async {
    try {
      final img.Image? image = _convertCameraImage(cameraImage);
      if (image == null) {
        await _fallbackCapture();
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/capture_${DateTime.now().millisecondsSinceEpoch}.jpg');
      final jpegBytes = img.encodeJpg(image, quality: 90); // Increased from 70% to 90% for better face detection
      await file.writeAsBytes(jpegBytes);

      if (mounted) {
        Navigator.pop(context, file);
      }
    } catch (e) {
      print('Save frame error: $e');
      await _fallbackCapture();
    }
  }

  img.Image? _convertCameraImage(CameraImage cameraImage) {
    try {
      if (cameraImage.format.group == ImageFormatGroup.yuv420) {
        return _convertYUV420(cameraImage);
      } else if (cameraImage.format.group == ImageFormatGroup.bgra8888) {
        return _convertBGRA8888(cameraImage);
      }
    } catch (e) {
      print('Image conversion error: $e');
    }
    return null;
  }

  img.Image _convertYUV420(CameraImage cameraImage) {
    final width = cameraImage.width;
    final height = cameraImage.height;
    final yBuffer = cameraImage.planes[0].bytes;
    final uBuffer = cameraImage.planes[1].bytes;
    final vBuffer = cameraImage.planes[2].bytes;
    final yRowStride = cameraImage.planes[0].bytesPerRow;
    final uvRowStride = cameraImage.planes[1].bytesPerRow;
    final uvPixelStride = cameraImage.planes[1].bytesPerPixel ?? 1;

    final image = img.Image(width: width, height: height);

    for (int y = 0; y < height; y++) {
      final yIndex = y * yRowStride;
      final uvIndex = (y ~/ 2) * uvRowStride;

      for (int x = 0; x < width; x++) {
        final yValue = yBuffer[yIndex + x];
        final uvX = (x ~/ 2) * uvPixelStride;
        final uValue = uBuffer[uvIndex + uvX];
        final vValue = vBuffer[uvIndex + uvX];

        final r = ((yValue + 1.402 * (vValue - 128)).clamp(0, 255).toInt());
        final g = ((yValue - 0.344 * (uValue - 128) - 0.714 * (vValue - 128)).clamp(0, 255).toInt());
        final b = ((yValue + 1.772 * (uValue - 128)).clamp(0, 255).toInt());

        image.setPixel(x, y, img.ColorRgb8(r, g, b));
      }
    }

    return image;
  }

  img.Image _convertBGRA8888(CameraImage cameraImage) {
    final width = cameraImage.width;
    final height = cameraImage.height;
    final buffer = cameraImage.planes[0].bytes;
    final image = img.Image(width: width, height: height);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final offset = (y * width + x) * 4;
        final b = buffer[offset];
        final g = buffer[offset + 1];
        final r = buffer[offset + 2];
        final a = buffer[offset + 3];
        image.setPixel(x, y, img.ColorRgba8(r, g, b, a));
      }
    }

    return image;
  }

  Future<void> _fallbackCapture() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      if (mounted) {
        Navigator.pop(context);
      }
      return;
    }

    try {
      final XFile image = await _controller!.takePicture();
      if (mounted) {
        Navigator.pop(context, File(image.path));
      }
    } catch (e) {
      print('Fallback capture error: $e');
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  void dispose() {
    _faceDetector?.close();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera preview
          if (_controller != null && _controller!.value.isInitialized)
            Center(
              child: AspectRatio(
                aspectRatio: 1.0,
                child: ClipOval(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _controller!.value.previewSize!.height,
                      height: _controller!.value.previewSize!.width,
                      child: CameraPreview(_controller!),
                    ),
                  ),
                ),
              ),
            ),
          
          // Face detection circle overlay
          if (_controller != null && _controller!.value.isInitialized)
            Center(
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.3),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Container(
                  margin: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.blue.withOpacity(0.8),
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
          
          // Instructions text
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Position your face in the circle',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Capturing automatically...',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Corner guides for better face positioning
          if (_controller != null && _controller!.value.isInitialized)
            ...List.generate(4, (index) {
              final positions = [
                const Alignment(-0.6, -0.6), // Top-left
                const Alignment(0.6, -0.6),  // Top-right
                const Alignment(-0.6, 0.6),  // Bottom-left
                const Alignment(0.6, 0.6),   // Bottom-right
              ];
              
              return Positioned(
                top: positions[index].y < 0 ? 100 : null,
                bottom: positions[index].y > 0 ? 100 : null,
                left: positions[index].x < 0 ? 20 : null,
                right: positions[index].x > 0 ? 20 : null,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.white.withOpacity(0.8),
                        width: 3,
                      ),
                      right: BorderSide(
                        color: positions[index].x < 0 
                            ? Colors.transparent 
                            : Colors.white.withOpacity(0.8),
                        width: 3,
                      ),
                      left: BorderSide(
                        color: positions[index].x < 0 
                            ? Colors.white.withOpacity(0.8) 
                            : Colors.transparent,
                        width: 3,
                      ),
                      top: BorderSide(
                        color: positions[index].y < 0 
                            ? Colors.transparent 
                            : Colors.white.withOpacity(0.8),
                        width: 3,
                      ),
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}