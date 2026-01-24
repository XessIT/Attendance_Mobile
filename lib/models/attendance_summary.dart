class AttendanceSummary {
  final int totalEmployees;
  final int totalPresent;
  final int totalAbsent;
  final int totalLate;
  final int totalHalfDay;

  AttendanceSummary({
    required this.totalEmployees,
    required this.totalPresent,
    required this.totalAbsent,
    required this.totalLate,
    required this.totalHalfDay,
  });

  factory AttendanceSummary.fromJson(Map<String, dynamic> json) {
    final overall = json['overallSummary'] as Map<String, dynamic>? ?? {};
    return AttendanceSummary(
      totalEmployees: (overall['totalEmployees'] ?? json['totalEmployees'] ?? 0) as int,
      totalPresent: (overall['totalPresent'] ?? 0) as int,
      totalAbsent: (overall['totalAbsent'] ?? 0) as int,
      totalLate: (overall['totalLate'] ?? 0) as int,
      totalHalfDay: (overall['totalHalfDay'] ?? 0) as int,
    );
  }
}

