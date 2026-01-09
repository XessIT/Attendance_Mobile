class Salary {
  final int? id;
  final int employeeId;
  final int month;
  final int year;
  final double baseSalary;
  final int totalDays;
  final int presentDays;
  final int absentDays;
  final int lateDays;
  final int halfDays;
  final double totalWorkingHours;
  final double deductions;
  final double allowances;
  final double netSalary;
  final bool isPaid;
  final DateTime? paidDate;

  Salary({
    this.id,
    required this.employeeId,
    required this.month,
    required this.year,
    required this.baseSalary,
    required this.totalDays,
    required this.presentDays,
    required this.absentDays,
    required this.lateDays,
    required this.halfDays,
    required this.totalWorkingHours,
    this.deductions = 0.0,
    this.allowances = 0.0,
    required this.netSalary,
    this.isPaid = false,
    this.paidDate,
  });

  factory Salary.fromJson(Map<String, dynamic> json) {
    return Salary(
      id: json['id'],
      employeeId: json['employee_id'],
      month: json['month'],
      year: json['year'],
      baseSalary: double.parse(json['base_salary'].toString()),
      totalDays: json['total_days'],
      presentDays: json['present_days'],
      absentDays: json['absent_days'],
      lateDays: json['late_days'],
      halfDays: json['half_days'],
      totalWorkingHours: double.parse(json['total_working_hours'].toString()),
      deductions: double.parse(json['deductions'].toString()),
      allowances: double.parse(json['allowances'].toString()),
      netSalary: double.parse(json['net_salary'].toString()),
      isPaid: json['is_paid'] == 1,
      paidDate: json['paid_date'] != null ? DateTime.parse(json['paid_date']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employee_id': employeeId,
      'month': month,
      'year': year,
      'base_salary': baseSalary,
      'total_days': totalDays,
      'present_days': presentDays,
      'absent_days': absentDays,
      'late_days': lateDays,
      'half_days': halfDays,
      'total_working_hours': totalWorkingHours,
      'deductions': deductions,
      'allowances': allowances,
      'net_salary': netSalary,
      'is_paid': isPaid ? 1 : 0,
      'paid_date': paidDate?.toIso8601String(),
    };
  }

  double get attendancePercentage => totalDays > 0 ? (presentDays / totalDays) * 100 : 0.0;
  double get dailySalary => baseSalary / 30; // Assuming 30 days per month
  double get presentDaySalary => presentDays * dailySalary;
  double get halfDaySalary => halfDays * (dailySalary / 2);
  double get lateDaySalary => lateDays * (dailySalary * 0.8); // 20% deduction for late
  double get grossSalary => presentDaySalary + halfDaySalary + lateDaySalary + allowances;
} 