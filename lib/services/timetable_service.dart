// dart
import 'package:flutter/services.dart' show rootBundle;
import 'package:icalendar_parser/icalendar_parser.dart';
import 'package:intl/intl.dart';

import '../controllers/timetable_controller.dart';

class TimetableService {
  // ---------- public API ----------

  Future<List<Map<String, dynamic>>> loadInstancesFromAsset(
      String assetPath) async {
    final icsContent = await rootBundle.loadString(assetPath);
    final calendar = ICalendar.fromString(icsContent);
    final json = calendar.toJson();
    final controller = TimetableController();

    final rawEvents = (json['data'] as List)
        .where((e) => e['type'] == 'VEVENT')
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    final List<Map<String, dynamic>> allInstances = [];

    for (final event in rawEvents) {
      final rrule = event['rrule'];
      if (rrule != null) {
        allInstances.addAll(_expandRecurringEventLikeGoogle(event));
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

    // Sort globally by start time
    allInstances.sort((a, b) {
      final da = _asDateTime(a['dtstart'])!;
      final db = _asDateTime(b['dtstart'])!;
      return da.compareTo(db);
    });

    // compute next event and set controller after instances are ready
    final nextEvent = findNextEvent(allInstances);
    controller.setTimetable(events: allInstances, next: nextEvent);

    return allInstances;
  }

  /// Group events by day label (e.g. "Monday, 29 September 2025").
  Map<String, List<Map<String, dynamic>>> groupByDay(
      List<Map<String, dynamic>> events) {
    final Map<String, List<Map<String, dynamic>>> groups = {};
    final formatter = DateFormat('EEEE, dd MMMM yyyy');

    for (final e in events) {
      final start = _asDateTime(e['dtstart']);
      if (start == null) continue;

      final key = formatter.format(start);
      groups.putIfAbsent(key, () => []);
      groups[key]!.add(e);
    }

    // Sort events within each day by start time
    for (final list in groups.values) {
      list.sort((a, b) {
        final sa = _asDateTime(a['dtstart'])!;
        final sb = _asDateTime(b['dtstart'])!;
        return sa.compareTo(sb);
      });
    }

    return groups;
  }
  List<Map<String, dynamic>> findFreeGapsForDay(
      List<Map<String, dynamic>> events,
      DateTime day,
      int minGapMinutes,
      ) {
    final startOfDay = DateTime(day.year, day.month, day.day, 9, 0); // start at 9am
    final endOfDay = DateTime(day.year, day.month, day.day, 23, 59);

    final gaps = <Map<String, dynamic>>[];

    // If no events at all → whole day is free
    if (events.isEmpty) {
      final duration = endOfDay.difference(startOfDay).inMinutes;
      if (duration >= minGapMinutes) {
        gaps.add({
          'start': startOfDay,
          'end': endOfDay,
          'duration': duration,
        });
      }
      return gaps;
    }

    // Sort events by start time
    events.sort((a, b) =>
        (a['dtstart'] as DateTime).compareTo(b['dtstart'] as DateTime));

    DateTime prevEnd = startOfDay;

    for (final e in events) {
      final s = e['dtstart'] as DateTime;

      // Only consider gaps AFTER 9am
      if (s.isAfter(prevEnd)) {
        final duration = s.difference(prevEnd).inMinutes;
        if (duration >= minGapMinutes) {
          gaps.add({
            'start': prevEnd,
            'end': s,
            'duration': duration,
          });
        }
      }

      prevEnd = (e['dtend'] as DateTime);
    }

    // Gap after last lesson
    if (endOfDay.isAfter(prevEnd)) {
      final duration = endOfDay.difference(prevEnd).inMinutes;
      if (duration >= minGapMinutes) {
        gaps.add({
          'start': prevEnd,
          'end': endOfDay,
          'duration': duration,
        });
      }
    }

    return gaps;
  }


  /// Find the earliest event strictly after `now`.
  Map<String, dynamic>? findNextEvent(List<Map<String, dynamic>> events) {
    final now = DateTime.now();
    Map<String, dynamic>? candidate;
    DateTime? candidateStart;

    for (final e in events) {
      final start = _asDateTime(e['dtstart']);
      if (start == null) continue;
      if (!start.isAfter(now)) continue;

      if (candidate == null || start.isBefore(candidateStart!)) {
        candidate = e;
        candidateStart = start;
      }
    }
    return candidate;
  }

  // ---------- internal helpers ----------

  /// Normalise various dt representations into DateTime.
  DateTime? _parseDate(dynamic dtObj) {
    if (dtObj == null) return null;

    if (dtObj is DateTime) return dtObj;

    if (dtObj is Map && dtObj['dt'] is String) {
      var raw = dtObj['dt'] as String;

      // If it's UTC-style, drop the 'Z' and treat as local
      if (raw.endsWith('Z')) raw = raw.substring(0, raw.length - 1);

      // Compact datetime with seconds: YYYYMMDDTHHMMSS
      if (RegExp(r'^\d{8}T\d{6}$').hasMatch(raw)) {
        final y = int.parse(raw.substring(0, 4));
        final mo = int.parse(raw.substring(4, 6));
        final d = int.parse(raw.substring(6, 8));
        final hh = int.parse(raw.substring(9, 11));
        final mm = int.parse(raw.substring(11, 13));
        final ss = int.parse(raw.substring(13, 15));
        return DateTime(y, mo, d, hh, mm, ss);
      }

      // Compact datetime without seconds: YYYYMMDDTHHMM
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

  /// Safely cast any 'dtstart'/'dtend' field to DateTime.
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

    // Compact date only: YYYYMMDD
    final dateOnly = RegExp(r'^(\d{4})(\d{2})(\d{2})$');
    final m = dateOnly.firstMatch(raw);
    if (m != null) {
      return DateTime(
        int.parse(m.group(1)!),
        int.parse(m.group(2)!),
        int.parse(m.group(3)!),
        23,
        59,
        59,
      );
    }

    // Compact datetime: YYYYMMDDTHHMMSS
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

  // Map ICS BYDAY tokens to Dart weekday ints (Mon=1..Sun=7)
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
    final delta = normalized.weekday - DateTime.monday; // 0..6
    return normalized.subtract(Duration(days: delta));
  }

  DateTime _dateForWeekday(DateTime weekStartMonday, int weekday) {
    final offset = weekday - DateTime.monday;
    return weekStartMonday.add(Duration(days: offset));
  }

  List<Map<String, dynamic>> _expandRecurringEventLikeGoogle(
      Map<String, dynamic> event) {
    final dtStart = _parseDate(event['dtstart']);
    final dtEnd = _parseDate(event['dtend']);
    if (dtStart == null || dtEnd == null) return [];

    final rruleRaw = event['rrule'];
    if (rruleRaw == null) {
      return [
        {
          ...event,
          'dtstart': dtStart,
          'dtend': dtEnd,
        }
      ];
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

    // If BYDAY not specified, default to the DTSTART weekday
    final defaultWeekday = dtStart.weekday;
    final byDays = byDayTokens.isEmpty
        ? [defaultWeekday]
        : byDayTokens
        .map((token) => _weekdayMap[token])
        .where((w) => w != null)
        .cast<int>()
        .toList();

    const int maxInstances = 365;

    // DAILY
    if (freq == 'DAILY') {
      final result = <Map<String, dynamic>>[];
      var currentStart = dtStart;
      var currentEnd = dtEnd;
      int generated = 0;

      while (true) {
        if (countLimit > 0 && generated >= countLimit) break;
        if (until != null && currentStart.isAfter(until)) break;
        if (generated >= maxInstances) break;

        result.add({
          ...event,
          'dtstart': currentStart,
          'dtend': currentEnd,
        });

        currentStart = currentStart.add(Duration(days: interval));
        currentEnd = currentEnd.add(Duration(days: interval));
        generated++;
      }
      return result;
    }

    // WEEKLY
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
            occurrenceDate.year,
            occurrenceDate.month,
            occurrenceDate.day,
            dtStart.hour,
            dtStart.minute,
            dtStart.second,
          );
          final duration = dtEnd.difference(dtStart);
          final end = start.add(duration);

          if (until != null && start.isAfter(until)) {
            continue;
          }

          if (start.isBefore(dtStart)) {
            continue;
          }

          result.add({
            ...event,
            'dtstart': start,
            'dtend': end,
          });
          generated++;
        }

        anchorWeekStart = anchorWeekStart.add(Duration(days: 7 * interval));
      }

      return result;
    }

    // Fallback: unsupported FREQ, just return single instance
    return [
      {
        ...event,
        'dtstart': dtStart,
        'dtend': dtEnd,
      }
    ];
  }
}
