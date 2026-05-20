import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:icalendar_parser/icalendar_parser.dart';
import '../models/event.dart';
import '../models/study_session.dart';
import '../models/free_time_slot.dart';
import '../models/deadline.dart';
import '../models/gap_recommendation.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../services/analytics_service.dart';
import '../services/sm2_service.dart';

class _TimeBlock {
  final DateTime start;
  final DateTime end;
  _TimeBlock(this.start, this.end);
}

class TimetableController extends ChangeNotifier {
  static final TimetableController _instance =
  TimetableController._internal();
  factory TimetableController() => _instance;
  TimetableController._internal();

  final StorageService _storage = StorageService();
  final NotificationService _notifications = NotificationService();

  bool _initialized = false;
  bool get isInitialized => _initialized;

  // ==================== INITIALISATION ====================

  Future<void> initialize() async {
    if (_initialized) return;
    await _storage.initialize();
    await _storage.preloadGraphs();
    _initialized = true;
    notifyListeners();
  }

  Future<void> refresh() async {
    await _storage.loadCalendarEventsAsync();
    await _storage.loadStudySessionsAsync();
    await _storage.loadDeadlinesAsync();
    await _storage.preloadGraphs();
    notifyListeners();
  }

  Future<void> clearAllData() async {
    try { await _notifications.cancelAll(); } catch (_) {}
    await _storage.clearAllData();
    notifyListeners();
  }

  // ==================== ICS IMPORT ====================

  Future<void> loadFromIcs(String content) async {
    debugPrint('Loading ICS (${content.length} chars)');

    try {
      final calendar = ICalendar.fromString(content);
      final json = calendar.toJson();

      final rawEvents = (json['data'] as List)
          .where((e) => e['type'] == 'VEVENT')
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      final List<Map<String, dynamic>> allInstances = [];
      for (final event in rawEvents) {
        final rrule = event['rrule'];
        if (rrule != null) {
          allInstances.addAll(_expandRecurringEvent(event));
        } else {
          final dtStart = _parseDate(event['dtstart']);
          final dtEnd = _parseDate(event['dtend']);
          if (dtStart == null || dtEnd == null) continue;
          allInstances
              .add({...event, 'dtstart': dtStart, 'dtend': dtEnd});
        }
      }

      allInstances.sort((a, b) =>
          _asDateTime(a['dtstart'])!
              .compareTo(_asDateTime(b['dtstart'])!));

      if (allInstances.isEmpty) {
        throw Exception('No valid events found in ICS file');
      }

      final calendarEvents =
      allInstances.map((m) => _mapToEvent(m)).toList();
      await _storage.saveCalendarEvents(calendarEvents);
      await _storage.saveIcsContent(content);

      notifyListeners();
      debugPrint('ICS import complete: ${calendarEvents.length} events');
    } catch (e, st) {
      debugPrint('ERROR in loadFromIcs: $e\n$st');
      rethrow;
    }

    try {
      await _notifications
          .scheduleClassReminders(_storage.loadCalendarEvents());
    } catch (e) {
      debugPrint('Failed to schedule class reminders: $e');
    }
  }

  // ==================== EVENT METHODS ====================

  CalendarEvent? getNextEvent() {
    final now = DateTime.now();
    final upcoming = _storage
        .loadCalendarEvents()
        .where((e) => e.endTime.isAfter(now))
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    return upcoming.isNotEmpty ? upcoming.first : null;
  }

  List<CalendarEvent> getEventsForDay(DateTime day) {
    return _storage
        .loadCalendarEvents()
        .where((e) =>
    e.startTime.year == day.year &&
        e.startTime.month == day.month &&
        e.startTime.day == day.day)
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  List<CalendarEvent> getEventsForRange(DateTime start, DateTime end) {
    return _storage
        .loadCalendarEvents()
        .where((e) =>
    e.startTime.isBefore(end) && e.endTime.isAfter(start))
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  List<CalendarEvent> getEventsForWeek(DateTime weekStart) =>
      getEventsForRange(
          weekStart, weekStart.add(const Duration(days: 7)));

  // ==================== STUDY SESSION METHODS ====================

  List<StudySession> getStudySessionsForDay(DateTime day) =>
      _storage.getStudySessionsForDay(day);

  List<StudySession> getStudySessionsForWeek(DateTime weekStart) =>
      _storage.getStudySessionsForWeek(weekStart);

  List<StudySession> getStudySessionsForRange(
      DateTime start, DateTime end) =>
      _storage.getStudySessionsForRange(start, end);

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
    await _storage.deleteStudySession(id);
    try { await _notifications.cancelSessionReminder(id); } catch (_) {}
    notifyListeners();
  }

  Future<void> toggleSessionCompletion(String id) async {
    await _storage.toggleSessionCompletion(id);
    notifyListeners();
  }

  // ==================== DEADLINE METHODS ====================

  List<Deadline> getAllDeadlines() =>
      _storage.loadDeadlines()
        ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

  List<Deadline> getUpcomingDeadlines() => _storage.getUpcomingDeadlines();
  List<Deadline> getOverdueDeadlines() => _storage.getOverdueDeadlines();
  List<Deadline> getDeadlinesForModule(String m) =>
      _storage.getDeadlinesForModule(m);

  List<Deadline> getDeadlinesDueSoon({int days = 7}) {
    final cutoff = DateTime.now().add(Duration(days: days));
    return _storage
        .loadDeadlines()
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
    await _storage.deleteDeadline(id);
    try { await _notifications.cancelDeadlineWarnings(id); } catch (_) {}
    notifyListeners();
  }

  Future<void> toggleDeadlineStatus(String id) async {
    final deadlines = _storage.loadDeadlines();
    final idx = deadlines.indexWhere((d) => d.id == id);
    if (idx == -1) return;
    final d = deadlines[idx];
    final newStatus = d.status == DeadlineStatus.completed
        ? DeadlineStatus.todo
        : DeadlineStatus.completed;
    final updated = d.copyWith(
      status: newStatus,
      completedAt:
      newStatus == DeadlineStatus.completed ? DateTime.now() : null,
    );
    await _storage.updateDeadline(updated);
    try {
      if (newStatus == DeadlineStatus.completed) {
        await _notifications.cancelDeadlineWarnings(id);
      } else {
        await _notifications.scheduleDeadlineWarnings(updated);
      }
    } catch (_) {}
    notifyListeners();
  }

  double getLoggedHoursForDeadline(String deadlineId) {
    final linked = _storage
        .loadStudySessions()
        .where((s) => s.isCompleted && s.deadlineId == deadlineId);
    return linked.fold<int>(
        0,
            (sum, s) =>
        sum + (s.actualDurationMinutes ?? s.durationMinutes)) /
        60.0;
  }

  // ==================== FREE TIME SLOTS ====================

  /// Only returns gaps BETWEEN events — not before the first or after the last.
  List<FreeTimeSlot> findFreeTimeSlots(DateTime day) {
    final dayEvents = getEventsForDay(day);
    final daySessions = getStudySessionsForDay(day);

    if (dayEvents.isEmpty && daySessions.isEmpty) return [];

    final blocked = <_TimeBlock>[
      ...dayEvents.map((e) => _TimeBlock(e.startTime, e.endTime)),
      ...daySessions.map((s) => _TimeBlock(s.startTime, s.endTime)),
    ]..sort((a, b) => a.start.compareTo(b.start));

    // Merge overlapping blocks
    final merged = <_TimeBlock>[];
    for (final b in blocked) {
      if (merged.isEmpty) {
        merged.add(b);
      } else {
        final last = merged.last;
        if (b.start.isBefore(last.end) ||
            b.start.isAtSameMomentAs(last.end)) {
          merged[merged.length - 1] = _TimeBlock(last.start,
              b.end.isAfter(last.end) ? b.end : last.end);
        } else {
          merged.add(b);
        }
      }
    }

    // Gaps BETWEEN blocks only
    final slots = <FreeTimeSlot>[];
    for (int i = 0; i < merged.length - 1; i++) {
      final gapStart = merged[i].end;
      final gapEnd = merged[i + 1].start;
      if (gapEnd.difference(gapStart).inMinutes >= 30) {
        slots.add(FreeTimeSlot(
            startTime: gapStart, endTime: gapEnd, day: day));
      }
    }
    return slots;
  }

  // ==================== GAP RECOMMENDATIONS ====================

  bool get hasAnalyticsData =>
      AnalyticsService().getInsights().averageEfficiency != null;

  List<GapRecommendation> getGapRecommendations(DateTime day) {
    final freeSlots = findFreeTimeSlots(day);
    if (freeSlots.isEmpty) return [];

    final insights = AnalyticsService().getInsights();
    final hasData = insights.averageEfficiency != null;
    final optimalHour = insights.bestTimeToStudy?.hour;
    final urgentDeadlines = getDeadlinesDueSoon(days: 14);

    final recommendations = <GapRecommendation>[];
    for (final slot in freeSlots) {
      final slotHour = slot.startTime.hour;
      final durationMins = slot.duration.inMinutes;

      GapQuality quality;
      if (!hasData) {
        quality = (slotHour >= 9 && slotHour <= 17)
            ? GapQuality.good
            : GapQuality.light;
      } else {
        final diff = (slotHour - optimalHour!).abs();
        quality = diff <= 1
            ? GapQuality.peak
            : diff <= 3
            ? GapQuality.good
            : GapQuality.light;
      }

      String suggestion;
      String? relatedDeadline;

      if (urgentDeadlines.isNotEmpty) {
        relatedDeadline = urgentDeadlines.first.title;
        if (quality == GapQuality.peak) {
          suggestion = durationMins >= 50
              ? 'This is your peak focus window. Perfect for a Pomodoro session on your upcoming deadline.'
              : 'Your best focus time. Even a 25 minute sprint makes a difference.';
        } else if (quality == GapQuality.good) {
          suggestion =
          'Solid study window. Good time to make progress on your upcoming deadline.';
        } else {
          suggestion =
          'Use this time for reading or planning your approach to the upcoming deadline.';
        }
      } else {
        if (quality == GapQuality.peak) {
          suggestion =
          'Your peak focus window. Great for revision, coursework planning, or reading ahead.';
        } else if (quality == GapQuality.good) {
          suggestion =
          'Good study window. Consider reading ahead or reviewing recent lecture notes.';
        } else {
          suggestion =
          'Use this lighter period for reading, organising notes, or planning upcoming work.';
        }
      }

      recommendations.add(GapRecommendation(
        startTime: slot.startTime,
        endTime: slot.endTime,
        duration: slot.duration,
        quality: quality,
        suggestion: suggestion,
        relatedDeadlineTitle: relatedDeadline,
        dueNodeCount: null,
      ));
    }

    recommendations.sort((a, b) {
      if (a.quality.index != b.quality.index) {
        return a.quality.index.compareTo(b.quality.index);
      }
      return a.startTime.compareTo(b.startTime);
    });

    return recommendations;
  }

  // ==================== UTILITY ====================

  List<String> getModuleCodes() {
    return _storage
        .loadCalendarEvents()
        .where((e) => e.moduleCode != null)
        .map((e) => e.moduleCode!)
        .toSet()
        .toList()
      ..sort();
  }

  Color getModuleColor(String? moduleCode) {
    if (moduleCode == null) return Colors.grey;
    const colors = [
      Color(0xFF3B82F6), Color(0xFF8B5CF6), Color(0xFFEC4899),
      Color(0xFFF59E0B), Color(0xFF10B981), Color(0xFF06B6D4),
      Color(0xFFF97316), Color(0xFF84CC16), Color(0xFFEF4444),
      Color(0xFF6366F1),
    ];
    var hash = 0;
    for (var i = 0; i < moduleCode.length; i++) {
      hash = moduleCode.codeUnitAt(i) + ((hash << 5) - hash);
    }
    return colors[hash.abs() % colors.length];
  }

  List<int> getSmartTimeRange() => [0, 24];

  bool hasConflict(DateTime start, DateTime end,
      {String? excludeSessionId}) {
    for (final e in _storage.loadCalendarEvents()) {
      if (start.isBefore(e.endTime) && end.isAfter(e.startTime)) {
        return true;
      }
    }
    return _storage
        .getStudySessionsForRange(start, end)
        .where((s) => s.id != excludeSessionId)
        .isNotEmpty;
  }

  Future<void> updateEventLocation(String eventId, String location) async {
    await _storage.saveEventLocation(eventId, location);
    notifyListeners();
  }

  String? getEventLocation(String eventId) =>
      _storage.getEventLocation(eventId);

  Future<String?> getEventLocationAsync(String eventId) =>
      _storage.getEventLocationAsync(eventId);

  // ==================== PARSING HELPERS ====================

  DateTime? _parseDate(dynamic dtObj) {
    if (dtObj == null) return null;
    if (dtObj is DateTime) return dtObj;
    if (dtObj is Map && dtObj['dt'] is String) {
      var raw = dtObj['dt'] as String;
      if (raw.endsWith('Z')) raw = raw.substring(0, raw.length - 1);
      if (RegExp(r'^\d{8}T\d{6}$').hasMatch(raw)) {
        return DateTime(
          int.parse(raw.substring(0, 4)),
          int.parse(raw.substring(4, 6)),
          int.parse(raw.substring(6, 8)),
          int.parse(raw.substring(9, 11)),
          int.parse(raw.substring(11, 13)),
          int.parse(raw.substring(13, 15)),
        );
      }
      if (RegExp(r'^\d{8}T\d{4}$').hasMatch(raw)) {
        return DateTime(
          int.parse(raw.substring(0, 4)),
          int.parse(raw.substring(4, 6)),
          int.parse(raw.substring(6, 8)),
          int.parse(raw.substring(9, 11)),
          int.parse(raw.substring(11, 13)),
        );
      }
    }
    return null;
  }

  DateTime? _asDateTime(dynamic v) => v is DateTime ? v : _parseDate(v);

  Map<String, String> _parseRRule(String rrule) {
    final map = <String, String>{};
    for (final part in rrule.split(';')) {
      final kv = part.split('=');
      if (kv.length == 2) map[kv[0].toUpperCase()] = kv[1];
    }
    return map;
  }

  DateTime? _parseUntil(String? s) {
    if (s == null || s.isEmpty) return null;
    var raw = s;
    if (raw.endsWith('Z')) raw = raw.substring(0, raw.length - 1);
    final m = RegExp(r'^(\d{4})(\d{2})(\d{2})$').firstMatch(raw);
    if (m != null) {
      return DateTime(int.parse(m.group(1)!), int.parse(m.group(2)!),
          int.parse(m.group(3)!), 23, 59, 59);
    }
    if (RegExp(r'^\d{8}T\d{6}$').hasMatch(raw)) {
      return DateTime(
        int.parse(raw.substring(0, 4)),
        int.parse(raw.substring(4, 6)),
        int.parse(raw.substring(6, 8)),
        int.parse(raw.substring(9, 11)),
        int.parse(raw.substring(11, 13)),
        int.parse(raw.substring(13, 15)),
      );
    }
    return null;
  }

  static const _weekdayMap = {
    'MO': DateTime.monday, 'TU': DateTime.tuesday,
    'WE': DateTime.wednesday, 'TH': DateTime.thursday,
    'FR': DateTime.friday, 'SA': DateTime.saturday,
    'SU': DateTime.sunday,
  };

  DateTime _startOfWeekMonday(DateTime d) {
    final n = DateTime(d.year, d.month, d.day);
    return n.subtract(Duration(days: n.weekday - DateTime.monday));
  }

  DateTime _dateForWeekday(DateTime ws, int wd) =>
      ws.add(Duration(days: wd - DateTime.monday));

  List<Map<String, dynamic>> _expandRecurringEvent(
      Map<String, dynamic> event) {
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
    final byDays = byDayTokens.isEmpty
        ? [dtStart.weekday]
        : byDayTokens
        .map((t) => _weekdayMap[t])
        .where((w) => w != null)
        .cast<int>()
        .toList();
    const maxInstances = 365;

    if (freq == 'DAILY') {
      final result = <Map<String, dynamic>>[];
      var cs = dtStart;
      var ce = dtEnd;
      int gen = 0;
      while (true) {
        if (countLimit > 0 && gen >= countLimit) break;
        if (until != null && cs.isAfter(until)) break;
        if (gen >= maxInstances) break;
        result.add({...event, 'dtstart': cs, 'dtend': ce});
        cs = cs.add(Duration(days: interval));
        ce = ce.add(Duration(days: interval));
        gen++;
      }
      return result;
    }

    if (freq == 'WEEKLY') {
      final result = <Map<String, dynamic>>[];
      int gen = 0;
      var anchor = _startOfWeekMonday(dtStart);
      while (true) {
        if (gen >= maxInstances) break;
        if (countLimit > 0 && gen >= countLimit) break;
        for (final wd in byDays) {
          if (countLimit > 0 && gen >= countLimit) break;
          if (gen >= maxInstances) break;
          final occ = _dateForWeekday(anchor, wd);
          final start = DateTime(occ.year, occ.month, occ.day,
              dtStart.hour, dtStart.minute);
          final end = start.add(dtEnd.difference(dtStart));
          if (until != null && start.isAfter(until)) continue;
          if (start.isBefore(dtStart)) continue;
          result.add({...event, 'dtstart': start, 'dtend': end});
          gen++;
        }
        anchor = anchor.add(Duration(days: 7 * interval));
      }
      return result;
    }

    return [{...event, 'dtstart': dtStart, 'dtend': dtEnd}];
  }

  String? _extractModuleCode(String title) {
    final m = RegExp(r'^([MI]\d{5})').firstMatch(title);
    if (m != null) return m.group(1);
    return RegExp(r'^([A-Z]{2,4}\d{3,4})').firstMatch(title)?.group(1);
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
}