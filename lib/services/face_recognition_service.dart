import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class FaceRecognitionService {
  // Local Python API endpoint
  static const String baseUrl = 'http://localhost:5000';
  
  // Health check endpoint
  static const String healthEndpoint = '/health';
  
  // Face registration endpoint
  static const String registerEndpoint = '/register-face';
  
  // Face recognition endpoint
  static const String recognizeEndpoint = '/recognize-face';
  
  // Get employee endpoint
  static const String getEmployeeEndpoint = '/get-employee';
  
  // List employees endpoint
  static const String listEmployeesEndpoint = '/list-employees';

  /// Check if the face recognition server is running
  static Future<bool> isServerRunning() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$healthEndpoint'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['status'] == 'healthy';
      }
      return false;
    } catch (e) {
      print('Server health check failed: $e');
      return false;
    }
  }

  /// Register a face for an employee
  static Future<Map<String, dynamic>> registerFace(int employeeId, File imageFile) async {
    try {
      // Check if server is running
      if (!await isServerRunning()) {
        return {
          'success': false,
          'error': 'Face recognition server is not running. Please start the Python server first.',
        };
      }

      // Create multipart request
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl$registerEndpoint'),
      );

      // Add employee ID
      request.fields['employee_id'] = employeeId.toString();

      // Add image file
      request.files.add(
        await http.MultipartFile.fromPath(
          'image',
          imageFile.path,
        ),
      );

      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'error': errorData['error'] ?? 'Registration failed',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  /// Recognize a face and return employee information
  static Future<Map<String, dynamic>> recognizeFace(File imageFile) async {
    try {
      // Check if server is running
      if (!await isServerRunning()) {
        return {
          'success': false,
          'error': 'Face recognition server is not running. Please start the Python server first.',
        };
      }

      // Create multipart request
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl$recognizeEndpoint'),
      );

      // Add image file
      request.files.add(
        await http.MultipartFile.fromPath(
          'image',
          imageFile.path,
        ),
      );

      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else if (response.statusCode == 404) {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'error': errorData['error'] ?? 'Face not recognized',
        };
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'error': errorData['error'] ?? 'Recognition failed',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  /// Get employee information by ID
  static Future<Map<String, dynamic>> getEmployee(int employeeId) async {
    try {
      // Check if server is running
      if (!await isServerRunning()) {
        return {
          'success': false,
          'error': 'Face recognition server is not running. Please start the Python server first.',
        };
      }

      final response = await http.get(
        Uri.parse('$baseUrl$getEmployeeEndpoint/$employeeId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else if (response.statusCode == 404) {
        return {
          'success': false,
          'error': 'Employee not found',
        };
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'error': errorData['error'] ?? 'Failed to get employee',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  /// List all employees with face registration status
  static Future<Map<String, dynamic>> listEmployees() async {
    try {
      // Check if server is running
      if (!await isServerRunning()) {
        return {
          'success': false,
          'error': 'Face recognition server is not running. Please start the Python server first.',
        };
      }

      final response = await http.get(
        Uri.parse('$baseUrl$listEmployeesEndpoint'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'error': errorData['error'] ?? 'Failed to list employees',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  /// Capture image from camera
  static Future<File?> captureImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 80,
      );

      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      print('Error capturing image: $e');
      return null;
    }
  }

  /// Pick image from gallery
  static Future<File?> pickImageFromGallery() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      print('Error picking image: $e');
      return null;
    }
  }

  /// Validate image file
  static bool isValidImageFile(File file) {
    final String extension = file.path.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png'].contains(extension);
  }

  /// Get file size in MB
  static double getFileSizeInMB(File file) {
    final int bytes = file.lengthSync();
    return bytes / (1024 * 1024);
  }

  /// Validate image for face recognition
  static String? validateImageForFaceRecognition(File imageFile) {
    // Check file format
    if (!isValidImageFile(imageFile)) {
      return 'Invalid file format. Please use JPG, JPEG, or PNG images.';
    }

    // Check file size (max 5MB)
    final double fileSize = getFileSizeInMB(imageFile);
    if (fileSize > 5.0) {
      return 'File size too large. Maximum size is 5MB.';
    }

    return null; // No validation errors
  }
} 