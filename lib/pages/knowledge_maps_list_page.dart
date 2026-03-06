// lib/pages/knowledge_maps_list_page.dart
import 'package:flutter/material.dart';
import '../models/knowledge_node.dart';
import '../services/storage_service.dart';
import 'knowledge_graph_page.dart';

class KnowledgeMapsListPage extends StatefulWidget {
  const KnowledgeMapsListPage({super.key});

  @override
  State<KnowledgeMapsListPage> createState() => _KnowledgeMapsListPageState();
}

class _KnowledgeMapsListPageState extends State<KnowledgeMapsListPage> {
  final StorageService _storage = StorageService();
  List<KnowledgeMap> _maps = [];

  @override
  void initState() {
    super.initState();
    _loadMaps();
  }

  void _loadMaps() {
    _maps = _storage.loadKnowledgeMaps();
    setState(() {});
  }

  Future<void> _createNewMap() async {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        title: const Text('Create New Map', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Map Name',
                hintText: 'e.g., Machine Learning, Project Ideas...',
                labelStyle: TextStyle(color: Colors.white70),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Description (Optional)',
                labelStyle: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
            ),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (result == true && nameController.text.isNotEmpty) {
      final newMap = KnowledgeMap(
        name: nameController.text,
        description: descController.text.isEmpty ? null : descController.text,
      );

      await _storage.saveKnowledgeMap(newMap);

      // Create empty graph for this map
      await _storage.saveKnowledgeGraphData(KnowledgeGraphData(
        mapId: newMap.id,
        nodes: [],
        edges: [],
      ));

      _loadMaps();

      // Open the new map immediately
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => KnowledgeGraphPage(mapId: newMap.id),
          ),
        ).then((_) => _loadMaps());
      }
    }
  }

  Future<void> _deleteMap(KnowledgeMap map) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        title: const Text('Delete Map', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to delete "${map.name}"? This cannot be undone.',
          style: const TextStyle(color: Colors.white70),
        ),
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
      await _storage.deleteKnowledgeMap(map.id);
      _loadMaps();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      appBar: AppBar(
        title: const Text('My Knowledge Maps'),
        backgroundColor: const Color(0xFF020617),
        foregroundColor: Colors.white,
      ),
      body: _maps.isEmpty ? _buildEmptyState() : _buildMapsList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNewMap,
        icon: const Icon(Icons.add),
        label: const Text('New Map'),
        backgroundColor: const Color(0xFF3B82F6),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_tree_outlined,
            size: 80,
            color: Colors.white.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Knowledge Maps Yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first map to organize ideas,\nconcepts, and learning topics',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _createNewMap,
            icon: const Icon(Icons.add),
            label: const Text('Create First Map'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _maps.length,
      itemBuilder: (context, index) {
        final map = _maps[index];
        return _buildMapCard(map);
      },
    );
  }

  Widget _buildMapCard(KnowledgeMap map) {
    final graphData = _storage.getKnowledgeGraphData(map.id);
    final nodeCount = graphData?.nodes.length ?? 0;
    final edgeCount = graphData?.edges.length ?? 0;

    return Dismissible(
      key: Key(map.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => _deleteMap(map),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => KnowledgeGraphPage(mapId: map.id),
            ),
          ).then((_) => _loadMaps());
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1E293B)),
          ),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF8B5CF6),
                      const Color(0xFF3B82F6),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.account_tree,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      map.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    if (map.description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        map.description!,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.6),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildStatChip(Icons.circle, '$nodeCount nodes'),
                        const SizedBox(width: 8),
                        _buildStatChip(Icons.linear_scale, '$edgeCount links'),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                color: Color(0xFF64748B),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFF94A3B8)),
          const SizedBox(width: 4),
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
}