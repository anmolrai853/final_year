import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../controllers/timetable_controller.dart';
import '../models/study_session.dart';
import '../services/analytics_service.dart';
import '../widgets/analytics_dashboard.dart';
import '../widgets/session_completion_dialog.dart';
import '../widgets/study_session_dialog.dart';
import 'knowledge_graph_page.dart';
import 'knowledge_maps_list_page.dart';

class PlannerPage extends StatefulWidget {
  const PlannerPage({super.key});

  @override
  State<PlannerPage> createState() => _PlannerPageState();
}

class _PlannerPageState extends State<PlannerPage> with SingleTickerProviderStateMixin {
  final TimetableController _controller = TimetableController();
  final AnalyticsService _analytics = AnalyticsService();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _controller.addListener(_onControllerUpdate);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _controller.removeListener(_onControllerUpdate);
    super.dispose();
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Study Planner',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    onPressed: () => _showAddSessionDialog(),
                    icon: const Icon(Icons.add_circle_outline),
                    color: const Color(0xFF3B82F6),
                    iconSize: 28,
                  ),
                ],
              ),
            ),

            // Tab bar with 4 tabs
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: const Color(0xFF3B82F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: const Color(0xFF94A3B8),
                tabs: const [
                  Tab(text: 'Today'),
                  Tab(text: 'Week'),
                  Tab(text: 'Analytics'),
                  Tab(text: 'Knowledge'),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTodayTab(),
                  _buildWeekTab(),
                  AnalyticsDashboard(),
                  _buildKnowledgeTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayTab() {
    final today = DateTime.now();
    final sessions = _controller.getStudySessionsForDay(today);
    final completedCount = sessions.where((s) => s.isCompleted).length;
    final totalMinutes = sessions.fold<int>(0, (sum, s) => sum + s.durationMinutes);
    final completedMinutes = sessions
        .where((s) => s.isCompleted)
        .fold<int>(0, (sum, s) => sum + (s.actualDurationMinutes ?? s.durationMinutes));

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats cards
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Sessions',
                  '${sessions.length}',
                  Icons.menu_book,
                  const Color(0xFF3B82F6),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Completed',
                  '$completedCount/${sessions.length}',
                  Icons.check_circle,
                  const Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Minutes',
                  '$completedMinutes/$totalMinutes',
                  Icons.timer,
                  const Color(0xFFF59E0B),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Progress indicator
          if (sessions.isNotEmpty) ...[
            Text(
              'Today\'s Progress',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: sessions.isEmpty ? 0 : completedCount / sessions.length,
                backgroundColor: const Color(0xFF1E293B),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                minHeight: 12,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${(sessions.isEmpty ? 0 : (completedCount / sessions.length * 100)).toInt()}% complete',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF94A3B8),
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Sessions list
          Text(
            'Today\'s Sessions',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),

          if (sessions.isEmpty)
            _buildEmptyState(
              'No study sessions today',
              'Tap the + button to add a session',
            )
          else
            ...sessions.map((session) => _buildSessionCard(session)),
        ],
      ),
    );
  }

  Widget _buildWeekTab() {
    final weekStart = _getWeekStart(DateTime.now());
    final sessions = _controller.getStudySessionsForWeek(weekStart);

    final sessionsByDay = <DateTime, List<StudySession>>{};
    for (var i = 0; i < 7; i++) {
      final day = weekStart.add(Duration(days: i));
      sessionsByDay[day] = [];
    }
    for (final session in sessions) {
      final day = DateTime(
        session.startTime.year,
        session.startTime.month,
        session.startTime.day,
      );
      if (sessionsByDay.containsKey(day)) {
        sessionsByDay[day]!.add(session);
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Week summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildWeekStat('Total Sessions', '${sessions.length}'),
                _buildWeekStat('Completed', '${sessions.where((s) => s.isCompleted).length}'),
                _buildWeekStat('Total Hours', '${(sessions.fold<int>(0, (sum, s) => sum + (s.actualDurationMinutes ?? s.durationMinutes)) / 60).toStringAsFixed(1)}'),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Daily breakdown
          Text(
            'This Week',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),

          ...sessionsByDay.entries.map((entry) {
            final day = entry.key;
            final daySessions = entry.value..sort((a, b) => a.startTime.compareTo(b.startTime));
            final dayName = DateFormat('EEEE').format(day);
            final isToday = day.year == DateTime.now().year &&
                day.month == DateTime.now().month &&
                day.day == DateTime.now().day;

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        dayName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isToday ? const Color(0xFF3B82F6) : Colors.white,
                        ),
                      ),
                      if (isToday) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B82F6).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Today',
                            style: TextStyle(
                              fontSize: 10,
                              color: Color(0xFF3B82F6),
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),
                      Text(
                        '${daySessions.length} sessions',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (daySessions.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'No sessions',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    )
                  else
                    ...daySessions.map((session) => _buildSessionCard(session)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // In _buildKnowledgeTab():
  Widget _buildKnowledgeTab() {
    return const KnowledgeMapsListPage(); // Use the new list page
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }

  Widget _buildSessionCard(StudySession session) {
    final timeFormat = DateFormat('HH:mm');
    final isPast = session.isPast;
    final hasPerformance = session.hasPerformanceData;

    return Dismissible(
      key: Key('planner_${session.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) => _confirmDelete(session),
      onDismissed: (_) => _deleteSession(session),
      child: GestureDetector(
        onTap: () => _showEditSessionDialog(session),
        onLongPress: () => _toggleSessionComplete(session),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isPast ? const Color(0xFF0F172A).withOpacity(0.5) : const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: session.isCompleted
                  ? const Color(0xFF10B981)
                  : session.type.color.withOpacity(0.3),
              width: session.isCompleted ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              // Type icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: session.type.color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  session.type.icon,
                  color: session.type.color,
                ),
              ),
              const SizedBox(width: 16),

              // Session info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isPast ? Colors.white.withOpacity(0.5) : Colors.white,
                        decoration: session.isCompleted ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: isPast ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${timeFormat.format(session.startTime)} - ${timeFormat.format(session.endTime)}',
                          style: TextStyle(
                            fontSize: 13,
                            color: isPast ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: session.type.color.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            session.type.displayName,
                            style: TextStyle(
                              fontSize: 11,
                              color: session.type.color,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (hasPerformance) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.star,
                            size: 12,
                            color: Colors.amber,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${session.focusLevel?.stars ?? 0}/5 • ${session.efficiencyScore.toStringAsFixed(0)}% efficient',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Completion status
              if (session.isCompleted && hasPerformance)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${session.focusLevel?.stars ?? 0}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              else if (session.isCompleted)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 16,
                  ),
                )
              else if (isPast)
                  const Icon(
                    Icons.schedule,
                    color: Color(0xFF64748B),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModuleCard(String moduleCode) {
    final color = _controller.getModuleColor(moduleCode);

    return GestureDetector(
      onTap: () => _openKnowledgeGraph(moduleCode),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.account_tree,
                color: color,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    moduleCode,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Tap to view knowledge map',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: color,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(32),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 64,
            color: const Color(0xFF334155),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF64748B),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  DateTime _getWeekStart(DateTime date) {
    final weekday = date.weekday;
    return DateTime(date.year, date.month, date.day - (weekday - 1));
  }

  Future<bool> _confirmDelete(StudySession session) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Session'),
        content: Text('Are you sure you want to delete "${session.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFEF4444),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _deleteSession(StudySession session) async {
    await _controller.deleteStudySession(session.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${session.title}" deleted'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              await _controller.addStudySession(session);
            },
          ),
        ),
      );
    }
  }

  Future<void> _toggleSessionComplete(StudySession session) async {
    if (session.isCompleted) {
      await _controller.toggleSessionCompletion(session.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${session.title}" marked incomplete'),
            backgroundColor: const Color(0xFF64748B),
          ),
        );
      }
      return;
    }

    // Show completion dialog for rating
    showDialog(
      context: context,
      builder: (context) => SessionCompletionDialog(
        session: session,
        onComplete: (updatedSession) async {
          await _controller.updateStudySession(updatedSession);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Session completed! Efficiency: ${updatedSession.efficiencyScore.toStringAsFixed(0)}%'),
                backgroundColor: const Color(0xFF10B981),
              ),
            );
          }
        },
      ),
    );
  }

  void _showAddSessionDialog() {
    showDialog(
      context: context,
      builder: (context) => const StudySessionDialog(),
    );
  }

  void _showEditSessionDialog(StudySession session) {
    showDialog(
      context: context,
      builder: (context) => StudySessionDialog(session: session),
    );
  }

  void _openKnowledgeGraph(String mapId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => KnowledgeGraphPage(mapId: mapId),
      ),
    );
  }
}