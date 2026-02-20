import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // ── Study Sessions ───────────────────────────────────────────

  Future<void> saveStudySessions(List<Map<String, dynamic>> sessions) async {
    await init();
    final json = sessions.map((s) => {
      ...s,
      'start': (s['start'] as DateTime).toIso8601String(),
      'end':   (s['end']   as DateTime).toIso8601String(),
    }).toList();
    await _prefs!.setString('study_sessions', jsonEncode(json));
  }

  Future<List<Map<String, dynamic>>> loadStudySessions() async {
    await init();
    final raw = _prefs!.getString('study_sessions');
    if (raw == null) return [];
    return (jsonDecode(raw) as List).map((s) => {
      ...Map<String, dynamic>.from(s),
      'start': DateTime.parse(s['start']),
      'end':   DateTime.parse(s['end']),
    }).toList();
  }

  // ── Session History ──────────────────────────────────────────

  Future<void> appendToHistory(Map<String, dynamic> session) async {
    await init();
    final history = await loadHistory();
    history.add({
      ...session,
      'start': (session['start'] as DateTime).toIso8601String(),
      'end':   (session['end']   as DateTime).toIso8601String(),
    });
    await _prefs!.setString('session_history', jsonEncode(history));
  }

  Future<List<Map<String, dynamic>>> loadHistory() async {
    await init();
    final raw = _prefs!.getString('session_history');
    if (raw == null) return [];
    return (jsonDecode(raw) as List).map((s) => {
      ...Map<String, dynamic>.from(s),
      'start': DateTime.parse(s['start']),
      'end':   DateTime.parse(s['end']),
    }).toList();
  }

  // ── Knowledge Graphs ─────────────────────────────────────────

  Future<void> saveKnowledgeGraph(String module, Map<String, dynamic> data) async {
    await init();
    final all = await loadAllKnowledgeGraphs();
    all[module] = data;
    await _prefs!.setString('knowledge_graphs', jsonEncode(all));
    await _appendConfidenceSnapshot(module, data);
  }

  Future<Map<String, dynamic>?> loadKnowledgeGraph(String module) async {
    final all = await loadAllKnowledgeGraphs();
    return all[module];
  }

  Future<Map<String, dynamic>> loadAllKnowledgeGraphs() async {
    await init();
    final raw = _prefs!.getString('knowledge_graphs');
    if (raw == null) return {};
    return Map<String, dynamic>.from(jsonDecode(raw));
  }

  // ── Confidence Snapshots ─────────────────────────────────────

  Future<void> _appendConfidenceSnapshot(
      String module, Map<String, dynamic> graphData) async {
    await init();
    final nodes = graphData['nodes'] as List? ?? [];
    if (nodes.isEmpty) return;
    final total = nodes.fold<int>(
        0, (sum, n) => sum + ((n['confidenceLevel'] as int?) ?? 0));
    final avg = total / nodes.length;
    final all = await loadConfidenceSnapshots();
    all.putIfAbsent(module, () => []);
    all[module]!.add({
      'date': DateTime.now().toIso8601String(),
      'avg':  avg,
    });
    await _prefs!.setString('confidence_snapshots', jsonEncode(all));
  }

  Future<Map<String, List<Map<String, dynamic>>>> loadConfidenceSnapshots() async {
    await init();
    final raw = _prefs!.getString('confidence_snapshots');
    if (raw == null) return {};
    final decoded = Map<String, dynamic>.from(jsonDecode(raw));
    return decoded.map((k, v) => MapEntry(
        k, (v as List).map((e) => Map<String, dynamic>.from(e)).toList()));
  }

  // ── Exam Dates ───────────────────────────────────────────────

  Future<void> saveExamDates(Map<String, DateTime> dates) async {
    await init();
    final json = dates.map((k, v) => MapEntry(k, v.toIso8601String()));
    await _prefs!.setString('exam_dates', jsonEncode(json));
  }

  Future<Map<String, DateTime>> loadExamDates() async {
    await init();
    final raw = _prefs!.getString('exam_dates');
    if (raw == null) return {};
    final decoded = Map<String, dynamic>.from(jsonDecode(raw));
    return decoded.map((k, v) => MapEntry(k, DateTime.parse(v)));
  }

  // ── Event Location Edits ─────────────────────────────────────

  Future<void> saveEventLocationEdit(String id, String loc) async {
    await init();
    final edits = await loadEventLocationEdits();
    edits[id] = loc;
    await _prefs!.setString('event_location_edits', jsonEncode(edits));
  }

  Future<Map<String, String>> loadEventLocationEdits() async {
    await init();
    final raw = _prefs!.getString('event_location_edits');
    if (raw == null) return {};
    return Map<String, String>.from(jsonDecode(raw));
  }

  Future<String?> getEventLocationEdit(String id) async {
    final edits = await loadEventLocationEdits();
    return edits[id];
  }

  // ── Weekly Goal ──────────────────────────────────────────────

  Future<void> saveWeeklyGoal(int minutes) async {
    await init();
    await _prefs!.setInt('weekly_goal_minutes', minutes);
  }

  Future<int> loadWeeklyGoal() async {
    await init();
    return _prefs!.getInt('weekly_goal_minutes') ?? 300;
  }

  // ── Settings ─────────────────────────────────────────────────

  Future<void> saveSettings(Map<String, dynamic> settings) async {
    await init();
    await _prefs!.setString('settings', jsonEncode(settings));
  }

  Future<Map<String, dynamic>> loadSettings() async {
    await init();
    final raw = _prefs!.getString('settings');
    if (raw == null) return _defaultSettings();
    return Map<String, dynamic>.from(jsonDecode(raw));
  }

  Map<String, dynamic> _defaultSettings() => {
    'name':                  '',
    'university':            '',
    'themeMode':             'dark',
    'studyReminderMins':     10,
    'lateAlertMins':         10,
    'defaultSessionMins':    60,
    'notifyStudyReminder':   true,
    'notifySpacedRep':       true,
    'notifyDailySummary':    true,
  };

  // ── Clear All ────────────────────────────────────────────────

  Future<void> clearAllData() async {
    await init();
    await _prefs!.clear();
  }
}
