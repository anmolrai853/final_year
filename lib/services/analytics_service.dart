import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/study_session.dart';
import 'storage_service.dart';

class AnalyticsService {
  final StorageService _storage = StorageService();

  // ==================== SESSION-LEVEL METRICS ====================

  double calculateSessionEfficiency(StudySession session) {
    if (!session.hasPerformanceData) return 0.0;

    final focusWeight = 0.6;
    final timeWeight = 0.4;

    final focusScore = (session.focusLevel?.stars ?? 0) / 5.0;
    final timeScore = ((session.actualDurationMinutes ?? 0) / session.durationMinutes).clamp(0.0, 1.0);

    return (focusScore * focusWeight + timeScore * timeWeight) * 100;
  }

  // ==================== DAILY METRICS ====================

  DailyStats getDailyStats(DateTime day) {
    final sessions = _storage.getStudySessionsForDay(day)
        .where((s) => s.isCompleted && s.hasPerformanceData)
        .toList();

    if (sessions.isEmpty) return DailyStats.empty(day);

    final totalPlanned = sessions.fold<int>(0, (sum, s) => sum + s.durationMinutes);
    final totalActual = sessions.fold<int>(0, (sum, s) => sum + (s.actualDurationMinutes ?? 0));
    final avgFocus = sessions
        .where((s) => s.focusLevel != null)
        .map((s) => s.focusLevel!.stars)
        .fold<double>(0, (sum, stars) => sum + stars) /
        sessions.where((s) => s.focusLevel != null).length;

    return DailyStats(
      date: day,
      totalSessions: sessions.length,
      totalPlannedMinutes: totalPlanned,
      totalActualMinutes: totalActual,
      averageFocus: avgFocus,
      completionRate: totalPlanned > 0 ? totalActual / totalPlanned : 0.0,
      sessions: sessions,
    );
  }

  // ==================== WEEKLY METRICS ====================

  WeeklyStats getWeeklyStats(DateTime weekStart) {
    final weekEnd = weekStart.add(const Duration(days: 7));
    final sessions = _storage.getStudySessionsForRange(weekStart, weekEnd)
        .where((s) => s.isCompleted && s.hasPerformanceData)
        .toList();

    if (sessions.isEmpty) return WeeklyStats.empty(weekStart);

    final dailyStats = List.generate(7, (i) {
      final day = weekStart.add(Duration(days: i));
      return getDailyStats(day);
    });

    final totalPlanned = sessions.fold<int>(0, (sum, s) => sum + s.durationMinutes);
    final totalActual = sessions.fold<int>(0, (sum, s) => sum + (s.actualDurationMinutes ?? 0));

    final bestDay = dailyStats.reduce((a, b) =>
    a.averageEfficiency > b.averageEfficiency ? a : b);

    final timeDistribution = _analyzeTimeDistribution(sessions);

    return WeeklyStats(
      weekStart: weekStart,
      totalSessions: sessions.length,
      totalPlannedMinutes: totalPlanned,
      totalActualMinutes: totalActual,
      dailyStats: dailyStats,
      bestDay: bestDay.date,
      mostProductiveHour: timeDistribution.mostProductiveHour,
      averageFocus: sessions
          .where((s) => s.focusLevel != null)
          .map((s) => s.focusLevel!.stars)
          .fold<double>(0, (sum, s) => sum + s) /
          sessions.where((s) => s.focusLevel != null).length,
      consistencyScore: _calculateConsistency(sessions),
    );
  }

  // ==================== HABIT & STREAK TRACKING ====================

  StreakInfo getCurrentStreak() {
    final allSessions = _storage.loadStudySessions()
        .where((s) => s.isCompleted && s.hasPerformanceData)
        .toList();

    if (allSessions.isEmpty) return StreakInfo(currentStreak: 0, longestStreak: 0);

    final studyDays = <DateTime>{};
    for (final session in allSessions) {
      final day = DateTime(
        session.startTime.year,
        session.startTime.month,
        session.startTime.day,
      );
      studyDays.add(day);
    }

    final sortedDays = studyDays.toList()..sort((a, b) => b.compareTo(a));

    int currentStreak = 0;
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    for (int i = 0; i < sortedDays.length; i++) {
      final expectedDay = todayDate.subtract(Duration(days: i));
      if (_isSameDay(sortedDays[i], expectedDay)) {
        currentStreak++;
      } else {
        break;
      }
    }

    int longestStreak = 1;
    int currentRun = 1;
    for (int i = 1; i < sortedDays.length; i++) {
      final prevDay = sortedDays[i-1];
      final currDay = sortedDays[i];
      if (prevDay.difference(currDay).inDays == 1) {
        currentRun++;
        longestStreak = max(longestStreak, currentRun);
      } else {
        currentRun = 1;
      }
    }

    return StreakInfo(
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      lastStudyDate: sortedDays.firstOrNull,
    );
  }

  // ==================== PRODUCTIVITY INSIGHTS ====================

  ProductivityInsights getInsights() {
    final sessions = _storage.loadStudySessions()
        .where((s) => s.isCompleted && s.hasPerformanceData)
        .toList();

    if (sessions.length < 3) {
      return ProductivityInsights(
        message: "Keep tracking your sessions to get personalized insights!",
        bestTimeToStudy: null,
        recommendedSessionLength: 45,
        focusTrend: Trend.stable,
      );
    }

    final hourPerformance = <int, List<double>>{};
    for (final session in sessions) {
      final hour = session.startTime.hour;
      final efficiency = calculateSessionEfficiency(session);
      hourPerformance.putIfAbsent(hour, () => []).add(efficiency);
    }

    final avgByHour = hourPerformance.map((hour, efficiencies) =>
        MapEntry(hour, efficiencies.reduce((a, b) => a + b) / efficiencies.length));

    final bestHour = avgByHour.entries.reduce((a, b) => a.value > b.value ? a : b).key;

    final lengthEfficiency = <int, List<double>>{};
    for (final session in sessions) {
      final bucket = (session.durationMinutes / 15).round() * 15;
      final efficiency = calculateSessionEfficiency(session);
      lengthEfficiency.putIfAbsent(bucket, () => []).add(efficiency);
    }

    final avgByLength = lengthEfficiency.map((len, effs) =>
        MapEntry(len, effs.reduce((a, b) => a + b) / effs.length));

    final optimalLength = avgByLength.entries.reduce((a, b) => a.value > b.value ? a : b).key;

    final now = DateTime.now();
    final lastWeek = sessions.where((s) =>
        s.startTime.isAfter(now.subtract(const Duration(days: 7))));
    final previousWeek = sessions.where((s) =>
    s.startTime.isAfter(now.subtract(const Duration(days: 14))) &&
        s.startTime.isBefore(now.subtract(const Duration(days: 7))));

    final lastWeekAvg = lastWeek.isEmpty ? 0 :
    lastWeek.map(calculateSessionEfficiency).reduce((a, b) => a + b) / lastWeek.length;
    final prevWeekAvg = previousWeek.isEmpty ? 0 :
    previousWeek.map(calculateSessionEfficiency).reduce((a, b) => a + b) / previousWeek.length;

    Trend trend;
    if (lastWeekAvg > prevWeekAvg * 1.1) {
      trend = Trend.improving;
    } else if (lastWeekAvg < prevWeekAvg * 0.9) {
      trend = Trend.declining;
    } else {
      trend = Trend.stable;
    }

    return ProductivityInsights(
      message: _generateMessage(trend, bestHour, optimalLength),
      bestTimeToStudy: TimeOfDay(hour: bestHour, minute: 0),
      recommendedSessionLength: optimalLength,
      focusTrend: trend,
      averageEfficiency: sessions.map(calculateSessionEfficiency).reduce((a, b) => a + b) / sessions.length,
    );
  }

  // ==================== HELPERS ====================

  TimeDistribution _analyzeTimeDistribution(List<StudySession> sessions) {
    final hourProductivity = <int, double>{};

    for (int hour = 0; hour < 24; hour++) {
      final hourSessions = sessions.where((s) => s.startTime.hour == hour);
      if (hourSessions.isNotEmpty) {
        final avgEfficiency = hourSessions
            .map(calculateSessionEfficiency)
            .reduce((a, b) => a + b) / hourSessions.length;
        hourProductivity[hour] = avgEfficiency;
      }
    }

    if (hourProductivity.isEmpty) {
      return TimeDistribution(mostProductiveHour: 9, distribution: {});
    }

    final bestHour = hourProductivity.entries
        .reduce((a, b) => a.value > b.value ? a : b).key;

    return TimeDistribution(
      mostProductiveHour: bestHour,
      distribution: hourProductivity,
    );
  }

  double _calculateConsistency(List<StudySession> sessions) {
    if (sessions.length < 2) return 0.0;

    final dailyMinutes = <DateTime, int>{};
    for (final session in sessions) {
      final day = DateTime(
        session.startTime.year,
        session.startTime.month,
        session.startTime.day,
      );
      dailyMinutes[day] = (dailyMinutes[day] ?? 0) + (session.actualDurationMinutes ?? 0);
    }

    final values = dailyMinutes.values.toList();
    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance = values.map((v) => pow(v - mean, 2)).reduce((a, b) => a + b) / values.length;
    final stdDev = sqrt(variance);

    return (100 - (stdDev / mean * 100)).clamp(0.0, 100.0);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _generateMessage(Trend trend, int bestHour, int optimalLength) {
    final timeStr = DateFormat('h a').format(DateTime(2024, 1, 1, bestHour));

    switch (trend) {
      case Trend.improving:
        return "Great progress! Your focus is improving. Keep studying at $timeStr for best results.";
      case Trend.declining:
        return "Your focus has dropped recently. Try shorter ${optimalLength}min sessions at $timeStr.";
      case Trend.stable:
        return "You're consistent! Your optimal time is $timeStr with ${optimalLength}min sessions.";
    }
  }
}

// ==================== DATA CLASSES ====================

class DailyStats {
  final DateTime date;
  final int totalSessions;
  final int totalPlannedMinutes;
  final int totalActualMinutes;
  final double averageFocus;
  final double completionRate;
  final List<StudySession> sessions;

  DailyStats({
    required this.date,
    required this.totalSessions,
    required this.totalPlannedMinutes,
    required this.totalActualMinutes,
    required this.averageFocus,
    required this.completionRate,
    required this.sessions,
  });

  DailyStats.empty(DateTime day) : this(
    date: day,
    totalSessions: 0,
    totalPlannedMinutes: 0,
    totalActualMinutes: 0,
    averageFocus: 0,
    completionRate: 0,
    sessions: [],
  );

  double get averageEfficiency {
    if (sessions.isEmpty) return 0;
    final validSessions = sessions.where((s) => s.hasPerformanceData).toList();
    if (validSessions.isEmpty) return 0;
    return validSessions.map((s) => s.efficiencyScore).reduce((a, b) => a + b) / validSessions.length;
  }

  int get totalFocusScore => sessions
      .where((s) => s.focusLevel != null)
      .fold<int>(0, (sum, s) => sum + s.focusLevel!.stars);
}

class WeeklyStats {
  final DateTime weekStart;
  final int totalSessions;
  final int totalPlannedMinutes;
  final int totalActualMinutes;
  final List<DailyStats> dailyStats;
  final DateTime? bestDay;
  final int? mostProductiveHour;
  final double averageFocus;
  final double consistencyScore;

  WeeklyStats({
    required this.weekStart,
    required this.totalSessions,
    required this.totalPlannedMinutes,
    required this.totalActualMinutes,
    required this.dailyStats,
    this.bestDay,
    this.mostProductiveHour,
    required this.averageFocus,
    required this.consistencyScore,
  });

  WeeklyStats.empty(DateTime start) : this(
    weekStart: start,
    totalSessions: 0,
    totalPlannedMinutes: 0,
    totalActualMinutes: 0,
    dailyStats: [],
    bestDay: null,
    mostProductiveHour: null,
    averageFocus: 0,
    consistencyScore: 0,
  );

  double get completionRate => totalPlannedMinutes > 0
      ? totalActualMinutes / totalPlannedMinutes
      : 0.0;
}

class StreakInfo {
  final int currentStreak;
  final int longestStreak;
  final DateTime? lastStudyDate;

  StreakInfo({
    required this.currentStreak,
    required this.longestStreak,
    this.lastStudyDate,
  });

  bool get isOnStreak => currentStreak > 0;
}

class ProductivityInsights {
  final String message;
  final TimeOfDay? bestTimeToStudy;
  final int recommendedSessionLength;
  final Trend focusTrend;
  final double? averageEfficiency;

  ProductivityInsights({
    required this.message,
    this.bestTimeToStudy,
    required this.recommendedSessionLength,
    required this.focusTrend,
    this.averageEfficiency,
  });
}

class TimeDistribution {
  final int mostProductiveHour;
  final Map<int, double> distribution;

  TimeDistribution({
    required this.mostProductiveHour,
    required this.distribution,
  });
}

enum Trend { improving, declining, stable }