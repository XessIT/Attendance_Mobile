import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
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
  const FaceAttendanceScreen({super.key});

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
    setState(() {
      _status = 'Ready to capture face for attendance';
    });
    _checkLocationStatus();
    _initializeCamera();
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
            _cachedLocation = location; // Cache location for later use
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

    // Always use direct camera capture - get cameras if not already loaded
    if (_cameras == null || _cameras!.isEmpty) {
      try {
        _cameras = await availableCameras();
      } catch (e) {
        print('Error getting cameras: $e');
        setState(() {
          _isProcessing = false;
          _status = 'Camera not available';
        });
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
        await _processCapturedImage(result);
      } else {
        // User cancelled or error - reset silently
        setState(() {
          _isProcessing = false;
          _status = 'Ready to capture face for attendance';
        });
      }
    } else {
      setState(() {
        _isProcessing = false;
        _status = 'No camera available';
      });
    }
  }

  Future<void> _processCapturedImage(File imageFile) async {
    setState(() {
      _isProcessing = true;
      _capturedImage = imageFile;
      _status = 'Processing...';
    });

    try {
      // Compress image in background while showing status
      final compressedFile = _compressImage(imageFile);
      
      // Update status once compression starts
      setState(() {
        _status = 'Uploading and processing...';
      });

      // Wait for compression and immediately proceed to API call
      final finalImageFile = await compressedFile;
      
      // Mark attendance using the new API endpoint (no extra setState needed)
      await _markAttendanceWithImage(finalImageFile);
    } catch (e) {
      setState(() {
        _status = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
        _isProcessing = false;
      });
      
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
        imageQuality: 40, // Reduced from 50 to 40 for faster capture
      );

      if (image == null) {
        // User cancelled - silently reset without error
        setState(() {
          _isProcessing = false;
          _status = 'Ready to capture face for attendance';
        });
        return;
      }

      File imageFile = File(image.path);

      setState(() {
        _capturedImage = imageFile;
        _status = 'Processing...';
      });

      // Compress image for faster upload
      imageFile = await _compressImage(imageFile);

      setState(() {
        _capturedImage = imageFile;
        _status = 'Uploading and processing...';
      });

      // Mark attendance using the new API endpoint
      await _markAttendanceWithImage(imageFile);
    } catch (e) {
      setState(() {
        _status = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
        _isProcessing = false;
      });
      
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

    setState(() {
      _isProcessing = true;
      _status = 'Selecting image...';
    });

    try {
      // Pick image from gallery with lower quality for faster upload
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 40, // Reduced from 50 to 40 for faster upload
      );

      if (image == null) {
        // User cancelled - silently reset without error
        setState(() {
          _isProcessing = false;
          _status = 'Ready to capture face for attendance';
        });
        return;
      }

      File imageFile = File(image.path);

      setState(() {
        _capturedImage = imageFile;
        _status = 'Processing...';
      });

      // Compress image for faster upload
      imageFile = await _compressImage(imageFile);

      setState(() {
        _capturedImage = imageFile;
        _status = 'Uploading and processing...';
      });

      // Mark attendance using the new API endpoint
      await _markAttendanceWithImage(imageFile);
    } catch (e) {
      setState(() {
        _status = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
        _isProcessing = false;
      });
      
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

  Future<File> _compressImage(File imageFile) async {
    try {
      // Check file size first - skip compression if already small (< 200KB)
      final fileSize = await imageFile.length();
      if (fileSize < 200 * 1024) {
        return imageFile; // File is already small enough, skip compression
      }

      // Read image bytes
      final Uint8List imageBytes = await imageFile.readAsBytes();
      
      // Decode image
      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) {
        return imageFile; // Return original if decode fails
      }

      // Resize image if too large (reduced max width from 800px to 600px for faster upload)
      if (image.width > 600) {
        final ratio = 600 / image.width;
        image = img.copyResize(
          image,
          width: 600,
          height: (image.height * ratio).round(),
        );
      }

      // Compress image (reduced quality from 70% to 60% for faster upload)
      final compressedBytes = img.encodeJpg(image, quality: 60);

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
          _isProcessing = false;
        });

        // Show success snackbar instead of dialog (auto-dismisses)
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }

        // Refresh attendance list in the background (don't wait for it)
        Provider.of<AttendanceProvider>(context, listen: false).refresh().catchError((e) {
          // Silently handle refresh errors - attendance is already marked
          print('Background refresh error: $e');
        });
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

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.low, // Reduced from medium to low for faster capture
      enableAudio: false,
    );

    try {
      await _controller!.initialize();
      // Capture from stream to avoid preview screen
      if (mounted && !_hasCaptured) {
        _captureFromStream();
      }
    } catch (e) {
      print('Camera initialization error: $e');
      if (mounted) {
        Navigator.pop(context);
      }
    }
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
      final jpegBytes = img.encodeJpg(image, quality: 70); // Reduced from 85% to 70% for faster processing
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
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show completely black screen with no UI - capture happens instantly in background
    return const Scaffold(
      backgroundColor: Colors.black,
      body: SizedBox.expand(),
    );
  }
} 