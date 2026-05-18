import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

enum DeadlinePriority { low, medium, high, urgent }

enum DeadlineStatus { todo, inProgress, completed }

extension DeadlinePriorityExtension on DeadlinePriority {
  String get displayName {
    switch (this) {
      case DeadlinePriority.low:
        return 'Low';
      case DeadlinePriority.medium:
        return 'Medium';
      case DeadlinePriority.high:
        return 'High';
      case DeadlinePriority.urgent:
        return 'Urgent';
    }
  }

  Color get color {
    switch (this) {
      case DeadlinePriority.low:
        return const Color(0xFF64748B); // Slate
      case DeadlinePriority.medium:
        return const Color(0xFF3B82F6); // Blue
      case DeadlinePriority.high:
        return const Color(0xFFF59E0B); // Amber
      case DeadlinePriority.urgent:
        return const Color(0xFFEF4444); // Red
    }
  }

  IconData get icon {
    switch (this) {
      case DeadlinePriority.low:
        return Icons.arrow_downward;
      case DeadlinePriority.medium:
        return Icons.remove;
      case DeadlinePriority.high:
        return Icons.arrow_upward;
      case DeadlinePriority.urgent:
        return Icons.priority_high;
    }
  }
}

extension DeadlineStatusExtension on DeadlineStatus {
  String get displayName {
    switch (this) {
      case DeadlineStatus.todo:
        return 'To Do';
      case DeadlineStatus.inProgress:
        return 'In Progress';
      case DeadlineStatus.completed:
        return 'Completed';
    }
  }

  Color get color {
    switch (this) {
      case DeadlineStatus.todo:
        return const Color(0xFF64748B);
      case DeadlineStatus.inProgress:
        return const Color(0xFF3B82F6);
      case DeadlineStatus.completed:
        return const Color(0xFF10B981);
    }
  }

  IconData get icon {
    switch (this) {
      case DeadlineStatus.todo:
        return Icons.radio_button_unchecked;
      case DeadlineStatus.inProgress:
        return Icons.timelapse;
      case DeadlineStatus.completed:
        return Icons.check_circle;
    }
  }
}

class Deadline {
  final String id;
  final String title;
  final String? description;
  final String? moduleCode;
  final DateTime dueDate;
  final DeadlinePriority priority;
  final DeadlineStatus status;
  final double estimatedHours;
  final DateTime createdAt;
  final DateTime? completedAt;

  Deadline({
    String? id,
    required this.title,
    this.description,
    this.moduleCode,
    required this.dueDate,
    this.priority = DeadlinePriority.medium,
    this.status = DeadlineStatus.todo,
    this.estimatedHours = 0,
    DateTime? createdAt,
    this.completedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Deadline copyWith({
    String? title,
    String? description,
    String? moduleCode,
    DateTime? dueDate,
    DeadlinePriority? priority,
    DeadlineStatus? status,
    double? estimatedHours,
    DateTime? completedAt,
  }) {
    return Deadline(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      moduleCode: moduleCode ?? this.moduleCode,
      dueDate: dueDate ?? this.dueDate,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      estimatedHours: estimatedHours ?? this.estimatedHours,
      createdAt: createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  // ==================== COMPUTED PROPERTIES ====================

  Duration get timeRemaining => dueDate.difference(DateTime.now());

  int get daysRemaining => timeRemaining.inDays;

  bool get isOverdue =>
      dueDate.isBefore(DateTime.now()) && status != DeadlineStatus.completed;

  bool get isDueToday {
    final now = DateTime.now();
    return dueDate.year == now.year &&
        dueDate.month == now.month &&
        dueDate.day == now.day &&
        status != DeadlineStatus.completed;
  }

  bool get isDueThisWeek {
    final now = DateTime.now();
    final weekFromNow = now.add(const Duration(days: 7));
    return dueDate.isAfter(now) &&
        dueDate.isBefore(weekFromNow) &&
        status != DeadlineStatus.completed;
  }

  String get timeRemainingText {
    if (status == DeadlineStatus.completed) return 'Completed';
    if (isOverdue) {
      final overdueDays = -daysRemaining;
      if (overdueDays == 0) return 'Due today (overdue)';
      if (overdueDays == 1) return '1 day overdue';
      return '$overdueDays days overdue';
    }
    if (daysRemaining == 0) return 'Due today';
    if (daysRemaining == 1) return 'Due tomorrow';
    if (daysRemaining < 7) return 'Due in $daysRemaining days';
    if (daysRemaining < 14) return 'Due in 1 week';
    return 'Due in $daysRemaining days';
  }

  Color get urgencyColor {
    if (status == DeadlineStatus.completed) return const Color(0xFF10B981);
    if (isOverdue) return const Color(0xFFEF4444);
    if (daysRemaining <= 1) return const Color(0xFFEF4444);
    if (daysRemaining <= 3) return const Color(0xFFF59E0B);
    if (daysRemaining <= 7) return const Color(0xFF3B82F6);
    return const Color(0xFF64748B);
  }

  // ==================== SERIALIZATION ====================

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'moduleCode': moduleCode,
      'dueDate': dueDate.toIso8601String(),
      'priority': priority.index,
      'status': status.index,
      'estimatedHours': estimatedHours,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  factory Deadline.fromJson(Map<String, dynamic> json) {
    return Deadline(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      moduleCode: json['moduleCode'],
      dueDate: DateTime.parse(json['dueDate']),
      priority: DeadlinePriority.values[json['priority'] ?? 1],
      status: DeadlineStatus.values[json['status'] ?? 0],
      estimatedHours: (json['estimatedHours'] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.parse(json['createdAt']),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'])
          : null,
    );
  }
}