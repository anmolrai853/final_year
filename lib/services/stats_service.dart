import '../screens/knowledgeGraphpage.dart';

class StatsService {

  double completionRate(
      List<Map<String, dynamic>> sessions, DateTime weekStart) {
    final weekEnd = weekStart.add(const Duration(days: 7));
    final week = sessions.where((s) {
      final start = s['start'] as DateTime;
      return start.isAfter(weekStart) && start.isBefore(weekEnd);
    }).toList();
    if (week.isEmpty) return 0;
    return week.where((s) => s['completed'] == true).length / week.length;
  }

  int currentStreak(List<Map<String, dynamic>> history) {
    if (history.isEmpty) return 0;
    final byDay = <DateTime, List<Map<String, dynamic>>>{};
    for (final s in history) {
      final d   = s['start'] as DateTime;
      final key = DateTime(d.year, d.month, d.day);
      byDay.putIfAbsent(key, () => []).add(s);
    }
    int streak = 0;
    var day = DateTime.now();
    day = DateTime(day.year, day.month, day.day);
    while (true) {
      final sessions = byDay[day];
      if (sessions == null || sessions.isEmpty) break;
      if (!sessions.every((s) => s['completed'] == true)) break;
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  Map<String, int> minutesPerModule(List<Map<String, dynamic>> history) {
    final map = <String, int>{};
    for (final s in history.where((s) => s['completed'] == true)) {
      final module  = s['module'] as String? ?? 'Unknown';
      final actual  = s['actualDuration'] as int?;
      final planned = (s['end'] as DateTime)
          .difference(s['start'] as DateTime)
          .inMinutes;
      map[module] = (map[module] ?? 0) + (actual ?? planned);
    }
    return map;
  }

  Map<int, int> sessionsByHour(List<Map<String, dynamic>> history) {
    final map = <int, int>{};
    for (final s in history.where((s) => s['completed'] == true)) {
      final hour = (s['start'] as DateTime).hour;
      map[hour] = (map[hour] ?? 0) + 1;
    }
    return map;
  }

  String bestTimeOfDay(List<Map<String, dynamic>> history) {
    final byHour = sessionsByHour(history);
    if (byHour.isEmpty) return 'No data';
    final peak =
        byHour.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    if (peak < 12) return 'Morning (${peak}:00)';
    if (peak < 17) return 'Afternoon (${peak}:00)';
    return 'Evening (${peak}:00)';
  }

  Map<DateTime, int> heatmapData(List<Map<String, dynamic>> history) {
    final map = <DateTime, int>{};
    for (final s in history.where((s) => s['completed'] == true)) {
      final d   = s['start'] as DateTime;
      final key = DateTime(d.year, d.month, d.day);
      final actual  = s['actualDuration'] as int?;
      final planned = (s['end'] as DateTime)
          .difference(s['start'] as DateTime)
          .inMinutes;
      map[key] = (map[key] ?? 0) + (actual ?? planned);
    }
    return map;
  }

  List<String> underrevisedModules(List<Map<String, dynamic>> history,
      List<String> allModules, int days) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final recent = history
        .where((s) => (s['start'] as DateTime).isAfter(cutoff))
        .map((s) => s['module'] as String)
        .toSet();
    return allModules.where((m) => !recent.contains(m)).toList();
  }

  DateTime nextReviewDate(int confidenceLevel, DateTime lastReviewed) {
    const intervals = [1, 1, 3, 7, 14, 30];
    final days = intervals[confidenceLevel.clamp(0, 5)];
    return lastReviewed.add(Duration(days: days));
  }

  double avgConfidence(List<GraphNode> nodes) {
    if (nodes.isEmpty) return 0;
    final rated = nodes.where((n) => n.confidenceLevel > 0).toList();
    if (rated.isEmpty) return 0;
    return rated.fold(0.0, (sum, n) => sum + n.confidenceLevel) / rated.length;
  }

  List<GraphNode> nodesDueForReview(List<GraphNode> nodes) {
    final now = DateTime.now();
    return nodes
        .where((n) =>
    n.nextReviewDue != null && !n.nextReviewDue!.isAfter(now))
        .toList();
  }

  double productivityScore({
    required double completionRate,
    required double avgConfidence,
    required int streak,
  }) {
    final streakScore = (streak / 30).clamp(0.0, 1.0);
    final confScore   = avgConfidence / 5.0;
    return ((completionRate * 50) + (confScore * 30) + (streakScore * 20))
        .clamp(0.0, 100.0);
  }
}
