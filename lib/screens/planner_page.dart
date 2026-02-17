import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PlannerPage extends StatelessWidget {
  final List<Map<String, dynamic>> studySessions;

  const PlannerPage({super.key, required this.studySessions});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todaySessions = studySessions.where((s) {
      final st = s['start'] as DateTime;
      return st.year == today.year && st.month == today.month && st.day == today.day;
    }).toList();
    final weekSessions = _groupByDay(studySessions);


    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      appBar: AppBar(
        backgroundColor: const Color(0xFF020617),
        elevation: 0,
        title: const Text('Study Planner', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const TabBar(
              indicatorColor: Color(0xFF3B82F6),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white54,
              tabs: [Tab(text: 'Today'), Tab(text: 'This Week')],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildTodayTab(todaySessions),
                  _buildWeekTab(weekSessions),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayTab(List<Map<String, dynamic>> sessions) {
    if (sessions.isEmpty) {
      return const Center(
        child: Text('No study sessions planned for today.', style: TextStyle(color: Colors.white54)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sessions.length,
      itemBuilder: (_, i) => _buildSessionCard(sessions[i]),
    );
  }

  Widget _buildWeekTab(Map<DateTime, List<Map<String, dynamic>>> grouped) {
    if (grouped.isEmpty) {
      return const Center(
        child: Text('No study sessions planned this week.', style: TextStyle(color: Colors.white54)),
      );
    }
    final df = DateFormat('EEEE, dd MMM');
    return ListView(
      padding: const EdgeInsets.all(16),
      children: grouped.entries.map((entry) {
        final day = entry.key;
        final sessions = entry.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(df.format(day), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            ...sessions.map(_buildSessionCard).toList(),
            const SizedBox(height: 20),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildSessionCard(Map<String, dynamic> s) {
    final df = DateFormat('HH:mm');

    final start = s['start'] as DateTime;
    final end = s['end'] as DateTime;

    final module = s['module'];
    final type = s['type'];
    final completed = s['completed'] as bool;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: const Color(0xFF0F172A),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),

        // ✔ Tappable completion toggle
        leading: GestureDetector(
          onTap: () {
            s['completed'] = !completed;
          },
          child: Icon(
            completed ? Icons.check_circle : Icons.radio_button_unchecked,
            color: completed ? Colors.greenAccent : Colors.white38,
            size: 28,
          ),
        ),

        title: Text(
          module,
          style: TextStyle(
            color: completed ? Colors.white54 : Colors.white,
            fontWeight: FontWeight.w600,
            decoration: completed ? TextDecoration.lineThrough : null,
          ),
        ),

        subtitle: Text(
          '$type • ${df.format(start)} – ${df.format(end)}',
          style: TextStyle(
            color: completed ? Colors.white38 : Colors.white70,
            decoration: completed ? TextDecoration.lineThrough : null,
          ),
        ),
      ),
    );
  }


  Map<DateTime, List<Map<String, dynamic>>> _groupByDay(List<Map<String, dynamic>> sessions) {
    final map = <DateTime, List<Map<String, dynamic>>>{};
    for (final s in sessions) {
      final st = s['start'] as DateTime;
      final key = DateTime(st.year, st.month, st.day);
      map.putIfAbsent(key, () => []);
      map[key]!.add(s);
    }
    final sorted = map.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    return Map.fromEntries(sorted);
  }
}
