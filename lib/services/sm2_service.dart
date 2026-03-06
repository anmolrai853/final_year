// lib/services/sm2_service.dart
import 'dart:math';
import 'dart:ui';
import '../models/knowledge_node.dart';

/// SM-2 spaced repetition algorithm + Ebbinghaus forgetting curve.
class Sm2Service {
  static final Sm2Service _instance = Sm2Service._internal();
  factory Sm2Service() => _instance;
  Sm2Service._internal();

  // ─── SM-2 ────────────────────────────────────────────────────────────────

  /// Apply one SM-2 review to [node].
  ///
  /// [quality] is 0–5:
  ///   0 = complete blackout
  ///   1 = incorrect, remembered on seeing answer
  ///   2 = incorrect but easy to remember
  ///   3 = correct with serious difficulty
  ///   4 = correct after hesitation
  ///   5 = perfect response
  KnowledgeNode applyReview(KnowledgeNode node, int quality) {
    assert(quality >= 0 && quality <= 5);

    final now = DateTime.now();
    double ef = node.easeFactor;
    int reps = node.repetitions;
    int interval = node.interval;

    if (quality >= 3) {
      // Correct response
      if (reps == 0) {
        interval = 1;
      } else if (reps == 1) {
        interval = 6;
      } else {
        interval = (interval * ef).round();
      }
      reps += 1;
    } else {
      // Incorrect – restart
      reps = 0;
      interval = 1;
    }

    // Update ease factor (clamped to min 1.3)
    ef = ef + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));
    ef = max(1.3, ef);

    final nextReview = now.add(Duration(days: interval));

    // Map SM-2 quality to confidence level (1-5 display scale)
    final confidence = (quality / 5 * 5).round().clamp(1, 5);

    return node.copyWith(
      easeFactor: ef,
      interval: interval,
      repetitions: reps,
      lastReviewDate: now,
      nextReviewDate: nextReview,
      confidenceLevel: confidence,
    );
  }

  // ─── Ebbinghaus Forgetting Curve ─────────────────────────────────────────

  /// Returns memory retention [0.0–1.0] using the Ebbinghaus forgetting curve:
  ///   R = e^(-t / S)
  /// where t = days since last review, S = stability (derived from easeFactor & interval).
  double memoryRetention(KnowledgeNode node) {
    if (node.lastReviewDate == null) return 0.0;

    final daysSince = DateTime.now()
        .difference(node.lastReviewDate!)
        .inMinutes / 1440.0; // fractional days

    // Stability: how many days before 90% is forgotten.
    // Longer interval + higher EF = stronger memory.
    final stability = max(0.1, node.interval * (node.easeFactor / 2.5));

    final retention = exp(-daysSince / stability);
    return retention.clamp(0.0, 1.0);
  }

  /// Colour representing memory strength:
  /// Green (strong) → Yellow (fading) → Red (at risk)
  MemoryStatus memoryStatus(KnowledgeNode node) {
    if (node.lastReviewDate == null) return MemoryStatus.unreviewed;
    final r = memoryRetention(node);
    if (r >= 0.75) return MemoryStatus.strong;
    if (r >= 0.40) return MemoryStatus.fading;
    return MemoryStatus.atRisk;
  }

  /// Whether the node is due (or overdue) for review right now.
  bool isDue(KnowledgeNode node) {
    if (node.nextReviewDate == null) return false;
    return DateTime.now().isAfter(node.nextReviewDate!);
  }

  /// Days until the next scheduled review (negative = overdue).
  int daysUntilReview(KnowledgeNode node) {
    if (node.nextReviewDate == null) return 0;
    return node.nextReviewDate!.difference(DateTime.now()).inDays;
  }
}

enum MemoryStatus { unreviewed, strong, fading, atRisk }

extension MemoryStatusExt on MemoryStatus {
  Color get color {
    switch (this) {
      case MemoryStatus.strong:     return const Color(0xFF22C55E); // green
      case MemoryStatus.fading:     return const Color(0xFFEAB308); // yellow
      case MemoryStatus.atRisk:     return const Color(0xFFEF4444); // red
      case MemoryStatus.unreviewed: return const Color(0xFF64748B); // grey
    }
  }

  String get label {
    switch (this) {
      case MemoryStatus.strong:     return 'Strong memory';
      case MemoryStatus.fading:     return 'Fading – review soon';
      case MemoryStatus.atRisk:     return 'At risk of forgetting!';
      case MemoryStatus.unreviewed: return 'Not yet reviewed';
    }
  }
}

