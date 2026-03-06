import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

enum StudySessionType {
  revision,
  coursework,
  reading,
  practice,
  review,
}

enum FocusLevel {
  distracted,    // 1 star - many interruptions
  fair,         // 2 stars - some interruptions
  good,         // 3 stars - minor distractions
  focused,      // 4 stars - mostly focused
  deepWork,     // 5 stars - complete flow state
}

extension StudySessionTypeExtension on StudySessionType {
  String get displayName {
    switch (this) {
      case StudySessionType.revision:
        return 'Revision';
      case StudySessionType.coursework:
        return 'Coursework';
      case StudySessionType.reading:
        return 'Reading';
      case StudySessionType.practice:
        return 'Practice';
      case StudySessionType.review:
        return 'Review';
    }
  }

  Color get color {
    switch (this) {
      case StudySessionType.revision:
        return const Color(0xFF3B82F6); // Blue
      case StudySessionType.coursework:
        return const Color(0xFFF59E0B); // Amber
      case StudySessionType.reading:
        return const Color(0xFF10B981); // Emerald
      case StudySessionType.practice:
        return const Color(0xFF8B5CF6); // Violet
      case StudySessionType.review:
        return const Color(0xFFEC4899); // Pink
    }
  }

  IconData get icon {
    switch (this) {
      case StudySessionType.revision:
        return Icons.menu_book;
      case StudySessionType.coursework:
        return Icons.assignment;
      case StudySessionType.reading:
        return Icons.auto_stories;
      case StudySessionType.practice:
        return Icons.code;
      case StudySessionType.review:
        return Icons.rate_review;
    }
  }
}

extension FocusLevelExtension on FocusLevel {
  String get label {
    switch (this) {
      case FocusLevel.distracted:
        return 'Distracted';
      case FocusLevel.fair:
        return 'Fair';
      case FocusLevel.good:
        return 'Good';
      case FocusLevel.focused:
        return 'Focused';
      case FocusLevel.deepWork:
        return 'Deep Work';
    }
  }

  int get stars {
    switch (this) {
      case FocusLevel.distracted:
        return 1;
      case FocusLevel.fair:
        return 2;
      case FocusLevel.good:
        return 3;
      case FocusLevel.focused:
        return 4;
      case FocusLevel.deepWork:
        return 5;
    }
  }

  Color get color {
    switch (this) {
      case FocusLevel.distracted:
        return const Color(0xFFEF4444); // Red
      case FocusLevel.fair:
        return const Color(0xFFF97316); // Orange
      case FocusLevel.good:
        return const Color(0xFFF59E0B); // Amber
      case FocusLevel.focused:
        return const Color(0xFF3B82F6); // Blue
      case FocusLevel.deepWork:
        return const Color(0xFF10B981); // Emerald
    }
  }
}

class StudySession {
  final String id;
  final String title;
  final StudySessionType type;
  final DateTime startTime;
  final int durationMinutes; // Planned duration
  final bool isCompleted;
  final String? moduleCode;
  final String? notes;

  // Performance tracking fields
  final int? actualDurationMinutes; // Actual time spent studying
  final FocusLevel? focusLevel;     // 1-5 star rating
  final int? interruptionCount;     // Number of interruptions
  final String? topicsCovered;      // What was studied
  final int? understandingRating;   // 1-5 how well they understood
  final bool? completedFullSession; // Did they study full planned time?
  final DateTime? completedAt;      // When they marked it complete

  StudySession({
    String? id,
    required this.title,
    required this.type,
    required this.startTime,
    required this.durationMinutes,
    this.isCompleted = false,
    this.moduleCode,
    this.notes,
    // Performance fields
    this.actualDurationMinutes,
    this.focusLevel,
    this.interruptionCount,
    this.topicsCovered,
    this.understandingRating,
    this.completedFullSession,
    this.completedAt,
  }) : id = id ?? const Uuid().v4();

  StudySession copyWith({
    String? title,
    StudySessionType? type,
    DateTime? startTime,
    int? durationMinutes,
    bool? isCompleted,
    String? moduleCode,
    String? notes,
    int? actualDurationMinutes,
    FocusLevel? focusLevel,
    int? interruptionCount,
    String? topicsCovered,
    int? understandingRating,
    bool? completedFullSession,
    DateTime? completedAt,
  }) {
    return StudySession(
      id: id,
      title: title ?? this.title,
      type: type ?? this.type,
      startTime: startTime ?? this.startTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      isCompleted: isCompleted ?? this.isCompleted,
      moduleCode: moduleCode ?? this.moduleCode,
      notes: notes ?? this.notes,
      actualDurationMinutes: actualDurationMinutes ?? this.actualDurationMinutes,
      focusLevel: focusLevel ?? this.focusLevel,
      interruptionCount: interruptionCount ?? this.interruptionCount,
      topicsCovered: topicsCovered ?? this.topicsCovered,
      understandingRating: understandingRating ?? this.understandingRating,
      completedFullSession: completedFullSession ?? this.completedFullSession,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  DateTime get endTime => startTime.add(Duration(minutes: durationMinutes));
  Duration get duration => Duration(minutes: durationMinutes);
  bool get isPast => endTime.isBefore(DateTime.now());
  bool get isOngoing => startTime.isBefore(DateTime.now()) && endTime.isAfter(DateTime.now());

  // Performance metrics
  double get completionRate {
    if (actualDurationMinutes == null || durationMinutes == 0) return 0.0;
    return (actualDurationMinutes! / durationMinutes).clamp(0.0, 2.0); // Can exceed 100%
  }

  double get efficiencyScore {
    if (focusLevel == null || actualDurationMinutes == null) return 0.0;
    final focusMultiplier = focusLevel!.stars / 5.0;
    final timeRatio = (actualDurationMinutes! / durationMinutes).clamp(0.0, 1.0);
    return (focusMultiplier * timeRatio * 100);
  }

  bool get hasPerformanceData => focusLevel != null && actualDurationMinutes != null;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'type': type.index,
      'startTime': startTime.toIso8601String(),
      'durationMinutes': durationMinutes,
      'isCompleted': isCompleted,
      'moduleCode': moduleCode,
      'notes': notes,
      'actualDurationMinutes': actualDurationMinutes,
      'focusLevel': focusLevel?.index,
      'interruptionCount': interruptionCount,
      'topicsCovered': topicsCovered,
      'understandingRating': understandingRating,
      'completedFullSession': completedFullSession,
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  factory StudySession.fromJson(Map<String, dynamic> json) {
    return StudySession(
      id: json['id'],
      title: json['title'],
      type: StudySessionType.values[json['type']],
      startTime: DateTime.parse(json['startTime']),
      durationMinutes: json['durationMinutes'],
      isCompleted: json['isCompleted'] ?? false,
      moduleCode: json['moduleCode'],
      notes: json['notes'],
      actualDurationMinutes: json['actualDurationMinutes'],
      focusLevel: json['focusLevel'] != null
          ? FocusLevel.values[json['focusLevel']]
          : null,
      interruptionCount: json['interruptionCount'],
      topicsCovered: json['topicsCovered'],
      understandingRating: json['understandingRating'],
      completedFullSession: json['completedFullSession'],
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'])
          : null,
    );
  }
}