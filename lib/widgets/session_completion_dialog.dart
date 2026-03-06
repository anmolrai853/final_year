import 'package:flutter/material.dart';
import '../models/study_session.dart';

class SessionCompletionDialog extends StatefulWidget {
  final StudySession session;
  final Function(StudySession) onComplete;

  const SessionCompletionDialog({
    super.key,
    required this.session,
    required this.onComplete,
  });

  @override
  State<SessionCompletionDialog> createState() => _SessionCompletionDialogState();
}

class _SessionCompletionDialogState extends State<SessionCompletionDialog> {
  int _actualMinutes = 0;
  FocusLevel _focusLevel = FocusLevel.good;
  int _interruptions = 0;
  int _understanding = 3;
  final _topicsController = TextEditingController();
  bool _completedFull = false;

  @override
  void initState() {
    super.initState();
    _actualMinutes = widget.session.durationMinutes;
    _completedFull = true;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF0F172A),
      title: const Text(
        'Session Complete!',
        style: TextStyle(color: Colors.white),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How did "${widget.session.title}" go?',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 20),

            _buildSection('Actual Study Time'),
            Text(
              '$_actualMinutes minutes',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Slider(
              value: _actualMinutes.toDouble(),
              min: 0,
              max: (widget.session.durationMinutes * 1.5).toDouble(),
              divisions: widget.session.durationMinutes ~/ 5,
              activeColor: const Color(0xFF3B82F6),
              onChanged: (value) {
                setState(() {
                  _actualMinutes = value.round();
                  _completedFull = _actualMinutes >= widget.session.durationMinutes;
                });
              },
            ),

            const SizedBox(height: 20),

            _buildSection('Focus Level'),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: FocusLevel.values.map((level) {
                final isSelected = _focusLevel == level;
                return GestureDetector(
                  onTap: () => setState(() => _focusLevel = level),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSelected ? level.color.withOpacity(0.2) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? level.color : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          _getFocusIcon(level),
                          color: isSelected ? level.color : Colors.white.withOpacity(0.5),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          level.label,
                          style: TextStyle(
                            color: isSelected ? level.color : Colors.white.withOpacity(0.5),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            _buildSection('Understanding'),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final star = index + 1;
                return IconButton(
                  onPressed: () => setState(() => _understanding = star),
                  icon: Icon(
                    star <= _understanding ? Icons.star : Icons.star_border,
                    color: star <= _understanding ? Colors.amber : Colors.white.withOpacity(0.3),
                  ),
                );
              }),
            ),

            const SizedBox(height: 20),

            _buildSection('Interruptions'),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: _interruptions > 0
                      ? () => setState(() => _interruptions--)
                      : null,
                  icon: const Icon(Icons.remove_circle_outline),
                  color: Colors.white70,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    '$_interruptions',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _interruptions++),
                  icon: const Icon(Icons.add_circle_outline),
                  color: const Color(0xFF3B82F6),
                ),
              ],
            ),

            const SizedBox(height: 20),

            _buildSection('Topics Covered (Optional)'),
            TextField(
              controller: _topicsController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'e.g., Chapter 3, Sorting algorithms...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              maxLines: 2,
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
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF10B981),
            foregroundColor: Colors.white,
          ),
          child: const Text('Complete Session'),
        ),
      ],
    );
  }

  Widget _buildSection(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.white.withOpacity(0.6),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  IconData _getFocusIcon(FocusLevel level) {
    switch (level) {
      case FocusLevel.distracted:
        return Icons.cloud_off;
      case FocusLevel.fair:
        return Icons.cloud;
      case FocusLevel.good:
        return Icons.brightness_5;
      case FocusLevel.focused:
        return Icons.brightness_7;
      case FocusLevel.deepWork:
        return Icons.wb_sunny;
    }
  }

  void _submit() {
    final updatedSession = widget.session.copyWith(
      isCompleted: true,
      actualDurationMinutes: _actualMinutes,
      focusLevel: _focusLevel,
      interruptionCount: _interruptions,
      understandingRating: _understanding,
      topicsCovered: _topicsController.text.isEmpty ? null : _topicsController.text,
      completedFullSession: _completedFull,
      completedAt: DateTime.now(),
    );

    widget.onComplete(updatedSession);
    Navigator.pop(context);
  }
}