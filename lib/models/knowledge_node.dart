// lib/models/knowledge_node.dart
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

enum NodeType {
  concept,
  topic,
  subtopic,
  note,
  idea,        // New: freeform ideas
  question,    // New: questions to research
  resource,    // New: links, books, etc.
}

extension NodeTypeExtension on NodeType {
  String get displayName {
    switch (this) {
      case NodeType.concept:
        return 'Concept';
      case NodeType.topic:
        return 'Topic';
      case NodeType.subtopic:
        return 'Subtopic';
      case NodeType.note:
        return 'Note';
      case NodeType.idea:
        return 'Idea';
      case NodeType.question:
        return 'Question';
      case NodeType.resource:
        return 'Resource';
    }
  }

  Color get color {
    switch (this) {
      case NodeType.concept:
        return const Color(0xFF8B5CF6); // Violet
      case NodeType.topic:
        return const Color(0xFF06B6D4); // Cyan
      case NodeType.subtopic:
        return const Color(0xFFF97316); // Orange
      case NodeType.note:
        return const Color(0xFF84CC16); // Lime
      case NodeType.idea:
        return const Color(0xFFEC4899); // Pink
      case NodeType.question:
        return const Color(0xFFEF4444); // Red
      case NodeType.resource:
        return const Color(0xFF3B82F6); // Blue
    }
  }

  double get size {
    switch (this) {
      case NodeType.concept:
        return 80;
      case NodeType.topic:
        return 65;
      case NodeType.subtopic:
        return 50;
      case NodeType.note:
      case NodeType.idea:
        return 45;
      case NodeType.question:
      case NodeType.resource:
        return 40;
    }
  }

  IconData get icon {
    switch (this) {
      case NodeType.concept:
        return Icons.lightbulb;
      case NodeType.topic:
        return Icons.folder;
      case NodeType.subtopic:
        return Icons.subdirectory_arrow_right;
      case NodeType.note:
        return Icons.sticky_note_2;
      case NodeType.idea:
        return Icons.emoji_objects;
      case NodeType.question:
        return Icons.help_outline;
      case NodeType.resource:
        return Icons.link;
    }
  }
}

/// 0 = not rated, 1 = very poor … 5 = confident
typedef ConfidenceLevel = int;

class KnowledgeNode {
  final String id;
  final String label;
  final String? content;
  final NodeType type;
  final Offset position;
  final String? moduleCode;
  final String mapId;
  final DateTime createdAt;
  final List<String> tags;
  final int confidenceLevel; // 0 = unrated, 1–5 = rating

  // ── SM-2 Spaced Repetition ──────────────────────────────
  final double easeFactor;      // starts at 2.5, min 1.3
  final int interval;           // days until next review
  final int repetitions;        // number of successful reviews
  final DateTime? lastReviewDate;
  final DateTime? nextReviewDate;
  // ────────────────────────────────────────────────────────

  KnowledgeNode({
    String? id,
    required this.label,
    this.content,
    required this.type,
    required this.position,
    this.moduleCode,
    required this.mapId,
    DateTime? createdAt,
    this.tags = const [],
    this.confidenceLevel = 0,
    this.easeFactor = 2.5,
    this.interval = 0,
    this.repetitions = 0,
    this.lastReviewDate,
    this.nextReviewDate,
  }) : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  KnowledgeNode copyWith({
    String? label,
    String? content,
    NodeType? type,
    Offset? position,
    String? moduleCode,
    String? mapId,
    List<String>? tags,
    int? confidenceLevel,
    double? easeFactor,
    int? interval,
    int? repetitions,
    DateTime? lastReviewDate,
    DateTime? nextReviewDate,
  }) {
    return KnowledgeNode(
      id: id,
      label: label ?? this.label,
      content: content ?? this.content,
      type: type ?? this.type,
      position: position ?? this.position,
      moduleCode: moduleCode ?? this.moduleCode,
      mapId: mapId ?? this.mapId,
      createdAt: createdAt,
      tags: tags ?? this.tags,
      confidenceLevel: confidenceLevel ?? this.confidenceLevel,
      easeFactor: easeFactor ?? this.easeFactor,
      interval: interval ?? this.interval,
      repetitions: repetitions ?? this.repetitions,
      lastReviewDate: lastReviewDate ?? this.lastReviewDate,
      nextReviewDate: nextReviewDate ?? this.nextReviewDate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'content': content,
      'type': type.index,
      'position': {'dx': position.dx, 'dy': position.dy},
      'moduleCode': moduleCode,
      'mapId': mapId,
      'createdAt': createdAt.toIso8601String(),
      'tags': tags,
      'confidenceLevel': confidenceLevel,
      'easeFactor': easeFactor,
      'interval': interval,
      'repetitions': repetitions,
      'lastReviewDate': lastReviewDate?.toIso8601String(),
      'nextReviewDate': nextReviewDate?.toIso8601String(),
    };
  }

  factory KnowledgeNode.fromJson(Map<String, dynamic> json) {
    return KnowledgeNode(
      id: json['id'],
      label: json['label'],
      content: json['content'],
      type: NodeType.values[json['type']],
      position: Offset(
        json['position']['dx'],
        json['position']['dy'],
      ),
      moduleCode: json['moduleCode'],
      mapId: json['mapId'] ?? 'default',
      createdAt: DateTime.parse(json['createdAt']),
      tags: (json['tags'] as List?)?.cast<String>() ?? [],
      confidenceLevel: (json['confidenceLevel'] as int?) ?? 0,
      easeFactor: (json['easeFactor'] as num?)?.toDouble() ?? 2.5,
      interval: (json['interval'] as int?) ?? 0,
      repetitions: (json['repetitions'] as int?) ?? 0,
      lastReviewDate: json['lastReviewDate'] != null
          ? DateTime.parse(json['lastReviewDate'])
          : null,
      nextReviewDate: json['nextReviewDate'] != null
          ? DateTime.parse(json['nextReviewDate'])
          : null,
    );
  }
}

class KnowledgeEdge {
  final String id;
  final String sourceId;
  final String targetId;
  final String? label;
  final EdgeType type; // New: different relationship types

  KnowledgeEdge({
    String? id,
    required this.sourceId,
    required this.targetId,
    this.label,
    this.type = EdgeType.relatesTo,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sourceId': sourceId,
      'targetId': targetId,
      'label': label,
      'type': type.index,
    };
  }

  factory KnowledgeEdge.fromJson(Map<String, dynamic> json) {
    return KnowledgeEdge(
      id: json['id'],
      sourceId: json['sourceId'],
      targetId: json['targetId'],
      label: json['label'],
      type: json['type'] != null
          ? EdgeType.values[json['type']]
          : EdgeType.relatesTo,
    );
  }
}

enum EdgeType {
  relatesTo,
  prerequisite,  // Must learn before
  leadsTo,       // Leads to next concept
  partOf,        // Is part of
  references,    // References/mentions
}

class KnowledgeMap {
  final String id;
  final String name;
  final String? description;
  final DateTime createdAt;
  final DateTime? lastModified;
  final String? color; // Theme color

  KnowledgeMap({
    String? id,
    required this.name,
    this.description,
    DateTime? createdAt,
    this.lastModified,
    this.color,
  }) : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  KnowledgeMap copyWith({
    String? name,
    String? description,
    DateTime? lastModified,
    String? color,
  }) {
    return KnowledgeMap(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt,
      lastModified: lastModified ?? DateTime.now(),
      color: color ?? this.color,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'lastModified': lastModified?.toIso8601String(),
      'color': color,
    };
  }

  factory KnowledgeMap.fromJson(Map<String, dynamic> json) {
    return KnowledgeMap(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      createdAt: DateTime.parse(json['createdAt']),
      lastModified: json['lastModified'] != null
          ? DateTime.parse(json['lastModified'])
          : null,
      color: json['color'],
    );
  }
}

class KnowledgeGraphData {
  final String mapId;
  final List<KnowledgeNode> nodes;
  final List<KnowledgeEdge> edges;

  KnowledgeGraphData({
    required this.mapId,
    required this.nodes,
    required this.edges,
  });

  KnowledgeGraphData copyWith({
    List<KnowledgeNode>? nodes,
    List<KnowledgeEdge>? edges,
  }) {
    return KnowledgeGraphData(
      mapId: mapId,
      nodes: nodes ?? this.nodes,
      edges: edges ?? this.edges,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'mapId': mapId,
      'nodes': nodes.map((n) => n.toJson()).toList(),
      'edges': edges.map((e) => e.toJson()).toList(),
    };
  }

  factory KnowledgeGraphData.fromJson(Map<String, dynamic> json) {
    return KnowledgeGraphData(
      mapId: json['mapId'],
      nodes: (json['nodes'] as List)
          .map((n) => KnowledgeNode.fromJson(n))
          .toList(),
      edges: (json['edges'] as List)
          .map((e) => KnowledgeEdge.fromJson(e))
          .toList(),
    );
  }
}