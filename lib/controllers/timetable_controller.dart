class TimetableController {
  // ---- Singleton ----
  static final TimetableController _instance = TimetableController._internal();
  factory TimetableController() => _instance;
  TimetableController._internal();

  // ---- Cached data ----
  List<Map<String, dynamic>> instances = [];
  Map<String, dynamic>? nextEvent;

  bool get isLoaded => instances.isNotEmpty;

  // ---- Save timetable ----
  void setTimetable({
    required List<Map<String, dynamic>> events,
    required Map<String, dynamic>? next,
  }) {
    instances = events;
    nextEvent = next;
  }

  // ---- Clear if needed ----
  void clear() {
    instances = [];
    nextEvent = null;
  }
}
