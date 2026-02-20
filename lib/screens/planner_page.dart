import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/storage_service.dart';
import '../services/stats_service.dart';
import '../widgets/pomodoro_timer.dart';
import 'knowledgeGraphpage.dart';

final _storage = StorageService();
final _stats   = StatsService();

class PlannerPage extends StatefulWidget {
  final List<Map<String, dynamic>> studySessions;
  const PlannerPage({super.key, required this.studySessions});

  @override
  State<PlannerPage> createState() => _PlannerPageState();
}

class _PlannerPageState extends State<PlannerPage> {
  List<Map<String, dynamic>> _history = [];
  Map<String, DateTime>      _examDates = {};
  int _weeklyGoalMinutes = 300;

  static const _palette = [
    Color(0xFF3B82F6), Color(0xFF10B981), Color(0xFFF97316),
    Color(0xFFE11D48), Color(0xFF8B5CF6), Color(0xFFF59E0B),
  ];

  Color _moduleColor(String t) =>
      _palette[t.hashCode.abs() % _palette.length];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final h = await _storage.loadHistory();
    final e = await _storage.loadExamDates();
    final g = await _storage.loadWeeklyGoal();
    setState(() {
      _history           = h;
      _examDates         = e;
      _weeklyGoalMinutes = g;
    });
  }

  // ── Completion toggle ────────────────────────────────────────
  Future<void> _toggleComplete(Map<String, dynamic> s) async {
    final wasComplete = s['completed'] as bool;
    setState(() => s['completed'] = !wasComplete);
    await _storage.saveStudySessions(widget.studySessions);
    if (!wasComplete) _showCompletionSheet(s);
  }

  // ── Completion sheet ─────────────────────────────────────────
  void _showCompletionSheet(Map<String, dynamic> s) {
    int confidence = 3;
    double actualMin = ((s['end'] as DateTime)
        .difference(s['start'] as DateTime)
        .inMinutes)
        .toDouble();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) =>
          StatefulBuilder(builder: (context, set) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(999)),
              ),
              const Text('How did it go?',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
              const SizedBox(height: 20),
              Text('Actual duration: ${actualMin.toInt()} min',
                  style: const TextStyle(color: Colors.white70)),
              Slider(
                value: actualMin,
                min: 5, max: 240, divisions: 47,
                activeColor: const Color(0xFF3B82F6),
                onChanged: (v) => set(() => actualMin = v),
              ),
              const SizedBox(height: 8),
              const Text('How confident do you feel?',
                  style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) => GestureDetector(
                  onTap: () => set(() => confidence = i + 1),
                  child: Icon(
                    i < confidence ? Icons.star : Icons.star_border,
                    color: Colors.amber, size: 36,
                  ),
                )),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  setState(() {
                    s['actualDuration']  = actualMin.toInt();
                    s['confidenceAfter'] = confidence;
                  });
                  await _storage.saveStudySessions(widget.studySessions);
                  await _storage.appendToHistory({...s});
                  await _loadData();
                  if (mounted) Navigator.pop(context);
                },
                child: const Text('Save'),
              ),
            ]),
          )),
    );
  }

  // ── Build ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todaySessions = widget.studySessions.where((s) {
      final st = s['start'] as DateTime;
      return st.year == today.year &&
          st.month == today.month &&
          st.day == today.day;
    }).toList();

    final modules = widget.studySessions
        .map((s) => s['module'] as String)
        .toSet()
        .toList();

    final underrevised =
    _stats.underrevisedModules(_history, modules, 5);

    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      appBar: AppBar(
        backgroundColor: const Color(0xFF020617),
        elevation: 0,
        title: const Text('Study Planner',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: DefaultTabController(
        length: 4,
        child: Column(children: [
          const TabBar(
            indicatorColor: Color(0xFF3B82F6),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            isScrollable: true,
            tabs: [
              Tab(text: 'Today'),
              Tab(text: 'This Week'),
              Tab(text: 'Stats'),
              Tab(text: 'Knowledge Map'),
            ],
          ),
          Expanded(
            child: TabBarView(children: [
              _todayTab(todaySessions, underrevised),
              _weekTab(),
              _statsTab(),
              _knowledgeMapTab(context, modules),
            ]),
          ),
        ]),
      ),
    );
  }

  // ── Today tab ────────────────────────────────────────────────
  Widget _todayTab(List<Map<String, dynamic>> sessions,
      List<String> underrevised) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (underrevised.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border:
              Border.all(color: Colors.orange.withOpacity(0.4)),
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [
                    Icon(Icons.warning_amber_rounded,
                        color: Colors.orange, size: 18),
                    SizedBox(width: 8),
                    Text('Not revised in 5+ days',
                        style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 6),
                  Text(underrevised.join(', '),
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13)),
                ]),
          ),
          const SizedBox(height: 12),
        ],
        _buildDueBanner(),
        const SizedBox(height: 12),
        if (sessions.isEmpty)
          const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('No study sessions today.',
                    style: TextStyle(color: Colors.white54)),
              ))
        else
          ...sessions.map((s) => _sessionCard(s)),
      ],
    );
  }

  // ── Due for review banner ────────────────────────────────────
  Widget _buildDueBanner() {
    final due = widget.studySessions.where((s) {
      final next = s['nextReviewDue'];
      if (next == null) return false;
      final date = next is DateTime
          ? next
          : DateTime.tryParse(next.toString());
      return date != null && !date.isAfter(DateTime.now());
    }).map((s) => s['module'] as String).toSet().toList();

    if (due.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.4)),
      ),
      child: Row(children: [
        const Icon(Icons.replay, color: Colors.blueAccent, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text('Due for review: ${due.join(', ')}',
              style: const TextStyle(
                  color: Colors.white70, fontSize: 13)),
        ),
      ]),
    );
  }

  // ── This Week tab ─────────────────────────────────────────────
  Widget _weekTab() {
    final grouped = _groupByDay(widget.studySessions);
    if (grouped.isEmpty) {
      return const Center(
          child: Text('No study sessions this week.',
              style: TextStyle(color: Colors.white54)));
    }
    final df = DateFormat('EEEE, dd MMM');
    return ListView(
      padding: const EdgeInsets.all(16),
      children: grouped.entries
          .map((entry) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(df.format(entry.key),
              style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                  fontSize: 14)),
          const SizedBox(height: 8),
          ...entry.value.map((s) => _sessionCard(s)),
          const SizedBox(height: 20),
        ],
      ))
          .toList(),
    );
  }

  // ── Stats tab ────────────────────────────────────────────────
  Widget _statsTab() {
    final now       = DateTime.now();
    final monday    = now.subtract(Duration(days: now.weekday - 1));
    final weekStart = DateTime(monday.year, monday.month, monday.day);

    final rate    = _stats.completionRate(widget.studySessions, weekStart);
    final streak  = _stats.currentStreak(_history);
    final minsPer = _stats.minutesPerModule(_history);
    final best    = _stats.bestTimeOfDay(_history);
    final heatmap = _stats.heatmapData(_history);
    final total   = widget.studySessions.length;
    final done    = widget.studySessions
        .where((s) => s['completed'] == true)
        .length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Stat chips
        Row(children: [
          _statChip('🔥', '$streak', 'Day streak'),
          const SizedBox(width: 10),
          _statChip('✅', '$done/$total', 'Sessions'),
          const SizedBox(width: 10),
          _statChip('⏰', best.split(' ')[0], 'Peak time'),
        ]),
        const SizedBox(height: 20),

        // Weekly goal
        _buildWeeklyGoal(),
        const SizedBox(height: 20),

        // Completion rate
        _sectionTitle('This Week'),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: rate,
            minHeight: 16,
            backgroundColor: Colors.white10,
            valueColor: AlwaysStoppedAnimation(
                rate > 0.7 ? Colors.greenAccent : Colors.orangeAccent),
          ),
        ),
        const SizedBox(height: 4),
        Text('${(rate * 100).toStringAsFixed(0)}% completed',
            style: const TextStyle(
                color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 20),

        // Heatmap
        _sectionTitle('Study Activity (last 12 weeks)'),
        const SizedBox(height: 10),
        _buildHeatmap(heatmap),
        const SizedBox(height: 20),

        // Bar chart
        if (minsPer.isNotEmpty) ...[
          _sectionTitle('Hours studied per module'),
          const SizedBox(height: 10),
          _buildBarChart(minsPer),
          const SizedBox(height: 20),
        ],

        // Hour distribution
        _sectionTitle('Best time of day'),
        const SizedBox(height: 8),
        _buildHourChart(_stats.sessionsByHour(_history)),
        const SizedBox(height: 20),

        // Exam countdowns
        if (_examDates.isNotEmpty) ...[
          _sectionTitle('Exam Countdowns'),
          const SizedBox(height: 8),
          ..._examDates.entries.map((e) {
            final days =
                e.value.difference(DateTime.now()).inDays;
            return _examChip(e.key, days);
          }),
        ],
      ],
    );
  }

  // ── Weekly goal ──────────────────────────────────────────────
  Widget _buildWeeklyGoal() {
    final now       = DateTime.now();
    final monday    = now.subtract(Duration(days: now.weekday - 1));
    final weekStart = DateTime(monday.year, monday.month, monday.day);
    final weekEnd   = weekStart.add(const Duration(days: 7));

    final doneMinutes = _history
        .where((s) {
      final d = s['start'] as DateTime;
      return d.isAfter(weekStart) &&
          d.isBefore(weekEnd) &&
          s['completed'] == true;
    })
        .fold<int>(0, (sum, s) {
      final actual  = s['actualDuration'] as int?;
      final planned = (s['end'] as DateTime)
          .difference(s['start'] as DateTime)
          .inMinutes;
      return sum + (actual ?? planned);
    });

    final progress =
    (doneMinutes / _weeklyGoalMinutes).clamp(0.0, 1.0);
    final doneHrs = (doneMinutes / 60).toStringAsFixed(1);
    final goalHrs = (_weeklyGoalMinutes / 60).toStringAsFixed(0);
    final pct     = (progress * 100).toInt();

    Color barColor;
    if (progress < 0.4)       barColor = Colors.redAccent;
    else if (progress < 0.75) barColor = Colors.orangeAccent;
    else                      barColor = Colors.greenAccent;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Weekly Goal',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15)),
                  GestureDetector(
                    onTap: _showGoalEditor,
                    child: const Icon(Icons.edit_outlined,
                        color: Colors.white38, size: 18),
                  ),
                ]),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 14,
                backgroundColor: Colors.white10,
                valueColor: AlwaysStoppedAnimation(barColor),
              ),
            ),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('$doneHrs hrs done',
                      style: TextStyle(
                          color: barColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  Text('Goal: ${goalHrs}hrs',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 13)),
                  Text('$pct%',
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 13)),
                ]),
            if (progress >= 1.0) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(children: [
                  Icon(Icons.emoji_events,
                      color: Colors.greenAccent, size: 16),
                  SizedBox(width: 8),
                  Text('Goal reached this week! 🎉',
                      style: TextStyle(
                          color: Colors.greenAccent, fontSize: 13)),
                ]),
              ),
            ],
          ]),
    );
  }

  void _showGoalEditor() {
    double goalHrs = _weeklyGoalMinutes / 60;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
          borderRadius:
          BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) =>
          StatefulBuilder(builder: (context, set) => Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child:
            Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(999)),
              ),
              const Text('Set weekly study goal',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
              const SizedBox(height: 24),
              Text('${goalHrs.toStringAsFixed(1)} hours per week',
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
              const SizedBox(height: 4),
              Text('${(goalHrs * 60).toInt()} minutes',
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 13)),
              Slider(
                value: goalHrs,
                min: 1, max: 40, divisions: 39,
                activeColor: const Color(0xFF3B82F6),
                onChanged: (v) => set(() => goalHrs = v),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (final h in [5, 10, 15, 20])
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(
                            color: Colors.white24),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                      ),
                      onPressed: () =>
                          set(() => goalHrs = h.toDouble()),
                      child: Text('${h}h'),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  final mins = (goalHrs * 60).toInt();
                  await _storage.saveWeeklyGoal(mins);
                  setState(() => _weeklyGoalMinutes = mins);
                  if (mounted) Navigator.pop(context);
                },
                child: const Text('Save goal'),
              ),
            ]),
          )),
    );
  }

  // ── Heatmap ──────────────────────────────────────────────────
  Widget _buildHeatmap(Map<DateTime, int> data) {
    final today   = DateTime.now();
    final todayDay = DateTime(today.year, today.month, today.day);
    const weeks   = 12;
    final cells   = weeks * 7;

    return Wrap(
      spacing: 3, runSpacing: 3,
      children: List.generate(cells, (i) {
        final day  = todayDay.subtract(Duration(days: cells - 1 - i));
        final mins = data[day] ?? 0;
        Color color;
        if (mins == 0)        color = Colors.white10;
        else if (mins < 30)   color = Colors.green.withOpacity(0.25);
        else if (mins < 60)   color = Colors.green.withOpacity(0.5);
        else if (mins < 120)  color = Colors.green.withOpacity(0.75);
        else                  color = Colors.green;

        return Tooltip(
          message: mins > 0
              ? '${DateFormat('dd MMM').format(day)}: ${mins}min'
              : '',
          child: Container(
            width: 14, height: 14,
            decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2)),
          ),
        );
      }),
    );
  }

  // ── Bar chart ────────────────────────────────────────────────
  Widget _buildBarChart(Map<String, int> data) {
    final entries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxVal = entries.first.value.toDouble();

    return SizedBox(
      height: 160,
      child: BarChart(BarChartData(
        maxY: maxVal,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= entries.length) {
                  return const SizedBox.shrink();
                }
                final label = entries[i].key;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    label.length > 8
                        ? '${label.substring(0, 7)}…'
                        : label,
                    style: const TextStyle(
                        fontSize: 9, color: Colors.white54),
                  ),
                );
              },
            ),
          ),
          leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
        ),
        barGroups: List.generate(
          entries.length,
              (i) => BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: entries[i].value.toDouble(),
                width: 14,
                borderRadius: BorderRadius.circular(4),
                color: _moduleColor(entries[i].key),
              ),
            ],
          ),
        ),
      )),
    );
  }

  // ── Hour chart ───────────────────────────────────────────────
  Widget _buildHourChart(Map<int, int> byHour) {
    if (byHour.isEmpty) {
      return const Text('No data yet.',
          style: TextStyle(color: Colors.white38, fontSize: 12));
    }
    final maxVal =
    byHour.values.reduce((a, b) => a > b ? a : b).toDouble();

    return SizedBox(
      height: 120,
      child: BarChart(BarChartData(
        maxY: maxVal,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 20,
              getTitlesWidget: (v, _) {
                final h = v.toInt();
                if (h % 6 != 0) return const SizedBox.shrink();
                return Text('${h}h',
                    style: const TextStyle(
                        fontSize: 9, color: Colors.white38));
              },
            ),
          ),
          leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
        ),
        barGroups: List.generate(
          24,
              (h) => BarChartGroupData(
            x: h,
            barRods: [
              BarChartRodData(
                toY: (byHour[h] ?? 0).toDouble(),
                width: 8,
                borderRadius: BorderRadius.circular(2),
                color: const Color(0xFF3B82F6).withOpacity(0.8),
              ),
            ],
          ),
        ),
      )),
    );
  }

  // ── Knowledge Map tab ────────────────────────────────────────
  Widget _knowledgeMapTab(BuildContext context, List<String> modules) {
    if (modules.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Plan some study sessions first to create knowledge maps.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 16),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: modules.length + 1,
      itemBuilder: (context, i) {
        if (i == modules.length) {
          return _addExamDateButton(context, modules);
        }
        final module = modules[i];
        final color  = _moduleColor(module);
        final exam   = _examDates[module];
        final days   = exam?.difference(DateTime.now()).inDays;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          color: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            leading: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.account_tree, color: color),
            ),
            title: Text(module,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600)),
            subtitle: Text(
              exam != null
                  ? 'Exam in $days days'
                  : 'Tap to view knowledge map',
              style: TextStyle(
                  color: exam != null && days! < 7
                      ? Colors.redAccent
                      : Colors.white70),
            ),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              if (days != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: days < 7
                        ? Colors.redAccent.withOpacity(0.2)
                        : Colors.blueAccent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('$days days',
                      style: TextStyle(
                          color: days < 7
                              ? Colors.redAccent
                              : Colors.blueAccent,
                          fontSize: 11)),
                ),
              const Icon(Icons.chevron_right,
                  color: Colors.white54),
            ]),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => KnowledgeGraphPage(
                    moduleTitle: module, moduleColor: color),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _addExamDateButton(
      BuildContext context, List<String> modules) {
    return TextButton.icon(
      style: TextButton.styleFrom(
          foregroundColor: Colors.white54),
      icon: const Icon(Icons.add),
      label: const Text('Set exam date'),
      onPressed: () => _showExamDateDialog(context, modules),
    );
  }

  void _showExamDateDialog(
      BuildContext context, List<String> modules) async {
    String? selected = modules.first;
    DateTime? picked;

    await showDialog(
      context: context,
      builder: (_) =>
          StatefulBuilder(builder: (context, set) => AlertDialog(
            backgroundColor: const Color(0xFF0F172A),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: const Text('Set exam date',
                style: TextStyle(color: Colors.white)),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                value: selected,
                dropdownColor: const Color(0xFF0F172A),
                style: const TextStyle(color: Colors.white),
                items: modules
                    .map((m) => DropdownMenuItem(
                    value: m, child: Text(m)))
                    .toList(),
                onChanged: (v) => set(() => selected = v),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70),
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now()
                        .add(const Duration(days: 7)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now()
                        .add(const Duration(days: 365)),
                  );
                  if (date != null) set(() => picked = date);
                },
                child: Text(picked == null
                    ? 'Pick date'
                    : DateFormat('dd MMM yyyy').format(picked!)),
              ),
            ]),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel',
                    style: TextStyle(color: Colors.white54)),
              ),
              TextButton(
                onPressed: picked == null
                    ? null
                    : () async {
                  final updated =
                  Map<String, DateTime>.from(_examDates);
                  updated[selected!] = picked!;
                  await _storage.saveExamDates(updated);
                  setState(() => _examDates = updated);
                  if (mounted) Navigator.pop(context);
                },
                child: const Text('Save',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          )),
    );
  }

  // ── Session card ─────────────────────────────────────────────
  Widget _sessionCard(Map<String, dynamic> s) {
    final df         = DateFormat('HH:mm');
    final start      = s['start']      as DateTime;
    final end        = s['end']        as DateTime;
    final completed  = s['completed']  as bool;
    final confidence = s['confidenceAfter'] as int?;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: const Color(0xFF0F172A),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 8),
        leading: GestureDetector(
          onTap: () => _toggleComplete(s),
          child: Icon(
            completed
                ? Icons.check_circle
                : Icons.radio_button_unchecked,
            color: completed ? Colors.greenAccent : Colors.white38,
            size: 28,
          ),
        ),
        title: Text(s['module'],
            style: TextStyle(
              color: completed ? Colors.white54 : Colors.white,
              fontWeight: FontWeight.w600,
              decoration:
              completed ? TextDecoration.lineThrough : null,
            )),
        subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${s['type']} • ${df.format(start)} – ${df.format(end)}',
                style: TextStyle(
                  color: completed
                      ? Colors.white38
                      : Colors.white70,
                  decoration: completed
                      ? TextDecoration.lineThrough
                      : null,
                ),
              ),
              if (confidence != null)
                Row(
                  children: List.generate(
                    5,
                        (i) => Icon(
                      i < confidence
                          ? Icons.star
                          : Icons.star_border,
                      color: Colors.amber,
                      size: 14,
                    ),
                  ),
                ),
            ]),
        trailing: IconButton(
          icon: const Icon(Icons.timer_outlined,
              color: Colors.white38, size: 22),
          onPressed: () => showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            isScrollControlled: true,
            builder: (_) =>
                PomodoroTimer(moduleName: s['module'] ?? ''),
          ),
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────
  Map<DateTime, List<Map<String, dynamic>>> _groupByDay(
      List<Map<String, dynamic>> sessions) {
    final map = <DateTime, List<Map<String, dynamic>>>{};
    for (final s in sessions) {
      final d   = s['start'] as DateTime;
      final key = DateTime(d.year, d.month, d.day);
      map.putIfAbsent(key, () => []).add(s);
    }
    return Map.fromEntries(map.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key)));
  }

  Widget _sectionTitle(String t) => Text(t,
      style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 15));

  Widget _statChip(String emoji, String value, String label) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
            Text(label,
                style: const TextStyle(
                    color: Colors.white54, fontSize: 11)),
          ]),
        ),
      );

  Widget _examChip(String module, int days) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding:
    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: days < 7
          ? Colors.redAccent.withOpacity(0.1)
          : const Color(0xFF0F172A),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
          color: days < 7
              ? Colors.redAccent.withOpacity(0.5)
              : Colors.white12),
    ),
    child: Row(children: [
      Icon(Icons.event,
          color: days < 7 ? Colors.redAccent : Colors.white54,
          size: 18),
      const SizedBox(width: 10),
      Expanded(
          child: Text(module,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600))),
      Text('$days days',
          style: TextStyle(
              color: days < 7
                  ? Colors.redAccent
                  : Colors.white54,
              fontSize: 13)),
    ]),
  );
}
