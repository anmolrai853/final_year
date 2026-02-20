import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../controllers/timetable_controller.dart';
import '../services/timetable_service.dart';
import '../services/storage_service.dart';

final _controller = TimetableController();
final _storage = StorageService();

class TimetablePage extends StatefulWidget {
  final List<Map<String, dynamic>> studySessions;
  const TimetablePage({super.key, required this.studySessions});

  @override
  State<TimetablePage> createState() => _TimetablePageState();
}

class _TimetablePageState extends State<TimetablePage>
    with SingleTickerProviderStateMixin {
  final _service = TimetableService();

  List<Map<String, dynamic>> instances = [];
  Map<String, dynamic>? nextEvent;
  String statusMessage = 'Load your timetable to get started.';
  Color statusColor = Colors.white70;
  late DateTime _currentWeekStart;
  late AnimationController _animCtrl;

  static const int _daysInWeek = 7;
  static const double _minHeight = 0.6;

  // ── Colour palette ──────────────────────────────────────────
  static const _palette = [
    Color(0xFF3B82F6), Color(0xFF10B981), Color(0xFFF97316),
    Color(0xFFE11D48), Color(0xFF8B5CF6), Color(0xFFF59E0B),
  ];

  Color _moduleColor(String t) => _palette[t.hashCode.abs() % _palette.length];

  // ── Init / dispose ───────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _currentWeekStart = _mondayOf(DateTime.now());
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _loadStoredData();
    if (_controller.isLoaded) _syncFromController('Timetable loaded from memory.');
  }

  @override
  void dispose() { _animCtrl.dispose(); super.dispose(); }

  void _syncFromController(String msg) => setState(() {
    instances  = _controller.instances;
    nextEvent  = _controller.nextEvent;
    statusMessage = msg;
    statusColor   = Colors.greenAccent;
  });

  // ── Helpers ──────────────────────────────────────────────────
  DateTime _mondayOf(DateTime d) {
    final n = DateTime(d.year, d.month, d.day);
    return n.subtract(Duration(days: n.weekday - DateTime.monday));
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _moduleTitle(Map<String, dynamic> e) {
    final desc = (e['description'] ?? '').toString().trim();
    if (desc.isEmpty) return 'Unknown module';
    final lines = desc.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    if (lines.length >= 2) return _titleCase(lines[1]);
    final words = desc.split(RegExp(r'\s+'));
    final caps = <String>[];
    for (final w in words) {
      if (RegExp(r'^[A-Z][A-Z]+$').hasMatch(w)) caps.add(w);
      else if (caps.isNotEmpty) break;
    }
    if (caps.isNotEmpty) return _titleCase(caps.join(' '));
    return words.length > 1 ? _titleCase(words.sublist(1).join(' ')) : 'Unknown module';
  }

  String _titleCase(String s) => s.toLowerCase().split(' ')
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join(' ');

  String _eventId(Map<String, dynamic> e) =>
      '${(e['dtstart'] as DateTime).toIso8601String()}_${(e['description'] ?? '').hashCode}';

  Future<String> _location(Map<String, dynamic> e) async {
    final override = await _storage.getEventLocationEdit(_eventId(e));
    if (override != null) return override;
    final loc = e['location']?.toString().trim();
    return (loc != null && loc.isNotEmpty) ? loc : 'Unknown location';
  }

  // ── Data loading ─────────────────────────────────────────────
  Future<void> _loadStoredData() async {
    final s = await _storage.loadStudySessions();
    setState(() { widget.studySessions..clear()..addAll(s); });
  }

  Future<void> _loadTimetable() async {
    if (_controller.isLoaded) {
      _syncFromController('Timetable loaded from memory.'); return;
    }
    setState(() { statusMessage = 'Loading timetable...'; statusColor = Colors.blueAccent; });
    try {
      await _service.loadInstancesFromAsset('assets/calendar.ics');
      _syncFromController('Loaded ${_controller.instances.length} events.');
    } catch (e) {
      setState(() { statusMessage = 'Failed: $e'; statusColor = Colors.redAccent; });
    }
  }

  // ── Study session CRUD ───────────────────────────────────────
  Future<void> _saveSession({
    required String module, required String type,
    required DateTime start, required int duration,
  }) async {
    setState(() => widget.studySessions.add({
      'module': module, 'type': type,
      'start': start, 'end': start.add(Duration(minutes: duration)),
      'completed': false,
    }));
    await _storage.saveStudySessions(widget.studySessions);
    _animCtrl.forward(from: 0);
  }

  Future<void> _deleteSession(DateTime start) async {
    setState(() => widget.studySessions
        .removeWhere((s) => (s['start'] as DateTime).isAtSameMomentAs(start)));
    await _storage.saveStudySessions(widget.studySessions);
  }

  Future<void> _toggleComplete(Map<String, dynamic> s) async {
    setState(() => s['completed'] = !(s['completed'] as bool));
    await _storage.saveStudySessions(widget.studySessions);
  }

  // ── Conflict check ───────────────────────────────────────────
  bool _hasConflict(DateTime start, DateTime end, DateTime day) {
    final allDay = [
      ...instances.where((e) => _sameDay(e['dtstart'] as DateTime, day))
          .map((e) => (e['dtstart'] as DateTime, e['dtend'] as DateTime)),
      ...widget.studySessions.where((s) => _sameDay(s['start'] as DateTime, day))
          .map((s) => (s['start'] as DateTime, s['end'] as DateTime)),
    ];
    return allDay.any((r) => start.isBefore(r.$2) && end.isAfter(r.$1));
  }

  // ── Time range (24hr) ────────────────────────────────────────
  (int, int) _timeRange() {
    final weekEnd = _currentWeekStart.add(const Duration(days: 7));
    int earliest = 24 * 60, latest = 0;

    void check(DateTime s, DateTime e) {
      if (s.isAfter(_currentWeekStart) && s.isBefore(weekEnd)) {
        final sm = s.hour * 60 + s.minute;
        final em = e.hour * 60 + e.minute;
        if (sm < earliest) earliest = sm;
        if (em > latest) latest = em;
      }
    }

    for (final e in instances) check(e['dtstart'], e['dtend']);
    for (final s in widget.studySessions) check(s['start'], s['end']);

    if (earliest == 24 * 60 || latest == 0) return (0, 24 * 60);

    return (
    (earliest - 60).clamp(0, 7 * 60),
    (latest + 60).clamp(22 * 60, 24 * 60),
    );
  }

  // ── Grid helpers ─────────────────────────────────────────────
  List<Map<String, dynamic>> _eventsForDay(int d, int sMin, int eMin) =>
      instances.where((e) {
        final s = e['dtstart'] as DateTime;
        final sm = s.hour * 60 + s.minute;
        final em = (e['dtend'] as DateTime).hour * 60 + (e['dtend'] as DateTime).minute;
        return s.difference(_currentWeekStart).inDays == d &&
            em > sMin && sm < eMin;
      }).toList()
        ..sort((a, b) => (a['dtstart'] as DateTime).compareTo(b['dtstart'] as DateTime));

  List<Map<String, dynamic>> _sessionsForDay(DateTime day) =>
      widget.studySessions
          .where((s) => _sameDay(s['start'] as DateTime, day))
          .toList()
        ..sort((a, b) => (a['start'] as DateTime).compareTo(b['start'] as DateTime));

  double _top(DateTime t, int sMin) =>
      (t.hour * 60 + t.minute - sMin) * _minHeight;

  double _blockHeight(DateTime s, DateTime e) =>
      e.difference(s).inMinutes * _minHeight;

  // ── Widgets ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      appBar: AppBar(
        backgroundColor: const Color(0xFF020617),
        elevation: 0,
        title: const Text('Timetable', style: TextStyle(fontWeight: FontWeight.w600)),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _loadTimetable)],
      ),
      body: Column(children: [
        if (statusMessage.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(statusMessage, style: TextStyle(color: statusColor, fontSize: 12)),
          ),
        _nextEventCard(),
        _weekSelector(),
        Expanded(child: _weeklyGrid()),
      ]),
    );
  }

  // ── Next event card ──────────────────────────────────────────
  Widget _nextEventCard() {
    if (nextEvent == null) {
      return Card(
        color: const Color(0xFF020617),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Row(children: [
            Icon(Icons.event_available, color: Colors.white38),
            SizedBox(width: 12),
            Text('No upcoming events.', style: TextStyle(color: Colors.white70)),
          ]),
        ),
      );
    }

    final e = nextEvent!;
    final title = _moduleTitle(e);
    final start = e['dtstart'] as DateTime;
    final end   = e['dtend']   as DateTime;
    final color = _moduleColor(title);
    final df = DateFormat('EEEE, dd MMM'), tf = DateFormat('HH:mm');

    return FutureBuilder<String>(
      future: _location(e),
      builder: (_, snap) => Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              colors: [color.withOpacity(0.95), color.withOpacity(0.75)],
              begin: Alignment.centerLeft, end: Alignment.centerRight,
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            leading: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.play_arrow, color: Colors.white, size: 20),
            ),
            title: const Text('Next event',
                style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
                const SizedBox(height: 4),
                Text(snap.data ?? '...', style: const TextStyle(color: Colors.white70)),
                Text('${df.format(start)} • ${tf.format(start)} – ${tf.format(end)}',
                    style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Week selector ────────────────────────────────────────────
  Widget _weekSelector() {
    final s = _currentWeekStart;
    final e = s.add(const Duration(days: 6));
    final isNow = _sameDay(s, _mondayOf(DateTime.now()));
    final range = '${DateFormat('dd MMM').format(s)} – ${DateFormat('dd MMM').format(e)}';

    btnStyle(Color bg) => IconButton.styleFrom(backgroundColor: bg, foregroundColor: Colors.white);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton.filledTonal(
            style: btnStyle(const Color(0xFF1F2937)),
            icon: const Icon(Icons.chevron_left),
            onPressed: () => setState(() =>
            _currentWeekStart = _currentWeekStart.subtract(const Duration(days: 7))),
          ),
          Column(children: [
            const Text('Week view', style: TextStyle(fontSize: 12, color: Colors.white54)),
            Text(range, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
          ]),
          Row(children: [
            if (!isNow)
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: Colors.white70),
                icon: const Icon(Icons.today, size: 18),
                label: const Text('Today'),
                onPressed: () => setState(() => _currentWeekStart = _mondayOf(DateTime.now())),
              ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              style: btnStyle(const Color(0xFF1F2937)),
              icon: const Icon(Icons.chevron_right),
              onPressed: () => setState(() =>
              _currentWeekStart = _currentWeekStart.add(const Duration(days: 7))),
            ),
          ]),
        ],
      ),
    );
  }

  // ── Weekly grid ──────────────────────────────────────────────
  Widget _weeklyGrid() {
    if (instances.isEmpty) {
      return const Center(
          child: Text('No timetable loaded yet.', style: TextStyle(color: Colors.white60)));
    }

    final today = DateTime.now();
    final isNow = _sameDay(_currentWeekStart, _mondayOf(today));
    final (sMin, eMin) = _timeRange();
    final totalHeight = (eMin - sMin) * _minHeight;
    final df = DateFormat('EEE\ndd MMM');

    Widget dayHeader(int d) {
      final date = _currentWeekStart.add(Duration(days: d));
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF020617),
            border: Border(bottom: BorderSide(color: Colors.grey.shade900)),
          ),
          child: Text(
            df.format(date),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isNow && _sameDay(date, today) ? Colors.blueAccent : Colors.white70,
            ),
          ),
        ),
      );
    }

    return Column(children: [
      // Header
      Row(children: [
        const SizedBox(width: 60,
            child: Center(child: Text('Time',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70)))),
        for (int d = 0; d < _daysInWeek; d++) dayHeader(d),
      ]),
      // Scrollable grid
      Expanded(
        child: SingleChildScrollView(
          child: SizedBox(
            height: totalHeight,
            child: Stack(children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Time labels
                SizedBox(
                  width: 60,
                  child: Stack(children: [
                    for (int m = sMin; m < eMin; m += 60)
                      Positioned(
                        top: (m - sMin) * _minHeight,
                        child: SizedBox(width: 60,
                          child: Text(
                            '${(m ~/ 60).toString().padLeft(2, '0')}:00',
                            style: const TextStyle(fontSize: 10, color: Colors.white38),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ]),
                ),
                // Day columns
                Expanded(
                  child: Stack(children: [
                    for (int m = sMin; m < eMin; m += 60)
                      Positioned(
                        top: (m - sMin) * _minHeight, left: 0, right: 0,
                        child: Container(height: 1, color: Colors.white10),
                      ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (int d = 0; d < _daysInWeek; d++)
                          Expanded(child: _dayColumn(d, sMin, eMin, totalHeight)),
                      ],
                    ),
                  ]),
                ),
              ]),
              // Current time line
              if (isNow) _timeLine(sMin),
            ]),
          ),
        ),
      ),
    ]);
  }

  // ── Current time line ────────────────────────────────────────
  Widget _timeLine(int sMin) {
    final now = DateTime.now();
    final cur = now.hour * 60 + now.minute;
    if (cur < sMin || cur > 24 * 60) return const SizedBox.shrink();
    return Positioned(
      top: (cur - sMin) * _minHeight, left: 60, right: 0,
      child: Row(children: [
        Container(width: 8, height: 8,
            decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle)),
        Expanded(child: Container(height: 2, color: Colors.redAccent)),
      ]),
    );
  }

  // ── Day column ───────────────────────────────────────────────
  Widget _dayColumn(int d, int sMin, int eMin, double totalH) {
    final day = _currentWeekStart.add(Duration(days: d));
    final events   = _eventsForDay(d, sMin, eMin);
    final sessions = _sessionsForDay(day);
    final gaps     = _service.findFreeGapsForDay(List.from(events), day, 30);

    return GestureDetector(
      onTap: (events.isEmpty && sessions.isEmpty)
          ? () => _openCustomStudy(day) : null,
      child: Container(
        height: totalH,
        decoration: const BoxDecoration(
            border: Border(right: BorderSide(color: Colors.white10, width: 0.5))),
        child: Stack(clipBehavior: Clip.hardEdge, children: [
          for (final g in gaps)   _gapBlock(g, sMin),
          for (final e in events) _eventBlock(e, sMin),
          for (final s in sessions) _sessionBlock(s, sMin),
        ]),
      ),
    );
  }

  // ── Gap block ────────────────────────────────────────────────
  Widget _gapBlock(Map<String, dynamic> gap, int sMin) {
    final s = gap['start'] as DateTime;
    final e = gap['end']   as DateTime;
    final h = _blockHeight(s, e);
    if (h < 10) return const SizedBox.shrink();
    return Positioned(
      top: _top(s, sMin), left: 1, right: 1, height: h,
      child: GestureDetector(
        onTap: () => _openPlanSession(gap),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 1),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.white.withOpacity(0.07), width: 0.5),
          ),
          child: h > 20 ? const Center(child: Icon(Icons.add, size: 12, color: Colors.white24)) : null,
        ),
      ),
    );
  }

  // ── Event block ──────────────────────────────────────────────
  Widget _eventBlock(Map<String, dynamic> e, int sMin) {
    final s     = e['dtstart'] as DateTime;
    final end   = e['dtend']   as DateTime;
    final title = _moduleTitle(e);
    final color = _moduleColor(title);
    final past  = s.isBefore(DateTime.now());

    return Positioned(
      top: _top(s, sMin), left: 1, right: 1,
      height: _blockHeight(s, end).clamp(18.0, double.infinity),
      child: GestureDetector(
        onTap: () => _openEventEditor(e),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 1),
          decoration: BoxDecoration(
            color: color.withOpacity(past ? 0.35 : 0.85),
            borderRadius: BorderRadius.circular(4),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
          child: Text(title,
            maxLines: 3,
            style: TextStyle(
              fontSize: 9, fontWeight: FontWeight.w600, overflow: TextOverflow.ellipsis,
              color: past ? Colors.white38 : Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  // ── Study session block ──────────────────────────────────────
  Widget _sessionBlock(Map<String, dynamic> s, int sMin) {
    final start     = s['start'] as DateTime;
    final end       = s['end']   as DateTime;
    final completed = s['completed'] as bool;

    return Positioned(
      top: _top(start, sMin), left: 1, right: 1,
      height: _blockHeight(start, end).clamp(18.0, double.infinity),
      child: GestureDetector(
        onTap: () => _editSession(s),
        onLongPress: () => _toggleComplete(s),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 1),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(completed ? 0.25 : 0.6),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: (completed ? Colors.green : Colors.greenAccent).withOpacity(0.5),
              width: 0.5,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
          child: Text(s['module'] ?? '',
            maxLines: 3,
            style: TextStyle(
              fontSize: 9, fontWeight: FontWeight.w600, overflow: TextOverflow.ellipsis,
              color: completed ? Colors.white38 : Colors.white,
              decoration: completed ? TextDecoration.lineThrough : null,
            ),
          ),
        ),
      ),
    );
  }

  // ── Dialogs & bottom sheets ──────────────────────────────────
  void _openEventEditor(Map<String, dynamic> e) async {
    final title = _moduleTitle(e);
    final loc   = await _location(e);
    final s     = e['dtstart'] as DateTime;
    final end   = e['dtend']   as DateTime;
    final df = DateFormat('EEEE, dd MMM'), tf = DateFormat('HH:mm');

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF020617),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(999)))),
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(height: 8),
            _iconRow(Icons.place, loc),
            const SizedBox(height: 6),
            _iconRow(Icons.access_time, '${df.format(s)} • ${tf.format(s)} – ${tf.format(end)}'),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6), foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit location'),
              onPressed: () { Navigator.pop(context); _openEditForm(e); },
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconRow(IconData icon, String text) => Row(children: [
    Icon(icon, size: 16, color: Colors.white54),
    const SizedBox(width: 6),
    Expanded(child: Text(text, style: const TextStyle(color: Colors.white70))),
  ]);

  void _openEditForm(Map<String, dynamic> e) async {
    final ctrl = TextEditingController(text: await _location(e));
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF020617),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit location', style: TextStyle(color: Colors.white)),
        content: _styledTextField(ctrl, 'Location'),
        actions: [
          _dialogBtn('Cancel', Colors.white70, () => Navigator.pop(context)),
          _dialogBtn('Save', Colors.white, () async {
            await _storage.saveEventLocationEdit(_eventId(e), ctrl.text.trim());
            setState(() {});
            if (mounted) Navigator.pop(context);
          }),
        ],
      ),
    );
  }

  void _editSession(Map<String, dynamic> session) {
    final ctrl = TextEditingController(text: session['module']);
    String type = session['type'];

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, set) => AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Edit study session', style: TextStyle(color: Colors.white)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            _styledTextField(ctrl, 'Title'),
            const SizedBox(height: 16),
            _typeDropdown(type, (v) => set(() => type = v!)),
          ]),
          actions: [
            _dialogBtn('Delete', Colors.redAccent, () async {
              await _deleteSession(session['start']); Navigator.pop(context); }),
            _dialogBtn('Cancel', Colors.white70, () => Navigator.pop(context)),
            _dialogBtn('Save', Colors.white, () async {
              setState(() { session['module'] = ctrl.text.trim(); session['type'] = type; });
              await _storage.saveStudySessions(widget.studySessions);
              if (mounted) Navigator.pop(context);
            }),
          ],
        ),
      ),
    );
  }

  void _openPlanSession(Map<String, dynamic> gap) =>
      _plannerSheet(start: gap['start'], duration: gap['duration']);

  void _openCustomStudy(DateTime day) async {
    Future<DateTime?> pick(String label) async {
      final t = await showTimePicker(
          context: context, initialTime: const TimeOfDay(hour: 9, minute: 0), helpText: label);
      return t == null ? null : DateTime(day.year, day.month, day.day, t.hour, t.minute);
    }

    final start = await pick('Select start time'); if (start == null) return;
    final end   = await pick('Select end time');   if (end == null)   return;

    if (!end.isAfter(start)) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('End time must be after start time')));
      return;
    }
    _plannerSheet(start: start, duration: end.difference(start).inMinutes);
  }

  void _plannerSheet({required DateTime start, required int duration}) {
    String type = 'Revision';
    double mins = 60;
    DateTime selStart = start;
    final gapEnd = start.add(Duration(minutes: duration));
    final moduleCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF020617),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(builder: (context, set) {
        final tf = DateFormat('HH:mm');
        final selEnd = selStart.add(Duration(minutes: mins.toInt()));
        final conflict = _hasConflict(selStart, selEnd,
            DateTime(selStart.year, selStart.month, selStart.day));

        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
                left: 20, right: 20, top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(999)))),
                const Text('Plan study session',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 16),
                const Text('Title', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 6),
                _styledTextField(moduleCtrl, ''),
                const SizedBox(height: 16),
                const Text('Study type', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 6),
                _typeDropdown(type, (v) => set(() => type = v!)),
                const SizedBox(height: 16),
                const Text('Start time', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () async {
                    final p = await showTimePicker(
                        context: context, initialTime: TimeOfDay.fromDateTime(selStart));
                    if (p == null) return;
                    final ns = DateTime(selStart.year, selStart.month, selStart.day, p.hour, p.minute);
                    if (ns.isBefore(start) || ns.isAfter(gapEnd)) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('Must be between ${tf.format(start)} – ${tf.format(gapEnd)}')));
                      return;
                    }
                    set(() => selStart = ns);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                        color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white24)),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(tf.format(selStart), style: const TextStyle(color: Colors.white, fontSize: 16)),
                        const Icon(Icons.access_time, color: Colors.white54),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Duration: ${mins.toInt()} min', style: const TextStyle(color: Colors.white70)),
                Slider(value: mins, min: 30, max: 180, divisions: 10,
                    onChanged: (v) => set(() => mins = v)),
                if (conflict)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      border: Border.all(color: Colors.orange.withOpacity(0.5)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                      SizedBox(width: 8),
                      Expanded(child: Text('This time overlaps with another event',
                          style: TextStyle(color: Colors.orange, fontSize: 12))),
                    ]),
                  ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: conflict ? Colors.grey : const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: conflict ? null : () async {
                    final name = moduleCtrl.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter a title')));
                      return;
                    }
                    await _saveSession(module: name, type: type,
                        start: selStart, duration: mins.toInt());
                    if (mounted) Navigator.pop(context);
                  },
                  child: Text(conflict ? 'Conflict detected' : 'Save session'),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  // ── Shared small widgets ─────────────────────────────────────
  Widget _styledTextField(TextEditingController ctrl, String label) =>
      TextField(
        controller: ctrl,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label, labelStyle: const TextStyle(color: Colors.white70),
          filled: true, fillColor: const Color(0xFF1E293B),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.white24)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.white)),
        ),
      );

  Widget _typeDropdown(String value, ValueChanged<String?> onChanged) =>
      DropdownButtonFormField<String>(
        value: value,
        dropdownColor: const Color(0xFF0F172A),
        decoration: InputDecoration(
          filled: true, fillColor: const Color(0xFF1E293B),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        items: ['Revision', 'Coursework', 'Reading']
            .map((t) => DropdownMenuItem(value: t,
            child: Text(t, style: const TextStyle(color: Colors.white))))
            .toList(),
        onChanged: onChanged,
      );

  TextButton _dialogBtn(String label, Color color, VoidCallback onTap) =>
      TextButton(onPressed: onTap, child: Text(label, style: TextStyle(color: color)));
}
