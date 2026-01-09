class Employee {
  final int? id;
  final String name;
  final String email;
  final String phone;
  final String position;
  final double salary;
  final String faceData;
  final DateTime createdAt;
  final bool isActive;
  final int? shiftId;
  final String? shiftName; // Store shift name from API
  final int? companyId; // Company ID the employee belongs to

  Employee({
    this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.position,
    required this.salary,
    required this.faceData,
    required this.createdAt,
    this.isActive = true,
    this.shiftId,
    this.shiftName,
    this.companyId,
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
    
    return Employee(
      id: json['id'],
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      position: json['department'] ?? json['position'] ?? '', // API uses 'department'
      salary: json['salary'] != null ? double.parse(json['salary'].toString()) : 0.0,
      faceData: faceDataValue,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
      isActive: json['is_active'] == 1 || json['is_active'] == true || json['is_active'] == null,
      shiftId: json['shift_id'],
      shiftName: json['shift'], // API returns shift name
      companyId: json['company_id'],
    );
  }

  Map<String, dynamic> toJson({bool forCreation = false, bool forUpdate = false}) {
    final Map<String, dynamic> json = {
      'name': name,
      'email': email,
      'phone': phone,
    };
    
    // For API update, use 'department' instead of 'position'
    if (forUpdate) {
      json['department'] = position;
      json['salary'] = salary;
      json['is_active'] = isActive ? 1 : 0;
      if (shiftName != null) json['shift'] = shiftName!;
      if (id != null) json['employee_id'] = 'EMP${id.toString().padLeft(3, '0')}';
    } else {
      json['position'] = position;
      json['salary'] = salary;
      json['face_data'] = faceData;
      
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
    String? shiftName,
    int? companyId,
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
      shiftName: shiftName ?? this.shiftName,
      companyId: companyId ?? this.companyId,
    );
  }
} 