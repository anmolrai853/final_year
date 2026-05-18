// lib/widgets/gap_recommendations_card.dart

import 'package:flutter/material.dart';
import '../models/gap_recommendation.dart';
import '../pages/pomodoro_timer_page.dart';
import '../pages/knowledge_maps_list_page.dart';

class GapRecommendationsCard extends StatefulWidget {
  final List<GapRecommendation> gaps;
  final bool hasAnalyticsData;

  const GapRecommendationsCard({
    super.key,
    required this.gaps,
    required this.hasAnalyticsData,
  });

  @override
  State<GapRecommendationsCard> createState() => _GapRecommendationsCardState();
}

class _GapRecommendationsCardState extends State<GapRecommendationsCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = true;
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
      value: 1.0, // starts expanded
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _expanded = !_expanded;
      if (_expanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.gaps.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header — tappable to collapse/expand
          GestureDetector(
            onTap: _toggleExpanded,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                children: [
                  const Icon(
                    Icons.auto_awesome,
                    color: Color(0xFF3B82F6),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Free Gaps Today',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Gap count badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${widget.gaps.length}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Personalised / General tips badge
                  if (!widget.hasAnalyticsData)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'General tips',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Personalised',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF3B82F6),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  // Chevron that rotates on collapse
                  AnimatedRotation(
                    turns: _expanded ? 0 : -0.5,
                    duration: const Duration(milliseconds: 250),
                    child: const Icon(
                      Icons.keyboard_arrow_down,
                      color: Color(0xFF64748B),
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Animated collapsible content
          SizeTransition(
            sizeFactor: _expandAnimation,
            axisAlignment: -1,
            child: Column(
              children: [
                const Divider(color: Color(0xFF1E293B), height: 1),
                ...widget.gaps.map((gap) => _buildGapTile(context, gap)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGapTile(BuildContext context, GapRecommendation gap) {
    final qualityColor = _qualityColor(gap.quality);
    final isLast = widget.gaps.last == gap;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isLast ? Colors.transparent : const Color(0xFF1E293B),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: time + quality badge + duration
          Row(
            children: [
              Icon(Icons.schedule, size: 14, color: qualityColor),
              const SizedBox(width: 6),
              Text(
                gap.formattedTime,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: qualityColor,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: qualityColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: qualityColor.withOpacity(0.4)),
                ),
                child: Text(
                  gap.quality.label,
                  style: TextStyle(
                    fontSize: 10,
                    color: qualityColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                gap.formattedDuration,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Suggestion text
          Text(
            gap.suggestion,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF94A3B8),
              height: 1.4,
            ),
          ),

          // Related deadline chip
          if (gap.relatedDeadlineTitle != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: const Color(0xFFF59E0B).withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.flag,
                      size: 12, color: Color(0xFFF59E0B)),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      gap.relatedDeadlineTitle!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFF59E0B),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Due review nodes chip
          if (gap.dueNodeCount != null && gap.dueNodeCount! > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: const Color(0xFF8B5CF6).withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.memory,
                      size: 12, color: Color(0xFF8B5CF6)),
                  const SizedBox(width: 5),
                  Text(
                    '${gap.dueNodeCount} knowledge node${gap.dueNodeCount! > 1 ? 's' : ''} due for review',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF8B5CF6),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 10),

          // Action buttons
          Row(
            children: [
              _actionButton(
                context,
                icon: Icons.play_circle_outline,
                label: 'Pomodoro',
                color: const Color(0xFFEF4444),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const PomodoroTimerPage()),
                ),
              ),
              const SizedBox(width: 8),
              if (gap.dueNodeCount != null && gap.dueNodeCount! > 0)
                _actionButton(
                  context,
                  icon: Icons.account_tree_outlined,
                  label: 'Review',
                  color: const Color(0xFF8B5CF6),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const KnowledgeMapsListPage()),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionButton(
      BuildContext context, {
        required IconData icon,
        required String label,
        required Color color,
        required VoidCallback onTap,
      }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _qualityColor(GapQuality quality) {
    switch (quality) {
      case GapQuality.peak:
        return const Color(0xFF10B981);
      case GapQuality.good:
        return const Color(0xFF3B82F6);
      case GapQuality.light:
        return const Color(0xFF64748B);
    }
  }
}