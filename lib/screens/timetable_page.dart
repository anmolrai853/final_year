// lib/screens/timetable_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../controllers/timetable_controller.dart';
import '../services/timetable_service.dart';

final TimetableController _controller = TimetableController();

class TimetablePage extends StatefulWidget {
  final List<Map<String, dynamic>> studySessions;

  const TimetablePage({
    super.key,
    required this.studySessions,
  });

  @override
  State<TimetablePage> createState() => _TimetablePageState();
}

class _TimetablePageState extends State<TimetablePage> {
  final _service = TimetableService();

  List<Map<String, dynamic>> instances = [];
  Map<String, dynamic>? nextEvent;

  String statusMessage = 'Load your timetable to get started.';
  Color statusColor = Colors.white70;

  final int daysInWeek = 7;
  DateTime _currentWeekStart = DateTime.now();



  @override
  void initState() {
    super.initState();
    _currentWeekStart = _weekStartMonday(_currentWeekStart);

    if (_controller.isLoaded) {
      instances = _controller.instances;
      nextEvent = _controller.nextEvent;
      statusMessage = 'Timetable loaded from memory.';
      statusColor = Colors.greenAccent;
    }
  }

  // ------------------ Helpers ------------------

  String _extractLocation(Map<String, dynamic> e) {
    final loc = e['location']?.toString().trim();
    return (loc != null && loc.isNotEmpty) ? loc : 'Unknown location';
  }

  String _extractModuleTitle(Map<String, dynamic> e) {
    final desc = (e['description'] ?? '').toString().trim();
    if (desc.isEmpty) return 'Unknown module';

    // Split into lines and clean
    final lines = desc
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    // If the second line exists, it's usually the short module name
    if (lines.length >= 2) {
      return _toTitleCase(lines[1]);
    }

    // Try to extract uppercase module code/title
    final words = desc.split(RegExp(r'\s+'));
    final buffer = <String>[];
    for (final w in words) {
      if (RegExp(r'^[A-Z][A-Z]+$').hasMatch(w)) {
        buffer.add(w);
      } else if (buffer.isNotEmpty) {
        break;
      }
    }
    if (buffer.isNotEmpty) {
      return _toTitleCase(buffer.join(' '));
    }

    // Fallback: drop the first word (usually a code)
    if (words.length > 1) {
      return _toTitleCase(words.sublist(1).join(' '));
    }

    return 'Unknown module';
  }



  String _toTitleCase(String s) => s
      .toLowerCase()
      .split(' ')
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + (w.length > 1 ? w.substring(1) : ''))
      .join(' ');

  DateTime _weekStartMonday(DateTime d) {
    final n = DateTime(d.year, d.month, d.day);
    return n.subtract(Duration(days: n.weekday - DateTime.monday));
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Color _colorForModule(String title) {
    final colors = [
      const Color(0xFF3B82F6),
      const Color(0xFF10B981),
      const Color(0xFFF97316),
      const Color(0xFFE11D48),
      const Color(0xFF8B5CF6),
      const Color(0xFFF59E0B),
    ];
    return colors[title.hashCode.abs() % colors.length];
  }

  // ------------------ Load Timetable ------------------

  Future<void> _loadTimetable() async {
    try {
      if (_controller.isLoaded) {
        setState(() {
          instances = _controller.instances;
          nextEvent = _controller.nextEvent;
          statusMessage = 'Timetable loaded from memory.';
          statusColor = Colors.greenAccent;
        });
        return;
      }

      setState(() {
        statusMessage = 'Loading timetable...';
        statusColor = Colors.blueAccent;
      });

      final all = await _service.loadInstancesFromAsset('assets/calendar.ics');
      final nxt = _service.findNextEvent(all);

      _controller.setTimetable(events: all, next: nxt);

      setState(() {
        instances = all;
        nextEvent = nxt;
        statusMessage = 'Loaded ${all.length} events.';
        statusColor = Colors.greenAccent;
      });
    } catch (e) {
      setState(() {
        statusMessage = 'Failed to load timetable: $e';
        statusColor = Colors.redAccent;
      });
    }
  }

  // ------------------ Next Event Card ------------------

  Widget _buildNextEventCard() {
    if (nextEvent == null) {
      return Card(
        color: const Color(0xFF020617),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.event_available, color: Colors.white38, size: 24),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'No upcoming events found.',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final e = nextEvent!;
    final title = _extractModuleTitle(e);
    final loc = _extractLocation(e);
    final start = e['dtstart'] as DateTime;
    final end = e['dtend'] as DateTime;
    final df = DateFormat('EEEE, dd MMM');
    final tf = DateFormat('HH:mm');
    final color = _colorForModule(title);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: [color.withOpacity(0.95), color.withOpacity(0.75)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
        child: ListTile(
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          leading: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.play_arrow, color: Colors.white, size: 20),
          ),
          title: const Text(
            'Next event',
            style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(loc, style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 2),
                Text(
                  '${df.format(start)} • ${tf.format(start)} – ${tf.format(end)}',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ------------------ Week Selector ------------------

  Widget _buildWeekSelector() {
    final s = _currentWeekStart;
    final e = s.add(const Duration(days: 6));
    final range =
        '${DateFormat('dd MMM').format(s)} – ${DateFormat('dd MMM').format(e)}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton.filledTonal(
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF1F2937),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.chevron_left),
            onPressed: () => setState(
                  () => _currentWeekStart =
                  _currentWeekStart.subtract(const Duration(days: 7)),
            ),
          ),
          Column(
            children: [
              const Text(
                'Week view',
                style: TextStyle(fontSize: 12, color: Colors.white54),
              ),
              Text(
                range,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          IconButton.filledTonal(
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF1F2937),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.chevron_right),
            onPressed: () => setState(
                  () => _currentWeekStart =
                  _currentWeekStart.add(const Duration(days: 7)),
            ),
          ),
        ],
      ),
    );
  }
  // ------------------ Save Study Session ------------------

  void _saveStudySession({
    required String module,
    required String type,
    required DateTime start,
    required int duration,
  }) {
    final end = start.add(Duration(minutes: duration));

    widget.studySessions.add({
      'module': module,
      'type': type,
      'start': start,
      'end': end,
      'completed': false,
    });

    setState(() {});
  }

  // ------------------ Custom Time Picker for Empty Days ------------------

  Future<DateTime?> _pickTime(BuildContext context, DateTime baseDate, String label) async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: 9, minute: 0),
      helpText: label,
    );

    if (t == null) return null;

    return DateTime(baseDate.year, baseDate.month, baseDate.day, t.hour, t.minute);
  }

  void _openCustomStudyForEmptyDay(DateTime day) async {
    final start = await _pickTime(context, day, "Select start time");
    if (start == null) return;

    final end = await _pickTime(context, day, "Select end time");
    if (end == null) return;

    if (end.isBefore(start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("End time must be after start time")),
      );
      return;
    }

    final duration = end.difference(start).inMinutes;

    _openStudyPlannerSheetCustom(
      start: start,
      duration: duration,
    );
  }
  // ------------------ Event Editor ------------------

  void _openEventEditor(Map<String, dynamic> e) {
    final title = _extractModuleTitle(e);
    final loc = _extractLocation(e);
    final start = e['dtstart'] as DateTime;
    final end = e['dtend'] as DateTime;
    final df = DateFormat('EEEE, dd MMM');
    final tf = DateFormat('HH:mm');

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF020617),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.place, size: 16, color: Colors.white54),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      loc,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.access_time, size: 16, color: Colors.white54),
                  const SizedBox(width: 6),
                  Text(
                    '${df.format(start)} • ${tf.format(start)} – ${tf.format(end)}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit event'),
                onPressed: () {
                  Navigator.pop(context);
                  _openEditForm(e);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // ------------------ Edit Event Form ------------------

  void _openEditForm(Map<String, dynamic> e) {
    final ctrl = TextEditingController(text: _extractLocation(e));

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: const Color(0xFF020617),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Edit event',
            style: TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: ctrl,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Location',
              labelStyle: TextStyle(color: Colors.white70),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white30),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  e['location'] = ctrl.text.trim();
                });
                Navigator.pop(context);
              },
              child: const Text(
                'Save',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }


  // ------------------ Study Planner Sheet (for gaps) ------------------

  void _openPlanStudySession(Map<String, dynamic> gap) {
    _openStudyPlannerSheetGap(
      start: gap['start'],
      duration: gap['duration'],
    );
  }

  // ------------------ Study Planner Sheet (Gap Version) ------------------

  void _openStudyPlannerSheetGap({
    required DateTime start,
    required int duration,
  }) {
    _openStudyPlannerSheet(
      start: start,
      duration: duration,
    );
  }

  // ------------------ Study Planner Sheet (Custom Time Version) ------------------

  void _openStudyPlannerSheetCustom({
    required DateTime start,
    required int duration,
  }) {
    _openStudyPlannerSheet(
      start: start,
      duration: duration,
    );
  }

  // ------------------ Shared Study Planner Sheet ------------------

  void _openStudyPlannerSheet({
    required DateTime start,
    required int duration,
  }) {
    final modules = instances.map((e) => _extractModuleTitle(e)).toSet().toList();

    String selectedModule = modules.isNotEmpty ? modules.first : 'General';
    String studyType = 'Revision';
    double sliderDuration = duration.toDouble();
    TextEditingController moduleCtrl = TextEditingController();


    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF020617),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const Text(
                      'Plan study session',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Module name input
                    const Text('Revision Title', style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 6),

                    TextField(
                      controller: moduleCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF1E293B),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        labelText: '',
                        labelStyle: const TextStyle(color: Colors.white54),
                      ),
                    ),


                    const SizedBox(height: 16),

                    // Study type
                    const Text('Study type', style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: studyType,
                      dropdownColor: const Color(0xFF0F172A),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF1E293B),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      items: ['Revision', 'Coursework', 'Reading']
                          .map(
                            (t) => DropdownMenuItem(
                          value: t,
                          child: Text(t, style: const TextStyle(color: Colors.white)),
                        ),
                      )
                          .toList(),
                      onChanged: (v) => setModalState(() => studyType = v!),
                    ),

                    const SizedBox(height: 16),

                    // Duration slider
                    Text(
                      'Duration: ${sliderDuration.toInt()} min',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    Slider(
                      value: sliderDuration,
                      min: 15,
                      max: duration.toDouble(),
                      divisions: (duration / 15).floor(),
                      onChanged: (v) => setModalState(() => sliderDuration = v),
                    ),

                    const SizedBox(height: 20),

                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () {
                        final moduleName = moduleCtrl.text.trim();
                        if (moduleName.isEmpty) return;

                        _saveStudySession(
                          module: moduleName,
                          type: studyType,
                          start: start,
                          duration: sliderDuration.toInt(),
                        );

                        Navigator.pop(context);
                      },
                      child: const Text('Save session'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ------------------ Timetable Grid Helpers ------------------

  (int startMinute, int endMinute) _minuteBounds24h() => (0, 24 * 60);

  List<Map<String, dynamic>> _eventsForDay(
      int day,
      DateTime weekStart,
      int startMin,
      int endMin,
      ) {
    final list = <Map<String, dynamic>>[];

    for (final e in instances) {
      final s = e['dtstart'] as DateTime;
      final diff = s.difference(weekStart).inDays;
      if (diff != day) continue;

      final sm = s.hour * 60 + s.minute;
      final em = (e['dtend'] as DateTime).hour * 60 + (e['dtend'] as DateTime).minute;

      if (em <= startMin || sm >= endMin) continue;

      list.add(e);
    }

    list.sort((a, b) =>
        (a['dtstart'] as DateTime).compareTo(b['dtstart'] as DateTime));

    return list;
  }

  // ------------------ Timetable Grid ------------------

  Widget _buildWeeklyTimetable() {
    if (instances.isEmpty) {
      return const Center(
        child: Text(
          'No timetable loaded yet.',
          style: TextStyle(color: Colors.white60),
        ),
      );
    }

    final weekStart = _currentWeekStart;
    final (startMin, endMin) = _minuteBounds24h();
    final totalMin = endMin - startMin;
    const minuteHeight = 0.6;
    final contentHeight = totalMin * minuteHeight;

    final df = DateFormat('EEE\ndd MMM');
    final today = DateTime.now();

    // Header row
    final header = Row(
      children: [
        const SizedBox(
          width: 60,
          child: Center(
            child: Text(
              'Time',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white70,
              ),
            ),
          ),
        ),
        for (int d = 0; d < daysInWeek; d++)
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(6),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF020617),
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade900),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    df.format(weekStart.add(Duration(days: d))),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _isSameDay(
                        weekStart.add(Duration(days: d)),
                        today,
                      )
                          ? Colors.white
                          : Colors.white70,
                    ),
                  ),
                  if (_isSameDay(weekStart.add(Duration(days: d)), today))
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'Today',
                        style: TextStyle(fontSize: 10, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );

    // Body grid
    final body = AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: SingleChildScrollView(
        key: ValueKey(_currentWeekStart),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 32),
          child: SizedBox(
            height: contentHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 60,
                  child: _buildTimeColumn(startMin, endMin, minuteHeight),
                ),
                for (int d = 0; d < daysInWeek; d++)
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(color: Colors.grey.shade900),
                        ),
                      ),
                      child: _buildDayColumn(
                        dayIndex: d,
                        events: _eventsForDay(
                          d,
                          weekStart,
                          startMin,
                          endMin,
                        ),
                        weekStart: weekStart,
                        startMinute: startMin,
                        endMinute: endMin,
                        totalMinutes: totalMin,
                        minuteHeight: minuteHeight,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    return Column(
      children: [
        header,
        const SizedBox(height: 4),
        Expanded(child: body),
      ],
    );
  }

  // ------------------ Time Column ------------------

  Widget _buildTimeColumn(int startMin, int endMin, double minuteHeight) {
    final children = <Widget>[];
    final startHour = startMin ~/ 60;
    final endHour = (endMin / 60).ceil();
    final tf = DateFormat('HH:mm');

    for (int h = startHour; h < endHour; h++) {
      final sliceStart = (h * 60).clamp(startMin, endMin);
      final sliceEnd = (h * 60 + 60).clamp(startMin, endMin);
      final span = sliceEnd - sliceStart;

      if (span <= 0) continue;

      children.add(
        SizedBox(
          height: span * minuteHeight,
          child: Container(
            alignment: Alignment.topRight,
            padding: const EdgeInsets.only(right: 6, top: 2),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade900),
              ),
            ),
            child: Text(
              tf.format(DateTime(0, 1, 1, h)),
              style: const TextStyle(fontSize: 11, color: Colors.white38),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  // ------------------ Day Column ------------------

  Widget _buildDayColumn({
    required int dayIndex,
    required List<Map<String, dynamic>> events,
    required DateTime weekStart,
    required int startMinute,
    required int endMinute,
    required int totalMinutes,
    required double minuteHeight,
  }) {
    final children = <Widget>[];
    int offset = 0;

    final day = weekStart.add(Duration(days: dayIndex));

    // If no events → whole column is tappable for custom study session
    if (events.isEmpty) {
      return GestureDetector(
        onTap: () => _openCustomStudyForEmptyDay(day),
        child: Container(
          color: Colors.transparent,
        ),
      );
    }

    // Events exist → show gaps + events
    for (final e in events) {
      final s = e['dtstart'] as DateTime;
      final en = e['dtend'] as DateTime;

      int es = (s.hour * 60 + s.minute) - startMinute;
      int ee = (en.hour * 60 + en.minute) - startMinute;

      es = es.clamp(0, totalMinutes);
      ee = ee.clamp(0, totalMinutes);

      // Gap before event
      final gap = es - offset;
      if (gap > 0) {
        children.add(
          SizedBox(
            height: gap * minuteHeight,
            child: GestureDetector(
              onTap: () => _openPlanStudySession({
                'start': DateTime(
                  day.year,
                  day.month,
                  day.day,
                  (startMinute + offset) ~/ 60,
                  (startMinute + offset) % 60,
                ),
                'duration': gap,
              }),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white24),
                ),
                child: Text(
                  'Free time • ${gap} min',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white70,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
          ),
        );

        offset += gap;
      }

      // Event block
      final dur = (ee - es).clamp(1, totalMinutes - offset);
      if (dur > 0) {
        final title = _extractModuleTitle(e);
        final loc = _extractLocation(e);
        final df = DateFormat('EEEE, dd MMM');
        final tf = DateFormat('HH:mm');
        final color = _colorForModule(title);

        children.add(
          SizedBox(
            height: dur * minuteHeight,
            child: GestureDetector(
              onTap: () => _openEventEditor(e),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withOpacity(0.7)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      loc,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white70,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${df.format(s)} • ${tf.format(s)} – ${tf.format(en)}',
                      style: const TextStyle(
                        fontSize: 9,
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        offset += dur;
      }
    }

    // Gap after last event
    final remaining = totalMinutes - offset;
    if (remaining > 0) {
      children.add(
        SizedBox(
          height: remaining * minuteHeight,
          child: GestureDetector(
            onTap: () => _openPlanStudySession({
              'start': DateTime(
                day.year,
                day.month,
                day.day,
                (startMinute + offset) ~/ 60,
                (startMinute + offset) % 60,
              ),
              'duration': remaining,
            }),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white24),
              ),
              child: Text(
                'Free time • ${remaining} min',
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white70,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
  // ------------------ Build ------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),

      appBar: AppBar(
        backgroundColor: const Color(0xFF020617),
        elevation: 0,
        title: const Text('Timetable'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTimetable,
          ),
        ],
      ),

      body: Column(
        children: [
          _buildNextEventCard(),
          _buildWeekSelector(),
          Expanded(child: _buildWeeklyTimetable()),

          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Text(
              statusMessage,
              style: TextStyle(
                color: statusColor,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

