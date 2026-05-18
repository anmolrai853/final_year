import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../controllers/timetable_controller.dart';
import '../models/study_session.dart';
import '../models/deadline.dart';
import '../services/analytics_service.dart';
import '../widgets/analytics_dashboard.dart';
import '../widgets/session_completion_dialog.dart';
import '../widgets/study_session_dialog.dart';
import '../widgets/deadline_dialog.dart';
import 'pomodoro_timer_page.dart';

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
    final overdueCount = _controller.getOverdueDeadlines().length;

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
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => _showAddDeadlineDialog(),
                        icon: const Icon(Icons.flag_outlined),
                        color: const Color(0xFFF59E0B),
                        iconSize: 24,
                        tooltip: 'Add Deadline',
                      ),
                      IconButton(
                        onPressed: () => _showAddSessionDialog(),
                        icon: const Icon(Icons.add_circle_outline),
                        color: const Color(0xFF3B82F6),
                        iconSize: 28,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Tab bar with 5 tabs
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
                labelPadding: EdgeInsets.zero,
                tabs: [
                  const Tab(text: 'Today'),
                  const Tab(text: 'Week'),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Deadlines'),
                        if (overdueCount > 0) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$overdueCount',
                              style: const TextStyle(fontSize: 10, color: Colors.white),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Tab(text: 'Analytics'),
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
                  _buildDeadlinesTab(),
                  AnalyticsDashboard(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== TODAY TAB ====================

  Widget _buildTodayTab() {
    final today = DateTime.now();
    final sessions = _controller.getStudySessionsForDay(today);
    final completedCount = sessions.where((s) => s.isCompleted).length;
    final totalMinutes = sessions.fold<int>(0, (sum, s) => sum + s.durationMinutes);
    final completedMinutes = sessions
        .where((s) => s.isCompleted)
        .fold<int>(0, (sum, s) => sum + (s.actualDurationMinutes ?? s.durationMinutes));

    // Deadlines due soon
    final urgentDeadlines = _controller.getDeadlinesDueSoon(days: 3);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Urgent deadlines banner
          if (urgentDeadlines.isNotEmpty) ...[
            _buildUrgentDeadlinesBanner(urgentDeadlines),
            const SizedBox(height: 16),
          ],

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

  Widget _buildUrgentDeadlinesBanner(List<Deadline> deadlines) {
    final overdue = deadlines.where((d) => d.isOverdue).toList();
    final upcoming = deadlines.where((d) => !d.isOverdue).toList();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: overdue.isNotEmpty
              ? [const Color(0xFFEF4444).withOpacity(0.2), const Color(0xFFEF4444).withOpacity(0.05)]
              : [const Color(0xFFF59E0B).withOpacity(0.2), const Color(0xFFF59E0B).withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: overdue.isNotEmpty
              ? const Color(0xFFEF4444).withOpacity(0.4)
              : const Color(0xFFF59E0B).withOpacity(0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                overdue.isNotEmpty ? Icons.warning : Icons.flag,
                size: 18,
                color: overdue.isNotEmpty ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
              ),
              const SizedBox(width: 8),
              Text(
                overdue.isNotEmpty
                    ? '${overdue.length} overdue deadline${overdue.length > 1 ? 's' : ''}'
                    : '${upcoming.length} deadline${upcoming.length > 1 ? 's' : ''} due soon',
                style: TextStyle(
                  color: overdue.isNotEmpty ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...deadlines.take(3).map((d) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(
                    color: d.urgencyColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    d.title,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  d.timeRemainingText,
                  style: TextStyle(color: d.urgencyColor, fontSize: 11),
                ),
              ],
            ),
          )),
          if (deadlines.length > 3)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '+${deadlines.length - 3} more',
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }

  // ==================== WEEK TAB ====================

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
                        style: TextStyle(color: Color(0xFF64748B)),
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

  // ==================== DEADLINES TAB ====================

  Widget _buildDeadlinesTab() {
    final allDeadlines = _controller.getAllDeadlines();
    final active = allDeadlines.where((d) => d.status != DeadlineStatus.completed).toList();
    final completed = allDeadlines.where((d) => d.status == DeadlineStatus.completed).toList();
    final overdue = active.where((d) => d.isOverdue).toList();
    final upcoming = active.where((d) => !d.isOverdue).toList();

    if (allDeadlines.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.flag_outlined, size: 72, color: Colors.white.withOpacity(0.2)),
            const SizedBox(height: 16),
            const Text(
              'No Deadlines Yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your coursework deadlines\nto stay on top of things',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.6)),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showAddDeadlineDialog,
              icon: const Icon(Icons.add),
              label: const Text('Add Deadline'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary stats
          _buildDeadlineStats(active, completed),

          const SizedBox(height: 20),

          // Overdue section
          if (overdue.isNotEmpty) ...[
            _buildDeadlineSectionHeader(
              'Overdue',
              overdue.length,
              const Color(0xFFEF4444),
            ),
            const SizedBox(height: 8),
            ...overdue.map((d) => _buildDeadlineCard(d)),
            const SizedBox(height: 20),
          ],

          // Upcoming section
          if (upcoming.isNotEmpty) ...[
            _buildDeadlineSectionHeader(
              'Upcoming',
              upcoming.length,
              const Color(0xFF3B82F6),
            ),
            const SizedBox(height: 8),
            ...upcoming.map((d) => _buildDeadlineCard(d)),
            const SizedBox(height: 20),
          ],

          // Completed section
          if (completed.isNotEmpty) ...[
            _buildDeadlineSectionHeader(
              'Completed',
              completed.length,
              const Color(0xFF10B981),
            ),
            const SizedBox(height: 8),
            ...completed.take(5).map((d) => _buildDeadlineCard(d)),
            if (completed.length > 5)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '+${completed.length - 5} more completed',
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                ),
              ),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildDeadlineStats(List<Deadline> active, List<Deadline> completed) {
    final overdue = active.where((d) => d.isOverdue).length;
    final dueThisWeek = active.where((d) => d.isDueThisWeek).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildDeadlineStatItem('Active', '${active.length}', const Color(0xFF3B82F6)),
          _buildDeadlineStatItem('This Week', '$dueThisWeek', const Color(0xFFF59E0B)),
          _buildDeadlineStatItem('Overdue', '$overdue', const Color(0xFFEF4444)),
          _buildDeadlineStatItem('Done', '${completed.length}', const Color(0xFF10B981)),
        ],
      ),
    );
  }

  Widget _buildDeadlineStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
        ),
      ],
    );
  }

  Widget _buildDeadlineSectionHeader(String title, int count, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildDeadlineCard(Deadline deadline) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final timeFormat = DateFormat('HH:mm');
    final moduleColor = _controller.getModuleColor(deadline.moduleCode);
    final loggedHours = _controller.getLoggedHoursForDeadline(deadline.id);

    return GestureDetector(
      onTap: () => _showEditDeadlineDialog(deadline),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: deadline.isOverdue
                ? const Color(0xFFEF4444).withOpacity(0.5)
                : deadline.status == DeadlineStatus.completed
                ? const Color(0xFF10B981).withOpacity(0.3)
                : const Color(0xFF1E293B),
            width: deadline.isOverdue ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: title + priority + status toggle
            Row(
              children: [
                // Status toggle
                GestureDetector(
                  onTap: () => _controller.toggleDeadlineStatus(deadline.id),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: deadline.status == DeadlineStatus.completed
                          ? const Color(0xFF10B981).withOpacity(0.2)
                          : const Color(0xFF1E293B),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: deadline.status == DeadlineStatus.completed
                            ? const Color(0xFF10B981)
                            : const Color(0xFF475569),
                        width: 2,
                      ),
                    ),
                    child: deadline.status == DeadlineStatus.completed
                        ? const Icon(Icons.check, size: 16, color: Color(0xFF10B981))
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                // Title
                Expanded(
                  child: Text(
                    deadline.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: deadline.status == DeadlineStatus.completed
                          ? const Color(0xFF64748B)
                          : Colors.white,
                      decoration: deadline.status == DeadlineStatus.completed
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                // Priority badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: deadline.priority.color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: deadline.priority.color.withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(deadline.priority.icon, size: 12, color: deadline.priority.color),
                      const SizedBox(width: 4),
                      Text(
                        deadline.priority.displayName,
                        style: TextStyle(
                          fontSize: 10,
                          color: deadline.priority.color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Bottom row: due date, module, hours
            Row(
              children: [
                // Due date
                Icon(Icons.schedule, size: 14, color: deadline.urgencyColor),
                const SizedBox(width: 4),
                Text(
                  '${dateFormat.format(deadline.dueDate)} at ${timeFormat.format(deadline.dueDate)}',
                  style: TextStyle(fontSize: 12, color: deadline.urgencyColor),
                ),
                const Spacer(),
                // Module chip
                if (deadline.moduleCode != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: moduleColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      deadline.moduleCode!,
                      style: TextStyle(fontSize: 10, color: moduleColor, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ],
            ),

            // Hours progress (if estimated)
            if (deadline.estimatedHours > 0) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.hourglass_empty, size: 14, color: Color(0xFF64748B)),
                  const SizedBox(width: 4),
                  Text(
                    '${loggedHours.toStringAsFixed(1)} / ${deadline.estimatedHours.toStringAsFixed(0)}h logged',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (loggedHours / deadline.estimatedHours).clamp(0.0, 1.0),
                        backgroundColor: const Color(0xFF1E293B),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          loggedHours >= deadline.estimatedHours
                              ? const Color(0xFF10B981)
                              : const Color(0xFF3B82F6),
                        ),
                        minHeight: 6,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // Time remaining text
            if (deadline.status != DeadlineStatus.completed) ...[
              const SizedBox(height: 6),
              Text(
                deadline.timeRemainingText,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: deadline.urgencyColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==================== KNOWLEDGE TAB ====================

  // ==================== SHARED WIDGETS ====================

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
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
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
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

  Widget _buildEmptyState(String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.event_note,
              size: 48,
              color: Colors.white.withOpacity(0.2),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionCard(StudySession session) {
    final timeFormat = DateFormat('HH:mm');
    final color = session.type.color;
    final canStartPomodoro = !session.isCompleted;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: session.isCompleted
              ? const Color(0xFF10B981).withOpacity(0.3)
              : const Color(0xFF1E293B),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Type icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  session.type.icon,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: session.isCompleted ? const Color(0xFF64748B) : Colors.white,
                        decoration: session.isCompleted ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${timeFormat.format(session.startTime)} - ${timeFormat.format(session.endTime)} • ${session.durationMinutes} min',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
              // Pomodoro button (for incomplete sessions)
              if (canStartPomodoro)
                IconButton(
                  onPressed: () => _startPomodoro(session),
                  icon: const Icon(Icons.play_circle_outline),
                  color: const Color(0xFFEF4444),
                  tooltip: 'Start Pomodoro',
                ),
              // Complete button
              if (!session.isCompleted && session.isPast)
                IconButton(
                  onPressed: () => _showCompletionDialog(session),
                  icon: const Icon(Icons.check_circle_outline),
                  color: const Color(0xFF10B981),
                )
              else if (session.isCompleted)
                const Icon(
                  Icons.check_circle,
                  color: Color(0xFF10B981),
                  size: 24,
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== DIALOGS ====================

  void _showAddSessionDialog() {
    showDialog(
      context: context,
      builder: (context) => const StudySessionDialog(),
    );
  }

  void _showAddDeadlineDialog() {
    showDialog(
      context: context,
      builder: (context) => const DeadlineDialog(),
    );
  }

  void _showEditDeadlineDialog(Deadline deadline) {
    showDialog(
      context: context,
      builder: (context) => DeadlineDialog(deadline: deadline),
    );
  }

  void _showCompletionDialog(StudySession session) {
    showDialog(
      context: context,
      builder: (context) => SessionCompletionDialog(
        session: session,
        onComplete: (updatedSession) async {
          await _controller.updateStudySession(updatedSession);
        },
      ),
    );
  }

  void _startPomodoro(StudySession session) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PomodoroTimerPage(session: session),
      ),
    );
  }

  // ==================== HELPERS ====================

  DateTime _getWeekStart(DateTime date) {
    final weekday = date.weekday;
    return DateTime(date.year, date.month, date.day - (weekday - 1));
  }
}