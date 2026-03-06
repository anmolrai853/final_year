// lib/pages/knowledge_graph_page.dart
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/knowledge_node.dart';
import '../services/sm2_service.dart';
import '../services/storage_service.dart';

class KnowledgeGraphPage extends StatefulWidget {
  final String mapId; // Changed from moduleCode to mapId

  const KnowledgeGraphPage({
    super.key,
    required this.mapId,
  });

  @override
  State<KnowledgeGraphPage> createState() => _KnowledgeGraphPageState();
}

class _KnowledgeGraphPageState extends State<KnowledgeGraphPage> {
  final StorageService _storage = StorageService();
  final Sm2Service _sm2 = Sm2Service();

  KnowledgeMap? _map;
  KnowledgeGraphData? _graph;
  String? _selectedNodeId;
  String? _connectingNodeId;
  Offset? _dragStartPosition;
  Offset? _dragCurrentPosition;

  final TransformationController _transformationController = TransformationController();
  final TextEditingController _searchController = TextEditingController();
  List<KnowledgeNode> _filteredNodes = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _map = _storage.loadKnowledgeMaps().firstWhere(
          (m) => m.id == widget.mapId,
      orElse: () => KnowledgeMap(name: 'Unknown'),
    );
    _graph = _storage.getKnowledgeGraphData(widget.mapId) ??
        KnowledgeGraphData(mapId: widget.mapId, nodes: [], edges: []);
    _filteredNodes = _graph?.nodes ?? [];
    setState(() {});
  }

  Future<void> _saveGraph() async {
    if (_graph != null) {
      await _storage.saveKnowledgeGraphData(_graph!);
    }
  }

  void _searchNodes(String query) {
    if (query.isEmpty) {
      _filteredNodes = _graph?.nodes ?? [];
    } else {
      _filteredNodes = (_graph?.nodes ?? []).where((n) =>
      n.label.toLowerCase().contains(query.toLowerCase()) ||
          n.tags.any((t) => t.toLowerCase().contains(query.toLowerCase()))
      ).toList();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_map == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_map!.name),
            if (_graph != null)
              Text(
                '${_graph!.nodes.length} nodes • ${_graph!.edges.length} connections',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
          ],
        ),
        backgroundColor: const Color(0xFF020617),
        foregroundColor: Colors.white,
        actions: [
          // Search button
          IconButton(
            onPressed: () => _showSearchDialog(),
            icon: const Icon(Icons.search),
          ),
          // Add node
          IconButton(
            onPressed: () => _showAddNodeDialog(),
            icon: const Icon(Icons.add),
          ),
          if (_selectedNodeId != null) ...[
            IconButton(
              onPressed: () => _showEditNodeDialog(),
              icon: const Icon(Icons.edit),
            ),
            IconButton(
              onPressed: () => _deleteSelectedNode(),
              icon: const Icon(Icons.delete),
            ),
          ],
        ],
      ),
      body: Stack(
        children: [
          // Graph canvas
          InteractiveViewer(
            transformationController: _transformationController,
            boundaryMargin: const EdgeInsets.all(1000),
            minScale: 0.1,
            maxScale: 3.0,
            panEnabled: _connectingNodeId == null,
            child: GestureDetector(
              onTapUp: _onCanvasTap,
              onPanUpdate: _connectingNodeId != null ? _onPanUpdate : null,
              onPanEnd: _connectingNodeId != null ? _onPanEnd : null,
              child: Container(
                width: 3000,
                height: 3000,
                color: Colors.transparent,
                child: Stack(
                  children: [
                    CustomPaint(
                      size: const Size(3000, 3000),
                      painter: EdgePainter(
                        nodes: _graph?.nodes ?? [],
                        edges: _graph?.edges ?? [],
                        selectedNodeId: _selectedNodeId,
                        connectingNodeId: _connectingNodeId,
                        dragStartPosition: _dragStartPosition,
                        dragCurrentPosition: _dragCurrentPosition,
                      ),
                    ),
                    ...(_graph?.nodes ?? []).map((node) => _buildNodeWidget(node)),
                  ],
                ),
              ),
            ),
          ),

          // Instructions overlay
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'How to use:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildInstruction('Tap empty space', 'Add new node'),
                  _buildInstruction('Tap node', 'Select'),
                  _buildInstruction('Long-press node → tap another', 'Connect'),
                  _buildInstruction('Drag node', 'Move'),
                  _buildInstruction('Pinch/scroll', 'Zoom & pan'),
                  _buildInstruction('🧠 Study tab', 'Review & track memory'),
                ],
              ),
            ),
          ),

          // Connection mode indicator
          if (_connectingNodeId != null)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.link, color: Colors.white),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Connection mode: Tap another node to connect',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() {
                        _connectingNodeId = null;
                        _dragStartPosition = null;
                        _dragCurrentPosition = null;
                      }),
                      icon: const Icon(Icons.close, color: Colors.white),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInstruction(String action, String result) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFF3B82F6),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            action,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.arrow_forward, size: 12, color: Color(0xFF64748B)),
          const SizedBox(width: 4),
          Text(
            result,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildNodeWidget(KnowledgeNode node) {
    final isSelected = _selectedNodeId == node.id;
    final isConnectingSource = _connectingNodeId == node.id;
    final isHighlighted = _filteredNodes.contains(node) || _searchController.text.isEmpty;
    final memStatus = _sm2.memoryStatus(node);
    final memColor = memStatus.color;
    final hasReview = node.lastReviewDate != null;
    final isDue = _sm2.isDue(node);

    // Border colour priority: selected > connecting > memory heatmap > type colour
    final borderColor = isSelected
        ? Colors.white
        : isConnectingSource
            ? const Color(0xFFF59E0B)
            : hasReview
                ? memColor
                : node.type.color;

    return Positioned(
      left: node.position.dx - node.type.size / 2,
      top: node.position.dy - node.type.size / 2,
      child: GestureDetector(
        onTap: () => _onNodeTap(node),
        onLongPress: () => _onNodeLongPress(node),
        onPanUpdate: (details) {
          if (_connectingNodeId != null) return;
          setState(() {
            final nodeIndex = _graph!.nodes.indexWhere((n) => n.id == node.id);
            if (nodeIndex != -1) {
              final scale = _transformationController.value.getMaxScaleOnAxis();
              final delta = details.delta / scale;
              final currentPos = _graph!.nodes[nodeIndex].position;
              _graph!.nodes[nodeIndex] = _graph!.nodes[nodeIndex].copyWith(
                position: currentPos + delta,
              );
            }
          });
        },
        onPanEnd: (_) => _saveGraph(),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // ── Outer heatmap glow ring ──────────────────────────────────
            if (hasReview)
              Positioned.fill(
                child: CustomPaint(
                  painter: _RetentionRingPainter(
                    retention: _sm2.memoryRetention(node),
                    color: memColor,
                    isSelected: isSelected,
                  ),
                ),
              ),

            // ── Node circle ──────────────────────────────────────────────
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: node.type.size,
              height: node.type.size,
              decoration: BoxDecoration(
                color: isHighlighted
                    ? node.type.color.withOpacity(isSelected ? 0.9 : 0.8)
                    : Colors.grey.withOpacity(0.3),
                shape: BoxShape.circle,
                border: Border.all(
                  color: borderColor,
                  width: isSelected ? 4 : (isConnectingSource || hasReview) ? 3 : 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: hasReview
                        ? memColor.withOpacity(isSelected ? 0.6 : 0.35)
                        : node.type.color.withOpacity(isSelected ? 0.4 : 0.2),
                    blurRadius: isSelected ? 22 : 12,
                    spreadRadius: isSelected ? 4 : 2,
                  ),
                ],
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(node.type.icon, size: node.type.size < 50 ? 16 : 20, color: Colors.white),
                    Padding(
                      padding: const EdgeInsets.all(4),
                      child: Text(
                        node.label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: node.type.size < 50 ? 9 : 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Memory status badge (top-right) ──────────────────────────
            if (hasReview)
              Positioned(
                top: -6,
                right: -6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: memColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF020617), width: 1.5),
                    boxShadow: [BoxShadow(color: memColor.withOpacity(0.5), blurRadius: 6)],
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(
                      isDue ? Icons.alarm : Icons.memory,
                      size: 9, color: Colors.white,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      isDue ? 'DUE' : '${(_sm2.memoryRetention(node) * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ]),
                ),
              ),
          ],

        ),
      ),
    );
  }

  void _onCanvasTap(TapUpDetails details) {
    final tapPosition = details.localPosition;
    final tappedNode = _graph?.nodes.firstWhere(
          (node) => (node.position - tapPosition).distance < node.type.size / 2,
      orElse: () => KnowledgeNode(
        label: '',
        type: NodeType.concept,
        position: Offset.zero,
        mapId: widget.mapId,
      ),
    );

    if (tappedNode?.label.isEmpty ?? true) {
      if (_connectingNodeId != null) {
        setState(() {
          _connectingNodeId = null;
          _dragStartPosition = null;
          _dragCurrentPosition = null;
        });
      } else {
        _showAddNodeDialog(initialPosition: tapPosition);
      }
    }
  }

  void _onNodeTap(KnowledgeNode node) {
    if (_connectingNodeId != null) {
      if (_connectingNodeId != node.id) {
        _createConnection(_connectingNodeId!, node.id);
      }
      setState(() {
        _connectingNodeId = null;
        _dragStartPosition = null;
        _dragCurrentPosition = null;
      });
    } else {
      setState(() {
        _selectedNodeId = _selectedNodeId == node.id ? null : node.id;
      });
    }
  }

  void _onNodeLongPress(KnowledgeNode node) {
    setState(() {
      _connectingNodeId = node.id;
      _dragStartPosition = node.position;
      _dragCurrentPosition = node.position;
      _selectedNodeId = null;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_connectingNodeId != null) {
      setState(() {
        _dragCurrentPosition = (_dragCurrentPosition ?? _dragStartPosition)! + details.delta;
      });
    }
  }

  void _onPanEnd(DragEndDetails details) {}

  Future<void> _createConnection(String sourceId, String targetId) async {
    final edge = KnowledgeEdge(
      sourceId: sourceId,
      targetId: targetId,
    );

    final currentEdges = List<KnowledgeEdge>.from(_graph?.edges ?? []);
    currentEdges.add(edge);

    _graph = _graph?.copyWith(edges: currentEdges);
    await _saveGraph();

    setState(() {});

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connected!'),
          backgroundColor: Color(0xFF10B981),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _deleteSelectedNode() async {
    if (_selectedNodeId == null) return;

    final node = _graph!.nodes.firstWhere((n) => n.id == _selectedNodeId);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        title: const Text('Delete Node', style: TextStyle(color: Colors.white)),
        content: Text('Delete "${node.label}"?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFEF4444)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final newNodes = List<KnowledgeNode>.from(_graph!.nodes)
        ..removeWhere((n) => n.id == _selectedNodeId);
      final newEdges = List<KnowledgeEdge>.from(_graph!.edges)
        ..removeWhere((e) => e.sourceId == _selectedNodeId || e.targetId == _selectedNodeId);

      _graph = _graph!.copyWith(nodes: newNodes, edges: newEdges);
      await _saveGraph();

      setState(() {
        _selectedNodeId = null;
      });
    }
  }

  void _showAddNodeDialog({Offset? initialPosition}) {
    final labelController = TextEditingController();
    final contentController = TextEditingController();
    final tagsController = TextEditingController();
    NodeType selectedType = NodeType.concept;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          title: const Text('Add Node', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: labelController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Label',
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: contentController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Notes/Content',
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: tagsController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Tags (comma separated)',
                    hintText: 'e.g., important, exam, review',
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<NodeType>(
                  value: selectedType,
                  dropdownColor: const Color(0xFF1E293B),
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                  items: NodeType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Row(
                        children: [
                          Icon(type.icon, color: type.color, size: 16),
                          const SizedBox(width: 8),
                          Text(type.displayName, style: const TextStyle(color: Colors.white)),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selectedType = value);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (labelController.text.isNotEmpty) {
                  final position = initialPosition ??
                      Offset(1500 + (_graph!.nodes.length * 20) % 200,
                          1500 + (_graph!.nodes.length * 30) % 200);

                  final tags = tagsController.text
                      .split(',')
                      .map((t) => t.trim())
                      .where((t) => t.isNotEmpty)
                      .toList();

                  final newNode = KnowledgeNode(
                    label: labelController.text,
                    content: contentController.text.isEmpty ? null : contentController.text,
                    type: selectedType,
                    position: position,
                    mapId: widget.mapId,
                    tags: tags,
                  );

                  final newNodes = List<KnowledgeNode>.from(_graph!.nodes)..add(newNode);
                  _graph = _graph!.copyWith(nodes: newNodes);
                  await _saveGraph();

                  if (mounted) {
                    Navigator.pop(context);
                    setState(() {});
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6)),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditNodeDialog() {
    if (_selectedNodeId == null) return;

    final node = _graph!.nodes.firstWhere((n) => n.id == _selectedNodeId);
    final labelController = TextEditingController(text: node.label);
    final contentController = TextEditingController(text: node.content ?? '');
    final tagsController = TextEditingController(text: node.tags.join(', '));
    NodeType selectedType = node.type;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          title: const Text('Edit Node', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: labelController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Label',
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: contentController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Content',
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: tagsController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Tags',
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<NodeType>(
                  value: selectedType,
                  dropdownColor: const Color(0xFF1E293B),
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                  items: NodeType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Row(
                        children: [
                          Icon(type.icon, color: type.color, size: 16),
                          const SizedBox(width: 8),
                          Text(type.displayName, style: const TextStyle(color: Colors.white)),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selectedType = value);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (labelController.text.isNotEmpty) {
                  final tags = tagsController.text
                      .split(',')
                      .map((t) => t.trim())
                      .where((t) => t.isNotEmpty)
                      .toList();

                  final updatedNode = node.copyWith(
                    label: labelController.text,
                    content: contentController.text.isEmpty ? null : contentController.text,
                    type: selectedType,
                    tags: tags,
                  );

                  final nodeIndex = _graph!.nodes.indexWhere((n) => n.id == node.id);
                  _graph!.nodes[nodeIndex] = updatedNode;
                  await _saveGraph();

                  if (mounted) {
                    Navigator.pop(context);
                    setState(() {});
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6)),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        title: const Text('Search Nodes', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: _searchController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Search by name or tag...',
            hintStyle: TextStyle(color: Colors.white38),
            prefixIcon: Icon(Icons.search, color: Colors.white70),
          ),
          onChanged: (value) {
            _searchNodes(value);
            setState(() {});
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              _searchController.clear();
              _searchNodes('');
              Navigator.pop(context);
            },
            child: const Text('Clear'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6)),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

// EdgePainter remains the same as your original
class EdgePainter extends CustomPainter {
  final List<KnowledgeNode> nodes;
  final List<KnowledgeEdge> edges;
  final String? selectedNodeId;
  final String? connectingNodeId;
  final Offset? dragStartPosition;
  final Offset? dragCurrentPosition;

  EdgePainter({
    required this.nodes,
    required this.edges,
    this.selectedNodeId,
    this.connectingNodeId,
    this.dragStartPosition,
    this.dragCurrentPosition,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (final edge in edges) {
      final sourceNode = nodes.firstWhere(
            (n) => n.id == edge.sourceId,
        orElse: () => KnowledgeNode(label: '', type: NodeType.concept, position: Offset.zero, mapId: ''),
      );
      final targetNode = nodes.firstWhere(
            (n) => n.id == edge.targetId,
        orElse: () => KnowledgeNode(label: '', type: NodeType.concept, position: Offset.zero, mapId: ''),
      );

      if (sourceNode.label.isNotEmpty && targetNode.label.isNotEmpty) {
        final isHighlighted = selectedNodeId == sourceNode.id || selectedNodeId == targetNode.id;
        paint.color = isHighlighted
            ? const Color(0xFF3B82F6).withOpacity(0.8)
            : const Color(0xFF64748B).withOpacity(0.4);
        paint.strokeWidth = isHighlighted ? 3 : 2;

        final path = Path();
        path.moveTo(sourceNode.position.dx, sourceNode.position.dy);

        final midX = (sourceNode.position.dx + targetNode.position.dx) / 2;
        final controlPoint1 = Offset(midX, sourceNode.position.dy);
        final controlPoint2 = Offset(midX, targetNode.position.dy);

        path.cubicTo(
          controlPoint1.dx, controlPoint1.dy,
          controlPoint2.dx, controlPoint2.dy,
          targetNode.position.dx, targetNode.position.dy,
        );

        canvas.drawPath(path, paint);
        _drawArrow(canvas, targetNode.position, sourceNode.position, paint.color);
      }
    }

    if (connectingNodeId != null && dragStartPosition != null && dragCurrentPosition != null) {
      paint.color = const Color(0xFFF59E0B).withOpacity(0.6);
      paint.strokeWidth = 2;
      canvas.drawLine(dragStartPosition!, dragCurrentPosition!, paint);
    }
  }

  void _drawArrow(Canvas canvas, Offset tip, Offset from, Color color) {
    final arrowPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final angle = (tip - from).direction;
    const arrowSize = 10;
    const arrowAngle = 0.5;

    final path = Path();
    path.moveTo(tip.dx, tip.dy);
    path.lineTo(
      tip.dx - arrowSize * cos(angle - arrowAngle),
      tip.dy - arrowSize * sin(angle - arrowAngle),
    );
    path.lineTo(
      tip.dx - arrowSize * cos(angle + arrowAngle),
      tip.dy - arrowSize * sin(angle + arrowAngle),
    );
    path.close();

    canvas.drawPath(path, arrowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ── Retention arc ring drawn behind each node ────────────────────────────────
class _RetentionRingPainter extends CustomPainter {
  final double retention; // 0.0–1.0
  final Color color;
  final bool isSelected;

  const _RetentionRingPainter({
    required this.retention,
    required this.color,
    required this.isSelected,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 + (isSelected ? 7 : 5);

    // Background track
    final trackPaint = Paint()
      ..color = color.withOpacity(0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSelected ? 4 : 3
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    // Filled arc representing retention
    final arcPaint = Paint()
      ..color = color.withOpacity(isSelected ? 0.9 : 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSelected ? 4 : 3
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,              // start at top
      2 * pi * retention,   // sweep proportional to retention
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(_RetentionRingPainter old) =>
      old.retention != retention || old.color != color || old.isSelected != isSelected;
}

// ── Forgetting curve chart shown in the review bottom sheet ──────────────────
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
    final now = DateTime.now();
    final daysSinceReview = now.difference(node.lastReviewDate!).inHours / 24.0;
    final stability = (node.interval * (node.easeFactor / 2.5)).clamp(0.1, 999.0);

    // Draw gradient fill
    final path = Path();
    path.moveTo(0, size.height);

    for (int px = 0; px <= size.width.toInt(); px++) {
      final dayOffset = (px / size.width) * totalDays;
      final r = exp(-dayOffset / stability).clamp(0.0, 1.0);
      final y = size.height - r * (size.height - 8);
      if (px == 0) {
        path.lineTo(0, y);
      } else {
        path.lineTo(px.toDouble(), y);
      }
    }
    path.lineTo(size.width, size.height);
    path.close();

    final gradient = LinearGradient(
      colors: [
        const Color(0xFF22C55E).withOpacity(0.3),
        const Color(0xFFEAB308).withOpacity(0.2),
        const Color(0xFFEF4444).withOpacity(0.1),
      ],
    );
    final fillPaint = Paint()
      ..shader = gradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(path, fillPaint);

    // Draw curve line
    final linePath = Path();
    bool first = true;
    for (int px = 0; px <= size.width.toInt(); px++) {
      final dayOffset = (px / size.width) * totalDays;
      final r = exp(-dayOffset / stability).clamp(0.0, 1.0);
      final y = size.height - r * (size.height - 8);
      if (first) { linePath.moveTo(px.toDouble(), y); first = false; }
      else linePath.lineTo(px.toDouble(), y);
    }

    // Colour the line based on current retention
    final currentRetention = sm2.memoryRetention(node);
    Color lineColor;
    if (currentRetention >= 0.75) lineColor = const Color(0xFF22C55E);
    else if (currentRetention >= 0.40) lineColor = const Color(0xFFEAB308);
    else lineColor = const Color(0xFFEF4444);

    canvas.drawPath(linePath, Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round);

    // "Now" vertical marker
    final nowX = (daysSinceReview / totalDays * size.width).clamp(0.0, size.width);
    canvas.drawLine(
      Offset(nowX, 0), Offset(nowX, size.height),
      Paint()..color = Colors.white.withOpacity(0.4)..strokeWidth = 1.5
        ..style = PaintingStyle.stroke,
    );

    // Next review marker
    if (node.nextReviewDate != null) {
      final daysToNext = node.nextReviewDate!.difference(node.lastReviewDate!).inHours / 24.0;
      final nextX = (daysToNext / totalDays * size.width).clamp(0.0, size.width);
      canvas.drawLine(
        Offset(nextX, 0), Offset(nextX, size.height),
        Paint()..color = const Color(0xFF3B82F6).withOpacity(0.6)..strokeWidth = 1.5
          ..style = PaintingStyle.stroke,
      );
    }

    // X-axis labels
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    for (final label in ['0d', '${(totalDays ~/ 2)}d', '${totalDays.toInt()}d']) {
      final x = label == '0d' ? 0.0 : label.contains((totalDays ~/ 2).toString()) ? size.width / 2 : size.width - 20;
      textPainter.text = TextSpan(
        text: label,
        style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 9),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x, size.height - 11));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}


