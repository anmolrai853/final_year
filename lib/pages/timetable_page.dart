import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../controllers/timetable_controller.dart';
import '../models/event.dart';
import '../models/free_time_slot.dart';
import '../models/study_session.dart';
import '../widgets/next_event_card.dart';
import '../widgets/study_session_dialog.dart';
import '../widgets/event_location_dialog.dart';

class TimetablePage extends StatefulWidget {
  const TimetablePage({super.key});

  @override
  State<TimetablePage> createState() => _TimetablePageState();
}

class _TimetablePageState extends State<TimetablePage> {
  final TimetableController _controller = TimetableController();
  late DateTime _currentWeekStart;
  final ScrollController _scrollController = ScrollController();
  
  // Time range for display
  late int _startHour;
  late int _endHour;
  final double _hourHeight = 70;

  @override
  void initState() {
    super.initState();
    _currentWeekStart = _getWeekStart(DateTime.now());
    _updateTimeRange();
    _controller.addListener(_onControllerUpdate);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _controller.removeListener(_onControllerUpdate);
    super.dispose();
  }

  void _onControllerUpdate() {
    if (mounted) {
      setState(() {
        _updateTimeRange();
      });
    }
  }

  void _updateTimeRange() {
    final range = _controller.getSmartTimeRange();
    _startHour = range[0];
    _endHour = range[1];
  }

  DateTime _getWeekStart(DateTime date) {
    // Get Monday of the week
    final weekday = date.weekday;
    return DateTime(date.year, date.month, date.day - (weekday - 1));
  }

  void _goToPreviousWeek() {
    setState(() {
      _currentWeekStart = _currentWeekStart.subtract(const Duration(days: 7));
    });
  }

  void _goToNextWeek() {
    setState(() {
      _currentWeekStart = _currentWeekStart.add(const Duration(days: 7));
    });
  }

  void _goToToday() {
    setState(() {
      _currentWeekStart = _getWeekStart(DateTime.now());
    });
  }

  bool get _isCurrentWeek {
    final today = DateTime.now();
    final thisWeekStart = _getWeekStart(today);
    return _currentWeekStart.year == thisWeekStart.year &&
           _currentWeekStart.month == thisWeekStart.month &&
           _currentWeekStart.day == thisWeekStart.day;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      body: SafeArea(
        child: Column(
          children: [
            // Header with week navigation
            _buildHeader(),
            
            // Next Event Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: NextEventCard(
                event: _controller.getNextEvent(),
                onLocationTap: (event) => _showLocationDialog(event),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Week navigation bar
            _buildWeekNavigation(),
            
            const SizedBox(height: 8),
            
            // Day headers
            _buildDayHeaders(),
            
            // Timetable grid
            Expanded(
              child: _buildTimetableGrid(),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showQuickAddDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Quick Add'),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Timetable',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          if (!_isCurrentWeek)
            TextButton.icon(
              onPressed: _goToToday,
              icon: const Icon(Icons.today, size: 18),
              label: const Text('Today'),
            ),
        ],
      ),
    );
  }

  Widget _buildWeekNavigation() {
    final weekEnd = _currentWeekStart.add(const Duration(days: 6));
    final dateFormat = DateFormat('MMM d');
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: _goToPreviousWeek,
            icon: const Icon(Icons.chevron_left),
            color: Colors.white,
          ),
          Text(
            '${dateFormat.format(_currentWeekStart)} - ${dateFormat.format(weekEnd)}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          IconButton(
            onPressed: _goToNextWeek,
            icon: const Icon(Icons.chevron_right),
            color: Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _buildDayHeaders() {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final today = DateTime.now();
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 70), // Account for time column
      child: Row(
        children: List.generate(7, (index) {
          final day = _currentWeekStart.add(Duration(days: index));
          final isToday = day.year == today.year &&
                         day.month == today.month &&
                         day.day == today.day;
          
          return Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isToday ? const Color(0xFF3B82F6).withOpacity(0.2) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    days[index],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isToday ? const Color(0xFF3B82F6) : const Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${day.day}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isToday ? const Color(0xFF3B82F6) : Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTimetableGrid() {
    final totalHours = _endHour - _startHour;
    
    return SingleChildScrollView(
      controller: _scrollController,
      child: SizedBox(
        height: totalHours * _hourHeight + 20,
        child: Row(
          children: [
            // Time column
            _buildTimeColumn(),
            
            // Day columns
            Expanded(
              child: Row(
                children: List.generate(7, (dayIndex) {
                  final day = _currentWeekStart.add(Duration(days: dayIndex));
                  return Expanded(
                    child: _buildDayColumn(day),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeColumn() {
    final totalHours = _endHour - _startHour + 1;

    return SizedBox(
      width: 70,
      child: SingleChildScrollView( // Add this
        physics: const NeverScrollableScrollPhysics(), // Disable scroll since parent scrolls
        child: Column(
          mainAxisSize: MainAxisSize.min, // Add this
          children: List.generate(totalHours, (index) {
            final hour = _startHour + index;
            return Container(
              height: _hourHeight,
              alignment: Alignment.topCenter,
              child: Text(
                '${hour.toString().padLeft(2, '0')}:00',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF64748B),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildDayColumn(DateTime day) {
    final events = _controller.getEventsForDay(day);
    final sessions = _controller.getStudySessionsForDay(day);
    final freeSlots = _controller.findFreeTimeSlots(day);
    final today = DateTime.now();
    final isToday = day.year == today.year &&
                    day.month == today.month &&
                    day.day == today.day;

    return Stack(
      children: [
        // Hour grid lines
        Column(
          children: List.generate(_endHour - _startHour, (index) {
            return Container(
              height: _hourHeight,
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: const Color(0xFF1E293B).withOpacity(0.5),
                    width: 1,
                  ),
                ),
              ),
            );
          }),
        ),
        
        // Current time indicator
        if (isToday) _buildCurrentTimeIndicator(),
        
        // Free time slots (tappable)
        ...freeSlots.map((slot) => _buildFreeTimeSlot(day, slot)),
        
        // Calendar events
        ...events.map((event) => _buildEventBlock(day, event)),
        
        // Study sessions
        ...sessions.map((session) => _buildStudySessionBlock(day, session)),
      ],
    );
  }

  Widget _buildCurrentTimeIndicator() {
    final now = DateTime.now();
    final currentHour = now.hour + now.minute / 60;
    
    if (currentHour < _startHour || currentHour > _endHour) {
      return const SizedBox.shrink();
    }
    
    final topOffset = (currentHour - _startHour) * _hourHeight;
    
    return Positioned(
      top: topOffset,
      left: 0,
      right: 0,
      child: Container(
        height: 2,
        color: const Color(0xFFEF4444),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFFEF4444),
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFreeTimeSlot(DateTime day, FreeTimeSlot slot) {
    final startHour = slot.startTime.hour + slot.startTime.minute / 60;
    final endHour = slot.endTime.hour + slot.endTime.minute / 60;
    final top = (startHour - _startHour) * _hourHeight;
    final height = (endHour - startHour) * _hourHeight;
    
    return Positioned(
      top: top,
      left: 2,
      right: 2,
      height: height,
      child: GestureDetector(
        onTap: () => _showCreateSessionDialog(day, slot),
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: const Color(0xFF10B981).withOpacity(0.3),
              width: 1,
              style: BorderStyle.solid,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_circle_outline,
                  size: 16,
                  color: const Color(0xFF10B981).withOpacity(0.6),
                ),
                const SizedBox(height: 2),
                Text(
                  slot.formattedDuration,
                  style: TextStyle(
                    fontSize: 10,
                    color: const Color(0xFF10B981).withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEventBlock(DateTime day, CalendarEvent event) {
    final startHour = event.startTime.hour + event.startTime.minute / 60;
    final endHour = event.endTime.hour + event.endTime.minute / 60;
    final top = (startHour - _startHour) * _hourHeight;
    final height = (endHour - startHour) * _hourHeight;
    
    final color = _controller.getModuleColor(event.moduleCode);
    final isPast = event.isPast;
    
    return Positioned(
      top: top,
      left: 2,
      right: 2,
      height: height,
      child: GestureDetector(
        onTap: () => _showLocationDialog(event),
        child: Container(
          margin: const EdgeInsets.all(2),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isPast ? color.withOpacity(0.3) : color.withOpacity(0.8),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                event.title,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isPast ? Colors.white.withOpacity(0.5) : Colors.white,
                  decoration: isPast ? TextDecoration.lineThrough : null,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (event.location != null && event.location!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 8,
                      color: isPast ? Colors.white.withOpacity(0.4) : Colors.white.withOpacity(0.8),
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        event.location!,
                        style: TextStyle(
                          fontSize: 8,
                          color: isPast ? Colors.white.withOpacity(0.4) : Colors.white.withOpacity(0.8),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStudySessionBlock(DateTime day, StudySession session) {
    final startHour = session.startTime.hour + session.startTime.minute / 60;
    final endHour = session.endTime.hour + session.endTime.minute / 60;
    final top = (startHour - _startHour) * _hourHeight;
    final height = (endHour - startHour) * _hourHeight;
    
    final color = session.type.color;
    final isPast = session.isPast;
    
    return Positioned(
      top: top,
      left: 2,
      right: 2,
      height: height,
      child: GestureDetector(
        onTap: () => _showEditSessionDialog(session),
        onLongPress: () => _toggleSessionComplete(session),
        child: Dismissible(
          key: Key(session.id),
          direction: DismissDirection.endToStart,
          background: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444),
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 12),
            child: const Icon(
              Icons.delete,
              color: Colors.white,
              size: 20,
            ),
          ),
          confirmDismiss: (_) => _confirmDelete(session),
          onDismissed: (_) => _deleteSession(session),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.all(2),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isPast ? color.withOpacity(0.3) : color.withOpacity(0.8),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isPast ? color.withOpacity(0.3) : color,
                width: session.isCompleted ? 3 : 1,
              ),
            ),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          session.type.icon,
                          size: 12,
                          color: isPast ? Colors.white.withOpacity(0.5) : Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            session.title,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isPast ? Colors.white.withOpacity(0.5) : Colors.white,
                              decoration: session.isCompleted ? TextDecoration.lineThrough : null,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${session.durationMinutes} min',
                      style: TextStyle(
                        fontSize: 8,
                        color: isPast ? Colors.white.withOpacity(0.4) : Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
                if (session.isCompleted)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 10,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
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
    await _controller.toggleSessionCompletion(session.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            session.isCompleted 
              ? '"${session.title}" marked incomplete'
              : '"${session.title}" completed!',
          ),
          backgroundColor: session.isCompleted 
            ? const Color(0xFF64748B)
            : const Color(0xFF10B981),
        ),
      );
    }
  }

  void _showCreateSessionDialog(DateTime day, FreeTimeSlot slot) {
    showDialog(
      context: context,
      builder: (context) => StudySessionDialog(
        initialDate: day,
        initialStartTime: TimeOfDay.fromDateTime(slot.startTime),
        maxDurationMinutes: slot.duration.inMinutes.toDouble(),
      ),
    );
  }

  void _showQuickAddDialog() {
    showDialog(
      context: context,
      builder: (context) => const StudySessionDialog(
        initialStartTime: null, // Will use current time
      ),
    );
  }

  void _showEditSessionDialog(StudySession session) {
    showDialog(
      context: context,
      builder: (context) => StudySessionDialog(
        session: session,
      ),
    );
  }

  void _showLocationDialog(CalendarEvent event) {
    showDialog(
      context: context,
      builder: (context) => EventLocationDialog(event: event),
    );
  }
}
