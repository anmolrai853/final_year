import 'package:flutter/material.dart';
import 'package:icalendar_parser/icalendar_parser.dart';

import '../models/deadline.dart';
import '../models/event.dart';
import '../models/free_time_slot.dart';
import '../models/gap_recommendation.dart';
import '../models/study_session.dart';
import '../services/analytics_service.dart';
import '../services/notification_service.dart';
import '../services/sm2_service.dart';
import '../services/storage_service.dart';

class _TimeBlock {
  final DateTime start;
  final DateTime end;
  const _TimeBlock(this.start, this.end);
}

class TimetableController extends ChangeNotifier {
  TimetableController._internal();
  static final TimetableController _instance = TimetableController._internal();
  factory TimetableController() => _instance;

  final StorageService _storage = StorageService();
  final NotificationService _notifications = NotificationService();

  final List<Map<String, dynamic>> _instances = [];
  final List<CalendarEvent> _events = [];

  bool _initialized = false;
  bool get isInitialized => _initialized;
  List<CalendarEvent> get events => List.unmodifiable(_events);

  // ==================== LIFECYCLE ====================

  Future<void> initialize() async {
    if (_initialized) return;
    await _storage.initialize();
    await _reloadEventsFromStorage();
    _initialized = true;
    notifyListeners();
  }

  Future<void> refresh() async {
    await _reloadEventsFromStorage();
    notifyListeners();
  }

  Future<void> clearAllData() async {
    try {
      await _notifications.cancelAll();
    } catch (_) {}
    await _storage.clearAllData();
    _instances.clear();
    _events.clear();
    notifyListeners();
  }

  // ==================== ICS IMPORT ====================

  Future<void> loadFromIcs(String content) async {
    debugPrint('Loading ICS content (${content.length} chars)...');

    try {
      final calendar = ICalendar.fromString(content);
      final json = calendar.toJson();
      final data = (json['data'] as List?) ?? [];

      final rawEvents = data
          .where((entry) => entry['type'] == 'VEVENT')
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList();

      final expandedInstances = <Map<String, dynamic>>[];

      for (final event in rawEvents) {
        if (event['rrule'] != null) {
          expandedInstances.addAll(_expandRecurringEvent(event));
        } else {
          final start = _parseDate(event['dtstart']);
          final end = _parseDate(event['dtend']);
          if (start == null || end == null) continue;
          expandedInstances.add({...event, 'dtstart': start, 'dtend': end});
        }
      }

      expandedInstances.sort((a, b) {
        return _asDateTime(a['dtstart'])!.compareTo(_asDateTime(b['dtstart'])!);
      });

      if (expandedInstances.isEmpty) {
        throw Exception('No valid events found in ICS file');
      }

      final calendarEvents = expandedInstances.map(_mapToEvent).toList();

      await _storage.saveCalendarEvents(calendarEvents);
      await _storage.saveIcsContent(content);

      _instances
        ..clear()
        ..addAll(expandedInstances);
      _events
        ..clear()
        ..addAll(calendarEvents);

      notifyListeners();

      try {
        await _notifications.scheduleClassReminders(_events);
      } catch (e) {
        debugPrint('Failed to schedule class reminders: $e');
      }
    } catch (e, stackTrace) {
      debugPrint('ERROR in loadFromIcs: $e\n$stackTrace');
      rethrow;
    }
  }

  // ==================== EVENTS ====================

  CalendarEvent? getNextEvent() {
    final now = DateTime.now();
    final upcoming = _events.where((e) => e.endTime.isAfter(now)).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    return upcoming.isEmpty ? null : upcoming.first;
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
    return getEventsForRange(weekStart, weekStart.add(const Duration(days: 7)));
  }

  Future<void> updateEventLocation(String eventId, String location) async {
    await _storage.saveEventLocation(eventId, location);
    notifyListeners();
  }

  String? getEventLocation(String eventId) => _storage.getEventLocation(eventId);

  // ==================== STUDY SESSIONS ====================

  List<StudySession> getStudySessionsForDay(DateTime day) =>
      _storage.getStudySessionsForDay(day);

  List<StudySession> getStudySessionsForWeek(DateTime weekStart) =>
      _storage.getStudySessionsForWeek(weekStart);

  List<StudySession> getStudySessionsForRange(DateTime start, DateTime end) =>
      _storage.getStudySessionsForRange(start, end);

  Future<void> addStudySession(StudySession session) async {
    await _storage.addStudySession(session);
    try {
      await _notifications.scheduleSessionReminder(session);
    } catch (_) {}
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
    try {
      await _notifications.cancelSessionReminder(id);
    } catch (_) {}
    await _storage.deleteStudySession(id);
    notifyListeners();
  }

  Future<void> toggleSessionCompletion(String id) async {
    await _storage.toggleSessionCompletion(id);
    notifyListeners();
  }

  // ==================== DEADLINES ====================

  List<Deadline> getAllDeadlines() {
    return _storage.loadDeadlines()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  }

  List<Deadline> getUpcomingDeadlines() => _storage.getUpcomingDeadlines();

  List<Deadline> getOverdueDeadlines() => _storage.getOverdueDeadlines();

  List<Deadline> getDeadlinesForModule(String moduleCode) =>
      _storage.getDeadlinesForModule(moduleCode);

  List<Deadline> getDeadlinesDueSoon({int days = 7}) {
    final cutoff = DateTime.now().add(Duration(days: days));
    return _storage
        .loadDeadlines()
        .where((d) =>
    d.status != DeadlineStatus.completed && d.dueDate.isBefore(cutoff))
        .toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  }

  Future<void> addDeadline(Deadline deadline) async {
    await _storage.addDeadline(deadline);
    try {
      await _notifications.scheduleDeadlineWarnings(deadline);
    } catch (_) {}
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
    try {
      await _notifications.cancelDeadlineWarnings(id);
    } catch (_) {}
    await _storage.deleteDeadline(id);
    notifyListeners();
  }

  Future<void> toggleDeadlineStatus(String id) async {
    final deadlines = _storage.loadDeadlines();
    final index = deadlines.indexWhere((d) => d.id == id);
    if (index == -1) return;

    final existing = deadlines[index];
    final newStatus = existing.status == DeadlineStatus.completed
        ? DeadlineStatus.todo
        : DeadlineStatus.completed;

    deadlines[index] = existing.copyWith(
      status: newStatus,
      completedAt: newStatus == DeadlineStatus.completed ? DateTime.now() : null,
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

  double getLoggedHoursForDeadline(String deadlineId) {
    final sessions = _storage.loadStudySessions();
    final linked = sessions.where((s) => s.isCompleted && s.deadlineId == deadlineId);
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
    final start = dayStart == null
        ? DateTime(day.year, day.month, day.day, 0, 0)
        : DateTime(day.year, day.month, day.day, dayStart.hour, dayStart.minute);

    final end = dayEnd == null
        ? DateTime(day.year, day.month, day.day, 23, 59)
        : DateTime(day.year, day.month, day.day, dayEnd.hour, dayEnd.minute);

    final blocked = <_TimeBlock>[
      for (final e in getEventsForDay(day)) _TimeBlock(e.startTime, e.endTime),
      for (final s in getStudySessionsForDay(day)) _TimeBlock(s.startTime, s.endTime),
    ]..sort((a, b) => a.start.compareTo(b.start));

    final merged = <_TimeBlock>[];
    for (final block in blocked) {
      if (merged.isEmpty) {
        merged.add(block);
        continue;
      }
      final last = merged.last;
      if (block.start.isBefore(last.end) || block.start.isAtSameMomentAs(last.end)) {
        merged[merged.length - 1] = _TimeBlock(
          last.start,
          block.end.isAfter(last.end) ? block.end : last.end,
        );
      } else {
        merged.add(block);
      }
    }

    final slots = <FreeTimeSlot>[];
    var cursor = start;

    for (final block in merged) {
      if (block.start.isAfter(cursor) && block.start.difference(cursor).inMinutes >= 30) {
        slots.add(FreeTimeSlot(startTime: cursor, endTime: block.start, day: day));
      }
      if (block.end.isAfter(cursor)) cursor = block.end;
    }

    if (cursor.isBefore(end) && end.difference(cursor).inMinutes >= 30) {
      slots.add(FreeTimeSlot(startTime: cursor, endTime: end, day: day));
    }

    return slots;
  }

  // ==================== GAP RECOMMENDATIONS ====================

  bool get hasAnalyticsData {
    return AnalyticsService().getInsights().averageEfficiency != null;
  }

  List<GapRecommendation> getGapRecommendations(DateTime day) {
    final freeSlots = findFreeTimeSlots(day);
    if (freeSlots.isEmpty) return [];

    final insights = AnalyticsService().getInsights();
    final sm2Service = Sm2Service();
    final hasData = insights.averageEfficiency != null;
    final optimalHour = insights.bestTimeToStudy?.hour;

    final urgentDeadlines = getDeadlinesDueSoon(days: 14);

    int totalDueNodes = 0;
    for (final map in _storage.loadKnowledgeMaps()) {
      final graph = _storage.getKnowledgeGraphData(map.id);
      if (graph != null) {
        totalDueNodes += graph.nodes.where((n) => sm2Service.isDue(n)).length;
      }
    }

    final recommendations = freeSlots.map((slot) {
      final quality = _classifyGapQuality(
        slotHour: slot.startTime.hour,
        hasData: hasData,
        optimalHour: optimalHour,
      );
      return GapRecommendation(
        startTime: slot.startTime,
        endTime: slot.endTime,
        duration: slot.duration,
        quality: quality,
        suggestion: _buildSuggestion(
          quality: quality,
          durationMins: slot.duration.inMinutes,
          urgentDeadlines: urgentDeadlines,
          totalDueNodes: totalDueNodes,
        ),
        relatedDeadlineTitle:
        urgentDeadlines.isNotEmpty ? urgentDeadlines.first.title : null,
        dueNodeCount: totalDueNodes > 0 ? totalDueNodes : null,
      );
    }).toList();

    recommendations.sort((a, b) {
      if (a.quality.index != b.quality.index) {
        return a.quality.index.compareTo(b.quality.index);
      }
      return a.startTime.compareTo(b.startTime);
    });

    return recommendations;
  }

  GapQuality _classifyGapQuality({
    required int slotHour,
    required bool hasData,
    required int? optimalHour,
  }) {
    if (!hasData) {
      return (slotHour >= 9 && slotHour <= 17) ? GapQuality.good : GapQuality.light;
    }
    final diff = (slotHour - optimalHour!).abs();
    if (diff <= 1) return GapQuality.peak;
    if (diff <= 3) return GapQuality.good;
    return GapQuality.light;
  }

  String _buildSuggestion({
    required GapQuality quality,
    required int durationMins,
    required List<Deadline> urgentDeadlines,
    required int totalDueNodes,
  }) {
    if (urgentDeadlines.isNotEmpty) {
      switch (quality) {
        case GapQuality.peak:
          return durationMins >= 50
              ? 'This is your peak focus window. Perfect for a Pomodoro session on your upcoming deadline.'
              : 'Your best focus time. Even a 25 minute sprint on your deadline makes a difference.';
        case GapQuality.good:
          return totalDueNodes > 0
              ? 'Good time for coursework or reviewing your knowledge maps before your deadline.'
              : 'Solid study window. Good time to make progress on your upcoming deadline.';
        case GapQuality.light:
          return totalDueNodes > 0
              ? 'Lower energy period. Great for lighter work like reviewing knowledge maps or reading notes.'
              : 'Use this time for reading or planning your approach to the upcoming deadline.';
      }
    }

    if (totalDueNodes > 0) {
      switch (quality) {
        case GapQuality.peak:
          return 'Peak focus window — ideal for deep knowledge review to strengthen your memory before it fades.';
        case GapQuality.good:
          return 'Good time to work through your knowledge map reviews before they slip further.';
        case GapQuality.light:
          return 'Low-stakes gap — perfect for quick knowledge map review to stay on top of your memory schedule.';
      }
    }

    switch (quality) {
      case GapQuality.peak:
        return 'Your peak focus window. Great for revision, coursework planning, or getting ahead on readings.';
      case GapQuality.good:
        return 'Good study window. Consider reading ahead or reviewing recent lecture notes.';
      case GapQuality.light:
        return 'Use this lighter period for reading, organising notes, or planning upcoming work.';
    }
  }

  // ==================== UTILITY ====================

  List<String> getModuleCodes() {
    return _events
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

  bool hasConflict(DateTime start, DateTime end, {String? excludeSessionId}) {
    for (final event in _events) {
      if (start.isBefore(event.endTime) && end.isAfter(event.startTime)) return true;
    }
    return _storage
        .getStudySessionsForRange(start, end)
        .where((s) => s.id != excludeSessionId)
        .isNotEmpty;
  }

  // ==================== PRIVATE HELPERS ====================

  Future<void> _reloadEventsFromStorage() async {
    final saved = _storage.loadCalendarEvents();
    _events
      ..clear()
      ..addAll(saved);
    _instances
      ..clear()
      ..addAll(saved.map(_eventToMap));
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;

    if (value is Map && value['dt'] is String) {
      var raw = value['dt'] as String;
      if (raw.endsWith('Z')) raw = raw.substring(0, raw.length - 1);

      if (RegExp(r'^\d{8}T\d{6}$').hasMatch(raw)) {
        return DateTime(
          int.parse(raw.substring(0, 4)), int.parse(raw.substring(4, 6)),
          int.parse(raw.substring(6, 8)), int.parse(raw.substring(9, 11)),
          int.parse(raw.substring(11, 13)), int.parse(raw.substring(13, 15)),
        );
      }
      if (RegExp(r'^\d{8}T\d{4}$').hasMatch(raw)) {
        return DateTime(
          int.parse(raw.substring(0, 4)), int.parse(raw.substring(4, 6)),
          int.parse(raw.substring(6, 8)), int.parse(raw.substring(9, 11)),
          int.parse(raw.substring(11, 13)),
        );
      }
    }
    return null;
  }

  DateTime? _asDateTime(dynamic value) =>
      value is DateTime ? value : _parseDate(value);

  Map<String, String> _parseRRule(String rrule) {
    final map = <String, String>{};
    for (final part in rrule.split(';')) {
      final kv = part.split('=');
      if (kv.length == 2) map[kv[0].toUpperCase()] = kv[1];
    }
    return map;
  }

  DateTime? _parseUntil(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    var s = raw.endsWith('Z') ? raw.substring(0, raw.length - 1) : raw;

    final m = RegExp(r'^(\d{4})(\d{2})(\d{2})$').firstMatch(s);
    if (m != null) {
      return DateTime(int.parse(m.group(1)!), int.parse(m.group(2)!),
          int.parse(m.group(3)!), 23, 59, 59);
    }
    if (RegExp(r'^\d{8}T\d{6}$').hasMatch(s)) {
      return DateTime(
        int.parse(s.substring(0, 4)), int.parse(s.substring(4, 6)),
        int.parse(s.substring(6, 8)), int.parse(s.substring(9, 11)),
        int.parse(s.substring(11, 13)), int.parse(s.substring(13, 15)),
      );
    }
    return null;
  }

  static const Map<String, int> _weekdayMap = {
    'MO': DateTime.monday, 'TU': DateTime.tuesday, 'WE': DateTime.wednesday,
    'TH': DateTime.thursday, 'FR': DateTime.friday, 'SA': DateTime.saturday,
    'SU': DateTime.sunday,
  };

  DateTime _startOfWeekMonday(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return d.subtract(Duration(days: d.weekday - DateTime.monday));
  }

  DateTime _dateForWeekday(DateTime weekStart, int weekday) =>
      weekStart.add(Duration(days: weekday - DateTime.monday));

  List<Map<String, dynamic>> _expandRecurringEvent(Map<String, dynamic> event) {
    final dtStart = _parseDate(event['dtstart']);
    final dtEnd = _parseDate(event['dtend']);
    if (dtStart == null || dtEnd == null) return [];

    final rruleRaw = event['rrule'];
    if (rruleRaw == null) return [{...event, 'dtstart': dtStart, 'dtend': dtEnd}];

    final rrule = _parseRRule(rruleRaw.toString());
    final freq = (rrule['FREQ'] ?? '').toUpperCase();
    final until = _parseUntil(rrule['UNTIL']);
    final interval = int.tryParse(rrule['INTERVAL'] ?? '1') ?? 1;
    final countLimit = int.tryParse(rrule['COUNT'] ?? '0') ?? 0;
    final duration = dtEnd.difference(dtStart);

    final byDayTokens = (rrule['BYDAY'] ?? '')
        .split(',')
        .where((s) => s.trim().isNotEmpty)
        .map((s) => s.trim().toUpperCase())
        .toList();

    final byDays = byDayTokens.isEmpty
        ? [dtStart.weekday]
        : byDayTokens.map((t) => _weekdayMap[t]).whereType<int>().toList();

    const maxInstances = 365;

    if (freq == 'DAILY') {
      final result = <Map<String, dynamic>>[];
      var current = dtStart;
      while (result.length < maxInstances) {
        if (countLimit > 0 && result.length >= countLimit) break;
        if (until != null && current.isAfter(until)) break;
        result.add({...event, 'dtstart': current, 'dtend': current.add(duration)});
        current = current.add(Duration(days: interval));
      }
      return result;
    }

    if (freq == 'WEEKLY') {
      final result = <Map<String, dynamic>>[];
      var anchorWeek = _startOfWeekMonday(dtStart);

      while (result.length < maxInstances) {
        if (countLimit > 0 && result.length >= countLimit) break;

        for (final wd in byDays) {
          if (result.length >= maxInstances) break;
          if (countLimit > 0 && result.length >= countLimit) break;

          final occDate = _dateForWeekday(anchorWeek, wd);
          final occStart = DateTime(
            occDate.year, occDate.month, occDate.day,
            dtStart.hour, dtStart.minute, dtStart.second,
          );

          if (occStart.isBefore(dtStart)) continue;
          if (until != null && occStart.isAfter(until)) continue;

          result.add({...event, 'dtstart': occStart, 'dtend': occStart.add(duration)});
        }

        anchorWeek = anchorWeek.add(Duration(days: 7 * interval));
      }
      return result;
    }

    return [{...event, 'dtstart': dtStart, 'dtend': dtEnd}];
  }

  String? _extractModuleCode(String title) {
    final primary = RegExp(r'^([MI]\d{5})').firstMatch(title);
    if (primary != null) return primary.group(1);
    return RegExp(r'^([A-Z]{2,4}\d{3,4})').firstMatch(title)?.group(1);
  }

  CalendarEvent _mapToEvent(Map<String, dynamic> map) {
    final summary = map['summary'] as String? ?? 'Untitled';
    return CalendarEvent(
      title: summary,
      description: map['description'] as String?,
      startTime: _asDateTime(map['dtstart'])!,
      endTime: _asDateTime(map['dtend'])!,
      location: map['location'] as String?,
      moduleCode: _extractModuleCode(summary),
      rrule: map['rrule'] as String?,
      isRecurring: map['rrule'] != null,
    );
  }

  Map<String, dynamic> _eventToMap(CalendarEvent e) => {
    'summary': e.title,
    'description': e.description,
    'dtstart': e.startTime,
    'dtend': e.endTime,
    'location': e.location,
    'rrule': e.rrule,
  };
}