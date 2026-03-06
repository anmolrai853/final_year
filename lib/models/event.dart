import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class CalendarEvent {
  final String id;
  final String title;
  final String? description;
  final DateTime startTime;
  final DateTime endTime;
  final String? location;
  final String? moduleCode;
  final String? rrule;
  final bool isRecurring;
  final Color? overrideColor;

  CalendarEvent({
    String? id,
    required this.title,
    this.description,
    required this.startTime,
    required this.endTime,
    this.location,
    this.moduleCode,
    this.rrule,
    this.isRecurring = false,
    this.overrideColor,
  }) : id = id ?? const Uuid().v4();

  CalendarEvent copyWith({
    String? title,
    String? description,
    DateTime? startTime,
    DateTime? endTime,
    String? location,
    String? moduleCode,
    String? rrule,
    bool? isRecurring,
    Color? overrideColor,
  }) {
    return CalendarEvent(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      location: location ?? this.location,
      moduleCode: moduleCode ?? this.moduleCode,
      rrule: rrule ?? this.rrule,
      isRecurring: isRecurring ?? this.isRecurring,
      overrideColor: overrideColor ?? this.overrideColor,
    );
  }

  Duration get duration => endTime.difference(startTime);

  bool get isPast => endTime.isBefore(DateTime.now());

  bool get isOngoing => 
    startTime.isBefore(DateTime.now()) && endTime.isAfter(DateTime.now());

  bool overlapsWith(CalendarEvent other) {
    return startTime.isBefore(other.endTime) && endTime.isAfter(other.startTime);
  }

  bool overlapsWithTimeRange(DateTime start, DateTime end) {
    return startTime.isBefore(end) && endTime.isAfter(start);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'location': location,
      'moduleCode': moduleCode,
      'rrule': rrule,
      'isRecurring': isRecurring,
      'overrideColor': overrideColor?.value,
    };
  }

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    return CalendarEvent(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      startTime: DateTime.parse(json['startTime']),
      endTime: DateTime.parse(json['endTime']),
      location: json['location'],
      moduleCode: json['moduleCode'],
      rrule: json['rrule'],
      isRecurring: json['isRecurring'] ?? false,
      overrideColor: json['overrideColor'] != null 
        ? Color(json['overrideColor']) 
        : null,
    );
  }
}
