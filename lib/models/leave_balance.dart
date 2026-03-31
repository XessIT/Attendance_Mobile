class LeaveBalanceResponse {
  final bool success;
  final LeaveBalanceData data;

  LeaveBalanceResponse({
    required this.success,
    required this.data,
  });

  factory LeaveBalanceResponse.fromJson(Map<String, dynamic> json) {
    return LeaveBalanceResponse(
      success: json['success'] ?? false,
      data: LeaveBalanceData.fromJson(json['data'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'data': data.toJson(),
    };
  }
}

class LeaveBalanceData {
  final EmployeeInfo employee;
  final LeavePeriod period;
  final List<LeaveBalance> leaveBalances;

  LeaveBalanceData({
    required this.employee,
    required this.period,
    required this.leaveBalances,
  });

  factory LeaveBalanceData.fromJson(Map<String, dynamic> json) {
    var balancesList = json['leaveBalances'] as List<dynamic>? ?? [];
    var balances = balancesList.map((balance) => LeaveBalance.fromJson(balance)).toList();

    return LeaveBalanceData(
      employee: EmployeeInfo.fromJson(json['employee'] ?? {}),
      period: LeavePeriod.fromJson(json['period'] ?? {}),
      leaveBalances: balances,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'employee': employee.toJson(),
      'period': period.toJson(),
      'leaveBalances': leaveBalances.map((balance) => balance.toJson()).toList(),
    };
  }
}

class EmployeeInfo {
  final int id;
  final String employeeId;
  final String name;

  EmployeeInfo({
    required this.id,
    required this.employeeId,
    required this.name,
  });

  factory EmployeeInfo.fromJson(Map<String, dynamic> json) {
    return EmployeeInfo(
      id: json['id'] ?? 0,
      employeeId: json['employeeId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employeeId': employeeId,
      'name': name,
    };
  }
}

class LeavePeriod {
  final int year;
  final int month;

  LeavePeriod({
    required this.year,
    required this.month,
  });

  factory LeavePeriod.fromJson(Map<String, dynamic> json) {
    return LeavePeriod(
      year: json['year'] ?? 0,
      month: json['month'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'year': year,
      'month': month,
    };
  }

  String get monthName {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months.isNotEmpty && month > 0 && month <= 12 
        ? months[month - 1] 
        : 'Unknown';
  }
}

class LeaveBalance {
  final String leaveType;
  final bool isPaid;
  final dynamic monthlyAllowance;
  final dynamic yearlyAllowance;
  final int usedThisMonth;
  final int usedThisYear;
  final dynamic remainingThisMonth;
  final dynamic remainingThisYear;

  LeaveBalance({
    required this.leaveType,
    required this.isPaid,
    required this.monthlyAllowance,
    required this.yearlyAllowance,
    required this.usedThisMonth,
    required this.usedThisYear,
    required this.remainingThisMonth,
    required this.remainingThisYear,
  });

  factory LeaveBalance.fromJson(Map<String, dynamic> json) {
    return LeaveBalance(
      leaveType: json['leaveType']?.toString() ?? '',
      isPaid: json['isPaid'] ?? false,
      monthlyAllowance: json['monthlyAllowance'],
      yearlyAllowance: json['yearlyAllowance'],
      usedThisMonth: json['usedThisMonth'] ?? 0,
      usedThisYear: json['usedThisYear'] ?? 0,
      remainingThisMonth: json['remainingThisMonth'],
      remainingThisYear: json['remainingThisYear'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'leaveType': leaveType,
      'isPaid': isPaid,
      'monthlyAllowance': monthlyAllowance,
      'yearlyAllowance': yearlyAllowance,
      'usedThisMonth': usedThisMonth,
      'usedThisYear': usedThisYear,
      'remainingThisMonth': remainingThisMonth,
      'remainingThisYear': remainingThisYear,
    };
  }

  String get monthlyAllowanceText {
    if (monthlyAllowance == null) return 'N/A';
    if (monthlyAllowance is String) return monthlyAllowance;
    return monthlyAllowance.toString();
  }

  String get yearlyAllowanceText {
    if (yearlyAllowance == null) return 'N/A';
    if (yearlyAllowance is String) return yearlyAllowance;
    return yearlyAllowance.toString();
  }

  String get remainingThisMonthText {
    if (remainingThisMonth == null) return 'N/A';
    if (remainingThisMonth is String) return remainingThisMonth;
    return remainingThisMonth.toString();
  }

  String get remainingThisYearText {
    if (remainingThisYear == null) return 'N/A';
    if (remainingThisYear is String) return remainingThisYear;
    return remainingThisYear.toString();
  }

  bool get isUncapped => monthlyAllowanceText == 'Uncapped';
}
