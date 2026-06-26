import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../models/employee.dart';
import '../models/attendance.dart';
import '../models/salary.dart';
import '../models/leave_balance.dart';
import '../utils/auth_utils.dart';
import 'location_service.dart';

class ApiService {
  // Face recognition and attendance API base URL
  static const String baseUrl = 'https://face.agniplay.com/api/';
  
  // User management and company registration API base URL
  static const String userBaseUrl = 'https://nodeface.agniplay.com/api/';

  // Dio instance for face recognition and attendance APIs
  static final Dio _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 60),
    receiveTimeout: const Duration(seconds: 60),
    sendTimeout: const Duration(seconds: 60),
    headers: {
      'Connection': 'keep-alive',
      'Accept': '*/*',
    },
  ));

  // Dio instance for user management APIs
  static final Dio _userDio = Dio(BaseOptions(
    baseUrl: userBaseUrl,
    connectTimeout: const Duration(seconds: 60),
    receiveTimeout: const Duration(seconds: 60),
    sendTimeout: const Duration(seconds: 60),
    headers: {
      'Connection': 'keep-alive',
      'Accept': '*/*',
    },
  ));

  // Employee APIs
  static Future<Map<String, dynamic>> getEmployees({
    int page = 1,
    int limit = 10,
    String? search,
    String? department,
    String? status,
    String? sort,
    String? order,
  }) async {
    try {
      print('========================================');
      print('GET EMPLOYEES API CALL (PAGINATED)');
      print('========================================');
      
      final queryParameters = {
        'page': page,
        'limit': limit,
        if (search != null && search.isNotEmpty) 'search': search,
        if (department != null && department.isNotEmpty) 'department': department,
        if (status != null && status.isNotEmpty) 'status': status,
        if (sort != null && sort.isNotEmpty) 'sort': sort,
        if (order != null && order.isNotEmpty) 'order': order,
      };

      print('URL: $userBaseUrl/employee');
      print('Parameters: $queryParameters');
      print('Method: GET');
      
      final headers = await _getAuthHeaders();
      
      print('📤 Sending request...');
      final response = await _userDio.get('/employee', queryParameters: queryParameters, options: Options(headers: headers));
      
      print('Response Status Code: ${response.statusCode}');
      print('Response Data Type: ${response.data.runtimeType}');
      
      if (response.statusCode == 200) {
        print('✅ Employees loaded successfully');
        
        List<dynamic> employeesList;
        Map<String, dynamic>? pagination;

        if (response.data is Map) {
          if (response.data['pagination'] != null) {
            // Enhanced format with pagination metadata
            employeesList = response.data['data'] ?? [];
            pagination = response.data['pagination'];
          } else if (response.data['employees'] is List) {
            employeesList = response.data['employees'];
          } else if (response.data['data'] is List) {
            employeesList = response.data['data'];
          } else {
             employeesList = [];
          }
        } else if (response.data is List) {
          employeesList = response.data;
        } else {
          print('❌ Unexpected response format');
          throw Exception('Unexpected response format');
        }
        
        print('📋 Found ${employeesList.length} employees');
        if (pagination != null) {
          print('📄 Page: ${pagination['currentPage']} of ${pagination['totalPages']}');
        }
        print('========================================');
        
        return {
          'employees': employeesList.map((json) {
            // Handle both direct employee objects and wrapped objects
            if (json is Map<String, dynamic>) {
              return Employee.fromJson(json);
            } else {
              // Fallback for unexpected format
              return Employee.fromJson({});
            }
          }).toList(),
          'pagination': pagination,
        };
      }
      
      print('❌ Failed with status code: ${response.statusCode}');
      print('========================================');
      throw Exception('Failed to load employees');
    } on DioException catch (e) {
      print('========================================');
      print('❌ DIO EXCEPTION OCCURRED - GET EMPLOYEES');
      print('========================================');
      
      if (e.response != null) {
        print('Response Status Code: ${e.response?.statusCode}');
        print('Response Data: ${e.response?.data}');
        
        final errorMessage = e.response?.data?['message'] ??
                           e.response?.data?['error'] ??
                           'Failed to load employees';
        
        print('Error Message: $errorMessage');
        print('========================================');
        throw Exception(errorMessage);
      } else {
        print('No response received from server');
        print('Error Type: ${e.type}');
        print('Error Message: ${e.message}');
        print('========================================');
        throw Exception('Network error: ${e.message}');
      }
    } catch (e) {
      print('========================================');
      print('❌ GENERAL EXCEPTION OCCURRED - GET EMPLOYEES');
      print('Error: $e');
      print('Error Type: ${e.runtimeType}');
      print('========================================');
      throw Exception('Error: $e');
    }
  }

  static Future<Employee> createEmployee(Employee employee, {XFile? imageFile, String? shiftName, String? departmentName, int? departmentId, String? password}) async {
    final fullUrl = '$baseUrl/register';
    
    // Generate employee_id (format: E001, E002, etc.)
    // Using last 3 digits of timestamp, padded with zeros
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final lastDigits = (timestamp % 1000).toString().padLeft(3, '0');
    final employeeId = 'E$lastDigits';
    
    print('========================================');
    print('EMPLOYEE REGISTRATION API CALL');
    print('========================================');
    print('📍 URL: $fullUrl');
    print('Method: POST');
    print('Content-Type: multipart/form-data');
    print('Employee Data:');
    print('  - name: ${employee.name}');
    print('  - employee_id: $employeeId');
    print('  - email: ${employee.email}');
    print('  - phone: ${employee.phone}');
    print('  - department: ${employee.position}');
    print('  - salary: ${employee.salary}');
      print('  - shift: ${shiftName ?? "Not specified"}');
      print('  - password: ${password != null && password.isNotEmpty ? password : "Not specified"}');
      print('  - image: ${imageFile?.path ?? "No image"}');
      print('----------------------------------------');
    
    int retryCount = 0;
    const maxRetries = 3;
    
    while (retryCount <= maxRetries) {
      try {
        if (retryCount > 0) {
          print('🔄 Retry attempt ${retryCount}/${maxRetries}...');
          await Future.delayed(Duration(seconds: retryCount * 2)); // Exponential backoff
        }
        
        // Create FormData for multipart/form-data request
        final Map<String, dynamic> formFields = {
          'name': employee.name,
          'employee_id': employeeId,
          'phone': employee.phone,
          'department': departmentName ?? employee.position, // Use departmentName if provided, fallback to position
          'salary': employee.salary.toString(),
          if (departmentId != null) 'department_id': departmentId.toString(),
        };
        
        // Only include email if it's provided
        if (employee.email != null && employee.email!.isNotEmpty) {
          formFields['email'] = employee.email!;
        }
        
        // Include date of joining if provided
        if (employee.dateOfJoining != null) {
          formFields['date_of_joining'] = employee.dateOfJoining!.toIso8601String().split('T')[0];
        }
        
        // Include date of birth if provided
        if (employee.dateOfBirth != null) {
          formFields['date_of_birth'] = employee.dateOfBirth!.toIso8601String().split('T')[0];
        }

        // Add shift if provided
        if (shiftName != null && shiftName.isNotEmpty) {
          formFields['shift'] = shiftName;
        }

        // Add password if provided (required field)
        if (password != null && password.isNotEmpty) {
          formFields['password'] = password;
          print('✅ Password added to formFields: $password');
        } else {
          print('⚠️ WARNING: Password is null or empty!');
        }
        
        print('📋 FormFields before creating FormData:');
        formFields.forEach((key, value) {
          if (key == 'password') {
            print('   $key: $value');
          } else {
            print('   $key: $value');
          }
        });
        
        final formData = FormData.fromMap(formFields);
        
        // Add image file if provided
        if (imageFile != null) {
          formData.files.add(MapEntry(
            'image',
            MultipartFile.fromBytes(
              await imageFile.readAsBytes(),
              filename: imageFile.name,
            ),
          ));
          print('✅ Image file added to form data');
        } else {
          print('⚠️ No image file provided or file does not exist');
        }
        
        final token = await AuthUtils.getToken();
        print('📤 Sending request...');
        print('🔗 Full Request URL: $fullUrl/register');
        if (token != null) {
          print('🔑 Authorization: Bearer ${token.substring(0, 20)}...');
        } else {
          print('⚠️ No auth token found');
        }
        
        // Create options with Authorization header
        final options = Options(
          headers: {
            if (token != null) 'Authorization': 'Bearer $token',
          },
        );
        
        final response = await _dio.post('/register', data: formData, options: options);
        
        print('📥 Response Status Code: ${response.statusCode}');
        print('📥 Response Headers: ${response.headers}');
        print('📥 Response Body: ${jsonEncode(response.data)}');
        print('========================================');
        
        if (response.statusCode == 201 || response.statusCode == 200) {
          // Check if API call was successful
          if (response.data['success'] == true) {
            print('✅ Employee created successfully!');
            
            // Extract IDs from response with safe type handling
            // response.data example: {"employee_id":"EMP-3","id":268,"message":"...","success":true}
            final dynamic rawId = response.data['id'] ?? response.data['employee_id'];
            int? id;
            if (rawId is int) {
              id = rawId;
            } else if (rawId != null) {
              id = int.tryParse(rawId.toString());
            }
            
            final String? empId = response.data['employee_id']?.toString();
            
            // If API returns full employee data in 'data' field, use it
            Map<String, dynamic>? employeeData = response.data['data'];
            
            // Create Employee object - use API response data if available, otherwise use original employee data
            final createdEmployee = Employee(
              id: id ?? (employeeData?['id'] is int ? employeeData!['id'] : int.tryParse(employeeData?['id']?.toString() ?? '')),
              employeeId: empId ?? employeeData?['employee_id']?.toString(),
              name: employeeData?['name'] ?? employee.name,
              email: employeeData?['email'] ?? employee.email,
              phone: employeeData?['phone'] ?? employee.phone,
              position: employeeData?['department'] ?? 
                       employeeData?['position'] ?? 
                       employee.position,
              salary: employeeData?['salary'] != null 
                  ? double.parse(employeeData!['salary'].toString()) 
                  : employee.salary,
              faceData: employeeData?['face_data'] ?? 
                       employeeData?['faceData'] ?? 
                       employee.faceData,
              createdAt: employeeData?['created_at'] != null
                  ? DateTime.parse(employeeData!['created_at'])
                  : DateTime.now(),
              isActive: employeeData?['is_active'] == 1 || 
                       employeeData?['is_active'] == true || 
                       employeeData?['isActive'] == true || 
                       employee.isActive,
              payloan: employeeData?['payloan'] != null
                  ? double.parse(employeeData!['payloan'].toString())
                  : employee.payloan,
              shiftId: employeeData?['shift_id'] is int ? employeeData!['shift_id'] : int.tryParse(employeeData?['shift_id']?.toString() ?? ''),
              departmentId: employeeData?['department_id'] is int ? employeeData!['department_id'] : int.tryParse(employeeData?['department_id']?.toString() ?? ''),
            );
            
            print('📋 Created Employee Details:');
            print('   ID: ${createdEmployee.id}');
            print('   Name: ${createdEmployee.name}');
            print('   Email: ${createdEmployee.email}');
            print('   Payloan: ${createdEmployee.payloan}');
            
            return createdEmployee;
          } else {
            print('❌ Response indicates failure: ${response.data['message'] ?? 'Unknown error'}');
            throw Exception(response.data['message'] ?? 'Failed to create employee');
          }
        }
        print('❌ Unexpected status code: ${response.statusCode}');
        throw Exception('Failed to create employee: Status ${response.statusCode}');
      } on DioException catch (e) {
        print('========================================');
        print('❌ DIO EXCEPTION OCCURRED');
        print('========================================');
        print('Error Type: ${e.type}');
        print('Error Message: ${e.message}');
        
        // Check if this is a connection-related error that can be retried
        final isConnectionError = e.type == DioExceptionType.connectionTimeout ||
                                 e.type == DioExceptionType.sendTimeout ||
                                 e.type == DioExceptionType.receiveTimeout ||
                                 e.type == DioExceptionType.connectionError ||
                                 e.message?.contains('Broken pipe') == true ||
                                 e.message?.contains('Connection reset') == true;
        
        if (isConnectionError && retryCount < maxRetries) {
          retryCount++;
          print('🔄 Connection error detected, retrying... (Attempt $retryCount/$maxRetries)');
          continue;
        }
        
        if (e.response != null) {
          print('Response Status Code: ${e.response?.statusCode}');
          print('Response Headers: ${e.response?.headers}');
          print('Response Data: ${jsonEncode(e.response?.data)}');
          
          final errorMessage = e.response?.data['error'] ?? 
                              e.response?.data['message'] ?? 
                              e.response?.data.toString() ??
                              'Failed to create employee';
          print('Extracted Error Message: $errorMessage');
          print('========================================');
          throw Exception(errorMessage);
        } else {
          print('No response received from server');
          print('Request Options: ${e.requestOptions.uri}');
          print('Request Data Type: ${e.requestOptions.data.runtimeType}');
          print('========================================');
          
          if (isConnectionError) {
            throw Exception('Network connection error: ${e.message}. Please check your internet connection and try again.');
          } else {
            throw Exception('Network error: ${e.message}');
          }
        }
      } catch (e, stackTrace) {
        if (retryCount < maxRetries && e.toString().contains('Broken pipe')) {
          retryCount++;
          print('🔄 Broken pipe error detected, retrying... (Attempt $retryCount/$maxRetries)');
          continue;
        }
        
        print('========================================');
        print('❌ GENERAL EXCEPTION OCCURRED');
        print('========================================');
        print('Error: $e');
        print('Stack Trace: $stackTrace');
        print('========================================');
        throw Exception('Error creating employee: $e');
      }
    }
    
    throw Exception('Failed to create employee after $maxRetries attempts');
  }

  static Future<Employee> updateEmployee(Employee employee) async {
    try {
      print('========================================');
      print('UPDATE EMPLOYEE API CALL');
      print('========================================');
      print('URL: $userBaseUrl/employee/${employee.id}');
      print('Method: PUT');
      print('Content-Type: application/json');
      
      final token = await AuthUtils.getToken();
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final storedCompanyId = prefs.getInt('company_id');
      if (token != null) {
        print('🔑 Authorization: Bearer ${token.substring(0, 20)}...');
      } else {
        print('⚠️ No auth token found');
      }
      
      // Use employee's companyId if available, otherwise use stored companyId
      final companyId = employee.companyId ?? storedCompanyId ?? 1;
      
      print('📋 Employee Company ID: ${employee.companyId}');
      print('📋 Stored Company ID: $storedCompanyId');
      print('📋 Using Company ID: $companyId');
      
      // Prepare request data according to API format
      final requestData = {
        'name': employee.name,
        'employee_id': 'EMP${employee.id?.toString().padLeft(3, '0')}', // Format as EMP001, EMP002, etc.
        'email': employee.email,
        'phone': employee.phone,
        'department': employee.position,
        'salary': employee.salary,
        'shift': employee.shiftName ?? 'Day Shift', // Default shift if not provided
        'company_id': companyId,
        'is_active': employee.isActive ? 1 : 0,
        'department_id': employee.departmentId,
      };
      
      print('Request Data: $requestData');
      print('📤 Sending request...');
      
      // Create options with Authorization header
      final options = Options(
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      
      final response = await _userDio.put(
        '/employee/${employee.id}',
        data: requestData,
        options: options,
      );
      
      print('Response Status Code: ${response.statusCode}');
      print('Response Data: ${response.data}');
      print('========================================');
      
      if (response.statusCode == 200) {
        print('✅ Employee updated successfully');
        
        // Handle different response formats
        if (response.data is Map) {
          if (response.data['data'] != null) {
            return Employee.fromJson(response.data['data']);
          } else if (response.data['employee'] != null) {
            return Employee.fromJson(response.data['employee']);
          } else {
            // Return the updated employee with the response data merged
            return employee.copyWith(
              name: response.data['name'] ?? employee.name,
              email: response.data['email'] ?? employee.email,
              phone: response.data['phone'] ?? employee.phone,
              position: response.data['department'] ?? employee.position,
              salary: response.data['salary'] != null 
                  ? double.parse(response.data['salary'].toString()) 
                  : employee.salary,
              isActive: response.data['is_active'] == 1 || response.data['is_active'] == true,
              companyId: response.data['company_id'] ?? companyId,
            );
          }
        }
        
        // If no data in response, return the original employee
        return employee;
      }
      
      print('❌ Failed with status code: ${response.statusCode}');
      print('========================================');
      throw Exception('Failed to update employee');
    } on DioException catch (e) {
      print('========================================');
      print('❌ DIO EXCEPTION OCCURRED - UPDATE EMPLOYEE');
      print('========================================');
      
      if (e.response != null) {
        print('Response Status Code: ${e.response?.statusCode}');
        print('Response Data: ${e.response?.data}');
        
        final errorMessage = e.response?.data?['message'] ??
                           e.response?.data?['error'] ??
                           'Failed to update employee';
        
        print('Error Message: $errorMessage');
        print('========================================');
        throw Exception(errorMessage);
      } else {
        print('No response received from server');
        print('Error Type: ${e.type}');
        print('Error Message: ${e.message}');
        print('========================================');
        throw Exception('Network error: ${e.message}');
      }
    } catch (e) {
      print('========================================');
      print('❌ GENERAL EXCEPTION OCCURRED - UPDATE EMPLOYEE');
      print('Error: $e');
      print('Error Type: ${e.runtimeType}');
      print('========================================');
      throw Exception('Error: $e');
    }
  }

  static Future<bool> deleteEmployee(int id) async {
    try {
      final response = await _dio.delete('/employees.php', data: {'id': id});
      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // Activate employee
  static Future<Employee> activateEmployee(int employeeId) async {
    try {
      print('========================================');
      print('ACTIVATE EMPLOYEE API CALL');
      print('========================================');
      print('URL: $userBaseUrl/employee/$employeeId/activate');
      print('Method: PATCH');
      
      final token = await AuthUtils.getToken();
      if (token != null) {
        print('🔑 Authorization: Bearer ${token.substring(0, 20)}...');
      } else {
        print('⚠️ No auth token found');
      }
      
      print('📤 Sending request...');
      
      final options = Options(
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      
      final response = await _userDio.patch(
        '/employee/$employeeId/activate',
        options: options,
      );
      
      print('Response Status Code: ${response.statusCode}');
      print('Response Data: ${response.data}');
      print('========================================');
      
      if (response.statusCode == 200) {
        print('✅ Employee activated successfully');
        
        // Handle different response formats
        if (response.data is Map) {
          if (response.data['data'] != null) {
            return Employee.fromJson(response.data['data']);
          } else if (response.data['employee'] != null) {
            return Employee.fromJson(response.data['employee']);
          }
        }
        
        throw Exception('Invalid response format');
      }
      
      print('❌ Failed with status code: ${response.statusCode}');
      print('========================================');
      throw Exception('Failed to activate employee');
    } on DioException catch (e) {
      print('========================================');
      print('❌ DIO EXCEPTION OCCURRED - ACTIVATE EMPLOYEE');
      print('========================================');
      
      if (e.response != null) {
        print('Response Status Code: ${e.response?.statusCode}');
        print('Response Data: ${e.response?.data}');
        
        final errorMessage = e.response?.data?['message'] ??
                           e.response?.data?['error'] ??
                           'Failed to activate employee';
        
        print('Error Message: $errorMessage');
        print('========================================');
        throw Exception(errorMessage);
      } else {
        print('No response received from server');
        print('Error Type: ${e.type}');
        print('Error Message: ${e.message}');
        print('========================================');
        throw Exception('Network error: ${e.message}');
      }
    } catch (e) {
      print('========================================');
      print('❌ GENERAL EXCEPTION OCCURRED - ACTIVATE EMPLOYEE');
      print('Error: $e');
      print('Error Type: ${e.runtimeType}');
      print('========================================');
      throw Exception('Error: $e');
    }
  }

  // Deactivate employee
  static Future<Employee> deactivateEmployee(int employeeId) async {
    try {
      print('========================================');
      print('DEACTIVATE EMPLOYEE API CALL');
      print('========================================');
      print('URL: $userBaseUrl/employee/$employeeId/deactivate');
      print('Method: PATCH');
      
      final token = await AuthUtils.getToken();
      if (token != null) {
        print('🔑 Authorization: Bearer ${token.substring(0, 20)}...');
      } else {
        print('⚠️ No auth token found');
      }
      
      print('📤 Sending request...');
      
      final options = Options(
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      
      final response = await _userDio.patch(
        '/employee/$employeeId/deactivate',
        options: options,
      );
      
      print('Response Status Code: ${response.statusCode}');
      print('Response Data: ${response.data}');
      print('========================================');
      
      if (response.statusCode == 200) {
        print('✅ Employee deactivated successfully');
        
        // Handle different response formats
        if (response.data is Map) {
          if (response.data['data'] != null) {
            return Employee.fromJson(response.data['data']);
          } else if (response.data['employee'] != null) {
            return Employee.fromJson(response.data['employee']);
          }
        }
        
        throw Exception('Invalid response format');
      }
      
      print('❌ Failed with status code: ${response.statusCode}');
      print('========================================');
      throw Exception('Failed to deactivate employee');
    } on DioException catch (e) {
      print('========================================');
      print('❌ DIO EXCEPTION OCCURRED - DEACTIVATE EMPLOYEE');
      print('========================================');
      
      if (e.response != null) {
        print('Response Status Code: ${e.response?.statusCode}');
        print('Response Data: ${e.response?.data}');
        
        final errorMessage = e.response?.data?['message'] ??
                           e.response?.data?['error'] ??
                           'Failed to deactivate employee';
        
        print('Error Message: $errorMessage');
        print('========================================');
        throw Exception(errorMessage);
      } else {
        print('No response received from server');
        print('Error Type: ${e.type}');
        print('Error Message: ${e.message}');
        print('========================================');
        throw Exception('Network error: ${e.message}');
      }
    } catch (e) {
      print('========================================');
      print('❌ GENERAL EXCEPTION OCCURRED - DEACTIVATE EMPLOYEE');
      print('Error: $e');
      print('Error Type: ${e.runtimeType}');
      print('========================================');
      throw Exception('Error: $e');
    }
  }

  // Face Recognition APIs
  static Future<Map<String, dynamic>> registerFace(int employeeId, File imageFile) async {
    try {
      final formData = FormData.fromMap({
        'employee_id': employeeId,
        'face_image': await MultipartFile.fromFile(imageFile.path),
      });

      final response = await _dio.post('/face_register.php', data: formData);
      if (response.statusCode == 200) {
        return response.data;
      }
      throw Exception('Failed to register face');
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  static Future<Map<String, dynamic>> recognizeFace(File imageFile) async {
    try {
      final formData = FormData.fromMap({
        'face_image': await MultipartFile.fromFile(imageFile.path),
      });

      final response = await _dio.post('/face_recognize.php', data: formData);
      if (response.statusCode == 200) {
        return response.data;
      }
      throw Exception('Failed to recognize face');
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // Attendance APIs
  static Future<List<Attendance>> getAttendance({
    int? employeeId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final Map<String, dynamic> params = {};
      if (employeeId != null) params['employee_id'] = employeeId;
      if (startDate != null) params['start_date'] = startDate.toIso8601String().split('T')[0];
      if (endDate != null) params['end_date'] = endDate.toIso8601String().split('T')[0];

      final response = await _dio.get('/attendance.php', queryParameters: params);
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['data'];
        return data.map((json) => Attendance.fromJson(json)).toList();
      }
      throw Exception('Failed to load attendance');
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  static Future<Attendance> markAttendance(Attendance attendance) async {
    try {
      final response = await _dio.post('/attendance.php', data: attendance.toJson());
      if (response.statusCode == 201) {
        return Attendance.fromJson(response.data['data']);
      }
      throw Exception('Failed to mark attendance');
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  static Future<Attendance> updateAttendance(Attendance attendance) async {
    try {
      final response = await _dio.put('/attendance.php', data: attendance.toJson());
      if (response.statusCode == 200) {
        return Attendance.fromJson(response.data['data']);
      }
      throw Exception('Failed to update attendance');
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // Salary APIs
  static Future<List<Salary>> getSalaries({
    int? employeeId,
    int? month,
    int? year,
  }) async {
    try {
      final Map<String, dynamic> params = {};
      if (employeeId != null) params['employee_id'] = employeeId;
      if (month != null) params['month'] = month;
      if (year != null) params['year'] = year;

      final response = await _dio.get('/salary.php', queryParameters: params);
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['data'];
        return data.map((json) => Salary.fromJson(json)).toList();
      }
      throw Exception('Failed to load salaries');
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  static Future<Salary> calculateSalary(Salary salary) async {
    try {
      final response = await _dio.post('/salary.php', data: salary.toJson());
      if (response.statusCode == 201) {
        return Salary.fromJson(response.data['data']);
      }
      throw Exception('Failed to calculate salary');
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  static Future<bool> markSalaryPaid(int salaryId) async {
    try {
      final response = await _dio.put('/salary.php', data: {
        'id': salaryId,
        'is_paid': 1,
        'paid_date': DateTime.now().toIso8601String(),
      });
      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // Calculate all salaries API
  static Future<Map<String, dynamic>> calculateAllSalaries({
    required String startDate,
    required String endDate,
  }) async {
    try {
      print('========================================');
      print('CALCULATE ALL SALARIES API CALL');
      print('========================================');
      print('URL: $userBaseUrl/employee/salary/calculate-all');
      print('Method: POST');
      print('Content-Type: application/json');
      print('Request Body:');
      print('  - start_date: $startDate');
      print('  - end_date: $endDate');
      print('----------------------------------------');
      
      final headers = await _getAuthHeaders();
      
      print('📤 Sending request...');
      final response = await _userDio.post(
        '/employee/salary/calculate-all',
        data: {
          'start_date': startDate,
          'end_date': endDate,
        },
        options: Options(headers: headers),
      );
      
      print('Response Status Code: ${response.statusCode}');
      print('Response Data: ${response.data}');
      print('========================================');
      
      if (response.statusCode == 200) {
        print('✅ Salaries calculated successfully');
        return Map<String, dynamic>.from(response.data);
      }
      
      print('❌ Failed with status code: ${response.statusCode}');
      print('========================================');
      throw Exception('Failed to calculate salaries');
    } on DioException catch (e) {
      print('========================================');
      print('❌ DIO EXCEPTION OCCURRED - CALCULATE ALL SALARIES');
      print('========================================');
      
      if (e.response != null) {
        print('Response Status Code: ${e.response?.statusCode}');
        print('Response Data: ${e.response?.data}');
        
        final errorMessage = e.response?.data?['message'] ??
                           e.response?.data?['error'] ??
                           'Failed to calculate salaries';
        
        print('Error Message: $errorMessage');
        print('========================================');
        throw Exception(errorMessage);
      } else {
        print('No response received from server');
        print('Error Type: ${e.type}');
        print('Error Message: ${e.message}');
        print('========================================');
        throw Exception('Network error: ${e.message}');
      }
    } catch (e) {
      print('========================================');
      print('❌ GENERAL EXCEPTION OCCURRED - CALCULATE ALL SALARIES');
      print('Error: $e');
      print('Error Type: ${e.runtimeType}');
      print('========================================');
      throw Exception('Error: $e');
    }
  }

  // Dashboard APIs
  static Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      final response = await _dio.get('/dashboard.php');
      if (response.statusCode == 200) {
        return response.data;
      }
      throw Exception('Failed to load dashboard stats');
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // Attendance Summary API
  static Future<Map<String, dynamic>> fetchAttendanceSummary({
    required String startDate,
    required String endDate,
  }) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await _userDio.get(
        '/reports/attendance-summary',
        queryParameters: {'startDate': startDate, 'endDate': endDate},
        options: Options(headers: headers),
      );
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(response.data);
      } else {
        throw Exception('Failed to fetch attendance summary');
      }
    } on DioException catch (e) {
      if (e.response != null) {
        final errorMessage = e.response?.data?['message'] ?? e.response?.data?['error'] ?? 'Failed to fetch summary';
        throw Exception(errorMessage);
      } else {
        throw Exception('Network error: ${e.message}');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // Employee Full Report API
  static Future<Map<String, dynamic>> fetchEmployeeFullReport({
    required String startDate,
    required String endDate,
    int? employeeId,
  }) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await _userDio.get(
        '/reports/employee-full-report',
        queryParameters: {
          'startDate': startDate, 
          'endDate': endDate,
          if (employeeId != null) 'employeeId': employeeId,
        },
        options: Options(headers: headers),
      );
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(response.data);
      } else {
        throw Exception('Failed to fetch employee full report');
      }
    } on DioException catch (e) {
      if (e.response != null) {
        final errorMessage = e.response?.data?['message'] ?? e.response?.data?['error'] ?? 'Failed to fetch report';
        throw Exception(errorMessage);
      } else {
        throw Exception('Network error: ${e.message}');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // Mark attendance with face image, authorization token, and location
/*  static Future<Map<String, dynamic>> markAttendanceWithImage(
    File imageFile, {
    Map<String, double>? cachedLocation,
  }) async {
    final fullUrl = '${baseUrl}mark_attendance';
    
    print('========================================');
    print('MARK ATTENDANCE API CALL');
    print('========================================');
    print('URL: $fullUrl');
    print('Method: POST');
    print('Content-Type: multipart/form-data');
    print('Image Path: ${imageFile.path}');
    print('----------------------------------------');
    
    try {
      final token = await AuthUtils.getToken();
      if (token != null) {
        print('🔑 Authorization: Bearer ${token.substring(0, 20)}...');
      } else {
        print('⚠️ No auth token found');
      }
      
      // Use cached location if available, otherwise try to get current location (with timeout)
      Map<String, double>? location = cachedLocation;
      
      if (location == null) {
        // Only fetch location if not cached (with shorter timeout)
        try {
          location = await LocationService.getCurrentLocation().timeout(
            const Duration(seconds: 3),
            onTimeout: () {
              print('⚠️ Location fetch timeout, proceeding without location');
              return null;
            },
          );
        } catch (e) {
          print('⚠️ Location fetch error: $e');
          location = null;
        }
      } else {
        print('📍 Using cached location: Lat=${location['latitude']}, Lon=${location['longitude']}');
      }
      
      if (location != null) {
        print('📍 Location obtained: Lat=${location['latitude']}, Lon=${location['longitude']}');
      } else {
        print('⚠️ Could not obtain location');
      }
      
      // Create FormData for multipart/form-data request
      final Map<String, dynamic> formFields = {
        'image': await MultipartFile.fromFile(
          imageFile.path,
          filename: imageFile.path.split('/').last,
        ),
      };
      
      // Add location data if available
      if (location != null) {
        formFields['latitude'] = location['latitude'].toString();
        formFields['longitude'] = location['longitude'].toString();
      }
      
      final formData = FormData.fromMap(formFields);
      
      print('📤 Sending attendance request...');
      
      // Create options with Authorization header
      final options = Options(
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      
      final response = await _dio.post('mark_attendance', data: formData, options: options);
      
      print('Status Code: ${response.statusCode}');
      print('Response Headers: ${response.headers}');
      print('Response Body: ${jsonEncode(response.data)}');
      print('========================================');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (response.data['success'] == true) {
          print('✅ Attendance marked successfully!');
          return response.data;
        } else {
          print('❌ Response indicates failure: ${response.data['message'] ?? 'Unknown error'}');
          throw Exception(response.data['message'] ?? 'Failed to mark attendance');
        }
      }
      print('❌ Unexpected status code: ${response.statusCode}');
      throw Exception('Failed to mark attendance: Status ${response.statusCode}');
    } on DioException catch (e) {
      print('========================================');
      print('❌ DIO EXCEPTION OCCURRED');
      print('========================================');
      print('Error Type: ${e.type}');
      print('Error Message: ${e.message}');
      
      if (e.response != null) {
        print('Response Status Code: ${e.response?.statusCode}');
        print('Response Headers: ${e.response?.headers}');
        print('Response Data: ${jsonEncode(e.response?.data)}');
        
        final errorMessage = e.response?.data['error'] ?? 
                            e.response?.data['message'] ?? 
                            e.response?.data.toString() ??
                            'Failed to mark attendance';
        print('Extracted Error Message: $errorMessage');
        print('========================================');
        throw Exception(errorMessage);
      } else {
        print('No response received from server');
        print('Request Options: ${e.requestOptions.uri}');
        print('========================================');
        throw Exception('Network error: ${e.message}');
      }
    } catch (e, stackTrace) {
      print('========================================');
      print('❌ GENERAL EXCEPTION OCCURRED');
      print('========================================');
      print('Error: $e');
      print('Stack Trace: $stackTrace');
      print('========================================');
      throw Exception('Error marking attendance: $e');
    }
  }*/

  static Future<Map<String, dynamic>> markAttendanceWithImage(
      File imageFile, {
        Map<String, double>? cachedLocation,
      }) async {

    print('\n================ ATTENDANCE API ================');
    print('📌 API: POST /mark_attendance');
    print('🖼 Image: ${imageFile.path}');
    print('================================================\n');

    int retryCount = 0;
    const maxRetries = 2;

    while (retryCount <= maxRetries) {
      try {
        if (retryCount > 0) {
          print('🔄 Retry attempt ${retryCount}/${maxRetries}...');
          await Future.delayed(Duration(seconds: retryCount * 2));
        }

        final token = await AuthUtils.getToken();
        print(token != null
            ? '🔑 Token Found'
            : '⚠️ Token NOT Found');

        // Location
        Map<String, double>? location = cachedLocation;

        if (location == null) {
          try {
            location = await LocationService.getCurrentLocation().timeout(
              const Duration(seconds: 3),
              onTimeout: () {
                print('⚠️ Location timeout');
                return null;
              },
            );
          } catch (e) {
            print('⚠️ Location error: $e');
          }
        }

        if (location != null) {
          print('📍 Location: ${location['latitude']}, ${location['longitude']}');
        } else {
          print('⚠️ Location not available');
        }

        final formData = FormData.fromMap({
          'image': await MultipartFile.fromFile(
            imageFile.path,
            filename: imageFile.path.split('/').last,
          ),
          if (location != null) 'latitude': location['latitude'].toString(),
          if (location != null) 'longitude': location['longitude'].toString(),
        });

        print('📤 Sending request...');

        final response = await _dio.post(
          'mark_attendance',
          data: formData,
          options: Options(
            headers: {
              if (token != null) 'Authorization': 'Bearer $token',
            },
          ),
        );

        print('📥 Status Code: ${response.statusCode}');
        print('📥 Response: ${jsonEncode(response.data)}');

        if ((response.statusCode == 200 || response.statusCode == 201) &&
            response.data['success'] == true) {

          print('\n✅✅ ATTENDANCE SUCCESS ✅✅');
          print('🟢 Message: ${response.data['message'] ?? 'Attendance marked'}');
          print('===============================================\n');

          return response.data;
        } else {
          final msg = response.data['message'] ?? 'Attendance failed';

          print('\n❌❌ ATTENDANCE FAILED ❌❌');
          print('🔴 Message: $msg');
          print('===============================================\n');

          throw Exception(msg);
        }

      } on DioException catch (e) {
        final errorMsg =
            e.response?.data?['message'] ??
                e.response?.data?['error'] ??
                e.message ??
                'Network error';

        print('\n❌❌ DIO ERROR ❌❌');
        print('🔴 Status: ${e.response?.statusCode}');
        print('🔴 Message: $errorMsg');
        print('===============================================\n');

        // Check if this is a connection-related error that can be retried
        final isConnectionError = e.type == DioExceptionType.connectionTimeout ||
                                 e.type == DioExceptionType.sendTimeout ||
                                 e.type == DioExceptionType.receiveTimeout ||
                                 e.type == DioExceptionType.connectionError ||
                                 e.message?.contains('Broken pipe') == true ||
                                 e.message?.contains('Connection reset') == true ||
                                 e.response == null; // No response usually means connection issue

        if (isConnectionError && retryCount < maxRetries) {
          retryCount++;
          print('🔄 Connection error detected, retrying... (Attempt $retryCount/$maxRetries)');
          continue;
        }

        throw Exception(errorMsg);

      } catch (e) {
        if (retryCount < maxRetries && (e.toString().contains('Broken pipe') || e.toString().contains('Connection reset'))) {
          retryCount++;
          print('🔄 Connection error detected, retrying... (Attempt $retryCount/$maxRetries)');
          continue;
        }
        
        print('\n❌❌ GENERAL ERROR ❌❌');
        print('🔴 Error: $e');
        print('===============================================\n');

        throw Exception('Attendance error: $e');
      }
    }
    
    throw Exception('Failed to mark attendance after $maxRetries attempts due to network errors');
  }


  // User Registration API
  static Future<Map<String, dynamic>> registerUser({
    required String companyName,
    required String name,
    required String mobileNumber,
    required String address,
    required String username,
    required String password,
  }) async {
    try {
      print('========================================');
      print('USER REGISTRATION API CALL');
      print('========================================');

      final requestData = {
        'companyName': companyName,
        'name': name,
        'mobileNumber': mobileNumber,
        'address': address,
        'username': username,
        'password': password,
      };

      print('URL: $userBaseUrl/registration');
      print('Method: POST');
      print('Content-Type: application/json');
      print('Request Data: $requestData');

      final response = await _userDio.post(
        '/registration',
        data: requestData,
        options: Options(
          contentType: 'application/json',
        ),
      );

      print('Response Status Code: ${response.statusCode}');
      print('Response Data: ${response.data}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ User registration successful');
        print('========================================');
        return {
          'success': true,
          'data': response.data,
        };
      } else {
        print('❌ User registration failed with status: ${response.statusCode}');
        print('========================================');
        throw Exception('Registration failed: ${response.data}');
      }
    } on DioException catch (e) {
      print('========================================');
      print('❌ DIO EXCEPTION OCCURRED');
      print('========================================');

      if (e.response != null) {
        print('Response Status Code: ${e.response?.statusCode}');
        print('Response Data: ${e.response?.data}');

        final errorMessage = e.response?.data?['message'] ??
                           e.response?.data?['error'] ??
                           'Registration failed';

        print('Error Message: $errorMessage');
        print('========================================');
        throw Exception(errorMessage);
      } else {
        print('No response received from server');
        print('Request Options: ${e.requestOptions.uri}');
        print('========================================');
        throw Exception('Network error: ${e.message}');
      }
    } catch (e, stackTrace) {
      print('========================================');
      print('❌ GENERAL EXCEPTION OCCURRED');
      print('========================================');
      print('Error: $e');
      print('Stack Trace: $stackTrace');
      print('========================================');
      throw Exception('Error during registration: $e');
    }
  }

  // Check Mobile Number API
  static Future<Map<String, dynamic>> checkMobile({
    required String mobileNumber,
  }) async {
    try {
      print('========================================');
      print('CHECK MOBILE API CALL');
      print('========================================');

      final requestData = {
        'mobileNumber': mobileNumber,
      };

      print('URL: $userBaseUrl/check-mobile');
      print('Method: POST');
      print('Content-Type: application/json');
      print('Request Data: $requestData');

      final response = await _userDio.post(
        '/check-mobile',
        data: requestData,
        options: Options(
          contentType: 'application/json',
          validateStatus: (status) {
            // Accept both 200 and 404 as valid responses
            // API returns 404 when no companies found, but with success:true
            return status == 200 || status == 404;
          },
        ),
      );

      print('Response Status Code: ${response.statusCode}');
      print('Response Data: ${response.data}');

      if (response.statusCode == 200 || response.statusCode == 404) {
        print('✅ Mobile check successful');
        print('========================================');
        return {
          'success': true,
          'data': response.data,
        };
      } else {
        print('❌ Mobile check failed with status: ${response.statusCode}');
        print('========================================');
        throw Exception('Mobile check failed: ${response.data}');
      }
    } on DioException catch (e) {
      print('========================================');
      print('❌ DIO EXCEPTION OCCURRED - CHECK MOBILE');
      print('========================================');

      if (e.response != null) {
        print('Response Status Code: ${e.response?.statusCode}');
        print('Response Data: ${e.response?.data}');

        final errorMessage = e.response?.data?['message'] ??
                           e.response?.data?['error'] ??
                           'Mobile check failed';

        print('Error Message: $errorMessage');
        print('========================================');
        throw Exception(errorMessage);
      } else {
        print('No response received from server');
        print('Request Options: ${e.requestOptions.uri}');
        print('========================================');
        throw Exception('Network error: ${e.message}');
      }
    } catch (e, stackTrace) {
      print('========================================');
      print('❌ GENERAL EXCEPTION OCCURRED - CHECK MOBILE');
      print('========================================');
      print('Error: $e');
      print('Stack Trace: $stackTrace');
      print('========================================');
      throw Exception('Error during mobile check: $e');
    }
  }

  // User Login with Company API
  static Future<Map<String, dynamic>> loginUserWithCompany({
    required int companyId,
    required String mobileNumber,
    required String password,
  }) async {
    try {
      print('========================================');
      print('USER LOGIN WITH COMPANY API CALL');
      print('========================================');

      final requestData = {
        'company_id': companyId,
        'mobileNumber': mobileNumber,
        'password': password,
      };

      print('URL: $userBaseUrl/login-with-company');
      print('Method: POST');
      print('Content-Type: application/json');
      print('Request Data: $requestData');

      final response = await _userDio.post(
        '/login-with-company',
        data: requestData,
        options: Options(
          contentType: 'application/json',
        ),
      );

      print('Response Status Code: ${response.statusCode}');
      print('Response Data: ${response.data}');

      if (response.statusCode == 200) {
        print('✅ User login with company successful');
        print('========================================');

        // Try multiple possible token locations and keys
        String? token;

        // Check direct response.data level
        token ??= response.data['token'] ??
                  response.data['access_token'] ??
                  response.data['auth_token'] ??
                  response.data['jwt'] ??
                  response.data['bearer'];

        // Check nested in response.data.data level (API structure)
        if (token == null && response.data['data'] != null) {
          token = response.data['data']['token'] ??
                  response.data['data']['access_token'] ??
                  response.data['data']['auth_token'] ??
                  response.data['data']['jwt'] ??
                  response.data['data']['bearer'];
        }

        print('🔑 Token found in response: ${token != null ? "YES" : "NO"}');
        if (token != null) {
          print('🔑 Token value: ${token.substring(0, token.length > 20 ? 20 : token.length)}...');
        }

        return {
          'success': true,
          'token': token,
          'data': response.data,
        };
      } else {
        print('❌ User login with company failed with status: ${response.statusCode}');
        print('========================================');
        throw Exception('Login failed: ${response.data}');
      }
    } on DioException catch (e) {
      print('========================================');
      print('❌ DIO EXCEPTION OCCURRED');
      print('========================================');

      if (e.response != null) {
        print('Response Status Code: ${e.response?.statusCode}');
        print('Response Data: ${e.response?.data}');

        final errorMessage = e.response?.data?['message'] ??
                           e.response?.data?['error'] ??
                           'Login failed';

        print('Error Message: $errorMessage');
        print('========================================');
        throw Exception(errorMessage);
      } else {
        print('No response received from server');
        print('Request Options: ${e.requestOptions.uri}');
        print('========================================');
        throw Exception('Network error: ${e.message}');
      }
    } catch (e, stackTrace) {
      print('========================================');
      print('❌ GENERAL EXCEPTION OCCURRED');
      print('========================================');
      print('Error: $e');
      print('Stack Trace: $stackTrace');
      print('========================================');
      throw Exception('Error during login: $e');
    }
  }

  // User Login API
  static Future<Map<String, dynamic>> loginUser({
    required String mobileNumber,
    required String password,
  }) async {
    try {
      print('========================================');
      print('USER LOGIN API CALL');
      print('========================================');

      final requestData = {
        'mobileNumber': mobileNumber,
        'password': password,
      };

      print('URL: $userBaseUrl/login');
      print('Method: POST');
      print('Content-Type: application/json');
      print('Request Data: $requestData');

      final response = await _userDio.post(
        '/login',
        data: requestData,
        options: Options(
          contentType: 'application/json',
        ),
      );

      print('Response Status Code: ${response.statusCode}');
      print('Response Data: ${response.data}');

      if (response.statusCode == 200) {
        print('✅ User login successful');
        print('========================================');

        // Try multiple possible token locations and keys
        String? token;

        // Check direct response.data level
        token ??= response.data['token'] ??
                  response.data['access_token'] ??
                  response.data['auth_token'] ??
                  response.data['jwt'] ??
                  response.data['bearer'];

        // Check nested in response.data.data level (API structure)
        if (token == null && response.data['data'] != null) {
          token = response.data['data']['token'] ??
                  response.data['data']['access_token'] ??
                  response.data['data']['auth_token'] ??
                  response.data['data']['jwt'] ??
                  response.data['data']['bearer'];
        }

        print('🔑 Token found in response: ${token != null ? "YES" : "NO"}');
        if (token != null) {
          print('🔑 Token value: ${token.substring(0, token.length > 20 ? 20 : token.length)}...');
        }

        return {
          'success': true,
          'token': token,
          'data': response.data,
        };
      } else {
        print('❌ User login failed with status: ${response.statusCode}');
        print('========================================');
        throw Exception('Login failed: ${response.data}');
      }
    } on DioException catch (e) {
      print('========================================');
      print('❌ DIO EXCEPTION OCCURRED');
      print('========================================');

      if (e.response != null) {
        print('Response Status Code: ${e.response?.statusCode}');
        print('Response Data: ${e.response?.data}');

        final errorMessage = e.response?.data?['message'] ??
                           e.response?.data?['error'] ??
                           'Login failed';

        print('Error Message: $errorMessage');
        print('========================================');
        throw Exception(errorMessage);
      } else {
        print('No response received from server');
        print('Request Options: ${e.requestOptions.uri}');
        print('========================================');
        throw Exception('Network error: ${e.message}');
      }
    } catch (e, stackTrace) {
      print('========================================');
      print('❌ GENERAL EXCEPTION OCCURRED');
      print('========================================');
      print('Error: $e');
      print('Stack Trace: $stackTrace');
      print('========================================');
      throw Exception('Error during login: $e');
    }
  }

  // Update FCM Token API
  static Future<Map<String, dynamic>> updateFcmToken({
    required String fcmToken,
  }) async {
    try {
      print('========================================');
      print('UPDATE FCM TOKEN API CALL');
      print('========================================');

      final token = await AuthUtils.getToken();
      if (token == null) {
        print('⚠️ No auth token found - cannot update FCM token');
        throw Exception('Authentication required to update FCM token');
      }

      final requestData = {
        'fcmToken': fcmToken,
      };

      print('URL: $userBaseUrl/update-fcm-token');
      print('Method: POST');
      print('Content-Type: application/json');
      print('Authorization: Bearer ${token.substring(0, token.length > 20 ? 20 : token.length)}...');
      print('Request Data: $requestData');

      final response = await _userDio.post(
        '/update-fcm-token',
        data: requestData,
        options: Options(
          contentType: 'application/json',
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      print('Response Status Code: ${response.statusCode}');
      print('Response Data: ${response.data}');

      if (response.statusCode == 200) {
        print('✅ FCM token updated successfully');
        print('========================================');
        return {
          'success': true,
          'data': response.data,
        };
      } else {
        print('❌ FCM token update failed with status: ${response.statusCode}');
        print('========================================');
        throw Exception('FCM token update failed: ${response.data}');
      }
    } on DioException catch (e) {
      print('========================================');
      print('❌ DIO EXCEPTION OCCURRED - UPDATE FCM TOKEN');
      print('========================================');

      if (e.response != null) {
        print('Response Status Code: ${e.response?.statusCode}');
        print('Response Data: ${e.response?.data}');

        final errorMessage = e.response?.data?['message'] ??
                           e.response?.data?['error'] ??
                           'FCM token update failed';

        print('Error Message: $errorMessage');
        print('========================================');
        throw Exception(errorMessage);
      } else {
        print('No response received from server');
        print('Request Options: ${e.requestOptions.uri}');
        print('========================================');
        throw Exception('Network error: ${e.message}');
      }
    } catch (e, stackTrace) {
      print('========================================');
      print('❌ GENERAL EXCEPTION OCCURRED - UPDATE FCM TOKEN');
      print('========================================');
      print('Error: $e');
      print('Stack Trace: $stackTrace');
      print('========================================');
      throw Exception('Error updating FCM token: $e');
    }
  }

  // Shift Management APIs

  // Get authorization headers with token (from secure storage)
  static Future<Map<String, String>> _getAuthHeaders() async {
    try {
      final token = await AuthUtils.getToken();
      return {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };
    } catch (e) {
      return {'Content-Type': 'application/json'};
    }
  }

  // Get all shifts
  static Future<List<Map<String, dynamic>>> getShifts() async {
    try {
      print('========================================');
      print('GET SHIFTS API CALL');
      print('========================================');
      print('URL: $userBaseUrl/shift');

      final headers = await _getAuthHeaders();
      print('Headers: $headers');

      final response = await _userDio.get(
        '/shift',
        options: Options(headers: headers),
      );

      print('Response Status Code: ${response.statusCode}');
      print('Response Data: ${response.data}');

      if (response.statusCode == 200) {
        print('✅ Shifts loaded successfully');
        print('========================================');

        final data = response.data;
        if (data is Map && data['data'] is List) {
          return List<Map<String, dynamic>>.from(data['data']);
        } else if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        }
        return [];
      } else {
        throw Exception('Failed to load shifts: ${response.statusCode}');
      }
    } on DioException catch (e) {
      print('========================================');
      print('❌ DIO EXCEPTION OCCURRED');
      print('========================================');

      if (e.response != null) {
        print('Response Status Code: ${e.response?.statusCode}');
        print('Response Data: ${e.response?.data}');

        final errorMessage = e.response?.data?['message'] ??
                           e.response?.data?['error'] ??
                           'Failed to load shifts';

        print('Error Message: $errorMessage');
        print('========================================');
        throw Exception(errorMessage);
      } else {
        print('No response received from server');
        print('========================================');
        throw Exception('Network error: ${e.message}');
      }
    } catch (e) {
      print('========================================');
      print('❌ GENERAL EXCEPTION OCCURRED');
      print('Error: $e');
      print('========================================');
      throw Exception('Error loading shifts: $e');
    }
  }

  // Create new shift
  static Future<Map<String, dynamic>> createShift(Map<String, dynamic> shiftData) async {
    try {
      print('========================================');
      print('CREATE SHIFT API CALL');
      print('========================================');
      print('Method: POST');
      print('URL: $userBaseUrl/shift');
      print('Content-Type: application/json');
      print('Request Data:');
      shiftData.forEach((key, value) {
        print('  - $key: $value');
      });

      final headers = await _getAuthHeaders();
      print('Authorization: Bearer ${headers['Authorization']?.toString().substring(0, 20)}...');

      final response = await _userDio.post(
        '/shift',
        data: shiftData,
        options: Options(
          headers: headers,
          contentType: 'application/json',
        ),
      );

      print('Response Status Code: ${response.statusCode}');
      print('Response Data: ${response.data}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ Shift created successfully');
        print('========================================');

        final responseData = response.data;
        if (responseData is Map && responseData['data'] is Map) {
          return Map<String, dynamic>.from(responseData['data']);
        } else if (responseData is Map) {
          return Map<String, dynamic>.from(responseData);
        }
        return {};
      } else {
        throw Exception('Failed to create shift: ${response.statusCode}');
      }
    } on DioException catch (e) {
      print('========================================');
      print('❌ DIO EXCEPTION OCCURRED - CREATE SHIFT');
      print('========================================');

      if (e.response != null) {
        print('Response Status Code: ${e.response?.statusCode}');
        print('Response Data: ${e.response?.data}');

        final errorMessage = e.response?.data?['message'] ??
                           e.response?.data?['error'] ??
                           'Failed to create shift';

        print('Error Message: $errorMessage');
        print('========================================');
        throw Exception(errorMessage);
      } else {
        print('No response received from server');
        print('Error Type: ${e.type}');
        print('Error Message: ${e.message}');
        print('========================================');
        throw Exception('Network error: ${e.message}');
      }
    } catch (e) {
      print('========================================');
      print('❌ GENERAL EXCEPTION OCCURRED - CREATE SHIFT');
      print('Error: $e');
      print('Error Type: ${e.runtimeType}');
      print('========================================');
      throw Exception('Error creating shift: $e');
    }
  }

  // Update existing shift
  static Future<Map<String, dynamic>> updateShift(int id, Map<String, dynamic> shiftData) async {
    try {
      print('========================================');
      print('UPDATE SHIFT API CALL');
      print('========================================');
      print('Method: PUT');
      print('URL: $userBaseUrl/shift/$id');
      print('Content-Type: application/json');
      print('Request Data:');
      shiftData.forEach((key, value) {
        print('  - $key: $value');
      });

      final headers = await _getAuthHeaders();
      print('Authorization: Bearer ${headers['Authorization']?.toString().substring(0, 20)}...');

      final response = await _userDio.put(
        '/shift/$id',
        data: shiftData,
        options: Options(
          headers: headers,
          contentType: 'application/json',
        ),
      );

      print('Response Status Code: ${response.statusCode}');
      print('Response Data: ${response.data}');

      if (response.statusCode == 200) {
        print('✅ Shift updated successfully');
        print('========================================');

        final responseData = response.data;
        if (responseData is Map && responseData['data'] is Map) {
          return Map<String, dynamic>.from(responseData['data']);
        } else if (responseData is Map) {
          return Map<String, dynamic>.from(responseData);
        }
        return {};
      } else {
        throw Exception('Failed to update shift: ${response.statusCode}');
      }
    } on DioException catch (e) {
      print('========================================');
      print('❌ DIO EXCEPTION OCCURRED - UPDATE SHIFT');
      print('========================================');

      if (e.response != null) {
        print('Response Status Code: ${e.response?.statusCode}');
        print('Response Data: ${e.response?.data}');

        final errorMessage = e.response?.data?['message'] ??
                           e.response?.data?['error'] ??
                           'Failed to update shift';

        print('Error Message: $errorMessage');
        print('========================================');
        throw Exception(errorMessage);
      } else {
        print('No response received from server');
        print('Error Type: ${e.type}');
        print('Error Message: ${e.message}');
        print('========================================');
        throw Exception('Network error: ${e.message}');
      }
    } catch (e) {
      print('========================================');
      print('❌ GENERAL EXCEPTION OCCURRED - UPDATE SHIFT');
      print('Error: $e');
      print('Error Type: ${e.runtimeType}');
      print('========================================');
      throw Exception('Error updating shift: $e');
    }
  }

  // Delete shift
  static Future<void> deleteShift(int id) async {
    try {
      print('========================================');
      print('DELETE SHIFT API CALL');
      print('========================================');
      print('URL: $userBaseUrl/shift/$id');

      final headers = await _getAuthHeaders();
      print('Headers: $headers');

      final response = await _userDio.delete(
        '/shift/$id',
        options: Options(headers: headers),
      );

      print('Response Status Code: ${response.statusCode}');
      print('Response Data: ${response.data}');

      if (response.statusCode == 200 || response.statusCode == 204) {
        print('✅ Shift deleted successfully');
        print('========================================');
      } else {
        throw Exception('Failed to delete shift: ${response.statusCode}');
      }
    } on DioException catch (e) {
      print('========================================');
      print('❌ DIO EXCEPTION OCCURRED');
      print('========================================');

      if (e.response != null) {
        print('Response Status Code: ${e.response?.statusCode}');
        print('Response Data: ${e.response?.data}');

        final errorMessage = e.response?.data?['message'] ??
                           e.response?.data?['error'] ??
                           'Failed to delete shift';

        print('Error Message: $errorMessage');
        print('========================================');
        throw Exception(errorMessage);
      } else {
        print('No response received from server');
        print('========================================');
        throw Exception('Network error: ${e.message}');
      }
    } catch (e) {
      print('========================================');
      print('❌ GENERAL EXCEPTION OCCURRED');
      print('Error: $e');
      print('========================================');
      throw Exception('Error deleting shift: $e');
    }
  }

  // Employee Dashboard API
  static Future<Map<String, dynamic>> getEmployeeDashboardStats() async {
    try {
      print('========================================');
      print('GET EMPLOYEE DASHBOARD STATS API CALL');
      print('========================================');
      print('URL: $userBaseUrl/employee/dashboard');

      final headers = await _getAuthHeaders();
      print('Headers: $headers');

      final response = await _userDio.get(
        '/employee/dashboard',
        options: Options(headers: headers),
      );

      print('Response Status Code: ${response.statusCode}');
      print('Response Data: ${response.data}');

      if (response.statusCode == 200) {
        print('✅ Employee dashboard stats loaded successfully');
        print('========================================');
        return Map<String, dynamic>.from(response.data);
      } else {
        throw Exception('Failed to load employee dashboard stats: ${response.statusCode}');
      }
    } on DioException catch (e) {
      print('========================================');
      print('❌ DIO EXCEPTION OCCURRED - GET EMPLOYEE DASHBOARD');
      print('========================================');

      if (e.response != null) {
        print('Response Status Code: ${e.response?.statusCode}');
        print('Response Data: ${e.response?.data}');

        final errorMessage = e.response?.data?['message'] ??
                           e.response?.data?['error'] ??
                           'Failed to load employee dashboard';

        print('Error Message: $errorMessage');
        print('========================================');
        throw Exception(errorMessage);
      } else {
        print('No response received from server');
        print('========================================');
        throw Exception('Network error: ${e.message}');
      }
    } catch (e) {
      print('========================================');
      print('❌ GENERAL EXCEPTION OCCURRED - GET EMPLOYEE DASHBOARD');
      print('Error: $e');
      print('========================================');
      throw Exception('Error loading employee dashboard: $e');
    }
  }

  // Employee Leave API
  static Future<Map<String, dynamic>> applyLeave(Map<String, dynamic> leaveData, {File? certificate}) async {
    try {
      print('========================================');
      print('APPLY LEAVE API CALL');
      print('========================================');
      print('URL: $userBaseUrl/leave/apply');
      print('Leave Data: $leaveData');
      if (certificate != null) print('Certificate: ${certificate.path}');

      final headers = await _getAuthHeaders();
      print('Headers: $headers');
      
      // Create FormData
      final formData = FormData.fromMap({
        ...leaveData,
      });

      // Add certificate if provided
      if (certificate != null) {
        formData.files.add(MapEntry(
          'certificate',
          await MultipartFile.fromFile(
            certificate.path,
            filename: certificate.path.split('/').last,
          ),
        ));
      }

      final response = await _userDio.post(
        '/leave/apply',
        data: formData, // Send as FormData
        options: Options(headers: headers),
      );

      print('Response Status Code: ${response.statusCode}');
      print('Response Data: ${response.data}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ Leave application submitted successfully');
        print('========================================');
        final responseData = response.data;
        if (responseData is Map && responseData['data'] is Map) {
          return Map<String, dynamic>.from(responseData);
        } else if (responseData is Map) {
          return Map<String, dynamic>.from(responseData);
        }
        return {'success': true, 'message': 'Leave applied successfully'};
      } else {
        throw Exception('Failed to apply leave: ${response.statusCode}');
      }
    } on DioException catch (e) {
      print('========================================');
      print('❌ DIO EXCEPTION OCCURRED - APPLY LEAVE');
      print('========================================');

      if (e.response != null) {
        print('Response Status Code: ${e.response?.statusCode}');
        print('Response Data: ${e.response?.data}');

        final errorMessage = e.response?.data?['message'] ??
                           e.response?.data?['error'] ??
                           'Failed to apply leave';

        print('Error Message: $errorMessage');
        print('========================================');
        throw Exception(errorMessage);
      } else {
        print('No response received from server');
        print('========================================');
        throw Exception('Network error: ${e.message}');
      }
    } catch (e) {
      print('========================================');
      print('❌ GENERAL EXCEPTION OCCURRED - APPLY LEAVE');
      print('Error: $e');
      print('========================================');
      throw Exception('Error applying leave: $e');
    }
  }

  // Fetch Employee Leaves
  static Future<Map<String, dynamic>> getMyLeaves({
    String? status,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      print('========================================');
      print('GET MY LEAVES API CALL');
      print('========================================');
      print('URL: $userBaseUrl/leave/my-leaves');

      final Map<String, dynamic> queryParams = {};
      if (status != null && status.isNotEmpty && status != 'All') {
        queryParams['status'] = status;
      }
      if (startDate != null) {
        queryParams['startDate'] = DateFormat('yyyy-MM-dd').format(startDate);
      }
      if (endDate != null) {
        queryParams['endDate'] = DateFormat('yyyy-MM-dd').format(endDate);
      }

      // Add employeeId for non-employee users (staff/admin)
      final token = await AuthUtils.getToken();
      if (token != null) {
        final userType = AuthUtils.getRoleFromToken(token);
        print('User Type from token: $userType');
        
        if (userType != null && userType != 'employee') {
          final employeeId = AuthUtils.getEmployeeIdFromToken(token);
          if (employeeId != null) {
            queryParams['employeeId'] = employeeId.toString();
            print('Added employeeId to query params: $employeeId');
          } else {
            print('Warning: Could not extract employeeId from token for non-employee user');
          }
        }
      }

      print('Query Params: $queryParams');

      final headers = await _getAuthHeaders();
      print('Headers: $headers');

      final response = await _userDio.get(
        '/leave/my-leaves',
        queryParameters: queryParams,
        options: Options(headers: headers),
      );

      print('Response Status Code: ${response.statusCode}');
      print('Response Data: ${response.data}');

      if (response.statusCode == 200) {
        print('✅ Leaves loaded successfully');
        print('========================================');
        return Map<String, dynamic>.from(response.data);
      } else {
        throw Exception('Failed to load leaves: ${response.statusCode}');
      }
    } on DioException catch (e) {
      print('========================================');
      print('❌ DIO EXCEPTION OCCURRED - GET MY LEAVES');
      print('========================================');

      if (e.response != null) {
        print('Response Status Code: ${e.response?.statusCode}');
        print('Response Data: ${e.response?.data}');

        final errorMessage = e.response?.data?['message'] ??
                           e.response?.data?['error'] ??
                           'Failed to load leaves';

        print('Error Message: $errorMessage');
        print('========================================');
        throw Exception(errorMessage);
      } else {
        print('No response received from server');
        print('========================================');
        throw Exception('Network error: ${e.message}');
      }
    } catch (e) {
      print('========================================');
      print('❌ GENERAL EXCEPTION OCCURRED - GET MY LEAVES');
      print('Error: $e');
      print('========================================');
      throw Exception('Error loading leaves: $e');
    }
  }

  // Employee Attendance Report API
  static Future<Map<String, dynamic>> getEmployeeAttendanceReport({
    String? status,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      print('========================================');
      print('GET EMPLOYEE ATTENDANCE REPORT API CALL');
      print('========================================');
      print('URL: $userBaseUrl/employee/attendance-report');
      
      final Map<String, dynamic> queryParams = {};
      if (status != null && status.isNotEmpty && status != 'All') {
        queryParams['status'] = status.toLowerCase();
      }
      if (startDate != null) {
        queryParams['startDate'] = startDate.toIso8601String().split('T')[0];
      }
      if (endDate != null) {
        queryParams['endDate'] = endDate.toIso8601String().split('T')[0];
      }
      
      print('Query Params: $queryParams');

      final headers = await _getAuthHeaders();
      print('Headers: $headers');

      final response = await _userDio.get(
        '/employee/attendance-report',
        queryParameters: queryParams,
        options: Options(headers: headers),
      );

      print('Response Status Code: ${response.statusCode}');
      print('Response Data: ${response.data}');

      if (response.statusCode == 200) {
        print('✅ Employee attendance report loaded successfully');
        print('========================================');
        return Map<String, dynamic>.from(response.data);
      } else {
        throw Exception('Failed to load attendance report: ${response.statusCode}');
      }
    } on DioException catch (e) {
      print('========================================');
      print('❌ DIO EXCEPTION OCCURRED - GET ATTENDANCE REPORT');
      print('========================================');

      if (e.response != null) {
        print('Response Status Code: ${e.response?.statusCode}');
        print('Response Data: ${e.response?.data}');

        final errorMessage = e.response?.data?['message'] ??
                           e.response?.data?['error'] ??
                           'Failed to load attendance report';

        print('Error Message: $errorMessage');
        print('========================================');
        throw Exception(errorMessage);
      } else {
        print('No response received from server');
        print('========================================');
        throw Exception('Network error: ${e.message}');
      }
    } catch (e) {
      print('========================================');
      print('❌ GENERAL EXCEPTION OCCURRED - GET ATTENDANCE REPORT');
      print('Error: $e');
      print('========================================');
      throw Exception('Error loading attendance report: $e');
    }
  }

  // Cancel Leave API
  static Future<Map<String, dynamic>> cancelLeave(int leaveId) async {
    try {
      print('========================================');
      print('CANCEL LEAVE API CALL');
      print('========================================');
      print('URL: $userBaseUrl/leave/$leaveId/cancel');

      final headers = await _getAuthHeaders();
      print('Headers: $headers');

      final response = await _userDio.post(
        '/leave/$leaveId/cancel',
        options: Options(headers: headers),
      );

      print('Response Status Code: ${response.statusCode}');
      print('Response Data: ${response.data}');

      if (response.statusCode == 200) {
        print('✅ Leave cancelled successfully');
        print('========================================');
        return Map<String, dynamic>.from(response.data);
      } else {
        throw Exception('Failed to cancel leave: ${response.statusCode}');
      }
    } on DioException catch (e) {
      print('========================================');
      print('❌ DIO EXCEPTION OCCURRED - CANCEL LEAVE');
      print('========================================');

      if (e.response != null) {
        print('Response Status Code: ${e.response?.statusCode}');
        print('Response Data: ${e.response?.data}');

        final errorMessage = e.response?.data?['message'] ??
                           e.response?.data?['error'] ??
                           'Failed to cancel leave';

        print('Error Message: $errorMessage');
        print('========================================');
        throw Exception(errorMessage);
      } else {
        print('No response received from server');
        print('========================================');
        throw Exception('Network error: ${e.message}');
      }
    } catch (e) {
      print('========================================');
      print('❌ GENERAL EXCEPTION OCCURRED - CANCEL LEAVE');
      print('Error: $e');
      print('========================================');
      throw Exception('Error cancelling leave: $e');
    }
  }

  // Get All Leave Requests (Admin)
  static Future<Map<String, dynamic>> getAllLeaveRequests({
    String? status,
    String? search,
  }) async {
    try {
      print('========================================');
      print('GET ALL LEAVE REQUESTS API CALL');
      print('========================================');
      print('URL: $userBaseUrl/leave/all');

      final Map<String, dynamic> queryParams = {};
      if (status != null && status.isNotEmpty && status != 'All') {
        queryParams['status'] = status;
      }
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      print('Query Params: $queryParams');

      final headers = await _getAuthHeaders();
      print('Headers: $headers');

      final response = await _userDio.get(
        '/leave/all',
        queryParameters: queryParams,
        options: Options(headers: headers),
      );

      print('Response Status Code: ${response.statusCode}');
      print('Response Data: ${response.data}');

      if (response.statusCode == 200) {
        print('✅ All leave requests loaded successfully');
        print('========================================');
        return Map<String, dynamic>.from(response.data);
      } else {
        throw Exception('Failed to load leave requests: ${response.statusCode}');
      }
    } on DioException catch (e) {
      print('========================================');
      print('❌ DIO EXCEPTION OCCURRED - GET ALL LEAVE REQUESTS');
      print('========================================');

      if (e.response != null) {
        print('Response Status Code: ${e.response?.statusCode}');
        print('Response Data: ${e.response?.data}');

        final errorMessage = e.response?.data?['message'] ??
                           e.response?.data?['error'] ??
                           'Failed to load leave requests';

        print('Error Message: $errorMessage');
        print('========================================');
        throw Exception(errorMessage);
      } else {
        print('No response received from server');
        print('========================================');
        throw Exception('Network error: ${e.message}');
      }
    } catch (e) {
      print('========================================');
      print('❌ GENERAL EXCEPTION OCCURRED - GET ALL LEAVE REQUESTS');
      print('Error: $e');
      print('========================================');
      throw Exception('Error loading leave requests: $e');
    }
  }

  // Approve/Reject Leave Request
  static Future<Map<String, dynamic>> approveLeave(int leaveId, String status) async {
    try {
      print('========================================');
      print('APPROVE LEAVE API CALL');
      print('========================================');
      print('URL: $userBaseUrl/leave/$leaveId/status');
      print('Method: PATCH');
      print('Status: $status');

      final headers = await _getAuthHeaders();
      headers['Content-Type'] = 'application/json';
      print('Headers: $headers');

      final response = await _userDio.patch(
        '/leave/$leaveId/status',
        data: {'status': status},
        options: Options(headers: headers),
      );

      print('Response Status Code: ${response.statusCode}');
      print('Response Data: ${response.data}');

      if (response.statusCode == 200) {
        print('✅ Leave $status successfully');
        print('========================================');
        return Map<String, dynamic>.from(response.data);
      } else {
        throw Exception('Failed to $status leave: ${response.statusCode}');
      }
    } on DioException catch (e) {
      print('========================================');
      print('❌ DIO EXCEPTION OCCURRED - APPROVE LEAVE');
      print('========================================');

      if (e.response != null) {
        print('Response Status Code: ${e.response?.statusCode}');
        print('Response Data: ${e.response?.data}');

        final errorMessage = e.response?.data?['message'] ??
                           e.response?.data?['error'] ??
                           'Failed to $status leave';

        print('Error Message: $errorMessage');
        print('========================================');
        throw Exception(errorMessage);
      } else {
        print('No response received from server');
        print('========================================');
        throw Exception('Network error: ${e.message}');
      }
    } catch (e) {
      print('========================================');
      print('❌ GENERAL EXCEPTION OCCURRED - APPROVE LEAVE');
      print('Error: $e');
      print('========================================');
      throw Exception('Error $status leave: $e');
    }
  }

  // Get Employee Leave Balance
  static Future<LeaveBalanceResponse> getLeaveBalance([int? employeeId]) async {
    try {
      print('========================================');
      print('GET LEAVE BALANCE API CALL');
      print('========================================');
      print('URL: $userBaseUrl/leave/balance');

      final Map<String, dynamic> queryParams = {};
      
      // If employeeId is provided, use it. Otherwise, extract from token for non-employee users.
      if (employeeId != null) {
        queryParams['employeeId'] = employeeId;
        print('Using provided employeeId: $employeeId');
      } else {
        // Extract employeeId from token for non-employee users
        final token = await AuthUtils.getToken();
        if (token != null) {
          final userType = AuthUtils.getRoleFromToken(token);
          print('User Type from token: $userType');
          
          if (userType != null && userType != 'employee') {
            final extractedEmployeeId = AuthUtils.getEmployeeIdFromToken(token);
            if (extractedEmployeeId != null) {
              queryParams['employeeId'] = extractedEmployeeId.toString();
              print('Extracted employeeId from token: $extractedEmployeeId');
            } else {
              print('Warning: Could not extract employeeId from token for non-employee user');
              throw Exception('Employee ID not found in token for non-employee user');
            }
          } else {
            print('User is employee type, no employeeId parameter needed');
          }
        } else {
          print('Warning: No auth token found');
          throw Exception('Authentication token not found');
        }
      }

      print('Query Params: $queryParams');
      print('Method: GET');

      final headers = await _getAuthHeaders();
      headers['Content-Type'] = 'application/json';
      print('Headers: $headers');

      final response = await _userDio.get(
        '/leave/balance',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
        options: Options(headers: headers),
      );

      print('Response Status Code: ${response.statusCode}');
      print('Response Data: ${response.data}');

      if (response.statusCode == 200) {
        print('✅ Leave balance loaded successfully');
        print('========================================');
        return LeaveBalanceResponse.fromJson(response.data);
      } else {
        throw Exception('Failed to load leave balance: ${response.statusCode}');
      }
    } on DioException catch (e) {
      print('========================================');
      print('❌ DIO EXCEPTION OCCURRED - GET LEAVE BALANCE');
      print('========================================');

      if (e.response != null) {
        print('Response Status Code: ${e.response?.statusCode}');
        print('Response Data: ${e.response?.data}');

        final errorMessage = e.response?.data?['message'] ??
                           e.response?.data?['error'] ??
                           'Failed to load leave balance';

        print('Error Message: $errorMessage');
        print('========================================');
        throw Exception(errorMessage);
      } else {
        print('No response received from server');
        print('Error Type: ${e.type}');
        print('Error Message: ${e.message}');
        print('========================================');
        throw Exception('Network error: ${e.message}');
      }
    } catch (e) {
      print('========================================');
      print('❌ GENERAL EXCEPTION OCCURRED - GET LEAVE BALANCE');
      print('Error: $e');
      print('Error Type: ${e.runtimeType}');
      print('========================================');
      throw Exception('Error loading leave balance: $e');
    }
  }

  // Departments API
  static Future<List<dynamic>> getDepartments() async {
    try {
      print('========================================');
      print('GET DEPARTMENTS API CALL');
      print('========================================');
      print('URL: $userBaseUrl/departments');
      print('Method: GET');
      
      final token = await AuthUtils.getToken();
      if (token != null) {
        print('🔑 Authorization: Bearer ${token.substring(0, 20)}...');
      } else {
        print('⚠️ No auth token found');
      }
      
      // Create options with Authorization header
      final options = Options(
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      
      print('📤 Sending request...');
      final response = await _userDio.get('/departments', options: options);
      
      print('Response Status Code: ${response.statusCode}');
      print('Response Data Type: ${response.data.runtimeType}');
      
      if (response.statusCode == 200) {
        print('✅ Departments loaded successfully');
        
        // Handle different response formats
        List<dynamic> departmentsList;
        if (response.data is Map && response.data['departments'] is List) {
          departmentsList = response.data['departments'];
        } else if (response.data is Map && response.data['data'] is List) {
          departmentsList = response.data['data'];
        } else if (response.data is List) {
          departmentsList = response.data;
        } else {
          print('❌ Unexpected response format');
          print('Response: ${response.data}');
          throw Exception('Unexpected response format');
        }
        
        print('📋 Found ${departmentsList.length} departments');
        print('========================================');
        
        return departmentsList;
      }
      
      print('❌ Failed with status code: ${response.statusCode}');
      print('========================================');
      throw Exception('Failed to load departments');
    } on DioException catch (e) {
      print('========================================');
      print('❌ DIO EXCEPTION OCCURRED - GET DEPARTMENTS');
      print('========================================');
      
      if (e.response != null) {
        print('Response Status Code: ${e.response?.statusCode}');
        print('Response Data: ${e.response?.data}');
        
        final errorMessage = e.response?.data?['message'] ??
                           e.response?.data?['error'] ??
                           'Failed to load departments';
        
        print('Error Message: $errorMessage');
        print('========================================');
        throw Exception(errorMessage);
      } else {
        print('No response received from server');
        print('Error Type: ${e.type}');
        print('Error Message: ${e.message}');
        print('========================================');
        throw Exception('Network error: ${e.message}');
      }
    } catch (e) {
      print('========================================');
      print('❌ GENERAL EXCEPTION OCCURRED - GET DEPARTMENTS');
      print('Error: $e');
      print('Error Type: ${e.runtimeType}');
      print('========================================');
      throw Exception('Error: $e');
    }
  }
  // ---------------------------------------------------------------------------
  // COMP-OFF APIs
  // ---------------------------------------------------------------------------

  // 1. Apply for Comp-Off Credit
  static Future<Map<String, dynamic>> applyCompOffCredit(Map<String, dynamic> creditData) async {
    try {
      print('========================================');
      print('APPLY COMP-OFF CREDIT API CALL');
      print('========================================');
      print('URL: $userBaseUrl/comp-off/apply');
      print('Data: $creditData');

      final headers = await _getAuthHeaders();
      final response = await _userDio.post(
        '/comp-off/apply',
        data: creditData,
        options: Options(headers: headers),
      );

      print('Response Status: ${response.statusCode}');
      print('Response Data: ${response.data}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return Map<String, dynamic>.from(response.data);
      } else {
        throw Exception('Failed to apply for comp-off credit: ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.response != null) {
        throw Exception(e.response?.data['message'] ?? e.response?.data['error'] ?? 'Failed to apply');
      }
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // 2. Get Comp-Off Requests (Status)
  static Future<List<dynamic>> getCompOffCredits() async {
    try {
      print('========================================');
      print('GET COMP-OFF CREDITS API CALL');
      print('========================================');
      print('URL: $userBaseUrl/comp-off/my-credits');

      final headers = await _getAuthHeaders();
      final response = await _userDio.get(
        '/comp-off/my-credits',
        options: Options(headers: headers),
      );

      print('Response Status: ${response.statusCode}');
      print('Response Data: ${response.data}');

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map && data['data'] is List) {
          return List<dynamic>.from(data['data']);
        }
        return [];
      } else {
        throw Exception('Failed to load comp-off credits: ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.response != null) {
        throw Exception(e.response?.data['message'] ?? 'Failed to load credits');
      }
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // 3. Get Comp-Off Balance
  static Future<Map<String, dynamic>> getCompOffBalance() async {
    try {
      print('========================================');
      print('GET COMP-OFF BALANCE API CALL');
      print('========================================');
      print('URL: $userBaseUrl/comp-off/balance');

      final headers = await _getAuthHeaders();
      final response = await _userDio.get(
        '/comp-off/balance',
        options: Options(headers: headers),
      );

      print('Response Status: ${response.statusCode}');
      print('Response Data: ${response.data}');

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map && data['data'] is Map) {
          return Map<String, dynamic>.from(data['data']);
        }
        return {'availableCredits': '0.0'}; // Default fallback
      } else {
        throw Exception('Failed to load balance: ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.response != null) {
        throw Exception(e.response?.data['message'] ?? 'Failed to load balance');
      }
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // 4. Apply for Comp-Off Leave (Use Credit)
  static Future<Map<String, dynamic>> applyCompOffLeave(Map<String, dynamic> leaveData) async {
    try {
      print('========================================');
      print('APPLY COMP-OFF LEAVE API CALL');
      print('========================================');
      print('URL: $userBaseUrl/comp-off/leave/apply');
      print('Data: $leaveData');

      final headers = await _getAuthHeaders();
      final response = await _userDio.post(
        '/comp-off/leave/apply',
        data: leaveData,
        options: Options(headers: headers),
      );

      print('Response Status: ${response.statusCode}');
      print('Response Data: ${response.data}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return Map<String, dynamic>.from(response.data);
      } else {
        throw Exception('Failed to apply for comp-off leave: ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.response != null) {
         // Pass the specific error message (e.g., "Insufficient balance")
        throw Exception(e.response?.data['error'] ?? e.response?.data['message'] ?? 'Failed to apply');
      }
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // Manual Attendance Entry API
  static Future<Map<String, dynamic>> addManualAttendance(Map<String, dynamic> attendanceData) async {
    try {
      print('========================================');
      print('MANUAL ATTENDANCE API CALL');
      print('========================================');
      print('URL: $userBaseUrl/attendance/manual');
      print('Data: $attendanceData');

      final headers = await _getAuthHeaders();
      final response = await _userDio.post(
        '/attendance/manual',
        data: attendanceData,
        options: Options(headers: headers),
      );

      print('Response Status: ${response.statusCode}');
      print('Response Data: ${response.data}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return Map<String, dynamic>.from(response.data);
      } else {
        throw Exception(response.data['error'] ?? response.data['message'] ?? 'Failed to update attendance');
      }
    } on DioException catch (e) {
      if (e.response != null) {
        throw Exception(e.response?.data['error'] ?? e.response?.data['message'] ?? 'Failed to update attendance');
      }
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // Get or check current check-in for today
  static Future<Map<String, dynamic>> getTodayCheckIn(int employeeId) async {
    try {
      print('========================================');
      print('GET TODAY CHECK-IN API CALL');
      print('========================================');
      print('Employee ID: $employeeId');

      final headers = await _getAuthHeaders();
      final response = await _userDio.get(
        '/attendance/today-checkin',
        queryParameters: {'employeeId': employeeId},
        options: Options(headers: headers),
      );

      print('Response Status Code: ${response.statusCode}');
      print('Response Data: ${response.data}');

      if (response.statusCode == 200) {
        print('✅ Today check-in data loaded successfully');
        print('========================================');
        return Map<String, dynamic>.from(response.data);
      } else {
        throw Exception('Failed to get today check-in: ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.response != null) {
        throw Exception(e.response?.data?['message'] ?? e.response?.data?['error'] ?? 'Failed to get today check-in');
      }
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // Get or create attendance record for today (with auto-fill logic)
  static Future<Map<String, dynamic>> getOrCreateAttendance(int employeeId) async {
    try {
      print('========================================');
      print('GET OR CREATE ATTENDANCE API CALL');
      print('========================================');
      print('Employee ID: $employeeId');

      final headers = await _getAuthHeaders();
      final response = await _userDio.get(
        '/attendance/today',
        queryParameters: {'employeeId': employeeId},
        options: Options(headers: headers),
      );

      print('Response Status Code: ${response.statusCode}');
      print('Response Data: ${response.data}');

      if (response.statusCode == 200) {
        print('✅ Attendance record loaded/created successfully');
        print('========================================');
        return Map<String, dynamic>.from(response.data);
      } else {
        throw Exception('Failed to get attendance: ${response.statusCode}');
      }
    } on DioException catch (e) {
      print('========================================');
      print('❌ DIO EXCEPTION OCCURRED - GET OR CREATE ATTENDANCE');
      print('========================================');

      if (e.response != null) {
        print('Response Status Code: ${e.response?.statusCode}');
        print('Response Data: ${e.response?.data}');

        final errorMessage = e.response?.data?['message'] ??
                           e.response?.data?['error'] ??
                           'Failed to get attendance';

        print('Error Message: $errorMessage');
        print('========================================');
        throw Exception(errorMessage);
      } else {
        print('No response received from server');
        print('========================================');
        throw Exception('Network error: ${e.message}');
      }
    } catch (e) {
      print('========================================');
      print('❌ GENERAL EXCEPTION OCCURRED - GET OR CREATE ATTENDANCE');
      print('Error: $e');
      print('========================================');
      throw Exception('Error getting attendance: $e');
    }
  }

  // Update attendance (manual check-in/check-out)
  static Future<Map<String, dynamic>> updateAttendanceAutoFill({
    required int employeeId,
    String? checkInTime,
    String? checkOutTime,
  }) async {
    try {
      print('========================================');
      print('UPDATE ATTENDANCE API CALL');
      print('========================================');
      print('Employee ID: $employeeId');
      if (checkInTime != null) print('Check In Time: $checkInTime');
      if (checkOutTime != null) print('Check Out Time: $checkOutTime');

      final headers = await _getAuthHeaders();
      final Map<String, dynamic> requestData = {
        'employeeId': employeeId,
      };

      if (checkInTime != null) requestData['checkInTime'] = checkInTime;
      if (checkOutTime != null) requestData['checkOutTime'] = checkOutTime;

      final response = await _userDio.post(
        '/attendance/update',
        data: requestData,
        options: Options(headers: headers),
      );

      print('Response Status Code: ${response.statusCode}');
      print('Response Data: ${response.data}');

      if (response.statusCode == 200) {
        print('✅ Attendance updated successfully');
        print('========================================');
        return Map<String, dynamic>.from(response.data);
      } else {
        throw Exception('Failed to update attendance: ${response.statusCode}');
      }
    } on DioException catch (e) {
      print('========================================');
      print('❌ DIO EXCEPTION OCCURRED - UPDATE ATTENDANCE');
      print('========================================');

      if (e.response != null) {
        print('Response Status Code: ${e.response?.statusCode}');
        print('Response Data: ${e.response?.data}');

        final errorMessage = e.response?.data?['message'] ??
                           e.response?.data?['error'] ??
                           'Failed to update attendance';

        print('Error Message: $errorMessage');
        print('========================================');
        throw Exception(errorMessage);
      } else {
        print('No response received from server');
        print('========================================');
        throw Exception('Network error: ${e.message}');
      }
    } catch (e) {
      print('========================================');
      print('❌ GENERAL EXCEPTION OCCURRED - UPDATE ATTENDANCE');
      print('Error: $e');
      print('========================================');
      throw Exception('Error updating attendance: $e');
    }
  }
}