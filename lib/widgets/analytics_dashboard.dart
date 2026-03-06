import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/analytics_service.dart';
import '../models/study_session.dart';

class AnalyticsDashboard extends StatelessWidget {
  final AnalyticsService analytics = AnalyticsService();

  AnalyticsDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final insights = analytics.getInsights();
    final streak = analytics.getCurrentStreak();
    final today = DateTime.now();
    final todayStats = analytics.getDailyStats(today);
    final weekStats = analytics.getWeeklyStats(_getWeekStart(today));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Streak Card
          _buildStreakCard(streak),

          const SizedBox(height: 16),

          // Today's Performance
          _buildTodayCard(todayStats),

          const SizedBox(height: 16),

          // Insights Card
          _buildInsightsCard(insights),

          const SizedBox(height: 16),

          // Weekly Overview
          _buildWeeklyCard(weekStats),

          const SizedBox(height: 16),

          // Best Time to Study
          if (insights.bestTimeToStudy != null)
            _buildBestTimeCard(insights),
        ],
      ),
    );
  }

  Widget _buildStreakCard(StreakInfo streak) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: streak.isOnStreak
              ? [const Color(0xFF10B981), const Color(0xFF059669)]
              : [const Color(0xFF64748B), const Color(0xFF475569)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${streak.currentStreak}',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  streak.isOnStreak ? 'Day Streak!' : 'Start a Streak',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  streak.isOnStreak
                      ? 'Keep it up! Longest: ${streak.longestStreak} days'
                      : 'Complete a session today to start',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            streak.isOnStreak ? Icons.local_fire_department : Icons.whatshot_outlined,
            color: Colors.white,
            size: 40,
          ),
        ],
      ),
    );
  }

  Widget _buildTodayCard(DailyStats stats) {
    final efficiency = stats.averageEfficiency;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Today's Performance",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStat(
                  'Sessions',
                  '${stats.totalSessions}',
                  Icons.menu_book,
                  const Color(0xFF3B82F6),
                ),
              ),
              Expanded(
                child: _buildStat(
                  'Focus',
                  stats.averageFocus.toStringAsFixed(1),
                  Icons.psychology,
                  const Color(0xFFF59E0B),
                ),
              ),
              Expanded(
                child: _buildStat(
                  'Efficiency',
                  '${efficiency.toStringAsFixed(0)}%',
                  Icons.speed,
                  _getEfficiencyColor(efficiency),
                ),
              ),
            ],
          ),
          if (stats.totalSessions > 0) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: stats.completionRate.clamp(0.0, 1.0),
                backgroundColor: const Color(0xFF1E293B),
                valueColor: AlwaysStoppedAnimation<Color>(
                  _getEfficiencyColor(efficiency),
                ),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Time: ${stats.totalActualMinutes} / ${stats.totalPlannedMinutes} min',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInsightsCard(ProductivityInsights insights) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb, color: Color(0xFFF59E0B)),
              const SizedBox(width: 8),
              const Text(
                'Insights',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              _buildTrendIndicator(insights.focusTrend),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            insights.message,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyCard(WeeklyStats stats) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This Week',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildWeekStat('Sessions', '${stats.totalSessions}'),
              _buildWeekStat('Hours', '${(stats.totalActualMinutes / 60).toStringAsFixed(1)}'),
              _buildWeekStat('Consistency', '${stats.consistencyScore.toStringAsFixed(0)}%'),
            ],
          ),
          if (stats.bestDay != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.emoji_events, color: Color(0xFF10B981)),
                  const SizedBox(width: 8),
                  Text(
                    'Best day: ${DateFormat('EEEE').format(stats.bestDay!)}',
                    style: const TextStyle(color: Color(0xFF10B981)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBestTimeCard(ProductivityInsights insights) {
    final time = insights.bestTimeToStudy!;
    final formattedTime = DateFormat('h:mm a').format(
      DateTime(2024, 1, 1, time.hour, time.minute),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF8B5CF6), const Color(0xFF6366F1)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.access_time,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Optimal Study Time',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formattedTime,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${insights.recommendedSessionLength} min sessions',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildWeekStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildTrendIndicator(Trend trend) {
    IconData icon;
    Color color;
    String label;

    switch (trend) {
      case Trend.improving:
        icon = Icons.trending_up;
        color = const Color(0xFF10B981);
        label = 'Improving';
        break;
      case Trend.declining:
        icon = Icons.trending_down;
        color = const Color(0xFFEF4444);
        label = 'Declining';
        break;
      case Trend.stable:
        icon = Icons.trending_flat;
        color = const Color(0xFF64748B);
        label = 'Stable';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Color _getEfficiencyColor(double efficiency) {
    if (efficiency >= 80) return const Color(0xFF10B981);
    if (efficiency >= 60) return const Color(0xFFF59E0B);
    if (efficiency >= 40) return const Color(0xFFF97316);
    return const Color(0xFFEF4444);
  }

  DateTime _getWeekStart(DateTime date) {
    final weekday = date.weekday;
    return DateTime(date.year, date.month, date.day - (weekday - 1));
  }
}