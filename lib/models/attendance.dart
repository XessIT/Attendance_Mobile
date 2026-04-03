class Attendance {
  final int? id;
  final int employeeId;
  final DateTime date;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final String status; // present, absent, late, half-day
  final double? workingHours;
  final String? notes;

  Attendance({
    this.id,
    required this.employeeId,
    required this.date,
    this.checkIn,
    this.checkOut,
    this.status = 'absent',
    this.workingHours,
    this.notes,
  });

  factory Attendance.fromJson(Map<String, dynamic> json) {
    DateTime? parseDateTime(dynamic value) {
      if (value == null) return null;
      final text = value.toString();
      if (text.isEmpty || text == '-') return null;
      try {
        return DateTime.parse(text);
      } catch (_) {
        return null;
      }
    }

    return Attendance(
      id: json['id'],
      employeeId: json['employee_id'],
      date: DateTime.parse(json['date']),
      checkIn: parseDateTime(
          json['check_in'] ?? json['checkIn'] ?? json['checkInTime']),
      checkOut: parseDateTime(
          json['check_out'] ?? json['checkOut'] ?? json['checkOutTime']),
      status: json['status'],
      workingHours: json['working_hours'] != null
          ? double.parse(json['working_hours'].toString())
          : null,
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employee_id': employeeId,
      'date': date.toIso8601String().split('T')[0],
      'check_in': checkIn?.toIso8601String(),
      'check_out': checkOut?.toIso8601String(),
      'status': status,
      'working_hours': workingHours,
      'notes': notes,
    };
  }

  double get totalWorkingHours {
    if (checkIn == null || checkOut == null) return 0.0;
    return checkOut!.difference(checkIn!).inMinutes / 60.0;
  }

  bool get isPresent =>
      status == 'present' || status == 'late' || status == 'half-day';
  bool get isLate => status == 'late';
  bool get isHalfDay => status == 'half-day';

  Attendance copyWith({
    int? id,
    int? employeeId,
    DateTime? date,
    DateTime? checkIn,
    DateTime? checkOut,
    String? status,
    double? workingHours,
    String? notes,
  }) {
    return Attendance(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      date: date ?? this.date,
      checkIn: checkIn ?? this.checkIn,
      checkOut: checkOut ?? this.checkOut,
      status: status ?? this.status,
      workingHours: workingHours ?? this.workingHours,
      notes: notes ?? this.notes,
    );
  }
}
