// lib/pages/study_page.dart
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/knowledge_node.dart';
import '../services/storage_service.dart';
import '../services/sm2_service.dart';

class StudyPage extends StatefulWidget {
  const StudyPage({super.key});

  @override
  State<StudyPage> createState() => _StudyPageState();
}

class _StudyPageState extends State<StudyPage> with SingleTickerProviderStateMixin {
  final StorageService _storage = StorageService();
  final Sm2Service _sm2 = Sm2Service();

  late TabController _tabController;

  List<KnowledgeMap> _maps = [];
  // All nodes across all maps
  List<_NodeWithMap> _allNodes = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadAll() {
    _maps = _storage.loadKnowledgeMaps();
    _allNodes = [];
    for (final map in _maps) {
      final graph = _storage.getKnowledgeGraphData(map.id);
      if (graph != null) {
        for (final node in graph.nodes) {
          _allNodes.add(_NodeWithMap(node: node, map: map));
        }
      }
    }
    setState(() {});
  }

  List<_NodeWithMap> get _dueNodes => _allNodes
      .where((n) => _sm2.isDue(n.node) || (n.node.nextReviewDate == null && n.node.lastReviewDate == null))
      .toList()
    ..sort((a, b) {
      // Overdue first, then unreviewed
      final aOverdue = a.node.nextReviewDate != null && _sm2.isDue(a.node);
      final bOverdue = b.node.nextReviewDate != null && _sm2.isDue(b.node);
      if (aOverdue && !bOverdue) return -1;
      if (!aOverdue && bOverdue) return 1;
      return a.node.label.compareTo(b.node.label);
    });

  List<_NodeWithMap> get _reviewedNodes =>
      _allNodes.where((n) => n.node.lastReviewDate != null).toList()
        ..sort((a, b) => (_sm2.memoryRetention(a.node)).compareTo(_sm2.memoryRetention(b.node)));

  // ── Stats ────────────────────────────────────────────────────────────────

  int get _totalReviewed => _allNodes.where((n) => n.node.lastReviewDate != null).length;
  int get _dueCount => _dueNodes.length;
  int get _strongCount => _allNodes.where((n) => _sm2.memoryStatus(n.node) == MemoryStatus.strong).length;
  int get _fadingCount => _allNodes.where((n) => _sm2.memoryStatus(n.node) == MemoryStatus.fading).length;
  int get _atRiskCount => _allNodes.where((n) => _sm2.memoryStatus(n.node) == MemoryStatus.atRisk).length;

  double get _avgRetention {
    final reviewed = _allNodes.where((n) => n.node.lastReviewDate != null).toList();
    if (reviewed.isEmpty) return 0;
    return reviewed.fold(0.0, (s, n) => s + _sm2.memoryRetention(n.node)) / reviewed.length;
  }

  // ── Save a reviewed node back to storage ──────────────────────────────────

  Future<void> _saveNode(_NodeWithMap nwm) async {
    final graph = _storage.getKnowledgeGraphData(nwm.map.id);
    if (graph == null) return;
    final idx = graph.nodes.indexWhere((n) => n.id == nwm.node.id);
    if (idx == -1) return;
    graph.nodes[idx] = nwm.node;
    await _storage.saveKnowledgeGraphData(graph);
  }

  // ── Review session ────────────────────────────────────────────────────────

  void _startReviewSession() {
    final due = _dueNodes;
    if (due.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ReviewSessionPage(
          nodes: due,
          sm2: _sm2,
          onSave: (updated) async {
            final idx = _allNodes.indexWhere((n) => n.node.id == updated.node.id);
            if (idx != -1) {
              _allNodes[idx] = updated;
              await _saveNode(updated);
            }
          },
        ),
      ),
    ).then((_) => _loadAll());
  }

  void _reviewSingleNode(_NodeWithMap nwm) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ReviewSheet(
        nwm: nwm,
        sm2: _sm2,
        onSave: (updated) async {
          final idx = _allNodes.indexWhere((n) => n.node.id == updated.node.id);
          if (idx != -1) {
            _allNodes[idx] = updated;
            await _saveNode(updated);
          }
          if (mounted) setState(() {});
        },
      ),
    ).then((_) => _loadAll());
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      appBar: AppBar(
        backgroundColor: const Color(0xFF020617),
        foregroundColor: Colors.white,
        title: const Text('Study'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF3B82F6),
          labelColor: Colors.white,
          unselectedLabelColor: const Color(0xFF64748B),
          tabs: [
            Tab(text: 'Due Now  ${_dueCount > 0 ? "($_dueCount)" : ""}'),
            const Tab(text: 'All Nodes'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildStatsHeader(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDueTab(),
                _buildAllTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Stats header ──────────────────────────────────────────────────────────

  Widget _buildStatsHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _statBox('${_dueCount}', 'Due', const Color(0xFF3B82F6)),
              _statBox('${_strongCount}', 'Strong', const Color(0xFF22C55E)),
              _statBox('${_fadingCount}', 'Fading', const Color(0xFFEAB308)),
              _statBox('${_atRiskCount}', 'At Risk', const Color(0xFFEF4444)),
            ],
          ),
          if (_totalReviewed > 0) ...[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Avg. retention: ${(_avgRetention * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                ),
                Text(
                  '$_totalReviewed / ${_allNodes.length} reviewed',
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Retention bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _avgRetention,
                minHeight: 6,
                backgroundColor: const Color(0xFF1E293B),
                valueColor: AlwaysStoppedAnimation(_retentionColor(_avgRetention)),
              ),
            ),
          ],
          if (_dueCount > 0) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _startReviewSession,
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text('Start Review Session ($_dueCount cards)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statBox(String value, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
        ],
      ),
    );
  }

  Color _retentionColor(double r) {
    if (r >= 0.75) return const Color(0xFF22C55E);
    if (r >= 0.40) return const Color(0xFFEAB308);
    return const Color(0xFFEF4444);
  }

  // ── Due tab ───────────────────────────────────────────────────────────────

  Widget _buildDueTab() {
    final due = _dueNodes;
    if (due.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline, size: 72, color: Color(0xFF22C55E)),
            const SizedBox(height: 16),
            const Text('All caught up!', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              _allNodes.isEmpty
                  ? 'Add nodes to your knowledge maps\nto start tracking your memory.'
                  : 'No reviews due right now.\nCome back later!',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: due.length,
      itemBuilder: (_, i) => _buildNodeCard(due[i]),
    );
  }

  // ── All nodes tab ─────────────────────────────────────────────────────────

  Widget _buildAllTab() {
    if (_allNodes.isEmpty) {
      return const Center(
        child: Text('No nodes yet. Create a knowledge map first.',
            style: TextStyle(color: Color(0xFF64748B))),
      );
    }
    // Group by map
    final byMap = <String, List<_NodeWithMap>>{};
    for (final n in _allNodes) {
        byMap.putIfAbsent(n.map.id, () => <_NodeWithMap>[]).add(n);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: _maps
          .where((m) => byMap.containsKey(m.id))
          .map((m) => _buildMapSection(m, byMap[m.id]!))
          .toList(),
    );
  }

  Widget _buildMapSection(KnowledgeMap map, List<_NodeWithMap> nodes) {
    final reviewed = nodes.where((n) => n.node.lastReviewDate != null).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Container(
                width: 10, height: 10,
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 8),
              Text(map.name,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(width: 8),
              Text('$reviewed/${nodes.length} reviewed',
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
            ],
          ),
        ),
        ...nodes.map((n) => _buildNodeCard(n)),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildNodeCard(_NodeWithMap nwm) {
    final node = nwm.node;
    final status = _sm2.memoryStatus(node);
    final isDue = _sm2.isDue(node);
    final isUnreviewed = node.lastReviewDate == null;
    final retention = _sm2.memoryRetention(node);
    final days = _sm2.daysUntilReview(node);

    return GestureDetector(
      onTap: () => _reviewSingleNode(nwm),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDue
                ? const Color(0xFFEF4444).withOpacity(0.6)
                : isUnreviewed
                    ? const Color(0xFF334155)
                    : status.color.withOpacity(0.3),
            width: isDue ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // Type icon circle
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: node.type.color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(node.type.icon, color: node.type.color, size: 18),
            ),
            const SizedBox(width: 12),
            // Label + map name
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(node.label,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(nwm.map.name,
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Status column
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (isUnreviewed)
                  _pill('New', const Color(0xFF3B82F6))
                else if (isDue)
                  _pill('DUE', const Color(0xFFEF4444))
                else
                  _pill('${(retention * 100).toStringAsFixed(0)}%', status.color),
                const SizedBox(height: 4),
                if (!isUnreviewed)
                  Text(
                    isDue
                        ? 'Overdue ${-days}d'
                        : days == 0
                            ? 'Due today'
                            : 'In ${days}d',
                    style: TextStyle(
                      color: isDue ? const Color(0xFFEF4444) : const Color(0xFF64748B),
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Color(0xFF334155), size: 18),
          ],
        ),
      ),
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

// ── Data wrapper ─────────────────────────────────────────────────────────────

class _NodeWithMap {
  KnowledgeNode node;
  final KnowledgeMap map;
  _NodeWithMap({required this.node, required this.map});
}

// ── Full-screen review session ───────────────────────────────────────────────

class _ReviewSessionPage extends StatefulWidget {
  final List<_NodeWithMap> nodes;
  final Sm2Service sm2;
  final Future<void> Function(_NodeWithMap) onSave;

  const _ReviewSessionPage({
    required this.nodes,
    required this.sm2,
    required this.onSave,
  });

  @override
  State<_ReviewSessionPage> createState() => _ReviewSessionPageState();
}

class _ReviewSessionPageState extends State<_ReviewSessionPage> {
  int _current = 0;
  bool _revealed = false;
  int _selectedQuality = -1;
  int _reviewed = 0;

  _NodeWithMap get _currentNode => widget.nodes[_current];

  Future<void> _submitReview() async {
    if (_selectedQuality < 0) return;
    final updated = widget.sm2.applyReview(_currentNode.node, _selectedQuality);
    _currentNode.node = updated;
    await widget.onSave(_currentNode);
    setState(() {
      _reviewed++;
      if (_current + 1 < widget.nodes.length) {
        _current++;
        _revealed = false;
        _selectedQuality = -1;
      } else {
        // Done
        _showDoneDialog();
      }
    });
  }

  void _showDoneDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        title: const Text('Session Complete! 🎉', style: TextStyle(color: Colors.white)),
        content: Text(
          'You reviewed $_reviewed card${_reviewed == 1 ? '' : 's'}.\nGreat work!',
          style: const TextStyle(color: Color(0xFF94A3B8)),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6)),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final node = _currentNode.node;
    final map = _currentNode.map;
    final status = widget.sm2.memoryStatus(node);
    final retention = widget.sm2.memoryRetention(node);

    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      appBar: AppBar(
        backgroundColor: const Color(0xFF020617),
        foregroundColor: Colors.white,
        title: Text('Review ${_current + 1} / ${widget.nodes.length}'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_current) / widget.nodes.length,
            backgroundColor: const Color(0xFF1E293B),
            valueColor: const AlwaysStoppedAnimation(Color(0xFF3B82F6)),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Map label
            Row(children: [
              const Icon(Icons.account_tree, size: 13, color: Color(0xFF64748B)),
              const SizedBox(width: 5),
              Text(map.name, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
            ]),
            const SizedBox(height: 16),

            // Concept card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: node.type.color.withOpacity(0.4), width: 1.5),
                boxShadow: [BoxShadow(color: node.type.color.withOpacity(0.1), blurRadius: 20)],
              ),
              child: Column(
                children: [
                  Icon(node.type.icon, color: node.type.color, size: 36),
                  const SizedBox(height: 12),
                  Text(node.label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  if (node.content != null && node.content!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Divider(color: Color(0xFF1E293B)),
                    const SizedBox(height: 8),
                    if (_revealed)
                      Text(node.content!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 15),
                      )
                    else
                      GestureDetector(
                        onTap: () => setState(() => _revealed = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text('Tap to reveal notes',
                            style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                        ),
                      ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Memory stats (if previously reviewed)
            if (node.lastReviewDate != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF1E293B)),
                ),
                child: Column(
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      _infoChip('Retention', '${(retention * 100).toStringAsFixed(0)}%', status.color),
                      _infoChip('Reviews', '${node.repetitions}', const Color(0xFF94A3B8)),
                      _infoChip('Interval', '${node.interval}d', const Color(0xFF94A3B8)),
                      _infoChip('EF', node.easeFactor.toStringAsFixed(1), const Color(0xFF94A3B8)),
                    ]),
                    const SizedBox(height: 10),
                    _ForgettingCurveWidget(node: node, sm2: widget.sm2),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Quality rating
            const Text('How well did you recall this?',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 4),
            const Text('0 = complete blackout  •  5 = perfect recall',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
            const SizedBox(height: 12),
            Row(
              children: List.generate(6, (q) {
                final qColors = [
                  const Color(0xFFEF4444), const Color(0xFFEF4444), const Color(0xFFF97316),
                  const Color(0xFFEAB308), const Color(0xFF84CC16), const Color(0xFF22C55E),
                ];
                final hints = ['✗', '~✗', '~✓', '✓!', '✓', '✓✓'];
                final col = qColors[q];
                final active = _selectedQuality == q;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedQuality = q),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      height: 66,
                      decoration: BoxDecoration(
                        color: active ? col.withOpacity(0.2) : const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: active ? col : const Color(0xFF334155), width: 2),
                      ),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text(hints[q], style: TextStyle(color: active ? col : const Color(0xFF64748B), fontSize: 14)),
                        const SizedBox(height: 2),
                        Text('$q', style: TextStyle(color: active ? col : const Color(0xFF475569), fontSize: 17, fontWeight: FontWeight.bold)),
                      ]),
                    ),
                  ),
                );
              }),
            ),
            if (_selectedQuality >= 0) ...[
              const SizedBox(height: 12),
              Center(child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                child: Text(
                  _qualityLabel(_selectedQuality),
                  key: ValueKey(_selectedQuality),
                  style: TextStyle(color: _qualityColor(_selectedQuality), fontSize: 13, fontWeight: FontWeight.w600),
                ),
              )),
              const SizedBox(height: 6),
              Center(child: Text(
                _previewNext(node, _selectedQuality),
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
              )),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedQuality < 0 ? null : _submitReview,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  disabledBackgroundColor: const Color(0xFF1E293B),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  _current + 1 < widget.nodes.length ? 'Next →' : 'Finish Session',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(String label, String value, Color color) {
    return Column(children: [
      Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
      Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 10)),
    ]);
  }

  String _qualityLabel(int q) {
    const labels = [
      'Complete blackout – resetting progress',
      'Incorrect, but remembered on seeing answer',
      'Incorrect, but felt easy',
      'Correct with serious difficulty',
      'Correct after hesitation',
      'Perfect recall!',
    ];
    return labels[q];
  }

  Color _qualityColor(int q) {
    const colors = [
      Color(0xFFEF4444), Color(0xFFEF4444), Color(0xFFF97316),
      Color(0xFFEAB308), Color(0xFF84CC16), Color(0xFF22C55E),
    ];
    return colors[q];
  }

  String _previewNext(KnowledgeNode node, int quality) {
    final preview = widget.sm2.applyReview(node, quality);
    return preview.interval <= 1 ? 'Next review: tomorrow' : 'Next review: in ${preview.interval} days';
  }
}

// ── Per-node review bottom sheet (used when tapping a card) ──────────────────

class _ReviewSheet extends StatefulWidget {
  final _NodeWithMap nwm;
  final Sm2Service sm2;
  final Future<void> Function(_NodeWithMap) onSave;

  const _ReviewSheet({required this.nwm, required this.sm2, required this.onSave});

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  int _selectedQuality = -1;

  @override
  Widget build(BuildContext context) {
    final node = widget.nwm.node;
    final status = widget.sm2.memoryStatus(node);
    final retention = widget.sm2.memoryRetention(node);
    final days = widget.sm2.daysUntilReview(node);

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: const Color(0xFF334155), borderRadius: BorderRadius.circular(2)),
          )),
          const SizedBox(height: 20),
          Row(children: [
            Icon(node.type.icon, color: node.type.color, size: 22),
            const SizedBox(width: 10),
            Expanded(child: Text(node.label,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: status.color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: status.color),
              ),
              child: Text(status.label, style: TextStyle(color: status.color, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: 16),

          if (node.lastReviewDate != null) ...[
            const Text('Memory Retention', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _ForgettingCurveWidget(node: node, sm2: widget.sm2),
            const SizedBox(height: 6),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Retention: ${(retention * 100).toStringAsFixed(0)}%',
                style: TextStyle(color: status.color, fontSize: 12, fontWeight: FontWeight.w600)),
              Text(
                days < 0 ? 'Overdue by ${-days}d' : days == 0 ? 'Due today' : 'Due in ${days}d',
                style: TextStyle(color: days <= 0 ? const Color(0xFFEF4444) : const Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ]),
            const SizedBox(height: 4),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Reviews: ${node.repetitions}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
              Text('Interval: ${node.interval}d', style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
              Text('EF: ${node.easeFactor.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
            ]),
            const SizedBox(height: 16),
            const Divider(color: Color(0xFF1E293B)),
            const SizedBox(height: 12),
          ],

          const Text('How well did you recall this?',
            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text('0 = complete blackout  •  5 = perfect recall',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
          const SizedBox(height: 12),
          Row(
            children: List.generate(6, (q) {
              final qColors = [
                const Color(0xFFEF4444), const Color(0xFFEF4444), const Color(0xFFF97316),
                const Color(0xFFEAB308), const Color(0xFF84CC16), const Color(0xFF22C55E),
              ];
              final hints = ['✗', '~✗', '~✓', '✓!', '✓', '✓✓'];
              final col = qColors[q];
              final active = _selectedQuality == q;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedQuality = q),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    height: 62,
                    decoration: BoxDecoration(
                      color: active ? col.withOpacity(0.2) : const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: active ? col : const Color(0xFF334155), width: 2),
                    ),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(hints[q], style: TextStyle(color: active ? col : const Color(0xFF64748B), fontSize: 13)),
                      Text('$q', style: TextStyle(color: active ? col : const Color(0xFF475569), fontSize: 16, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
              );
            }),
          ),
          if (_selectedQuality >= 0) ...[
            const SizedBox(height: 12),
            Center(child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: Text(_qualityLabel(_selectedQuality),
                key: ValueKey(_selectedQuality),
                style: TextStyle(color: _qualityColor(_selectedQuality), fontSize: 13, fontWeight: FontWeight.w600)),
            )),
            const SizedBox(height: 6),
            Center(child: Text(
              _previewNext(node, _selectedQuality),
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
            )),
            const SizedBox(height: 12),
          ],
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF334155)),
                foregroundColor: Colors.white70,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Cancel'),
            )),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(
              onPressed: _selectedQuality < 0 ? null : () async {
                final updated = widget.sm2.applyReview(widget.nwm.node, _selectedQuality);
                widget.nwm.node = updated;
                await widget.onSave(widget.nwm);
                if (mounted) Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                disabledBackgroundColor: const Color(0xFF1E293B),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Save Review', style: TextStyle(fontWeight: FontWeight.w600)),
            )),
          ]),
        ],
      ),
    );
  }

  String _qualityLabel(int q) {
    const labels = [
      'Complete blackout – resetting progress',
      'Incorrect, but remembered on seeing answer',
      'Incorrect, but felt easy',
      'Correct with serious difficulty',
      'Correct after hesitation',
      'Perfect recall!',
    ];
    return labels[q];
  }

  Color _qualityColor(int q) {
    const colors = [
      Color(0xFFEF4444), Color(0xFFEF4444), Color(0xFFF97316),
      Color(0xFFEAB308), Color(0xFF84CC16), Color(0xFF22C55E),
    ];
    return colors[q];
  }

  String _previewNext(KnowledgeNode node, int quality) {
    final preview = widget.sm2.applyReview(node, quality);
    return preview.interval <= 1 ? 'Next review: tomorrow' : 'Next review: in ${preview.interval} days';
  }
}

// ── Forgetting curve chart ────────────────────────────────────────────────────

class _ForgettingCurveWidget extends StatelessWidget {
  final KnowledgeNode node;
  final Sm2Service sm2;
  const _ForgettingCurveWidget({required this.node, required this.sm2});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: CustomPaint(
        painter: _ForgettingCurvePainter(node: node, sm2: sm2),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _ForgettingCurvePainter extends CustomPainter {
  final KnowledgeNode node;
  final Sm2Service sm2;
  const _ForgettingCurvePainter({required this.node, required this.sm2});

  @override
  void paint(Canvas canvas, Size size) {
    if (node.lastReviewDate == null) return;

    final totalDays = (node.interval * 1.5).clamp(7.0, 60.0);
    final daysSinceReview = DateTime.now().difference(node.lastReviewDate!).inHours / 24.0;
    final stability = max(0.1, node.interval * (node.easeFactor / 2.5));

    // Gradient fill
    final path = Path()..moveTo(0, size.height);
    for (int px = 0; px <= size.width.toInt(); px++) {
      final t = (px / size.width) * totalDays;
      final r = exp(-t / stability).clamp(0.0, 1.0);
      final y = size.height - r * (size.height - 8);
      px == 0 ? path.lineTo(0, y) : path.lineTo(px.toDouble(), y);
    }
    path..lineTo(size.width, size.height)..close();

    canvas.drawPath(path, Paint()
      ..shader = const LinearGradient(colors: [
        Color(0x4D22C55E), Color(0x33EAB308), Color(0x1AEF4444),
      ]).createShader(Rect.fromLTWH(0, 0, size.width, size.height)));

    // Curve line
    final currentR = sm2.memoryRetention(node);
    final lineColor = currentR >= 0.75
        ? const Color(0xFF22C55E)
        : currentR >= 0.40
            ? const Color(0xFFEAB308)
            : const Color(0xFFEF4444);

    final linePath = Path();
    bool first = true;
    for (int px = 0; px <= size.width.toInt(); px++) {
      final t = (px / size.width) * totalDays;
      final r = exp(-t / stability).clamp(0.0, 1.0);
      final y = size.height - r * (size.height - 8);
      first ? linePath.moveTo(px.toDouble(), y) : linePath.lineTo(px.toDouble(), y);
      first = false;
    }
    canvas.drawPath(linePath, Paint()
      ..color = lineColor..style = PaintingStyle.stroke..strokeWidth = 2..strokeCap = StrokeCap.round);

    // "Now" line
    final nowX = (daysSinceReview / totalDays * size.width).clamp(0.0, size.width);
    canvas.drawLine(Offset(nowX, 0), Offset(nowX, size.height),
      Paint()..color = Colors.white.withOpacity(0.35)..strokeWidth = 1.5);

    // Next review line
    if (node.nextReviewDate != null) {
      final daysToNext = node.nextReviewDate!.difference(node.lastReviewDate!).inHours / 24.0;
      final nextX = (daysToNext / totalDays * size.width).clamp(0.0, size.width);
      canvas.drawLine(Offset(nextX, 0), Offset(nextX, size.height),
        Paint()..color = const Color(0xFF3B82F6).withOpacity(0.6)..strokeWidth = 1.5);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}

