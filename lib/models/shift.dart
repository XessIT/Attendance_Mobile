import 'package:flutter/material.dart';

class Shift {
  final int? id;
  final String name;
  final String fromTime;
  final String toTime;
  final bool hasGracePeriod;
  final String? graceFromTime;
  final String? graceToTime;
  final int? gracePeriodMinutes; // For API compatibility
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Shift({
    this.id,
    required this.name,
    required this.fromTime,
    required this.toTime,
    required this.hasGracePeriod,
    this.graceFromTime,
    this.graceToTime,
    this.gracePeriodMinutes,
    this.createdAt,
    this.updatedAt,
  });

  // Convert TimeOfDay to string format (HH:mm)
  static String timeOfDayToString(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  // Convert string format (HH:mm) to TimeOfDay
  static TimeOfDay stringToTimeOfDay(String timeString) {
    final parts = timeString.split(':');
    return TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
  }

  // Convert HH:MM to HH:MM:SS format for API
  static String timeToApiFormat(String timeString) {
    return '${timeString}:00';
  }

  // Convert HH:MM:SS to HH:MM format for internal use
  static String timeFromApiFormat(String? timeString) {
    if (timeString == null || timeString.length < 5) return timeString ?? '';
    return timeString.substring(0, 5); // Remove seconds if present
  }

  // Calculate grace period in minutes from grace times
  int? get calculatedGracePeriodMinutes {
    if (!hasGracePeriod || graceFromTime == null || graceToTime == null) {
      return null;
    }

    try {
      final fromTimeOfDay = stringToTimeOfDay(graceFromTime!);
      final toTimeOfDay = stringToTimeOfDay(graceToTime!);

      final fromMinutes = fromTimeOfDay.hour * 60 + fromTimeOfDay.minute;
      final toMinutes = toTimeOfDay.hour * 60 + toTimeOfDay.minute;

      return toMinutes - fromMinutes;
    } catch (e) {
      return null;
    }
  }

  // Factory constructor to create Shift from JSON
  factory Shift.fromJson(Map<String, dynamic> json) {
    return Shift(
      id: json['id'],
      name: json['name'] ?? json['shiftName'] ?? json['shift_name'] ?? '',
      fromTime: json['from_time'] ?? json['fromTime'] ?? '',
      toTime: json['to_time'] ?? json['toTime'] ?? '',
      hasGracePeriod: json['has_grace_period'] ?? json['hasGracePeriod'] ?? false,
      graceFromTime: json['grace_from_time'] ?? json['graceFromTime'],
      graceToTime: json['grace_to_time'] ?? json['graceToTime'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  // Convert Shift to JSON (for local storage)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'from_time': fromTime,
      'to_time': toTime,
      'has_grace_period': hasGracePeriod,
      'grace_from_time': graceFromTime,
      'grace_to_time': graceToTime,
      'grace_period_minutes': gracePeriodMinutes,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  // Convert Shift to API format (for create/update)
  Map<String, dynamic> toApiJson({bool includeAllFields = true}) {
    final gracePeriod = gracePeriodMinutes ?? calculatedGracePeriodMinutes ?? 0;

    // For updates, API might only need essential fields
    if (!includeAllFields) {
      final Map<String, dynamic> essentialData = {
        'fromTime': timeToApiFormat(fromTime),
        'toTime': timeToApiFormat(toTime),
      };

      // Add optional fields only if they have values
      if (name.isNotEmpty) {
        essentialData['shiftName'] = name;
      }
      if (hasGracePeriod) {
        essentialData['gracePeriod'] = gracePeriod;
        if (graceFromTime != null) {
          essentialData['graceFromTime'] = timeToApiFormat(graceFromTime!);
        }
        if (graceToTime != null) {
          essentialData['graceToTime'] = timeToApiFormat(graceToTime!);
        }
      }

      return essentialData;
    }

    // Full data for create operations
    return {
      'shiftName': name,
      'fromTime': timeToApiFormat(fromTime),
      'toTime': timeToApiFormat(toTime),
      'gracePeriod': hasGracePeriod ? gracePeriod : 0,
      'graceFromTime': hasGracePeriod && graceFromTime != null ? timeToApiFormat(graceFromTime!) : null,
      'graceToTime': hasGracePeriod && graceToTime != null ? timeToApiFormat(graceToTime!) : null,
    };
  }

  // Create Shift from API response
  factory Shift.fromApiJson(Map<String, dynamic> json) {
    return Shift(
      id: json['id'],
      name: json['shiftName'] ?? json['shift_name'] ?? json['name'] ?? json['shift'] ?? '',
      fromTime: timeFromApiFormat(json['fromTime'] ?? json['from_time']),
      toTime: timeFromApiFormat(json['toTime'] ?? json['to_time']),
      hasGracePeriod: (json['gracePeriod'] ?? json['grace_period'] ?? 0) > 0,
      graceFromTime: timeFromApiFormat(json['graceFromTime'] ?? json['grace_from_time']),
      graceToTime: timeFromApiFormat(json['graceToTime'] ?? json['grace_to_time']),
      gracePeriodMinutes: json['gracePeriod'] ?? json['grace_period'],
    );
  }

  // Create a copy with updated values
  Shift copyWith({
    int? id,
    String? name,
    String? fromTime,
    String? toTime,
    bool? hasGracePeriod,
    String? graceFromTime,
    String? graceToTime,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Shift(
      id: id ?? this.id,
      name: name ?? this.name,
      fromTime: fromTime ?? this.fromTime,
      toTime: toTime ?? this.toTime,
      hasGracePeriod: hasGracePeriod ?? this.hasGracePeriod,
      graceFromTime: graceFromTime ?? this.graceFromTime,
      graceToTime: graceToTime ?? this.graceToTime,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Get formatted time strings for display (simple HH:MM format)
  String get formattedFromTime {
    return fromTime;
  }

  String get formattedToTime {
    return toTime;
  }

  String? get formattedGraceFromTime {
    return graceFromTime;
  }

  String? get formattedGraceToTime {
    return graceToTime;
  }

  // Override equality operator
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is Shift &&
        other.id == id &&
        other.name == name &&
        other.fromTime == fromTime &&
        other.toTime == toTime &&
        other.hasGracePeriod == hasGracePeriod &&
        other.graceFromTime == graceFromTime &&
        other.graceToTime == graceToTime &&
        other.gracePeriodMinutes == gracePeriodMinutes;
  }

  // Override hashCode
  @override
  int get hashCode {
    return Object.hash(
      id,
      name,
      fromTime,
      toTime,
      hasGracePeriod,
      graceFromTime,
      graceToTime,
      gracePeriodMinutes,
    );
  }
}
