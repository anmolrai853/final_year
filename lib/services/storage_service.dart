import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/event.dart';
import '../models/study_session.dart';
import '../models/knowledge_node.dart';
import '../models/deadline.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  SharedPreferences? _prefs;

  // Keys
  static const String _studySessionsKey = 'study_sessions';
  static const String _knowledgeMapsKey = 'knowledge_maps';
  static const String _knowledgeGraphDataKey = 'knowledge_graph_data_';
  static const String _eventLocationsKey = 'event_locations';
  static const String _calendarEventsKey = 'calendar_events';
  static const String _icsContentKey = 'ics_content';
  static const String _deadlinesKey = 'deadlines';
  static const String _notificationPrefsKey = 'notification_prefs';

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ==================== STUDY SESSIONS ====================

  Future<bool> saveStudySessions(List<StudySession> sessions) async {
    if (_prefs == null) await initialize();
    final jsonList = sessions.map((s) => s.toJson()).toList();
    return await _prefs!.setString(_studySessionsKey, jsonEncode(jsonList));
  }

  List<StudySession> loadStudySessions() {
    if (_prefs == null) return [];
    final jsonString = _prefs!.getString(_studySessionsKey);
    if (jsonString == null) return [];
    try {
      final jsonList = jsonDecode(jsonString) as List;
      return jsonList.map((j) => StudySession.fromJson(j)).toList();
    } catch (e) {
      debugPrint('Error loading study sessions: $e');
      return [];
    }
  }

  Future<bool> addStudySession(StudySession session) async {
    final sessions = loadStudySessions()..add(session);
    return await saveStudySessions(sessions);
  }

  Future<bool> updateStudySession(StudySession updatedSession) async {
    final sessions = loadStudySessions();
    final index = sessions.indexWhere((s) => s.id == updatedSession.id);
    if (index != -1) {
      sessions[index] = updatedSession;
      return await saveStudySessions(sessions);
    }
    return false;
  }

  Future<bool> deleteStudySession(String sessionId) async {
    final sessions = loadStudySessions()..removeWhere((s) => s.id == sessionId);
    return await saveStudySessions(sessions);
  }

  List<StudySession> getStudySessionsForDay(DateTime day) {
    return loadStudySessions().where((s) {
      return s.startTime.year == day.year &&
          s.startTime.month == day.month &&
          s.startTime.day == day.day;
    }).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  List<StudySession> getStudySessionsForRange(DateTime start, DateTime end) {
    return loadStudySessions().where((s) {
      return s.startTime.isBefore(end) && s.endTime.isAfter(start);
    }).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  List<StudySession> getStudySessionsForWeek(DateTime weekStart) {
    return getStudySessionsForRange(weekStart, weekStart.add(const Duration(days: 7)));
  }

  Future<bool> toggleSessionCompletion(String sessionId) async {
    final sessions = loadStudySessions();
    final index = sessions.indexWhere((s) => s.id == sessionId);
    if (index != -1) {
      sessions[index] = sessions[index].copyWith(isCompleted: !sessions[index].isCompleted);
      return await saveStudySessions(sessions);
    }
    return false;
  }

  // ==================== DEADLINES ====================

  Future<bool> saveDeadlines(List<Deadline> deadlines) async {
    if (_prefs == null) await initialize();
    final jsonList = deadlines.map((d) => d.toJson()).toList();
    return await _prefs!.setString(_deadlinesKey, jsonEncode(jsonList));
  }

  List<Deadline> loadDeadlines() {
    if (_prefs == null) return [];
    final jsonString = _prefs!.getString(_deadlinesKey);
    if (jsonString == null) return [];
    try {
      final jsonList = jsonDecode(jsonString) as List;
      return jsonList.map((j) => Deadline.fromJson(j)).toList();
    } catch (e) {
      debugPrint('Error loading deadlines: $e');
      return [];
    }
  }

  Future<bool> addDeadline(Deadline deadline) async {
    final deadlines = loadDeadlines()..add(deadline);
    return await saveDeadlines(deadlines);
  }

  Future<bool> updateDeadline(Deadline updated) async {
    final deadlines = loadDeadlines();
    final index = deadlines.indexWhere((d) => d.id == updated.id);
    if (index != -1) {
      deadlines[index] = updated;
      return await saveDeadlines(deadlines);
    }
    return false;
  }

  Future<bool> deleteDeadline(String deadlineId) async {
    final deadlines = loadDeadlines()..removeWhere((d) => d.id == deadlineId);
    return await saveDeadlines(deadlines);
  }

  List<Deadline> getUpcomingDeadlines() {
    return loadDeadlines().where((d) => d.status != DeadlineStatus.completed).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  }

  List<Deadline> getOverdueDeadlines() {
    return loadDeadlines().where((d) => d.isOverdue).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  }

  List<Deadline> getDeadlinesForModule(String moduleCode) {
    return loadDeadlines().where((d) => d.moduleCode == moduleCode).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  }

  Future<bool> clearDeadlines() async {
    if (_prefs == null) await initialize();
    return await _prefs!.remove(_deadlinesKey);
  }

  // ==================== NOTIFICATION PREFERENCES ====================

  Future<bool> saveNotificationPrefs(Map<String, dynamic> prefs) async {
    if (_prefs == null) await initialize();
    return await _prefs!.setString(_notificationPrefsKey, jsonEncode(prefs));
  }

  Map<String, dynamic>? loadNotificationPrefs() {
    if (_prefs == null) return null;
    final jsonString = _prefs!.getString(_notificationPrefsKey);
    if (jsonString == null) return null;
    try {
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error loading notification prefs: $e');
      return null;
    }
  }

  // ==================== KNOWLEDGE MAPS ====================

  Future<bool> saveKnowledgeMap(KnowledgeMap map) async {
    if (_prefs == null) await initialize();
    final maps = loadKnowledgeMaps();
    final index = maps.indexWhere((m) => m.id == map.id);
    if (index != -1) { maps[index] = map; } else { maps.add(map); }
    return await _prefs!.setString(_knowledgeMapsKey, jsonEncode(maps.map((m) => m.toJson()).toList()));
  }

  List<KnowledgeMap> loadKnowledgeMaps() {
    if (_prefs == null) return [];
    final jsonString = _prefs!.getString(_knowledgeMapsKey);
    if (jsonString == null) return [];
    try {
      final jsonList = jsonDecode(jsonString) as List;
      return jsonList.map((j) => KnowledgeMap.fromJson(j)).toList();
    } catch (e) {
      debugPrint('Error loading knowledge maps: $e');
      return [];
    }
  }

  Future<bool> deleteKnowledgeMap(String mapId) async {
    if (_prefs == null) await initialize();
    final maps = loadKnowledgeMaps()..removeWhere((m) => m.id == mapId);
    final result = await _prefs!.setString(_knowledgeMapsKey, jsonEncode(maps.map((m) => m.toJson()).toList()));
    await _prefs!.remove('$_knowledgeGraphDataKey$mapId');
    return result;
  }

  // ==================== KNOWLEDGE GRAPH DATA ====================

  Future<bool> saveKnowledgeGraphData(KnowledgeGraphData data) async {
    if (_prefs == null) await initialize();
    return await _prefs!.setString('$_knowledgeGraphDataKey${data.mapId}', jsonEncode(data.toJson()));
  }

  KnowledgeGraphData? getKnowledgeGraphData(String mapId) {
    if (_prefs == null) return null;
    final jsonString = _prefs!.getString('$_knowledgeGraphDataKey$mapId');
    if (jsonString == null) return null;
    try { return KnowledgeGraphData.fromJson(jsonDecode(jsonString)); }
    catch (e) { debugPrint('Error loading knowledge graph data: $e'); return null; }
  }

  Future<bool> deleteKnowledgeGraphData(String mapId) async {
    if (_prefs == null) await initialize();
    return await _prefs!.remove('$_knowledgeGraphDataKey$mapId');
  }

  Future<bool> addKnowledgeNode(String mapId, KnowledgeNode node) async {
    var data = getKnowledgeGraphData(mapId) ?? KnowledgeGraphData(mapId: mapId, nodes: [], edges: []);
    data = data.copyWith(nodes: List<KnowledgeNode>.from(data.nodes)..add(node));
    return await saveKnowledgeGraphData(data);
  }

  Future<bool> updateKnowledgeNode(String mapId, KnowledgeNode updatedNode) async {
    var data = getKnowledgeGraphData(mapId);
    if (data == null) return false;
    final nodes = List<KnowledgeNode>.from(data.nodes);
    final index = nodes.indexWhere((n) => n.id == updatedNode.id);
    if (index != -1) {
      nodes[index] = updatedNode;
      return await saveKnowledgeGraphData(data.copyWith(nodes: nodes));
    }
    return false;
  }

  Future<bool> deleteKnowledgeNode(String mapId, String nodeId) async {
    var data = getKnowledgeGraphData(mapId);
    if (data == null) return false;
    final nodes = List<KnowledgeNode>.from(data.nodes)..removeWhere((n) => n.id == nodeId);
    final edges = List<KnowledgeEdge>.from(data.edges)..removeWhere((e) => e.sourceId == nodeId || e.targetId == nodeId);
    return await saveKnowledgeGraphData(data.copyWith(nodes: nodes, edges: edges));
  }

  Future<bool> addKnowledgeEdge(String mapId, KnowledgeEdge edge) async {
    var data = getKnowledgeGraphData(mapId) ?? KnowledgeGraphData(mapId: mapId, nodes: [], edges: []);
    final edges = List<KnowledgeEdge>.from(data.edges);
    final exists = edges.any((e) => (e.sourceId == edge.sourceId && e.targetId == edge.targetId) || (e.sourceId == edge.targetId && e.targetId == edge.sourceId));
    if (!exists) {
      edges.add(edge);
      return await saveKnowledgeGraphData(data.copyWith(edges: edges));
    }
    return false;
  }

  Future<bool> deleteKnowledgeEdge(String mapId, String edgeId) async {
    var data = getKnowledgeGraphData(mapId);
    if (data == null) return false;
    final edges = List<KnowledgeEdge>.from(data.edges)..removeWhere((e) => e.id == edgeId);
    return await saveKnowledgeGraphData(data.copyWith(edges: edges));
  }

  // ==================== EVENT LOCATIONS ====================

  Future<bool> saveEventLocation(String eventId, String location) async {
    if (_prefs == null) await initialize();
    final locations = loadEventLocations();
    locations[eventId] = location;
    return await _prefs!.setString(_eventLocationsKey, jsonEncode(locations));
  }

  Map<String, String> loadEventLocations() {
    if (_prefs == null) return {};
    final jsonString = _prefs!.getString(_eventLocationsKey);
    if (jsonString == null) return {};
    try {
      final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
      return jsonMap.map((k, v) => MapEntry(k, v.toString()));
    } catch (e) { debugPrint('Error loading event locations: $e'); return {}; }
  }

  String? getEventLocation(String eventId) => loadEventLocations()[eventId];

  // ==================== CALENDAR EVENTS ====================

  Future<bool> saveCalendarEvents(List<CalendarEvent> events) async {
    if (_prefs == null) await initialize();
    return await _prefs!.setString(_calendarEventsKey, jsonEncode(events.map((e) => e.toJson()).toList()));
  }

  List<CalendarEvent> loadCalendarEvents() {
    if (_prefs == null) return [];
    final jsonString = _prefs!.getString(_calendarEventsKey);
    if (jsonString == null) return [];
    try {
      final jsonList = jsonDecode(jsonString) as List;
      return jsonList.map((j) => CalendarEvent.fromJson(j)).toList();
    } catch (e) { debugPrint('Error loading calendar events: $e'); return []; }
  }

  // ==================== ICS CONTENT ====================

  Future<bool> saveIcsContent(String content) async {
    if (_prefs == null) await initialize();
    return await _prefs!.setString(_icsContentKey, content);
  }

  String? loadIcsContent() {
    if (_prefs == null) return null;
    return _prefs!.getString(_icsContentKey);
  }

  // ==================== CLEAR DATA ====================

  Future<bool> clearAllData() async {
    if (_prefs == null) await initialize();
    return await _prefs!.clear();
  }

  Future<bool> clearStudySessions() async {
    if (_prefs == null) await initialize();
    return await _prefs!.remove(_studySessionsKey);
  }

  Future<bool> clearKnowledgeMaps() async {
    if (_prefs == null) await initialize();
    final maps = loadKnowledgeMaps();
    for (final map in maps) { await _prefs!.remove('$_knowledgeGraphDataKey${map.id}'); }
    return await _prefs!.remove(_knowledgeMapsKey);
  }

  Future<void> migrateOldGraphs() async {
    debugPrint('StorageService initialized - using user-created maps system');
  }

  // ==================== STATS ====================

  Map<String, dynamic> getStorageStats() {
    final sessions = loadStudySessions();
    final maps = loadKnowledgeMaps();
    final events = loadCalendarEvents();
    final deadlines = loadDeadlines();
    int totalNodes = 0, totalEdges = 0;
    for (final map in maps) {
      final data = getKnowledgeGraphData(map.id);
      if (data != null) { totalNodes += data.nodes.length; totalEdges += data.edges.length; }
    }
    return { 'events': events.length, 'sessions': sessions.length, 'maps': maps.length, 'nodes': totalNodes, 'edges': totalEdges, 'deadlines': deadlines.length };
  }

  // ==================== STUDY SPOTS ====================

  static const String _studySpotsKey = 'study_spots';

  Future<bool> saveStudySpots(List<Map<String, dynamic>> spots) async {
    if (_prefs == null) await initialize();
    return await _prefs!.setString(_studySpotsKey, jsonEncode(spots));
  }

  List<Map<String, dynamic>> loadStudySpots() {
    if (_prefs == null) return [];
    final json = _prefs!.getString(_studySpotsKey);
    if (json == null) return [];
    try { return (jsonDecode(json) as List).cast<Map<String, dynamic>>(); }
    catch (e) { return []; }
  }
}