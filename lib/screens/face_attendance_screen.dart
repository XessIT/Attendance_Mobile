import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import '../providers/attendance_provider.dart';
import '../services/api_service.dart';

class FaceAttendanceScreen extends StatefulWidget {
  const FaceAttendanceScreen({super.key});

  @override
  State<FaceAttendanceScreen> createState() => _FaceAttendanceScreenState();
}

class _FaceAttendanceScreenState extends State<FaceAttendanceScreen> {
  bool _isProcessing = false;
  String _status = 'Initializing...';
  String _locationStatus = 'Checking location...';
  File? _capturedImage;
  Map<String, double>? _cachedLocation;

  @override
  void initState() {
    super.initState();
    _checkLocationStatus();
  }

  Future<void> _checkLocationStatus() async {
    try {
      setState(() {
        _locationStatus = 'Getting location...';
      });

      // Try to get current location
      final position = await _getCurrentLocation();
      
      if (position != null) {
        _cachedLocation = {
          'latitude': position!.latitude,
          'longitude': position!.longitude,
        };
        setState(() {
          _locationStatus = 'Location: ${position!.latitude.toStringAsFixed(4)}, ${position!.longitude.toStringAsFixed(4)}';
        });
      } else {
        setState(() {
          _locationStatus = 'Location unavailable';
        });
      }
    } catch (e) {
      setState(() {
        _locationStatus = 'Location error: ${e.toString().replaceAll('Exception: ', '')}';
      });
    }
  }

  Future<dynamic> _getCurrentLocation() async {
    // This is a placeholder - you'll need to implement actual location services
    // For now, return null to simulate location unavailable
    await Future.delayed(const Duration(seconds: 1));
    return null;
  }

  Future<void> _requestLocationPermission() async {
    // This is a placeholder - implement actual permission request
    await _checkLocationStatus();
  }

  Future<void> _captureAndRecognize() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _status = 'Starting camera...';
    });

    try {
      // Get available cameras
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw Exception('No cameras available');
      }

      // Use front camera by default
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      // Navigate to camera capture screen
      if (mounted) {
        final result = await Navigator.push<File?>(
          context,
          MaterialPageRoute(
            builder: (context) => CameraCaptureScreen(camera: frontCamera),
          ),
        );

        if (result != null) {
          await _processCapturedImage(result!);
        }
      }
    } catch (e) {
      setState(() {
        _status = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
        _isProcessing = false;
      });
    }
  }

  Future<void> _processCapturedImage(File imageFile) async {
    setState(() {
      _status = 'Processing image...';
      _capturedImage = imageFile;
    });

    try {
      // Compress image for faster upload
      final compressedImage = await _compressImage(imageFile);
      
      // Mark attendance with the captured image
      await _markAttendanceWithImage(compressedImage);
    } catch (e) {
      setState(() {
        _status = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
        _isProcessing = false;
      });
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

  void _showGuideDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF152A4A).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.info_outline,
                color: Color(0xFF152A4A),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Quick Guide',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF152A4A),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...List.generate(4, (index) {
              final instructions = [
                {'icon': Icons.lightbulb_outline, 'text': 'Ensure good lighting'},
                {'icon': Icons.face, 'text': 'Look directly at camera'},
                {'icon': Icons.camera_enhance, 'text': 'Keep face clearly visible'},
                {'icon': Icons.check_circle_outline, 'text': 'System auto-recognizes & marks'},
              ];
              final item = instructions[index];
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    // Icon with subtle background
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFF152A4A).withOpacity(0.08),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF152A4A).withOpacity(0.15),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        item['icon'] as IconData,
                        color: const Color(0xFF152A4A),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    
                    // Instruction text
                    Expanded(
                      child: Text(
                        '${index + 1}. ${item['text']}',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Got it!',
              style: GoogleFonts.poppins(
                color: const Color(0xFF152A4A),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Face Attendance'),
        backgroundColor: const Color(0xFF152A4A),
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
      body: Stack(
        children: [
          // Main content
          Column(
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
                         _locationStatus.contains('error') || _locationStatus.contains('unavailable') ? Colors.orange[400] : Color(0x990F172A),
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
                    border: Border.all(color: const Color(0xFF152A4A), width: 3),
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
                                  'Face detection will start automatically',
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Position your face clearly in the camera view',
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
            ],
          ),

          // Help button - floating in corner
          Positioned(
            top: 20,
            right: 20,
            child: GestureDetector(
              onTap: _showGuideDialog,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.help_outline,
                  color: Color(0xFF152A4A),
                  size: 24,
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
      setState(() {}); // Rebuild to show camera preview
      
      // Wait 2 seconds to show the camera preview with face circle before auto-capturing
      await Future.delayed(const Duration(seconds: 2));
      
      // Capture from stream after showing preview
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
    try {
      final XFile? image = await _controller?.takePicture();
      if (image != null) {
        final file = File(image.path);
        if (mounted) {
          Navigator.pop(context, file);
        }
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
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera preview
          if (_controller != null && _controller!.value.isInitialized)
            Positioned.fill(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller!.value.previewSize!.height,
                  height: _controller!.value.previewSize!.width,
                  child: CameraPreview(_controller!),
                ),
              ),
            ),
          
          // Face guide circle
          if (_controller != null && _controller!.value.isInitialized)
            Center(
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 2,
                  ),
                ),
              ),
            ),
          
          // Instructions overlay
          if (_controller != null && _controller!.value.isInitialized)
            Positioned(
              top: 100,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Position face in circle',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
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

