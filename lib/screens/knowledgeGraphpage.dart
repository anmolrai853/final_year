// lib/knowledge_graph_page.dart
import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../services/stats_service.dart';
import '../services/storage_service.dart';


final _storage = StorageService();
final _statsService = StatsService();

// ── Models ───────────────────────────────────────────────────────────────────

class GraphNode {
  String id, label;
  Offset position;
  Color color;
  String? note, cluster;
  int confidenceLevel;
  DateTime? lastReviewed, nextReviewDue;

  GraphNode({
    required this.id, required this.label,
    required this.position, required this.color,
    this.note, this.cluster,
    this.confidenceLevel = 0,
    this.lastReviewed, this.nextReviewDue,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'label': label,
    'x': position.dx, 'y': position.dy,
    'color': color.value, 'note': note,
    'confidenceLevel': confidenceLevel,
    'lastReviewed':  lastReviewed?.toIso8601String(),
    'nextReviewDue': nextReviewDue?.toIso8601String(),
    'cluster': cluster,
  };

  factory GraphNode.fromJson(Map<String, dynamic> j) => GraphNode(
    id: j['id'], label: j['label'],
    position: Offset(j['x'], j['y']),
    color: Color(j['color']), note: j['note'],
    confidenceLevel: j['confidenceLevel'] ?? 0,
    lastReviewed:  j['lastReviewed']  != null ? DateTime.parse(j['lastReviewed'])  : null,
    nextReviewDue: j['nextReviewDue'] != null ? DateTime.parse(j['nextReviewDue']) : null,
    cluster: j['cluster'],
  );
}

class GraphEdge {
  String id, fromId, toId;
  String? label;
  GraphEdge({required this.id, required this.fromId, required this.toId, this.label});

  Map<String, dynamic> toJson() =>
      {'id': id, 'fromId': fromId, 'toId': toId, 'label': label};

  factory GraphEdge.fromJson(Map<String, dynamic> j) =>
      GraphEdge(id: j['id'], fromId: j['fromId'], toId: j['toId'], label: j['label']);
}

// ── Page ─────────────────────────────────────────────────────────────────────

class KnowledgeGraphPage extends StatefulWidget {
  final String moduleTitle;
  final Color  moduleColor;
  const KnowledgeGraphPage(
      {super.key, required this.moduleTitle, required this.moduleColor});

  @override
  State<KnowledgeGraphPage> createState() => _KnowledgeGraphPageState();
}

class _KnowledgeGraphPageState extends State<KnowledgeGraphPage> {
  List<GraphNode> nodes = [];
  List<GraphEdge> edges = [];

  String? selectedNodeId, connectingFromNodeId;
  String _searchQuery = '';
  bool _flashcardMode = false;
  int  _flashcardIndex = 0;
  bool _flashcardRevealed = false;

  int _nodeCounter = 0, _edgeCounter = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ── Persistence ──────────────────────────────────────────────
  Future<void> _load() async {
    final data = await _storage.loadKnowledgeGraph(widget.moduleTitle);
    if (data != null) {
      setState(() {
        nodes = (data['nodes'] as List).map((n) => GraphNode.fromJson(n)).toList();
        edges = (data['edges'] as List).map((e) => GraphEdge.fromJson(e)).toList();
        _nodeCounter = nodes.length;
        _edgeCounter = edges.length;
      });
    } else {
      _loadDemo();
    }
  }

  Future<void> _save() async {
    await _storage.saveKnowledgeGraph(widget.moduleTitle, {
      'nodes': nodes.map((n) => n.toJson()).toList(),
      'edges': edges.map((e) => e.toJson()).toList(),
    });
  }

  void _loadDemo() {
    nodes = [
      GraphNode(id: 'n0', label: 'Core Concept', position: const Offset(150, 120),
          color: widget.moduleColor, note: 'The main idea'),
      GraphNode(id: 'n1', label: 'Sub Topic A',  position: const Offset(80, 260),
          color: widget.moduleColor),
      GraphNode(id: 'n2', label: 'Sub Topic B',  position: const Offset(220, 260),
          color: widget.moduleColor),
    ];
    edges = [
      GraphEdge(id: 'e0', fromId: 'n0', toId: 'n1', label: 'leads to'),
      GraphEdge(id: 'e1', fromId: 'n0', toId: 'n2', label: 'leads to'),
    ];
    _nodeCounter = 3; _edgeCounter = 2;
  }

  // ── Node helpers ─────────────────────────────────────────────
  String _nid() => 'n${_nodeCounter++}';
  String _eid() => 'e${_edgeCounter++}';

  GraphNode? _nodeAt(Offset pos) {
    for (final n in nodes.reversed) {
      if ((n.position - pos).distance <= 30) return n;
    }
    return null;
  }

  void _addNode(Offset pos) {
    final n = GraphNode(
        id: _nid(), label: 'New Concept',
        position: pos, color: widget.moduleColor);
    setState(() { nodes.add(n); selectedNodeId = n.id; });
    _save();
    _showEditDialog(n);
  }

  void _deleteNode(String id) {
    setState(() {
      nodes.removeWhere((n) => n.id == id);
      edges.removeWhere((e) => e.fromId == id || e.toId == id);
      if (selectedNodeId == id) selectedNodeId = null;
      if (connectingFromNodeId == id) connectingFromNodeId = null;
    });
    _save();
  }

  void _addEdge(String fromId, String toId) {
    if (edges.any((e) => e.fromId == fromId && e.toId == toId)) return;
    setState(() {
      edges.add(GraphEdge(id: _eid(), fromId: fromId, toId: toId));
      connectingFromNodeId = null;
    });
    _save();
  }

  GraphEdge? _edgeAt(Offset pos) {
    for (final e in edges) {
      final from = nodes.firstWhereOrNull((n) => n.id == e.fromId);
      final to   = nodes.firstWhereOrNull((n) => n.id == e.toId);
      if (from == null || to == null) continue;
      if (_distToLine(pos, from.position, to.position) <= 10) return e;
    }
    return null;
  }

  double _distToLine(Offset p, Offset a, Offset b) {
    final l2 = (b - a).distanceSquared;
    if (l2 == 0) return (p - a).distance;
    final t = ((p - a).dx * (b - a).dx + (p - a).dy * (b - a).dy) / l2;
    final proj = a + (b - a) * t.clamp(0.0, 1.0);
    return (p - proj).distance;
  }

  // ── Confidence helper ─────────────────────────────────────────
  Color _confidenceColor(int level) {
    switch (level) {
      case 0: return Colors.white24;
      case 1:
      case 2: return Colors.redAccent;
      case 3: return Colors.orangeAccent;
      case 4:
      case 5: return Colors.greenAccent;
      default: return Colors.white24;
    }
  }

  // ── Auto-layout (force directed) ─────────────────────────────
  void _autoLayout() {
    for (int iter = 0; iter < 150; iter++) {
      for (final n in nodes) {
        var f = Offset.zero;
        for (final o in nodes) {
          if (o.id == n.id) continue;
          final d = n.position - o.position;
          final dist = d.distance.clamp(1.0, double.infinity);
          f += d / (dist * dist) * 6000;
        }
        for (final e in edges) {
          if (e.fromId != n.id && e.toId != n.id) continue;
          final other = nodes.firstWhereOrNull(
                  (x) => x.id == (e.fromId == n.id ? e.toId : e.fromId));
          if (other == null) continue;
          f += (other.position - n.position) * 0.01;
        }
        n.position += f * 0.08;
      }
    }
    setState(() {});
    _save();
  }

  // ── Spaced repetition update on node ─────────────────────────
  void _markReviewed(GraphNode n, int confidence) {
    setState(() {
      n.confidenceLevel = confidence;
      n.lastReviewed    = DateTime.now();
      n.nextReviewDue   = _statsService.nextReviewDate(confidence, DateTime.now());
    });
    _save();
  }

  // ── Edit dialog ──────────────────────────────────────────────
  void _showEditDialog(GraphNode node) {
    final labelCtrl = TextEditingController(text: node.label);
    final noteCtrl  = TextEditingController(text: node.note ?? '');
    int confidence  = node.confidenceLevel;
    String? cluster = node.cluster;

    final clusters = nodes
        .map((n) => n.cluster)
        .where((c) => c != null && c.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(builder: (context, set) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit Concept', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _field(labelCtrl, 'Concept name'),
            const SizedBox(height: 12),
            _field(noteCtrl, 'Note (optional)', maxLines: 3),
            const SizedBox(height: 16),
            // Confidence rating
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Confidence', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ),
            const SizedBox(height: 6),
            Row(mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) => GestureDetector(
                onTap: () => set(() => confidence = i + 1),
                child: Icon(
                  i < confidence ? Icons.star : Icons.star_border,
                  color: Colors.amber, size: 30,
                ),
              )),
            ),
            const SizedBox(height: 16),
            // Cluster input
            Row(children: [
              Expanded(child: _field(
                TextEditingController(text: cluster),
                'Cluster (optional)',
                onChanged: (v) => cluster = v.trim().isEmpty ? null : v.trim(),
              )),
              if (clusters.isNotEmpty) ...[
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.white54),
                  color: const Color(0xFF0F172A),
                  onSelected: (v) => set(() => cluster = v),
                  itemBuilder: (_) => clusters
                      .map((c) => PopupMenuItem(
                    value: c,
                    child: Text(c, style: const TextStyle(color: Colors.white)),
                  ))
                      .toList(),
                ),
              ],
            ]),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () { _deleteNode(node.id); Navigator.pop(context); },
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white70))),
          TextButton(
            onPressed: () {
              setState(() {
                node.label = labelCtrl.text.trim().isEmpty
                    ? 'Untitled' : labelCtrl.text.trim();
                node.note  = noteCtrl.text.trim().isEmpty
                    ? null : noteCtrl.text.trim();
                node.cluster = cluster;
                if (confidence != node.confidenceLevel) {
                  _markReviewed(node, confidence);
                }
              });
              _save();
              Navigator.pop(context);
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      )),
    );
  }

  TextField _field(TextEditingController ctrl, String label,
      {int maxLines = 1, ValueChanged<String>? onChanged}) =>
      TextField(
        controller: ctrl,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white),
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white30)),
          focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white)),
        ),
      );

  // ── Flashcard mode ───────────────────────────────────────────
  Widget _flashcard() {
    if (nodes.isEmpty) {
      return const Center(child: Text('No nodes yet.',
          style: TextStyle(color: Colors.white54)));
    }
    final node = nodes[_flashcardIndex % nodes.length];

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${_flashcardIndex + 1} / ${nodes.length}',
              style: const TextStyle(color: Colors.white54)),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () => setState(() => _flashcardRevealed = !_flashcardRevealed),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _flashcardRevealed
                    ? widget.moduleColor.withOpacity(0.2)
                    : const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: widget.moduleColor.withOpacity(0.5)),
              ),
              child: Column(children: [
                Text(node.label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22,
                        fontWeight: FontWeight.w700, color: Colors.white)),
                if (_flashcardRevealed) ...[
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white24),
                  const SizedBox(height: 12),
                  Text(
                    node.note?.isNotEmpty == true
                        ? node.note!
                        : 'No note added.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                ] else ...[
                  const SizedBox(height: 12),
                  const Text('Tap to reveal',
                      style: TextStyle(color: Colors.white38, fontSize: 13)),
                ],
              ]),
            ),
          ),
          if (_flashcardRevealed) ...[
            const SizedBox(height: 20),
            const Text('How well did you know this?',
                style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _fcBtn('Missed it', Colors.redAccent, () {
                _markReviewed(node, 1);
                setState(() {
                  _flashcardRevealed = false;
                  _flashcardIndex = (_flashcardIndex + 1) % nodes.length;
                });
              }),
              _fcBtn('Got it', Colors.greenAccent, () {
                final newConf = (node.confidenceLevel + 1).clamp(1, 5);
                _markReviewed(node, newConf);
                setState(() {
                  _flashcardRevealed = false;
                  _flashcardIndex = (_flashcardIndex + 1) % nodes.length;
                });
              }),
            ]),
          ],
          const SizedBox(height: 16),
          // Star confidence display
          Row(mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) => Icon(
              i < node.confidenceLevel ? Icons.star : Icons.star_border,
              color: Colors.amber, size: 20,
            )),
          ),
        ]),
      ),
    );
  }

  ElevatedButton _fcBtn(String label, Color color, VoidCallback onTap) =>
      ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withOpacity(0.2),
          foregroundColor: color,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: onTap,
        child: Text(label),
      );

  // ── Build ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final dueCount = _statsService.nodesDueForReview(nodes).length;
    final avgConf  = _statsService.avgConfidence(nodes);

    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      appBar: AppBar(
        backgroundColor: const Color(0xFF020617),
        elevation: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.moduleTitle),
          if (nodes.isNotEmpty)
            Text(
              '${(avgConf / 5 * 100).toStringAsFixed(0)}% confident'
                  '${dueCount > 0 ? ' • $dueCount due' : ''}',
              style: const TextStyle(fontSize: 12, color: Colors.white54),
            ),
        ]),
        actions: [
          // Search
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => showDialog(
              context: context,
              builder: (_) {
                final c = TextEditingController(text: _searchQuery);
                return AlertDialog(
                  backgroundColor: const Color(0xFF0F172A),
                  title: const Text('Search nodes', style: TextStyle(color: Colors.white)),
                  content: TextField(
                    controller: c,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Type to filter...',
                      hintStyle: TextStyle(color: Colors.white38),
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        setState(() => _searchQuery = '');
                        Navigator.pop(context);
                      },
                      child: const Text('Clear', style: TextStyle(color: Colors.white54)),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Done', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                );
              },
            ),
          ),
          // Auto-layout
          IconButton(
            icon: const Icon(Icons.auto_fix_high),
            tooltip: 'Auto-layout',
            onPressed: _autoLayout,
          ),
          // Flashcard toggle
          IconButton(
            icon: Icon(_flashcardMode ? Icons.account_tree : Icons.style),
            tooltip: _flashcardMode ? 'Graph view' : 'Flashcard mode',
            onPressed: () => setState(() {
              _flashcardMode = !_flashcardMode;
              _flashcardIndex = 0;
              _flashcardRevealed = false;
            }),
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showHelp,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(_searchQuery.isNotEmpty ? 30 : 0),
          child: _searchQuery.isNotEmpty
              ? Container(
            color: widget.moduleColor.withOpacity(0.1),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(children: [
              const Icon(Icons.filter_alt, size: 14, color: Colors.white54),
              const SizedBox(width: 6),
              Text('Filtering: "$_searchQuery"',
                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _searchQuery = ''),
                child: const Icon(Icons.close, size: 14, color: Colors.white54),
              ),
            ]),
          )
              : const SizedBox.shrink(),
        ),
      ),
      body: Column(children: [
        // Connecting mode banner
        if (connectingFromNodeId != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            color: widget.moduleColor.withOpacity(0.15),
            child: const Text('Tap another node to connect',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),

        Expanded(child: _flashcardMode
            ? _flashcard()
            : _graphView()),
      ]),
    );
  }

  // ── Graph view ───────────────────────────────────────────────
  Widget _graphView() {
    return InteractiveViewer(
      boundaryMargin: const EdgeInsets.all(300),
      minScale: 0.3,
      maxScale: 3.0,
      child: GestureDetector(
        onTapUp: (d) {
          final pos = d.localPosition;
          final tapped = _nodeAt(pos);

          if (tapped != null) {
            if (connectingFromNodeId != null) {
              if (tapped.id != connectingFromNodeId) {
                _addEdge(connectingFromNodeId!, tapped.id);
              } else {
                setState(() => connectingFromNodeId = null);
              }
            } else {
              setState(() => selectedNodeId = tapped.id);
              _showEditDialog(tapped);
            }
          } else {
            final edge = _edgeAt(pos);
            if (edge != null) {
              _showDeleteEdgeDialog(edge);
            } else {
              _addNode(pos);
            }
          }
        },
        onLongPressStart: (d) {
          final n = _nodeAt(d.localPosition);
          if (n != null) setState(() {
            connectingFromNodeId = n.id;
            selectedNodeId = n.id;
          });
        },
        child: CustomPaint(
          painter: GraphPainter(
            nodes: nodes, edges: edges,
            selectedNodeId: selectedNodeId,
            connectingFromNodeId: connectingFromNodeId,
          ),
          child: Stack(
            children: nodes.map((node) {
              final dimmed = _searchQuery.isNotEmpty &&
                  !node.label.toLowerCase().contains(_searchQuery);
              return Positioned(
                left: node.position.dx - 30,
                top:  node.position.dy - 30,
                child: Opacity(
                  opacity: dimmed ? 0.15 : 1.0,
                  child: Draggable(
                    feedback: _nodeWidget(node, isDragging: true),
                    childWhenDragging: const SizedBox.shrink(),
                    onDragEnd: (details) {
                      // Convert global → local using RenderBox
                      final box = context.findRenderObject() as RenderBox?;
                      if (box != null) {
                        setState(() =>
                        node.position = box.globalToLocal(details.offset)
                            + const Offset(30, 30));
                        _save();
                      }
                    },
                    child: _nodeWidget(node),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _nodeWidget(GraphNode node, {bool isDragging = false}) {
    final isSelected   = node.id == selectedNodeId;
    final isConnecting = node.id == connectingFromNodeId;
    final confColor    = _confidenceColor(node.confidenceLevel);

    return Container(
      width: 60, height: 60,
      decoration: BoxDecoration(
        color: node.color.withOpacity(isDragging ? 0.8 : 1.0),
        shape: BoxShape.circle,
        border: Border.all(
          color: isConnecting ? Colors.yellowAccent
              : isSelected    ? Colors.white
              : confColor,
          width: isConnecting ? 3 : 2,
        ),
        boxShadow: isDragging
            ? [BoxShadow(color: Colors.black38, blurRadius: 10, offset: const Offset(0, 4))]
            : [],
      ),
      child: Center(
        child: Text(node.label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  void _showDeleteEdgeDialog(GraphEdge edge) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete connection?', style: TextStyle(color: Colors.white)),
        content: const Text('This removes the connection between the two concepts.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white70))),
          TextButton(
            onPressed: () {
              setState(() => edges.removeWhere((e) => e.id == edge.id));
              _save(); Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  void _showHelp() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('How to use', style: TextStyle(color: Colors.white)),
        content: const Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HelpRow('Tap empty space', 'Add a node'),
            _HelpRow('Tap a node', 'Edit label, note & confidence'),
            _HelpRow('Long press → tap another', 'Connect two nodes'),
            _HelpRow('Drag a node', 'Reposition it'),
            _HelpRow('Tap a line', 'Delete the connection'),
            _HelpRow('🔍 Search', 'Filter nodes by name'),
            _HelpRow('⚡ Auto-layout', 'Spread nodes automatically'),
            _HelpRow('🃏 Flashcards', 'Quiz yourself on all nodes'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Got it', style: TextStyle(color: Colors.white))),
        ],
      ),
    );
  }
}

// ── Graph painter ─────────────────────────────────────────────────────────────

class GraphPainter extends CustomPainter {
  final List<GraphNode> nodes;
  final List<GraphEdge> edges;
  final String? selectedNodeId, connectingFromNodeId;

  GraphPainter({
    required this.nodes, required this.edges,
    this.selectedNodeId, this.connectingFromNodeId,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..strokeWidth = 2..style = PaintingStyle.stroke;

    // Draw cluster backgrounds first
    final clusters = nodes
        .where((n) => n.cluster != null && n.cluster!.isNotEmpty)
        .fold<Map<String, List<GraphNode>>>({}, (map, n) {
      map.putIfAbsent(n.cluster!, () => []).add(n); return map;
    });

    for (final entry in clusters.entries) {
      if (entry.value.length < 2) continue;
      final xs = entry.value.map((n) => n.position.dx);
      final ys = entry.value.map((n) => n.position.dy);
      final rect = Rect.fromLTRB(
        xs.reduce(math.min) - 40, ys.reduce(math.min) - 40,
        xs.reduce(math.max) + 40, ys.reduce(math.max) + 40,
      );
      final clusterPaint = Paint()
        ..color = Colors.white.withOpacity(0.04)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(16)), clusterPaint);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(16)),
        Paint()..color = Colors.white12..style = PaintingStyle.stroke..strokeWidth = 1,
      );

      final tp = TextPainter(
        text: TextSpan(text: entry.key,
            style: const TextStyle(color: Colors.white24, fontSize: 11)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(rect.left + 8, rect.top + 6));
    }

    // Draw edges
    for (final edge in edges) {
      final from = nodes.firstWhereOrNull((n) => n.id == edge.fromId);
      final to   = nodes.firstWhereOrNull((n) => n.id == edge.toId);
      if (from == null || to == null) continue;

      paint.color = Colors.white38;
      _arrow(canvas, from.position, to.position, paint);

      if (edge.label != null && edge.label!.isNotEmpty) {
        final mid = (from.position + to.position) / 2;
        final tp = TextPainter(
          text: TextSpan(text: edge.label,
              style: const TextStyle(color: Colors.white54, fontSize: 10,
                  backgroundColor: Color(0xFF020617))),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, mid - Offset(tp.width / 2, tp.height / 2));
      }
    }
  }

  void _arrow(Canvas canvas, Offset from, Offset to, Paint paint) {
    canvas.drawLine(from, to, paint);
    const size = 10.0;
    final angle = math.atan2(to.dy - from.dy, to.dx - from.dx);
    final path = Path()
      ..moveTo(to.dx, to.dy)
      ..lineTo(to.dx - size * math.cos(angle - math.pi / 6),
          to.dy - size * math.sin(angle - math.pi / 6))
      ..lineTo(to.dx - size * math.cos(angle + math.pi / 6),
          to.dy - size * math.sin(angle + math.pi / 6))
      ..close();
    canvas.drawPath(path, paint..style = PaintingStyle.fill);
    paint.style = PaintingStyle.stroke;
  }

  @override
  bool shouldRepaint(GraphPainter old) => true;
}

// ── Small help row widget ─────────────────────────────────────────────────────

class _HelpRow extends StatelessWidget {
  final String action, description;
  const _HelpRow(this.action, this.description);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('$action  ', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
      Expanded(child: Text(description, style: const TextStyle(color: Colors.white70, fontSize: 13))),
    ]),
  );
}

// ── Extension ─────────────────────────────────────────────────────────────────

extension IterableX<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final e in this) { if (test(e)) return e; }
    return null;
  }
}
