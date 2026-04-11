class Employee {
  final int? id;
  final String name;
  final String? email; // Made optional
  final String phone;
  final String position;
  final String? employeeId; // Added employeeId field from API
  final double salary;
  final String faceData;
  final DateTime createdAt;
  final bool isActive;
  final int? shiftId;
  final int? departmentId; // Added department ID
  final String? shiftName; // Store shift name from API
  final int? companyId; // Company ID the employee belongs to
  final DateTime? dateOfJoining;
  final DateTime? dateOfBirth; // Added date of birth
  final double? payloan; // Added payloan field

  Employee({
    this.id,
    required this.name,
    this.email, // Made optional
    required this.phone,
    required this.position,
    this.employeeId, // Added employeeId parameter
    required this.salary,
    required this.faceData,
    required this.createdAt,
    this.isActive = true,
    this.shiftId,
    this.departmentId, // Added department ID
    this.shiftName,
    this.companyId,
    this.dateOfJoining,
    this.dateOfBirth,
    this.payloan, // Added payloan parameter
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    // Handle image_paths (array) or face_data (string)
    String faceDataValue = '';
    if (json['image_paths'] != null && json['image_paths'] is List) {
      // New API format: image_paths is an array
      final List<dynamic> imagePaths = json['image_paths'];
      faceDataValue = imagePaths.isNotEmpty ? imagePaths[0].toString() : '';
    } else if (json['face_data'] != null) {
      // Old format: face_data is a string
      faceDataValue = json['face_data'].toString();
    }
    
    // Parse date_of_joining if available
    final DateTime? joiningDate = json['date_of_joining'] != null
        ? DateTime.parse(json['date_of_joining'])
        : null;
    
    // Parse date_of_birth if available
    final DateTime? birthDate = json['date_of_birth'] != null
        ? DateTime.parse(json['date_of_birth'])
        : null;
    
    // Parse payloan if available
    final double? payloanValue = json['payloan'] != null
        ? double.parse(json['payloan'].toString())
        : null;
    
    // Safely parse ID - check db_id first, then id
    final dynamic rawId = json['db_id'] ?? json['id'];
    int? intId;
    if (rawId is int) {
      intId = rawId;
    } else if (rawId != null) {
      intId = int.tryParse(rawId.toString());
    }

    // Safely parse employeeId string
    String? employeeIdStr = json['employeeId']?.toString() ?? json['employee_id']?.toString();
    // If id was a string (like "EMP-4"), and we don't have an explicit employeeId, use the id string
    if (employeeIdStr == null && json['id'] is String) {
      employeeIdStr = json['id'];
    }

    return Employee(
      id: intId,
      name: json['name'] ?? '',
      email: json['email'], // Can be null
      phone: json['phone'] ?? '',
      position: json['department'] ?? json['position'] ?? '', // API uses 'department'
      employeeId: employeeIdStr,
      salary: json['salary'] != null ? double.parse(json['salary'].toString()) : 0.0,
      faceData: faceDataValue,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
      isActive: json['is_active'] == 1 || json['is_active'] == true || json['is_active'] == null,
      shiftId: json['shift_id'] is int ? json['shift_id'] : int.tryParse(json['shift_id']?.toString() ?? ''),
      departmentId: json['department_id'] is int ? json['department_id'] : int.tryParse(json['department_id']?.toString() ?? ''),
      shiftName: json['shift'] ?? json['shift_name'] ?? json['shiftName'], // API returns shift name
      companyId: json['company_id'] is int ? json['company_id'] : int.tryParse(json['company_id']?.toString() ?? ''),
      dateOfJoining: joiningDate,
      dateOfBirth: birthDate,
      payloan: payloanValue, // Added payloan field
    );
  }

  Map<String, dynamic> toJson({bool forCreation = false, bool forUpdate = false}) {
    final Map<String, dynamic> json = {};
    // Common fields
    json['name'] = name;
    json['phone'] = phone;
    json['department'] = position;
    json['salary'] = salary;
    
    // Only include email if it's not null
    if (email != null && email!.isNotEmpty) {
      json['email'] = email;
    }
    
    if (forUpdate) {
      json['is_active'] = isActive ? 1 : 0;
      if (shiftName != null) json['shift'] = shiftName!;
      if (id != null) json['id'] = id!;
      json['department_id'] = departmentId;
      json['face_data'] = faceData;
      if (dateOfJoining != null) json['date_of_joining'] = dateOfJoining!.toIso8601String().split('T')[0];
      if (dateOfBirth != null) json['date_of_birth'] = dateOfBirth!.toIso8601String().split('T')[0];
      if (companyId != null) json['company_id'] = companyId;
      if (shiftId != null) json['shift_id'] = shiftId;
    } else {
      json['position'] = position;
      json['face_data'] = faceData;
      if (dateOfJoining != null) json['date_of_joining'] = dateOfJoining!.toIso8601String().split('T')[0];
      if (dateOfBirth != null) json['date_of_birth'] = dateOfBirth!.toIso8601String().split('T')[0];
      if (departmentId != null) json['department_id'] = departmentId;
      
      // Only include these fields if not creating a new employee
      if (!forCreation) {
        if (id != null) json['id'] = id!;
        json['created_at'] = createdAt.toIso8601String();
        json['is_active'] = isActive ? 1 : 0;
      }
    }
    
    return json;
  }

  Employee copyWith({
    int? id,
    String? name,
    String? email,
    String? phone,
    String? position,
    double? salary,
    String? faceData,
    DateTime? createdAt,
    bool? isActive,
    int? shiftId,
    int? departmentId,
    String? shiftName,
    int? companyId,
    DateTime? dateOfJoining,
    DateTime? dateOfBirth,
    double? payloan, // Added payloan parameter
  }) {
    return Employee(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      position: position ?? this.position,
      salary: salary ?? this.salary,
      faceData: faceData ?? this.faceData,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
      shiftId: shiftId ?? this.shiftId,
      departmentId: departmentId ?? this.departmentId,
      shiftName: shiftName ?? this.shiftName,
      companyId: companyId ?? this.companyId,
      dateOfJoining: dateOfJoining ?? this.dateOfJoining,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      payloan: payloan ?? this.payloan, // Added payloan field
    );
  }
} 