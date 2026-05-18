import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import '../models/event.dart';
import '../models/study_session.dart';
import '../models/deadline.dart';
import '../models/gap_recommendation.dart';
import 'storage_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();
  final StorageService _storage = StorageService();

  bool _initialized = false;
  bool get isInitialized => _initialized;

  // ==================== INITIALIZATION ====================

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      tz.initializeTimeZones();
      try {
        final timeZoneName = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(timeZoneName));
      } catch (e) {
        debugPrint('Timezone error, using UTC: $e');
        tz.setLocalLocation(tz.getLocation('UTC'));
      }

      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinInit = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const initSettings = InitializationSettings(
        android: androidInit,
        iOS: darwinInit,
      );

      await _plugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      _initialized = true;
      debugPrint('NotificationService initialized');
    } catch (e) {
      debugPrint('NotificationService failed to initialize: $e');
      _initialized = false;
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
  }

  // ==================== PERMISSIONS ====================

  Future<bool> requestPermissions() async {
    if (!_initialized) return false;

    try {
      if (Platform.isAndroid) {
        final android = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        if (android != null) {
          final granted = await android.requestNotificationsPermission();
          return granted ?? false;
        }
      } else if (Platform.isIOS) {
        final ios = _plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
        if (ios != null) {
          final granted = await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
          return granted ?? false;
        }
      }
    } catch (e) {
      debugPrint('Failed to request permissions: $e');
    }
    return false;
  }

  // ==================== CLASS REMINDERS ====================
  Future<void> scheduleImmediateTest() async {
    if (!_initialized) return;
    try {
      await _scheduleNotification(
        id: 99999,
        title: '🎒 Time to head to class',
        body: 'ARTIFICIAL INTELLIGENCE at Burnaby Building, 3.30 starts in 15 minutes',
        scheduledTime: DateTime.now().add(const Duration(seconds: 10)),
        payload: 'class:test',
        channelId: 'class-reminders',
        channelName: 'Class Reminders',
        channelDescription: 'Reminders to leave for your classes',
      );
      debugPrint('Test notification scheduled — fires in 10 seconds');
    } catch (e) {
      debugPrint('Test notification error: $e');
    }
  }


  Future<void> scheduleClassReminder(CalendarEvent event) async {
    if (!_initialized) return;
    try {
      final prefs = getNotificationPreferences();
      if (!prefs.classRemindersEnabled) return;

      final reminderTime = event.startTime.subtract(
        Duration(minutes: prefs.classReminderMinutes),
      );
      if (reminderTime.isBefore(DateTime.now())) return;

      // Build a location-aware body so the user knows where they're heading
      final location = _storage.getEventLocation(event.id) ?? event.location;
      final locationSuffix =
      (location != null && location.isNotEmpty) ? ' at $location' : '';

      final minutesText = prefs.classReminderMinutes == 1
          ? '1 minute'
          : '${prefs.classReminderMinutes} minutes';

      final id = _generateId(event.id, 'class');

      await _scheduleNotification(
        id: id,
        title: '🎒 Time to head to class',
        body: '${event.title}$locationSuffix starts in $minutesText',
        scheduledTime: reminderTime,
        payload: 'class:${event.id}',
        channelId: 'class-reminders',
        channelName: 'Class Reminders',
        channelDescription: 'Reminders to leave for your classes',
      );
    } catch (e) {
      debugPrint('Failed to schedule class reminder: $e');
    }
  }

  Future<void> scheduleClassReminders(List<CalendarEvent> events) async {
    if (!_initialized) return;

    try {
      final prefs = getNotificationPreferences();
      if (!prefs.classRemindersEnabled) return;

      await cancelClassReminders(events);

      for (final event in events) {
        await scheduleClassReminder(event);
      }

      debugPrint('Scheduled class reminders for ${events.length} events');
    } catch (e) {
      debugPrint('Failed to schedule class reminders: $e');
    }
  }

  Future<void> cancelClassReminders(List<CalendarEvent> events) async {
    if (!_initialized) return;

    try {
      for (final event in events) {
        final id = _generateId(event.id, 'class');
        await _plugin.cancel(id);
      }
    } catch (e) {
      debugPrint('Failed to cancel class reminders: $e');
    }
  }

  // ==================== STUDY SESSION REMINDERS ====================

  Future<void> scheduleSessionReminder(StudySession session) async {
    if (!_initialized) return;

    try {
      final prefs = getNotificationPreferences();
      if (!prefs.sessionRemindersEnabled) return;

      final reminderTime = session.startTime.subtract(
        Duration(minutes: prefs.sessionReminderMinutes),
      );

      if (reminderTime.isBefore(DateTime.now())) return;

      final id = _generateId(session.id, 'session');

      await _scheduleNotification(
        id: id,
        title: 'Study Session',
        body: '${session.title} starts in ${prefs.sessionReminderMinutes} minutes',
        scheduledTime: reminderTime,
        payload: 'session:${session.id}',
        channelId: 'session_reminders',
        channelName: 'Study Session Reminders',
        channelDescription: 'Reminders before your study sessions',
      );
    } catch (e) {
      debugPrint('Failed to schedule session reminder: $e');
    }
  }

  Future<void> cancelSessionReminder(String sessionId) async {
    if (!_initialized) return;

    try {
      final id = _generateId(sessionId, 'session');
      await _plugin.cancel(id);
    } catch (e) {
      debugPrint('Failed to cancel session reminder: $e');
    }
  }

  // ==================== DEADLINE WARNINGS ====================

  Future<void> scheduleDeadlineWarnings(Deadline deadline) async {
    if (!_initialized) return;

    try {
      final prefs = getNotificationPreferences();
      if (!prefs.deadlineRemindersEnabled) return;
      if (deadline.status == DeadlineStatus.completed) return;

      await cancelDeadlineWarnings(deadline.id);

      final now = DateTime.now();

      for (final daysBefore in prefs.deadlineReminderDays) {
        final warningTime =
        deadline.dueDate.subtract(Duration(days: daysBefore));

        if (warningTime.isAfter(now)) {
          final id = _generateId(deadline.id, 'deadline_$daysBefore');
          final daysText = daysBefore == 1 ? '1 day' : '$daysBefore days';

          await _scheduleNotification(
            id: id,
            title: 'Deadline Approaching',
            body: '"${deadline.title}" is due in $daysText',
            scheduledTime: warningTime,
            payload: 'deadline:${deadline.id}',
            channelId: 'deadline_warnings',
            channelName: 'Deadline Warnings',
            channelDescription: 'Warnings about approaching deadlines',
          );
        }
      }

      final dayOfReminder = DateTime(
        deadline.dueDate.year,
        deadline.dueDate.month,
        deadline.dueDate.day,
        9,
        0,
      );

      if (dayOfReminder.isAfter(now)) {
        final id = _generateId(deadline.id, 'deadline_0');
        await _scheduleNotification(
          id: id,
          title: 'Deadline Today!',
          body: '"${deadline.title}" is due today',
          scheduledTime: dayOfReminder,
          payload: 'deadline:${deadline.id}',
          channelId: 'deadline_warnings',
          channelName: 'Deadline Warnings',
          channelDescription: 'Warnings about approaching deadlines',
        );
      }
    } catch (e) {
      debugPrint('Failed to schedule deadline warnings: $e');
    }
  }

  Future<void> cancelDeadlineWarnings(String deadlineId) async {
    if (!_initialized) return;

    try {
      for (final days in [0, 1, 3, 7, 14]) {
        final id = _generateId(deadlineId, 'deadline_$days');
        await _plugin.cancel(id);
      }
    } catch (e) {
      debugPrint('Failed to cancel deadline warnings: $e');
    }
  }

  // ==================== GAP NOTIFICATIONS ====================

  /// Schedules a notification at the start of each free gap,
  /// with a contextual message based on gap quality, deadlines
  /// and SM2 review nodes due.
  Future<void> scheduleGapNotifications(
      List<GapRecommendation> gaps) async {
    if (!_initialized) return;

    try {
      final now = DateTime.now();

      for (final gap in gaps) {
        // Only schedule gaps that haven't started yet
        if (gap.startTime.isBefore(now)) continue;

        final id = _generateId(
            'gap_${gap.startTime.millisecondsSinceEpoch}', 'gap');

        String title;
        String body;

        switch (gap.quality) {
          case GapQuality.peak:
            title = '🔥 Peak Focus Window Starting';
            body = gap.relatedDeadlineTitle != null
                ? '${gap.formattedDuration} free — perfect for your ${gap.relatedDeadlineTitle} deadline.'
                : '${gap.formattedDuration} free — your best study time of the day.';
            break;
          case GapQuality.good:
            title = '✅ Free Gap — Good Study Time';
            body = gap.dueNodeCount != null && gap.dueNodeCount! > 0
                ? '${gap.formattedDuration} available. ${gap.dueNodeCount} knowledge cards due for review.'
                : '${gap.formattedDuration} available. Good time for coursework or revision.';
            break;
          case GapQuality.light:
            title = '📖 Free Time Available';
            body =
            '${gap.formattedDuration} free. Good for reading, notes or lighter review work.';
            break;
        }

        await _scheduleNotification(
          id: id,
          title: title,
          body: body,
          scheduledTime: gap.startTime,
          payload: 'gap:${gap.startTime.toIso8601String()}',
          channelId: 'gap_recommendations',
          channelName: 'Free Gap Recommendations',
          channelDescription:
          'Notifications when free study gaps start in your timetable',
        );
      }

      debugPrint('Scheduled ${gaps.length} gap notifications');
    } catch (e) {
      debugPrint('Failed to schedule gap notifications: $e');
    }
  }

  // ==================== RESCHEDULE ALL ====================

  Future<void> rescheduleAll({
    List<CalendarEvent>? events,
    List<StudySession>? sessions,
    List<Deadline>? deadlines,
  }) async {
    if (!_initialized) return;

    try {
      await _plugin.cancelAll();
      debugPrint('Cancelled all existing notifications');

      final prefs = getNotificationPreferences();

      if (prefs.classRemindersEnabled && events != null) {
        final now = DateTime.now();
        final cutoff = now.add(const Duration(days: 7));
        final soon = events
            .where((e) =>
        e.startTime.isAfter(now) && e.startTime.isBefore(cutoff))
            .toList();
        for (final event in soon) {
          await scheduleClassReminder(event);
        }
        debugPrint('Scheduled ${soon.length} class reminders');
      }

      if (prefs.sessionRemindersEnabled && sessions != null) {
        final now = DateTime.now();
        final upcoming =
        sessions.where((s) => s.startTime.isAfter(now) && !s.isCompleted);
        for (final session in upcoming) {
          await scheduleSessionReminder(session);
        }
        debugPrint('Scheduled reminders for ${upcoming.length} sessions');
      }

      if (prefs.deadlineRemindersEnabled && deadlines != null) {
        final active = deadlines
            .where((d) => d.status != DeadlineStatus.completed)
            .toList();
        for (final deadline in active) {
          await scheduleDeadlineWarnings(deadline);
        }
        debugPrint('Scheduled warnings for ${active.length} deadlines');
      }
    } catch (e) {
      debugPrint('Failed to reschedule notifications: $e');
    }
  }

  // ==================== CANCEL ALL ====================

  Future<void> cancelAll() async {
    if (!_initialized) return;

    try {
      await _plugin.cancelAll();
      debugPrint('All notifications cancelled');
    } catch (e) {
      debugPrint('Failed to cancel all notifications: $e');
    }
  }

  // ==================== PREFERENCES ====================

  NotificationPreferences getNotificationPreferences() {
    return NotificationPreferences.load(_storage);
  }

  Future<void> saveNotificationPreferences(
      NotificationPreferences prefs) async {
    await prefs.save(_storage);
  }

  // ==================== INTERNAL HELPERS ====================

  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    required String payload,
    required String channelId,
    required String channelName,
    required String channelDescription,
  }) async {
    try {
      final androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );

      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
      );

      final tzTime = tz.TZDateTime.from(scheduledTime, tz.local);

      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tzTime,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Failed to schedule notification: $e');
    }
  }

  int _generateId(String entityId, String type) {
    final combined = '$type:$entityId';
    return combined.hashCode.abs() % 2147483647;
  }
}

// ==================== NOTIFICATION PREFERENCES ====================

class NotificationPreferences {
  bool classRemindersEnabled;
  int classReminderMinutes;
  bool sessionRemindersEnabled;
  int sessionReminderMinutes;
  bool deadlineRemindersEnabled;
  List<int> deadlineReminderDays;

  NotificationPreferences({
    this.classRemindersEnabled = true,
    this.classReminderMinutes = 15,
    this.sessionRemindersEnabled = true,
    this.sessionReminderMinutes = 10,
    this.deadlineRemindersEnabled = true,
    this.deadlineReminderDays = const [1, 3],
  });

  static NotificationPreferences load(StorageService storage) {
    final saved = storage.loadNotificationPrefs();
    if (saved != null) {
      return NotificationPreferences.fromJson(saved);
    }
    return NotificationPreferences();
  }

  Future<void> save(StorageService storage) async {
    await storage.saveNotificationPrefs(toJson());
  }

  NotificationPreferences copyWith({
    bool? classRemindersEnabled,
    int? classReminderMinutes,
    bool? sessionRemindersEnabled,
    int? sessionReminderMinutes,
    bool? deadlineRemindersEnabled,
    List<int>? deadlineReminderDays,
  }) {
    return NotificationPreferences(
      classRemindersEnabled:
      classRemindersEnabled ?? this.classRemindersEnabled,
      classReminderMinutes: classReminderMinutes ?? this.classReminderMinutes,
      sessionRemindersEnabled:
      sessionRemindersEnabled ?? this.sessionRemindersEnabled,
      sessionReminderMinutes:
      sessionReminderMinutes ?? this.sessionReminderMinutes,
      deadlineRemindersEnabled:
      deadlineRemindersEnabled ?? this.deadlineRemindersEnabled,
      deadlineReminderDays: deadlineReminderDays ?? this.deadlineReminderDays,
    );
  }

  Map<String, dynamic> toJson() => {
    'classRemindersEnabled': classRemindersEnabled,
    'classReminderMinutes': classReminderMinutes,
    'sessionRemindersEnabled': sessionRemindersEnabled,
    'sessionReminderMinutes': sessionReminderMinutes,
    'deadlineRemindersEnabled': deadlineRemindersEnabled,
    'deadlineReminderDays': deadlineReminderDays,
  };

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      classRemindersEnabled: json['classRemindersEnabled'] ?? true,
      classReminderMinutes: json['classReminderMinutes'] ?? 15,
      sessionRemindersEnabled: json['sessionRemindersEnabled'] ?? true,
      sessionReminderMinutes: json['sessionReminderMinutes'] ?? 10,
      deadlineRemindersEnabled: json['deadlineRemindersEnabled'] ?? true,
      deadlineReminderDays:
      (json['deadlineReminderDays'] as List?)?.cast<int>() ?? [1, 3],
    );
  }
}