import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:icalendar_parser/icalendar_parser.dart';
import 'package:intl/intl.dart';
import '../models/event.dart';
import '../models/study_session.dart';
import '../models/free_time_slot.dart';
import '../models/deadline.dart';
import '../models/gap_recommendation.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../services/analytics_service.dart';
import '../services/sm2_service.dart';

// Helper class for time blocks
class _TimeBlock {
  final DateTime start;
  final DateTime end;
  _TimeBlock(this.start, this.end);
}

class TimetableController extends ChangeNotifier {
  static final TimetableController _instance = TimetableController._internal();
  factory TimetableController() => _instance;
  TimetableController._internal();

  final StorageService _storage = StorageService();
  final NotificationService _notifications = NotificationService();

  List<Map<String, dynamic>> _instances = [];
  List<CalendarEvent> _events = [];

  bool _initialized = false;
  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;
    await _storage.initialize();

    final savedEvents = _storage.loadCalendarEvents();
    if (savedEvents.isNotEmpty) {
      _events = savedEvents;
      _instances = savedEvents.map((e) => _eventToMap(e)).toList();
      debugPrint('Loaded ${savedEvents.length} events from storage');
    }

    _initialized = true;
    notifyListeners();
  }

  Future<void> loadFromIcs(String content) async {
    debugPrint('Loading ICS content (${content.length} chars)...');

    try {
      final calendar = ICalendar.fromString(content);
      final json = calendar.toJson();

      debugPrint('ICalendar version: ${calendar.version}');
      debugPrint('Data count: ${(json['data'] as List).length}');

      final rawEvents = (json['data'] as List)
          .where((e) => e['type'] == 'VEVENT')
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      debugPrint('Found ${rawEvents.length} VEVENTs');

      final List<Map<String, dynamic>> allInstances = [];

      for (final event in rawEvents) {
        final rrule = event['rrule'];
        if (rrule != null) {
          allInstances.addAll(_expandRecurringEvent(event));
        } else {
          final dtStart = _parseDate(event['dtstart']);
          final dtEnd = _parseDate(event['dtend']);
          if (dtStart == null || dtEnd == null) continue;

          allInstances.add({
            ...event,
            'dtstart': dtStart,
            'dtend': dtEnd,
          });
        }
      }

      allInstances.sort((a, b) {
        final da = _asDateTime(a['dtstart'])!;
        final db = _asDateTime(b['dtstart'])!;
        return da.compareTo(db);
      });

      debugPrint('Total instances after expansion: ${allInstances.length}');

      if (allInstances.isEmpty) {
        throw Exception('No valid events found in ICS file');
      }

      final calendarEvents = allInstances.map((m) => _mapToEvent(m)).toList();
      await _storage.saveCalendarEvents(calendarEvents);
      await _storage.saveIcsContent(content);

      _instances = allInstances;
      _events = calendarEvents;

      notifyListeners();
      debugPrint('ICS import complete: ${_events.length} events');

    } catch (e, stackTrace) {
      debugPrint('ERROR in loadFromIcs: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }

    try {
      await _notifications.scheduleClassReminders(_events);
    } catch (e) {
      debugPrint('Failed to schedule class reminders: $e');
    }
  }

  Future<void> refresh() async {
    final savedEvents = _storage.loadCalendarEvents();
    _events = savedEvents;
    _instances = savedEvents.map((e) => _eventToMap(e)).toList();
    notifyListeners();
  }

  Future<void> clearAllData() async {
    try { await _notifications.cancelAll(); } catch (_) {}
    await _storage.clearAllData();
    _instances = [];
    _events = [];
    notifyListeners();
  }

  // ==================== EVENT METHODS ====================

  CalendarEvent? getNextEvent() {
    final now = DateTime.now();
    final upcoming = _events.where((e) => e.endTime.isAfter(now)).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    return upcoming.isNotEmpty ? upcoming.first : null;
  }

  List<CalendarEvent> getEventsForDay(DateTime day) {
    return _events.where((event) {
      return event.startTime.year == day.year &&
          event.startTime.month == day.month &&
          event.startTime.day == day.day;
    }).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  List<CalendarEvent> getEventsForRange(DateTime start, DateTime end) {
    return _events.where((event) {
      return event.startTime.isBefore(end) && event.endTime.isAfter(start);
    }).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  List<CalendarEvent> getEventsForWeek(DateTime weekStart) {
    final weekEnd = weekStart.add(const Duration(days: 7));
    return getEventsForRange(weekStart, weekEnd);
  }

  // ==================== STUDY SESSION METHODS ====================

  List<StudySession> getStudySessionsForDay(DateTime day) {
    return _storage.getStudySessionsForDay(day);
  }

  List<StudySession> getStudySessionsForWeek(DateTime weekStart) {
    return _storage.getStudySessionsForWeek(weekStart);
  }

  List<StudySession> getStudySessionsForRange(DateTime start, DateTime end) {
    return _storage.getStudySessionsForRange(start, end);
  }

  Future<void> addStudySession(StudySession session) async {
    await _storage.addStudySession(session);
    try { await _notifications.scheduleSessionReminder(session); } catch (_) {}
    notifyListeners();
  }

  Future<void> updateStudySession(StudySession session) async {
    await _storage.updateStudySession(session);
    try {
      await _notifications.cancelSessionReminder(session.id);
      if (!session.isCompleted) {
        await _notifications.scheduleSessionReminder(session);
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> deleteStudySession(String id) async {
    try { await _notifications.cancelSessionReminder(id); } catch (_) {}
    await _storage.deleteStudySession(id);
    notifyListeners();
  }

  Future<void> toggleSessionCompletion(String id) async {
    await _storage.toggleSessionCompletion(id);
    notifyListeners();
  }

  // ==================== DEADLINE METHODS ====================

  List<Deadline> getAllDeadlines() {
    return _storage.loadDeadlines()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  }

  List<Deadline> getUpcomingDeadlines() {
    return _storage.getUpcomingDeadlines();
  }

  List<Deadline> getOverdueDeadlines() {
    return _storage.getOverdueDeadlines();
  }

  List<Deadline> getDeadlinesForModule(String moduleCode) {
    return _storage.getDeadlinesForModule(moduleCode);
  }

  List<Deadline> getDeadlinesDueSoon({int days = 7}) {
    final now = DateTime.now();
    final cutoff = now.add(Duration(days: days));
    return _storage.loadDeadlines()
        .where((d) =>
    d.status != DeadlineStatus.completed &&
        d.dueDate.isBefore(cutoff))
        .toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  }

  Future<void> addDeadline(Deadline deadline) async {
    await _storage.addDeadline(deadline);
    try { await _notifications.scheduleDeadlineWarnings(deadline); } catch (_) {}
    notifyListeners();
  }

  Future<void> updateDeadline(Deadline deadline) async {
    await _storage.updateDeadline(deadline);
    try {
      await _notifications.cancelDeadlineWarnings(deadline.id);
      if (deadline.status != DeadlineStatus.completed) {
        await _notifications.scheduleDeadlineWarnings(deadline);
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> deleteDeadline(String id) async {
    try { await _notifications.cancelDeadlineWarnings(id); } catch (_) {}
    await _storage.deleteDeadline(id);
    notifyListeners();
  }

  Future<void> toggleDeadlineStatus(String id) async {
    final deadlines = _storage.loadDeadlines();
    final index = deadlines.indexWhere((d) => d.id == id);
    if (index != -1) {
      final d = deadlines[index];
      final newStatus = d.status == DeadlineStatus.completed
          ? DeadlineStatus.todo
          : DeadlineStatus.completed;
      deadlines[index] = d.copyWith(
        status: newStatus,
        completedAt: newStatus == DeadlineStatus.completed
            ? DateTime.now()
            : null,
      );
      await _storage.saveDeadlines(deadlines);

      try {
        if (newStatus == DeadlineStatus.completed) {
          await _notifications.cancelDeadlineWarnings(id);
        } else {
          await _notifications.scheduleDeadlineWarnings(deadlines[index]);
        }
      } catch (_) {}

      notifyListeners();
    }
  }

  double getLoggedHoursForDeadline(String deadlineId) {
    final sessions = _storage.loadStudySessions();
    final linked = sessions.where((s) =>
    s.isCompleted && s.deadlineId == deadlineId);
    final totalMinutes = linked.fold<int>(
        0, (sum, s) => sum + (s.actualDurationMinutes ?? s.durationMinutes));
    return totalMinutes / 60.0;
  }

  // ==================== FREE TIME SLOTS ====================

  List<FreeTimeSlot> findFreeTimeSlots(
      DateTime day, {
        TimeOfDay? dayStart,
        TimeOfDay? dayEnd,
      }) {
    final slots = <FreeTimeSlot>[];

    final startOfDay = DateTime(day.year, day.month, day.day, 0, 0);
    final endOfDay = DateTime(day.year, day.month, day.day, 23, 59);

    final dayEvents = getEventsForDay(day);
    final daySessions = getStudySessionsForDay(day);

    final blockedTimes = <_TimeBlock>[];

    for (final event in dayEvents) {
      blockedTimes.add(_TimeBlock(event.startTime, event.endTime));
    }

    for (final session in daySessions) {
      blockedTimes.add(_TimeBlock(session.startTime, session.endTime));
    }

    blockedTimes.sort((a, b) => a.start.compareTo(b.start));

    final mergedBlocks = <_TimeBlock>[];
    for (final block in blockedTimes) {
      if (mergedBlocks.isEmpty) {
        mergedBlocks.add(block);
      } else {
        final last = mergedBlocks.last;
        if (block.start.isBefore(last.end) || block.start.isAtSameMomentAs(last.end)) {
          mergedBlocks[mergedBlocks.length - 1] = _TimeBlock(
            last.start,
            block.end.isAfter(last.end) ? block.end : last.end,
          );
        } else {
          mergedBlocks.add(block);
        }
      }
    }

    var currentTime = startOfDay;

    for (final block in mergedBlocks) {
      if (block.start.isAfter(currentTime)) {
        final gap = block.start.difference(currentTime);
        if (gap.inMinutes >= 30) {
          slots.add(FreeTimeSlot(
            startTime: currentTime,
            endTime: block.start,
            day: day,
          ));
        }
      }

      if (block.end.isAfter(currentTime)) {
        currentTime = block.end;
      }
    }

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

  // ==================== GAP RECOMMENDATIONS ====================

  /// Whether enough session data exists for personalised recommendations.
  bool get hasAnalyticsData {
    final analyticsService = AnalyticsService();
    final insights = analyticsService.getInsights();
    return insights.averageEfficiency != null;
  }

  /// Generate smart gap recommendations for a given day.
  /// Cross-references free slots with optimal study hours,
  /// upcoming deadlines, and SM2 nodes due for review.
  List<GapRecommendation> getGapRecommendations(DateTime day) {
    final freeSlots = findFreeTimeSlots(day);
    if (freeSlots.isEmpty) return [];

    final analyticsService = AnalyticsService();
    final sm2Service = Sm2Service();
    final insights = analyticsService.getInsights();
    final hasData = insights.averageEfficiency != null;
    final optimalHour = insights.bestTimeToStudy?.hour;

    // Get upcoming deadlines sorted by urgency
    final urgentDeadlines = getDeadlinesDueSoon(days: 14);

    // Count SM2 nodes due for review across all maps
    final allMaps = _storage.loadKnowledgeMaps();
    int totalDueNodes = 0;
    for (final map in allMaps) {
      final graph = _storage.getKnowledgeGraphData(map.id);
      if (graph != null) {
        totalDueNodes += graph.nodes
            .where((n) => sm2Service.isDue(n))
            .length;
      }
    }

    final recommendations = <GapRecommendation>[];

    for (final slot in freeSlots) {
      final slotHour = slot.startTime.hour;
      final durationMins = slot.duration.inMinutes;

      // Determine gap quality
      GapQuality quality;
      if (!hasData) {
        // No analytics yet — use general time-of-day heuristics
        if (slotHour >= 9 && slotHour <= 12) {
          quality = GapQuality.good;
        } else if (slotHour >= 13 && slotHour <= 17) {
          quality = GapQuality.good;
        } else {
          quality = GapQuality.light;
        }
      } else {
        // Personalised: compare slot hour to user's optimal hour
        final hourDiff = (slotHour - optimalHour!).abs();
        if (hourDiff <= 1) {
          quality = GapQuality.peak;
        } else if (hourDiff <= 3) {
          quality = GapQuality.good;
        } else {
          quality = GapQuality.light;
        }
      }

      // Build contextual suggestion
      String suggestion;
      String? relatedDeadline;

      if (urgentDeadlines.isNotEmpty) {
        final soonest = urgentDeadlines.first;
        relatedDeadline = soonest.title;

        if (quality == GapQuality.peak) {
          suggestion = durationMins >= 50
              ? 'This is your peak focus window. Perfect for a Pomodoro session on your upcoming deadline.'
              : 'Your best focus time. Even a 25 minute sprint on your deadline makes a difference.';
        } else if (quality == GapQuality.good) {
          suggestion = totalDueNodes > 0
              ? 'Good time for coursework or reviewing your knowledge maps before your deadline.'
              : 'Solid study window. Good time to make progress on your upcoming deadline.';
        } else {
          suggestion = totalDueNodes > 0
              ? 'Lower energy period. Great for lighter work like reviewing knowledge maps or reading notes.'
              : 'Use this time for reading or planning your approach to the upcoming deadline.';
        }
      } else if (totalDueNodes > 0) {
        if (quality == GapQuality.peak) {
          suggestion = 'Peak focus window — ideal for deep knowledge review to strengthen your memory before it fades.';
        } else if (quality == GapQuality.good) {
          suggestion = 'Good time to work through your knowledge map reviews before they slip further.';
        } else {
          suggestion = 'Low-stakes gap — perfect for quick knowledge map review to stay on top of your memory schedule.';
        }
      } else {
        if (quality == GapQuality.peak) {
          suggestion = 'Your peak focus window. Great for revision, coursework planning, or getting ahead on readings.';
        } else if (quality == GapQuality.good) {
          suggestion = 'Good study window. Consider reading ahead or reviewing recent lecture notes.';
        } else {
          suggestion = 'Use this lighter period for reading, organising notes, or planning upcoming work.';
        }
      }

      recommendations.add(GapRecommendation(
        startTime: slot.startTime,
        endTime: slot.endTime,
        duration: slot.duration,
        quality: quality,
        suggestion: suggestion,
        relatedDeadlineTitle: relatedDeadline,
        dueNodeCount: totalDueNodes > 0 ? totalDueNodes : null,
      ));
    }

    // Sort: peak first, then chronologically within same quality
    recommendations.sort((a, b) {
      if (a.quality.index != b.quality.index) {
        return a.quality.index.compareTo(b.quality.index);
      }
      return a.startTime.compareTo(b.startTime);
    });

    return recommendations;
  }

  // ==================== UTILITY METHODS ====================

  List<String> getModuleCodes() {
    final codes = _events
        .where((e) => e.moduleCode != null)
        .map((e) => e.moduleCode!)
        .toSet()
        .toList();
    codes.sort();
    return codes;
  }

  Color getModuleColor(String? moduleCode) {
    if (moduleCode == null) return Colors.grey;

    final colors = [
      const Color(0xFF3B82F6),
      const Color(0xFF8B5CF6),
      const Color(0xFFEC4899),
      const Color(0xFFF59E0B),
      const Color(0xFF10B981),
      const Color(0xFF06B6D4),
      const Color(0xFFF97316),
      const Color(0xFF84CC16),
      const Color(0xFFEF4444),
      const Color(0xFF6366F1),
    ];

    var hash = 0;
    for (var i = 0; i < moduleCode.length; i++) {
      hash = moduleCode.codeUnitAt(i) + ((hash << 5) - hash);
    }

    return colors[hash.abs() % colors.length];
  }

  List<int> getSmartTimeRange() {
    return [0, 24];
  }

  bool hasConflict(DateTime start, DateTime end, {String? excludeSessionId}) {
    for (final event in _events) {
      if (start.isBefore(event.endTime) && end.isAfter(event.startTime)) {
        return true;
      }
    }

    final sessions = _storage
        .getStudySessionsForRange(start, end)
        .where((s) => s.id != excludeSessionId);

    return sessions.isNotEmpty;
  }

  Future<void> updateEventLocation(String eventId, String location) async {
    await _storage.saveEventLocation(eventId, location);
    notifyListeners();
  }

  String? getEventLocation(String eventId) {
    return _storage.getEventLocation(eventId);
  }

  // ==================== PARSING HELPERS ====================

  DateTime? _parseDate(dynamic dtObj) {
    if (dtObj == null) return null;
    if (dtObj is DateTime) return dtObj;

    if (dtObj is Map && dtObj['dt'] is String) {
      var raw = dtObj['dt'] as String;

      if (raw.endsWith('Z')) raw = raw.substring(0, raw.length - 1);

      if (RegExp(r'^\d{8}T\d{6}$').hasMatch(raw)) {
        final y = int.parse(raw.substring(0, 4));
        final mo = int.parse(raw.substring(4, 6));
        final d = int.parse(raw.substring(6, 8));
        final hh = int.parse(raw.substring(9, 11));
        final mm = int.parse(raw.substring(11, 13));
        final ss = int.parse(raw.substring(13, 15));
        return DateTime(y, mo, d, hh, mm, ss);
      }

      if (RegExp(r'^\d{8}T\d{4}$').hasMatch(raw)) {
        final y = int.parse(raw.substring(0, 4));
        final mo = int.parse(raw.substring(4, 6));
        final d = int.parse(raw.substring(6, 8));
        final hh = int.parse(raw.substring(9, 11));
        final mm = int.parse(raw.substring(11, 13));
        return DateTime(y, mo, d, hh, mm);
      }
    }

    return null;
  }

  DateTime? _asDateTime(dynamic value) {
    if (value is DateTime) return value;
    return _parseDate(value);
  }

  Map<String, String> _parseRRule(String rrule) {
    final parts = rrule.split(';');
    final Map<String, String> map = {};
    for (final part in parts) {
      final kv = part.split('=');
      if (kv.length == 2) {
        map[kv[0].toUpperCase()] = kv[1];
      }
    }
    return map;
  }

  DateTime? _parseUntil(String? untilStr) {
    if (untilStr == null || untilStr.isEmpty) return null;
    var raw = untilStr;
    if (raw.endsWith('Z')) raw = raw.substring(0, raw.length - 1);

    final dateOnly = RegExp(r'^(\d{4})(\d{2})(\d{2})$');
    final m = dateOnly.firstMatch(raw);
    if (m != null) {
      return DateTime(
        int.parse(m.group(1)!),
        int.parse(m.group(2)!),
        int.parse(m.group(3)!),
        23, 59, 59,
      );
    }

    if (RegExp(r'^\d{8}T\d{6}$').hasMatch(raw)) {
      final y = int.parse(raw.substring(0, 4));
      final mo = int.parse(raw.substring(4, 6));
      final d = int.parse(raw.substring(6, 8));
      final hh = int.parse(raw.substring(9, 11));
      final mm = int.parse(raw.substring(11, 13));
      final ss = int.parse(raw.substring(13, 15));
      return DateTime(y, mo, d, hh, mm, ss);
    }

    return null;
  }

  static const Map<String, int> _weekdayMap = {
    'MO': DateTime.monday,
    'TU': DateTime.tuesday,
    'WE': DateTime.wednesday,
    'TH': DateTime.thursday,
    'FR': DateTime.friday,
    'SA': DateTime.saturday,
    'SU': DateTime.sunday,
  };

  DateTime _startOfWeekMonday(DateTime d) {
    final normalized = DateTime(d.year, d.month, d.day);
    final delta = normalized.weekday - DateTime.monday;
    return normalized.subtract(Duration(days: delta));
  }

  DateTime _dateForWeekday(DateTime weekStartMonday, int weekday) {
    final offset = weekday - DateTime.monday;
    return weekStartMonday.add(Duration(days: offset));
  }

  List<Map<String, dynamic>> _expandRecurringEvent(Map<String, dynamic> event) {
    final dtStart = _parseDate(event['dtstart']);
    final dtEnd = _parseDate(event['dtend']);
    if (dtStart == null || dtEnd == null) return [];

    final rruleRaw = event['rrule'];
    if (rruleRaw == null) {
      return [{...event, 'dtstart': dtStart, 'dtend': dtEnd}];
    }

    final rrule = _parseRRule(rruleRaw.toString());
    final freq = (rrule['FREQ'] ?? '').toUpperCase();
    final until = _parseUntil(rrule['UNTIL']);
    final interval = int.tryParse(rrule['INTERVAL'] ?? '1') ?? 1;
    final countLimit = int.tryParse(rrule['COUNT'] ?? '0') ?? 0;
    final byDayTokens = (rrule['BYDAY'] ?? '')
        .split(',')
        .where((s) => s.trim().isNotEmpty)
        .map((s) => s.trim().toUpperCase())
        .toList();

    final defaultWeekday = dtStart.weekday;
    final byDays = byDayTokens.isEmpty
        ? [defaultWeekday]
        : byDayTokens
        .map((token) => _weekdayMap[token])
        .where((w) => w != null)
        .cast<int>()
        .toList();

    const int maxInstances = 365;

    if (freq == 'DAILY') {
      final result = <Map<String, dynamic>>[];
      var currentStart = dtStart;
      var currentEnd = dtEnd;
      int generated = 0;

      while (true) {
        if (countLimit > 0 && generated >= countLimit) break;
        if (until != null && currentStart.isAfter(until)) break;
        if (generated >= maxInstances) break;

        result.add({...event, 'dtstart': currentStart, 'dtend': currentEnd});

        currentStart = currentStart.add(Duration(days: interval));
        currentEnd = currentEnd.add(Duration(days: interval));
        generated++;
      }
      return result;
    }

    if (freq == 'WEEKLY') {
      final result = <Map<String, dynamic>>[];
      int generated = 0;
      var anchorWeekStart = _startOfWeekMonday(dtStart);

      while (true) {
        if (generated >= maxInstances) break;
        if (countLimit > 0 && generated >= countLimit) break;

        for (final wd in byDays) {
          if (countLimit > 0 && generated >= countLimit) break;
          if (generated >= maxInstances) break;

          final occurrenceDate = _dateForWeekday(anchorWeekStart, wd);
          final start = DateTime(
            occurrenceDate.year, occurrenceDate.month, occurrenceDate.day,
            dtStart.hour, dtStart.minute, dtStart.second,
          );
          final duration = dtEnd.difference(dtStart);
          final end = start.add(duration);

          if (until != null && start.isAfter(until)) continue;
          if (start.isBefore(dtStart)) continue;

          result.add({...event, 'dtstart': start, 'dtend': end});
          generated++;
        }

        anchorWeekStart = anchorWeekStart.add(Duration(days: 7 * interval));
      }
      return result;
    }

    return [{...event, 'dtstart': dtStart, 'dtend': dtEnd}];
  }

  String? _extractModuleCode(String title) {
    final regex = RegExp(r'^([MI]\d{5})');
    final match = regex.firstMatch(title);
    if (match != null) return match.group(1);

    final fallback = RegExp(r'^([A-Z]{2,4}\d{3,4})');
    final fallbackMatch = fallback.firstMatch(title);
    return fallbackMatch?.group(1);
  }

  CalendarEvent _mapToEvent(Map<String, dynamic> map) {
    final start = _asDateTime(map['dtstart'])!;
    final end = _asDateTime(map['dtend'])!;
    final summary = map['summary'] as String? ?? 'Untitled';

    return CalendarEvent(
      title: summary,
      description: map['description'] as String?,
      startTime: start,
      endTime: end,
      location: map['location'] as String?,
      moduleCode: _extractModuleCode(summary),
      rrule: map['rrule'] as String?,
      isRecurring: map['rrule'] != null,
    );
  }

  Map<String, dynamic> _eventToMap(CalendarEvent e) {
    return {
      'summary': e.title,
      'description': e.description,
      'dtstart': e.startTime,
      'dtend': e.endTime,
      'location': e.location,
      'rrule': e.rrule,
    };
  }
}