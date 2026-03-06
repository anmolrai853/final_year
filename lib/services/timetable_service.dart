import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:icalendar_parser/icalendar_parser.dart';
import 'package:intl/intl.dart';
import '../models/event.dart';
import '../models/free_time_slot.dart';
import '../models/study_session.dart';

class TimetableService {
  static final TimetableService _instance = TimetableService._internal();
  factory TimetableService() => _instance;
  TimetableService._internal();

  List<CalendarEvent> _events = [];
  List<CalendarEvent> get events => List.unmodifiable(_events);

  Future<List<CalendarEvent>> parseIcsContent(String icsContent) async {
    try {
      debugPrint('=== ICS PARSER START ===');
      debugPrint('Content length: ${icsContent.length}');
      debugPrint('First 500 chars: ${icsContent.substring(0, icsContent.length > 500 ? 500 : icsContent.length)}');

      final iCalendar = ICalendar.fromString(icsContent);
      debugPrint('ICalendar version: ${iCalendar.version}');
      debugPrint('Data count: ${iCalendar.data.length}');

      final List<CalendarEvent> parsedEvents = [];

      for (final component in iCalendar.data) {
        final type = component['type'];
        debugPrint('Found component: $type');

        if (type == 'VEVENT') {
          final event = _parseVEvent(component);
          if (event != null) {
            debugPrint('✓ Parsed: ${event.title} at ${event.startTime}');
            parsedEvents.add(event);

            if (event.rrule != null) {
              final recurring = _expandRecurringEvent(event);
              debugPrint('  + $recurring recurring instances');
              parsedEvents.addAll(recurring);
            }
          } else {
            debugPrint('✗ Failed to parse VEVENT: $component');
          }
        }
      }

      _events = parsedEvents..sort((a, b) => a.startTime.compareTo(b.startTime));
      debugPrint('=== TOTAL EVENTS: ${_events.length} ===');

      return _events;
    } catch (e, stackTrace) {
      debugPrint('ERROR parsing ICS: $e');
      debugPrint('Stack trace: $stackTrace');
      return [];
    }
  }

  CalendarEvent? _parseVEvent(Map<String, dynamic> component) {
    try {
      final summary = component['summary'] as String? ?? 'Untitled Event';
      final description = component['description'] as String?;
      final location = component['location'] as String?;
      final dtStart = component['dtstart'] as String?;
      final dtEnd = component['dtend'] as String?;
      final rrule = component['rrule'] as String?;

      debugPrint('Parsing VEVENT: $summary');
      debugPrint('  dtstart: $dtStart, dtend: $dtEnd');

      if (dtStart == null) {
        debugPrint('  ✗ Missing dtstart');
        return null;
      }

      final startTime = _parseDateTime(dtStart);
      final endTime = dtEnd != null
          ? _parseDateTime(dtEnd)
          : startTime.add(const Duration(hours: 1));

      // Extract module code from title (e.g., "M21276/1THEORETICAL..." -> "M21276")
      final moduleCode = _extractModuleCode(summary);
      debugPrint('  Module: $moduleCode');

      return CalendarEvent(
        title: summary,
        description: description,
        startTime: startTime,
        endTime: endTime,
        location: location,
        moduleCode: moduleCode,
        rrule: rrule,
        isRecurring: rrule != null,
      );
    } catch (e, stackTrace) {
      debugPrint('ERROR parsing VEVENT: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Parse datetime string from ICS format - FIXED VERSION
  DateTime _parseDateTime(String dtString) {
    String cleaned = dtString.trim();
    debugPrint('Parsing datetime: $cleaned');

    try {
      // Handle ISO 8601 format with timezone: 2025-09-29T14:00:00+01:00
      if (cleaned.contains('-') && cleaned.contains('T')) {
        // Dart's DateTime.parse handles ISO 8601
        // But we need to handle the timezone offset properly
        if (cleaned.contains('+') || cleaned.contains('Z')) {
          // Has timezone info - parse as UTC then convert to local
          final dt = DateTime.parse(cleaned);
          return dt.toLocal();
        } else {
          // No timezone - assume local
          return DateTime.parse(cleaned);
        }
      }

      // Handle compact format: 20250929T140000
      if (cleaned.contains('T')) {
        final datePart = cleaned.substring(0, 8);
        final timePart = cleaned.substring(9);

        final year = int.parse(datePart.substring(0, 4));
        final month = int.parse(datePart.substring(4, 6));
        final day = int.parse(datePart.substring(6, 8));

        final hour = int.parse(timePart.substring(0, 2));
        final minute = int.parse(timePart.substring(2, 4));
        final second = timePart.length >= 6 ? int.parse(timePart.substring(4, 6)) : 0;

        // Check for UTC marker
        final isUtc = cleaned.endsWith('Z');

        var dt = DateTime(year, month, day, hour, minute, second);
        if (isUtc) {
          dt = dt.toLocal();
        }
        return dt;
      }

      // Date only format: 20250929
      if (cleaned.length == 8) {
        final year = int.parse(cleaned.substring(0, 4));
        final month = int.parse(cleaned.substring(4, 6));
        final day = int.parse(cleaned.substring(6, 8));
        return DateTime(year, month, day);
      }

      // Fallback - try standard parse
      return DateTime.parse(cleaned);

    } catch (e) {
      debugPrint('ERROR parsing datetime "$dtString": $e');
      // Return current time as fallback (so event still shows up)
      return DateTime.now();
    }
  }


  /// Extract module code from event title - FIXED for your format
  String? _extractModuleCode(String title) {
    // Your format: "M21276/1THEORETICAL COMPUTER SCIENCE..."
    // Also: "M26507/2BUSINESS ANALYTICS..."
    // Also: "M30225/2DISTRIBUTED SYSTEMS..."

    // Match M##### or I##### patterns at the start
    final regex = RegExp(r'^([MI]\d{5})');
    final match = regex.firstMatch(title);
    if (match != null) {
      return match.group(1);
    }

    // Fallback: match any 2-4 letters + 3-4 digits pattern
    final fallbackRegex = RegExp(r'^([A-Z]{2,4}\d{3,4})');
    final fallbackMatch = fallbackRegex.firstMatch(title);
    return fallbackMatch?.group(1);
  }

  /// Expand recurring events based on RRULE
  List<CalendarEvent> _expandRecurringEvent(CalendarEvent event) {
    final List<CalendarEvent> expanded = [];

    if (event.rrule == null) return expanded;

    try {
      final rrule = _parseRRule(event.rrule!);
      final freq = rrule['FREQ'];
      final interval = int.parse(rrule['INTERVAL'] ?? '1');
      final count = rrule['COUNT'] != null ? int.parse(rrule['COUNT']!) : null;
      final until = rrule['UNTIL'] != null ? _parseDateTime(rrule['UNTIL']!) : null;
      final byDay = rrule['BYDAY']?.split(',');

      // Generate occurrences for next 12 weeks
      var currentStart = event.startTime;
      var currentEnd = event.endTime;
      int occurrenceCount = 0;
      final maxDate = DateTime.now().add(const Duration(days: 84)); // 12 weeks
      final maxOccurrences = count ?? 50;

      while (occurrenceCount < maxOccurrences && currentStart.isBefore(maxDate)) {
        // Check UNTIL limit
        if (until != null && currentStart.isAfter(until)) break;

        // Check BYDAY constraint
        if (byDay != null) {
          final currentDayName = _getDayName(currentStart.weekday);
          if (!byDay.contains(currentDayName)) {
            currentStart = currentStart.add(const Duration(days: 1));
            currentEnd = currentEnd.add(const Duration(days: 1));
            continue;
          }
        }

        // Skip the original event date
        if (!currentStart.isAtSameMomentAs(event.startTime)) {
          expanded.add(CalendarEvent(
            title: event.title,
            description: event.description,
            startTime: currentStart,
            endTime: currentEnd,
            location: event.location,
            moduleCode: event.moduleCode,
            isRecurring: true,
          ));
        }

        occurrenceCount++;

        // Advance to next occurrence
        switch (freq) {
          case 'DAILY':
            currentStart = currentStart.add(Duration(days: interval));
            currentEnd = currentEnd.add(Duration(days: interval));
            break;
          case 'WEEKLY':
            currentStart = currentStart.add(Duration(days: 7 * interval));
            currentEnd = currentEnd.add(Duration(days: 7 * interval));
            break;
          case 'MONTHLY':
            currentStart = DateTime(
              currentStart.year,
              currentStart.month + interval,
              currentStart.day,
              currentStart.hour,
              currentStart.minute,
            );
            currentEnd = DateTime(
              currentEnd.year,
              currentEnd.month + interval,
              currentEnd.day,
              currentEnd.hour,
              currentEnd.minute,
            );
            break;
          default:
            currentStart = currentStart.add(Duration(days: 7 * interval));
            currentEnd = currentEnd.add(Duration(days: 7 * interval));
        }
      }
    } catch (e) {
      debugPrint('Error expanding RRULE: $e');
    }

    return expanded;
  }

  /// Parse RRULE string into map
  Map<String, String> _parseRRule(String rrule) {
    final Map<String, String> result = {};
    final parts = rrule.split(';');

    for (final part in parts) {
      final keyValue = part.split('=');
      if (keyValue.length == 2) {
        result[keyValue[0]] = keyValue[1];
      }
    }

    return result;
  }

  /// Get day name for BYDAY
  String _getDayName(int weekday) {
    const days = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];
    return days[weekday - 1];
  }

  /// Get the next upcoming event
  CalendarEvent? getNextEvent() {
    final now = DateTime.now();
    final upcoming = _events.where((e) => e.endTime.isAfter(now)).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    return upcoming.isNotEmpty ? upcoming.first : null;
  }

  /// Get events for a specific day
  List<CalendarEvent> getEventsForDay(DateTime day) {
    return _events.where((event) {
      return event.startTime.year == day.year &&
             event.startTime.month == day.month &&
             event.startTime.day == day.day;
    }).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  /// Get events for a date range
  List<CalendarEvent> getEventsForRange(DateTime start, DateTime end) {
    return _events.where((event) {
      return event.startTime.isBefore(end) && event.endTime.isAfter(start);
    }).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  /// Get events for a specific week
  List<CalendarEvent> getEventsForWeek(DateTime weekStart) {
    final weekEnd = weekStart.add(const Duration(days: 7));
    return getEventsForRange(weekStart, weekEnd);
  }

  /// Find free time slots between classes on a specific day
  List<FreeTimeSlot> findFreeTimeSlots(
    DateTime day, {
    TimeOfDay? dayStart,
    TimeOfDay? dayEnd,
    List<StudySession>? studySessions,
  }) {
    final slots = <FreeTimeSlot>[];

    final startOfDay = DateTime(day.year, day.month, day.day,
      dayStart?.hour ?? 8, dayStart?.minute ?? 0);
    final endOfDay = DateTime(day.year, day.month, day.day,
      dayEnd?.hour ?? 18, dayEnd?.minute ?? 0);

    // Get all events for the day
    var dayEvents = getEventsForDay(day);

    // Add study sessions as blocked time
    if (studySessions != null) {
      final daySessions = studySessions.where((s) {
        return s.startTime.year == day.year &&
               s.startTime.month == day.month &&
               s.startTime.day == day.day;
      });

      for (final session in daySessions) {
        dayEvents.add(CalendarEvent(
          title: session.title,
          startTime: session.startTime,
          endTime: session.endTime,
          moduleCode: session.moduleCode,
          overrideColor: session.type.color,
        ));
      }
    }

    dayEvents.sort((a, b) => a.startTime.compareTo(b.startTime));

    // Find gaps between events
    var currentTime = startOfDay;

    for (final event in dayEvents) {
      if (event.startTime.isAfter(currentTime)) {
        final gap = event.startTime.difference(currentTime);
        if (gap.inMinutes >= 30) { // Minimum 30 min for study session
          slots.add(FreeTimeSlot(
            startTime: currentTime,
            endTime: event.startTime,
            day: day,
          ));
        }
      }
      if (event.endTime.isAfter(currentTime)) {
        currentTime = event.endTime;
      }
    }

    // Check for free time after last event
    if (currentTime.isBefore(endOfDay)) {
      final gap = endOfDay.difference(currentTime);
      if (gap.inMinutes >= 30) {
        slots.add(FreeTimeSlot(
          startTime: currentTime,
          endTime: endOfDay,
          day: day,
        ));
      }
    }

    return slots;
  }

  /// Get smart time range for timetable display
  /// Returns [startHour, endHour] based on existing events
  List<int> getSmartTimeRange() {
    if (_events.isEmpty) {
      return [8, 18]; // Default range
    }

    var minHour = 23;
    var maxHour = 0;

    for (final event in _events) {
      final startHour = event.startTime.hour;
      final endHour = event.endTime.hour + (event.endTime.minute > 0 ? 1 : 0);

      if (startHour < minHour) minHour = startHour;
      if (endHour > maxHour) maxHour = endHour;
    }

    // Add padding (±1 hour)
    minHour = (minHour - 1).clamp(0, 23);
    maxHour = (maxHour + 1).clamp(0, 24);

    return [minHour, maxHour];
  }

  /// Get all unique module codes from events
  List<String> getModuleCodes() {
    final codes = _events
      .where((e) => e.moduleCode != null)
      .map((e) => e.moduleCode!)
      .toSet()
      .toList();
    codes.sort();
    return codes;
  }

  /// Get color for a module (consistent hash-based)
  Color getModuleColor(String? moduleCode) {
    if (moduleCode == null) return Colors.grey;

    final colors = [
      const Color(0xFF3B82F6), // Blue
      const Color(0xFF8B5CF6), // Violet
      const Color(0xFFEC4899), // Pink
      const Color(0xFFF59E0B), // Amber
      const Color(0xFF10B981), // Emerald
      const Color(0xFF06B6D4), // Cyan
      const Color(0xFFF97316), // Orange
      const Color(0xFF84CC16), // Lime
      const Color(0xFFEF4444), // Red
      const Color(0xFF6366F1), // Indigo
    ];

    var hash = 0;
    for (var i = 0; i < moduleCode.length; i++) {
      hash = moduleCode.codeUnitAt(i) + ((hash << 5) - hash);
    }

    return colors[hash.abs() % colors.length];
  }

  /// Clear all events
  void clearEvents() {
    _events = [];
  }

  /// Set events directly (for loading from storage)
  void setEvents(List<CalendarEvent> events) {
    _events = events..sort((a, b) => a.startTime.compareTo(b.startTime));
  }
}
