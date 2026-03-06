import 'package:flutter/material.dart';

class FreeTimeSlot {
  final DateTime startTime;
  final DateTime endTime;
  final DateTime day;

  FreeTimeSlot({
    required this.startTime,
    required this.endTime,
    required this.day,
  });

  Duration get duration => endTime.difference(startTime);

  String get formattedDuration {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (hours > 0 && minutes > 0) {
      return '${hours}h ${minutes}m';
    } else if (hours > 0) {
      return '${hours}h';
    } else {
      return '${minutes}m';
    }
  }

  bool containsTime(TimeOfDay time) {
    final timeDateTime = DateTime(
      day.year,
      day.month,
      day.day,
      time.hour,
      time.minute,
    );
    return timeDateTime.isAfter(startTime) && timeDateTime.isBefore(endTime);
  }
}
