import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/event.dart';
import '../models/study_session.dart';
import '../models/knowledge_node.dart';
import '../models/deadline.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  Database? _db;

  // ── In-memory caches so sync methods keep working ──────────────────────────
  List<CalendarEvent> _eventsCache = [];
  List<StudySession> _sessionsCache = [];
  List<Deadline> _deadlinesCache = [];
  List<KnowledgeMap> _mapsCache = [];
  final Map<String, KnowledgeGraphData> _graphCache = {};
  final Map<String, String> _locationCache = {};
  List<Map<String, dynamic>> _spotsCache = [];
  Map<String, dynamic>? _notifPrefsCache;
  String? _icsCache;

  // ==================== INITIALISATION ====================

  Future<void> initialize() async {
    if (_db != null) return;

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'student_planner.db');

    _db = await openDatabase(
      path,
      version: 1,
      onCreate: _createTables,
    );

    // Load everything into cache on startup
    await _loadAllCaches();
    debugPrint('SQLite ready. Loaded ${_eventsCache.length} events, '
        '${_sessionsCache.length} sessions, ${_deadlinesCache.length} deadlines');
  }

  Future<void> _loadAllCaches() async {
    _eventsCache = await _queryCalendarEvents();
    _sessionsCache = await _queryStudySessions();
    _deadlinesCache = await _queryDeadlines();
    _mapsCache = await _queryKnowledgeMaps();
    _spotsCache = await _queryStudySpots();
    _notifPrefsCache = await _queryNotificationPrefs();
    _icsCache = await _queryIcsContent();
    _locationCache.clear();
    final locRows = await _db!.query('event_locations');
    for (final r in locRows) {
      _locationCache[r['event_id'] as String] = r['location'] as String;
    }
  }

  Future<void> _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE calendar_events (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        start_time TEXT NOT NULL,
        end_time TEXT NOT NULL,
        location TEXT,
        module_code TEXT,
        rrule TEXT,
        is_recurring INTEGER NOT NULL DEFAULT 0,
        override_color INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE study_sessions (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        type INTEGER NOT NULL,
        start_time TEXT NOT NULL,
        duration_minutes INTEGER NOT NULL,
        is_completed INTEGER NOT NULL DEFAULT 0,
        module_code TEXT,
        notes TEXT,
        deadline_id TEXT,
        actual_duration_minutes INTEGER,
        focus_level INTEGER,
        interruption_count INTEGER,
        topics_covered TEXT,
        understanding_rating INTEGER,
        completed_full_session INTEGER,
        completed_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE deadlines (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        module_code TEXT,
        due_date TEXT NOT NULL,
        priority INTEGER NOT NULL DEFAULT 1,
        status INTEGER NOT NULL DEFAULT 0,
        estimated_hours REAL NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        completed_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE knowledge_maps (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        created_at TEXT NOT NULL,
        last_modified TEXT,
        color TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE knowledge_nodes (
        id TEXT PRIMARY KEY,
        map_id TEXT NOT NULL,
        label TEXT NOT NULL,
        content TEXT,
        type INTEGER NOT NULL DEFAULT 0,
        position_dx REAL NOT NULL DEFAULT 0,
        position_dy REAL NOT NULL DEFAULT 0,
        module_code TEXT,
        tags TEXT,
        confidence_level INTEGER NOT NULL DEFAULT 0,
        ease_factor REAL NOT NULL DEFAULT 2.5,
        interval_days INTEGER NOT NULL DEFAULT 0,
        repetitions INTEGER NOT NULL DEFAULT 0,
        last_review_date TEXT,
        next_review_date TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (map_id) REFERENCES knowledge_maps (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE knowledge_edges (
        id TEXT PRIMARY KEY,
        map_id TEXT NOT NULL,
        source_id TEXT NOT NULL,
        target_id TEXT NOT NULL,
        label TEXT,
        type INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (map_id) REFERENCES knowledge_maps (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE event_locations (
        event_id TEXT PRIMARY KEY,
        location TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE study_spots (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        notes TEXT NOT NULL DEFAULT '',
        lat REAL NOT NULL,
        lng REAL NOT NULL,
        type TEXT NOT NULL DEFAULT 'custom'
      )
    ''');

    await db.execute('''
      CREATE TABLE notification_prefs (
        id INTEGER PRIMARY KEY DEFAULT 1,
        class_reminders_enabled INTEGER NOT NULL DEFAULT 1,
        class_reminder_minutes INTEGER NOT NULL DEFAULT 15,
        session_reminders_enabled INTEGER NOT NULL DEFAULT 1,
        session_reminder_minutes INTEGER NOT NULL DEFAULT 10,
        deadline_reminders_enabled INTEGER NOT NULL DEFAULT 1,
        deadline_reminder_days TEXT NOT NULL DEFAULT '[1,3]'
      )
    ''');

    await db.execute('''
      CREATE TABLE ics_content (
        id INTEGER PRIMARY KEY DEFAULT 1,
        content TEXT NOT NULL
      )
    ''');

    debugPrint('SQLite tables created');
  }

  Database get _database {
    if (_db == null) {
      throw Exception('StorageService not initialised. Call initialize() first.');
    }
    return _db!;
  }

  // ==================== CALENDAR EVENTS ====================

  Future<void> saveCalendarEvents(List<CalendarEvent> events) async {
    final db = _database;
    final batch = db.batch();
    batch.delete('calendar_events');
    for (final e in events) {
      batch.insert('calendar_events', _eventToRow(e),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
    _eventsCache = List.from(events);
    debugPrint('Saved ${events.length} events to SQLite');
  }

  Future<List<CalendarEvent>> _queryCalendarEvents() async {
    if (_db == null) return [];
    final rows = await _db!.query('calendar_events',
        orderBy: 'start_time ASC');
    return rows.map(_rowToEvent).toList();
  }

  // Sync — returns from cache
  List<CalendarEvent> loadCalendarEvents() => List.from(_eventsCache);

  // Async — reloads from DB and refreshes cache
  Future<List<CalendarEvent>> loadCalendarEventsAsync() async {
    _eventsCache = await _queryCalendarEvents();
    return List.from(_eventsCache);
  }

  Map<String, dynamic> _eventToRow(CalendarEvent e) => {
    'id': e.id,
    'title': e.title,
    'description': e.description,
    'start_time': e.startTime.toIso8601String(),
    'end_time': e.endTime.toIso8601String(),
    'location': e.location,
    'module_code': e.moduleCode,
    'rrule': e.rrule,
    'is_recurring': e.isRecurring ? 1 : 0,
    'override_color': e.overrideColor?.value,
  };

  CalendarEvent _rowToEvent(Map<String, dynamic> r) => CalendarEvent(
    id: r['id'] as String,
    title: r['title'] as String,
    description: r['description'] as String?,
    startTime: DateTime.parse(r['start_time'] as String),
    endTime: DateTime.parse(r['end_time'] as String),
    location: r['location'] as String?,
    moduleCode: r['module_code'] as String?,
    rrule: r['rrule'] as String?,
    isRecurring: (r['is_recurring'] as int) == 1,
    overrideColor: r['override_color'] != null
        ? Color(r['override_color'] as int)
        : null,
  );

  // ==================== ICS CONTENT ====================

  Future<void> saveIcsContent(String content) async {
    await _database.insert('ics_content',
        {'id': 1, 'content': content},
        conflictAlgorithm: ConflictAlgorithm.replace);
    _icsCache = content;
  }

  Future<String?> _queryIcsContent() async {
    if (_db == null) return null;
    final rows =
    await _db!.query('ics_content', where: 'id = ?', whereArgs: [1]);
    if (rows.isEmpty) return null;
    return rows.first['content'] as String?;
  }

  String? loadIcsContent() => _icsCache;

  // ==================== STUDY SESSIONS ====================

  Future<void> addStudySession(StudySession session) async {
    await _database.insert('study_sessions', _sessionToRow(session),
        conflictAlgorithm: ConflictAlgorithm.replace);
    _sessionsCache.add(session);
  }

  Future<void> updateStudySession(StudySession session) async {
    await _database.update('study_sessions', _sessionToRow(session),
        where: 'id = ?', whereArgs: [session.id]);
    final idx = _sessionsCache.indexWhere((s) => s.id == session.id);
    if (idx != -1) _sessionsCache[idx] = session;
  }

  Future<void> deleteStudySession(String id) async {
    await _database
        .delete('study_sessions', where: 'id = ?', whereArgs: [id]);
    _sessionsCache.removeWhere((s) => s.id == id);
  }

  Future<void> toggleSessionCompletion(String id) async {
    final idx = _sessionsCache.indexWhere((s) => s.id == id);
    if (idx == -1) return;
    final updated =
    _sessionsCache[idx].copyWith(isCompleted: !_sessionsCache[idx].isCompleted);
    _sessionsCache[idx] = updated;
    await _database.update('study_sessions', _sessionToRow(updated),
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearStudySessions() async {
    await _database.delete('study_sessions');
    _sessionsCache.clear();
  }

  Future<List<StudySession>> _queryStudySessions() async {
    if (_db == null) return [];
    final rows =
    await _db!.query('study_sessions', orderBy: 'start_time ASC');
    return rows.map(_rowToSession).toList();
  }

  Future<List<StudySession>> loadStudySessionsAsync() async {
    _sessionsCache = await _queryStudySessions();
    return List.from(_sessionsCache);
  }

  // All sync session methods read from cache
  List<StudySession> loadStudySessions() => List.from(_sessionsCache);

  List<StudySession> getStudySessionsForDay(DateTime day) {
    return _sessionsCache
        .where((s) =>
    s.startTime.year == day.year &&
        s.startTime.month == day.month &&
        s.startTime.day == day.day)
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  List<StudySession> getStudySessionsForRange(
      DateTime start, DateTime end) {
    return _sessionsCache
        .where((s) =>
    s.startTime.isBefore(end) && s.endTime.isAfter(start))
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  List<StudySession> getStudySessionsForWeek(DateTime weekStart) {
    return getStudySessionsForRange(
        weekStart, weekStart.add(const Duration(days: 7)));
  }

  Map<String, dynamic> _sessionToRow(StudySession s) => {
    'id': s.id,
    'title': s.title,
    'type': s.type.index,
    'start_time': s.startTime.toIso8601String(),
    'duration_minutes': s.durationMinutes,
    'is_completed': s.isCompleted ? 1 : 0,
    'module_code': s.moduleCode,
    'notes': s.notes,
    'deadline_id': s.deadlineId,
    'actual_duration_minutes': s.actualDurationMinutes,
    'focus_level': s.focusLevel?.index,
    'interruption_count': s.interruptionCount,
    'topics_covered': s.topicsCovered,
    'understanding_rating': s.understandingRating,
    'completed_full_session': s.completedFullSession == null
        ? null
        : (s.completedFullSession! ? 1 : 0),
    'completed_at': s.completedAt?.toIso8601String(),
  };

  StudySession _rowToSession(Map<String, dynamic> r) => StudySession(
    id: r['id'] as String,
    title: r['title'] as String,
    type: StudySessionType.values[r['type'] as int],
    startTime: DateTime.parse(r['start_time'] as String),
    durationMinutes: r['duration_minutes'] as int,
    isCompleted: (r['is_completed'] as int) == 1,
    moduleCode: r['module_code'] as String?,
    notes: r['notes'] as String?,
    deadlineId: r['deadline_id'] as String?,
    actualDurationMinutes: r['actual_duration_minutes'] as int?,
    focusLevel: r['focus_level'] != null
        ? FocusLevel.values[r['focus_level'] as int]
        : null,
    interruptionCount: r['interruption_count'] as int?,
    topicsCovered: r['topics_covered'] as String?,
    understandingRating: r['understanding_rating'] as int?,
    completedFullSession: r['completed_full_session'] != null
        ? (r['completed_full_session'] as int) == 1
        : null,
    completedAt: r['completed_at'] != null
        ? DateTime.parse(r['completed_at'] as String)
        : null,
  );

  // ==================== DEADLINES ====================

  Future<void> addDeadline(Deadline deadline) async {
    await _database.insert('deadlines', _deadlineToRow(deadline),
        conflictAlgorithm: ConflictAlgorithm.replace);
    _deadlinesCache.add(deadline);
  }

  Future<void> updateDeadline(Deadline deadline) async {
    await _database.update('deadlines', _deadlineToRow(deadline),
        where: 'id = ?', whereArgs: [deadline.id]);
    final idx = _deadlinesCache.indexWhere((d) => d.id == deadline.id);
    if (idx != -1) _deadlinesCache[idx] = deadline;
  }

  Future<void> deleteDeadline(String id) async {
    await _database
        .delete('deadlines', where: 'id = ?', whereArgs: [id]);
    _deadlinesCache.removeWhere((d) => d.id == id);
  }

  Future<void> saveDeadlines(List<Deadline> deadlines) async {
    final batch = _database.batch();
    batch.delete('deadlines');
    for (final d in deadlines) {
      batch.insert('deadlines', _deadlineToRow(d),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
    _deadlinesCache = List.from(deadlines);
  }

  Future<List<Deadline>> _queryDeadlines() async {
    if (_db == null) return [];
    final rows =
    await _db!.query('deadlines', orderBy: 'due_date ASC');
    return rows.map(_rowToDeadline).toList();
  }

  Future<List<Deadline>> loadDeadlinesAsync() async {
    _deadlinesCache = await _queryDeadlines();
    return List.from(_deadlinesCache);
  }

  // Sync — from cache
  List<Deadline> loadDeadlines() => List.from(_deadlinesCache);

  List<Deadline> getUpcomingDeadlines() {
    return _deadlinesCache
        .where((d) => d.status != DeadlineStatus.completed)
        .toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  }

  List<Deadline> getOverdueDeadlines() {
    return _deadlinesCache.where((d) => d.isOverdue).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  }

  List<Deadline> getDeadlinesForModule(String moduleCode) {
    return _deadlinesCache
        .where((d) => d.moduleCode == moduleCode)
        .toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  }

  Map<String, dynamic> _deadlineToRow(Deadline d) => {
    'id': d.id,
    'title': d.title,
    'description': d.description,
    'module_code': d.moduleCode,
    'due_date': d.dueDate.toIso8601String(),
    'priority': d.priority.index,
    'status': d.status.index,
    'estimated_hours': d.estimatedHours,
    'created_at': d.createdAt.toIso8601String(),
    'completed_at': d.completedAt?.toIso8601String(),
  };

  Deadline _rowToDeadline(Map<String, dynamic> r) => Deadline(
    id: r['id'] as String,
    title: r['title'] as String,
    description: r['description'] as String?,
    moduleCode: r['module_code'] as String?,
    dueDate: DateTime.parse(r['due_date'] as String),
    priority: DeadlinePriority.values[r['priority'] as int],
    status: DeadlineStatus.values[r['status'] as int],
    estimatedHours: (r['estimated_hours'] as num).toDouble(),
    createdAt: DateTime.parse(r['created_at'] as String),
    completedAt: r['completed_at'] != null
        ? DateTime.parse(r['completed_at'] as String)
        : null,
  );

  // ==================== KNOWLEDGE MAPS ====================

  Future<void> saveKnowledgeMap(KnowledgeMap map) async {
    await _database.insert(
      'knowledge_maps',
      {
        'id': map.id,
        'name': map.name,
        'description': map.description,
        'created_at': map.createdAt.toIso8601String(),
        'last_modified': map.lastModified?.toIso8601String(),
        'color': map.color,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    final idx = _mapsCache.indexWhere((m) => m.id == map.id);
    if (idx != -1) {
      _mapsCache[idx] = map;
    } else {
      _mapsCache.add(map);
    }
  }

  Future<List<KnowledgeMap>> _queryKnowledgeMaps() async {
    if (_db == null) return [];
    final rows =
    await _db!.query('knowledge_maps', orderBy: 'created_at ASC');
    return rows
        .map((r) => KnowledgeMap(
      id: r['id'] as String,
      name: r['name'] as String,
      description: r['description'] as String?,
      createdAt: DateTime.parse(r['created_at'] as String),
      lastModified: r['last_modified'] != null
          ? DateTime.parse(r['last_modified'] as String)
          : null,
      color: r['color'] as String?,
    ))
        .toList();
  }

  Future<void> deleteKnowledgeMap(String mapId) async {
    await _database.delete('knowledge_maps',
        where: 'id = ?', whereArgs: [mapId]);
    await _database.delete('knowledge_nodes',
        where: 'map_id = ?', whereArgs: [mapId]);
    await _database.delete('knowledge_edges',
        where: 'map_id = ?', whereArgs: [mapId]);
    _mapsCache.removeWhere((m) => m.id == mapId);
    _graphCache.remove(mapId);
  }

  // Sync — from cache
  List<KnowledgeMap> loadKnowledgeMaps() => List.from(_mapsCache);

  // ==================== KNOWLEDGE GRAPH DATA ====================

  Future<void> saveKnowledgeGraphData(KnowledgeGraphData data) async {
    final db = _database;
    final batch = db.batch();

    batch.delete('knowledge_nodes',
        where: 'map_id = ?', whereArgs: [data.mapId]);
    batch.delete('knowledge_edges',
        where: 'map_id = ?', whereArgs: [data.mapId]);

    for (final node in data.nodes) {
      batch.insert(
        'knowledge_nodes',
        {
          'id': node.id,
          'map_id': data.mapId,
          'label': node.label,
          'content': node.content,
          'type': node.type.index,
          'position_dx': node.position.dx,
          'position_dy': node.position.dy,
          'module_code': node.moduleCode,
          'tags': jsonEncode(node.tags),
          'confidence_level': node.confidenceLevel,
          'ease_factor': node.easeFactor,
          'interval_days': node.interval,
          'repetitions': node.repetitions,
          'last_review_date': node.lastReviewDate?.toIso8601String(),
          'next_review_date': node.nextReviewDate?.toIso8601String(),
          'created_at': node.createdAt.toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    for (final edge in data.edges) {
      batch.insert(
        'knowledge_edges',
        {
          'id': edge.id,
          'map_id': data.mapId,
          'source_id': edge.sourceId,
          'target_id': edge.targetId,
          'label': edge.label,
          'type': edge.type.index,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
    _graphCache[data.mapId] = data;
  }

  Future<KnowledgeGraphData?> _queryKnowledgeGraph(String mapId) async {
    if (_db == null) return null;
    final nodeRows = await _db!.query('knowledge_nodes',
        where: 'map_id = ?', whereArgs: [mapId]);
    final edgeRows = await _db!.query('knowledge_edges',
        where: 'map_id = ?', whereArgs: [mapId]);

    final nodes = nodeRows.map((r) {
      final tags =
      (jsonDecode(r['tags'] as String? ?? '[]') as List).cast<String>();
      return KnowledgeNode(
        id: r['id'] as String,
        label: r['label'] as String,
        content: r['content'] as String?,
        type: NodeType.values[r['type'] as int],
        position: Offset(
          (r['position_dx'] as num).toDouble(),
          (r['position_dy'] as num).toDouble(),
        ),
        moduleCode: r['module_code'] as String?,
        mapId: r['map_id'] as String,
        tags: tags,
        confidenceLevel: r['confidence_level'] as int,
        easeFactor: (r['ease_factor'] as num).toDouble(),
        interval: r['interval_days'] as int,
        repetitions: r['repetitions'] as int,
        lastReviewDate: r['last_review_date'] != null
            ? DateTime.parse(r['last_review_date'] as String)
            : null,
        nextReviewDate: r['next_review_date'] != null
            ? DateTime.parse(r['next_review_date'] as String)
            : null,
        createdAt: DateTime.parse(r['created_at'] as String),
      );
    }).toList();

    final edges = edgeRows
        .map((r) => KnowledgeEdge(
      id: r['id'] as String,
      sourceId: r['source_id'] as String,
      targetId: r['target_id'] as String,
      label: r['label'] as String?,
      type: EdgeType.values[r['type'] as int],
    ))
        .toList();

    return KnowledgeGraphData(mapId: mapId, nodes: nodes, edges: edges);
  }

  // Sync — from cache (populated on first access)
  KnowledgeGraphData? getKnowledgeGraphData(String mapId) {
    return _graphCache[mapId];
  }

  Future<KnowledgeGraphData?> getKnowledgeGraphDataAsync(
      String mapId) async {
    final data = await _queryKnowledgeGraph(mapId);
    if (data != null) _graphCache[mapId] = data;
    return data;
  }

  // Load all graphs into cache (called during full init)
  Future<void> _preloadGraphCaches() async {
    for (final map in _mapsCache) {
      final data = await _queryKnowledgeGraph(map.id);
      if (data != null) _graphCache[map.id] = data;
    }
  }

  // ==================== EVENT LOCATIONS ====================

  Future<void> saveEventLocation(String eventId, String location) async {
    await _database.insert(
      'event_locations',
      {'event_id': eventId, 'location': location},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _locationCache[eventId] = location;
  }

  String? getEventLocation(String eventId) => _locationCache[eventId];

  Future<String?> getEventLocationAsync(String eventId) async =>
      _locationCache[eventId];

  // ==================== STUDY SPOTS ====================

  Future<void> saveStudySpots(List<Map<String, dynamic>> spots) async {
    final batch = _database.batch();
    batch.delete('study_spots');
    for (final spot in spots) {
      batch.insert(
        'study_spots',
        {
          'id': spot['id'],
          'name': spot['name'],
          'notes': spot['notes'] ?? '',
          'lat': spot['lat'],
          'lng': spot['lng'],
          'type': spot['type'] ?? 'custom',
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
    _spotsCache = List.from(spots);
  }

  Future<List<Map<String, dynamic>>> _queryStudySpots() async {
    if (_db == null) return [];
    final rows = await _db!.query('study_spots');
    return rows
        .map((r) => {
      'id': r['id'],
      'name': r['name'],
      'notes': r['notes'],
      'lat': r['lat'],
      'lng': r['lng'],
      'type': r['type'],
    })
        .toList();
  }

  // Sync — from cache
  List<Map<String, dynamic>> loadStudySpots() => List.from(_spotsCache);

  // ==================== NOTIFICATION PREFERENCES ====================

  Future<void> saveNotificationPrefs(Map<String, dynamic> prefs) async {
    await _database.insert(
      'notification_prefs',
      {
        'id': 1,
        'class_reminders_enabled':
        (prefs['classRemindersEnabled'] as bool) ? 1 : 0,
        'class_reminder_minutes': prefs['classReminderMinutes'],
        'session_reminders_enabled':
        (prefs['sessionRemindersEnabled'] as bool) ? 1 : 0,
        'session_reminder_minutes': prefs['sessionReminderMinutes'],
        'deadline_reminders_enabled':
        (prefs['deadlineRemindersEnabled'] as bool) ? 1 : 0,
        'deadline_reminder_days':
        jsonEncode(prefs['deadlineReminderDays']),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _notifPrefsCache = prefs;
  }

  Future<Map<String, dynamic>?> _queryNotificationPrefs() async {
    if (_db == null) return null;
    final rows = await _db!.query('notification_prefs',
        where: 'id = ?', whereArgs: [1]);
    if (rows.isEmpty) return null;
    final r = rows.first;
    return {
      'classRemindersEnabled':
      (r['class_reminders_enabled'] as int) == 1,
      'classReminderMinutes': r['class_reminder_minutes'],
      'sessionRemindersEnabled':
      (r['session_reminders_enabled'] as int) == 1,
      'sessionReminderMinutes': r['session_reminder_minutes'],
      'deadlineRemindersEnabled':
      (r['deadline_reminders_enabled'] as int) == 1,
      'deadlineReminderDays':
      jsonDecode(r['deadline_reminder_days'] as String),
    };
  }

  // Sync — from cache
  Map<String, dynamic>? loadNotificationPrefs() => _notifPrefsCache;

  // ==================== CLEAR ALL ====================

  Future<void> clearAllData() async {
    final batch = _database.batch();
    for (final table in [
      'calendar_events', 'study_sessions', 'deadlines',
      'knowledge_edges', 'knowledge_nodes', 'knowledge_maps',
      'event_locations', 'study_spots', 'notification_prefs', 'ics_content'
    ]) {
      batch.delete(table);
    }
    await batch.commit(noResult: true);
    _eventsCache.clear();
    _sessionsCache.clear();
    _deadlinesCache.clear();
    _mapsCache.clear();
    _graphCache.clear();
    _locationCache.clear();
    _spotsCache.clear();
    _notifPrefsCache = null;
    _icsCache = null;
    debugPrint('All SQLite data cleared');
  }

  // ==================== STATS ====================

  Map<String, dynamic> getStorageStats() => {
    'events': _eventsCache.length,
    'sessions': _sessionsCache.length,
    'deadlines': _deadlinesCache.length,
    'maps': _mapsCache.length,
    'nodes': _graphCache.values
        .fold<int>(0, (sum, g) => sum + g.nodes.length),
  };

  Future<Map<String, dynamic>> getStorageStatsAsync() async =>
      getStorageStats();

  // ==================== MIGRATION HELPER ====================

  /// Preload all graph data into cache after maps are loaded.
  /// Call this once after initialize() in the controller.
  Future<void> preloadGraphs() async {
    await _preloadGraphCaches();
  }
}