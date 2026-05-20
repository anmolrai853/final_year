import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/study_session.dart';
import '../controllers/timetable_controller.dart';
import '../widgets/session_completion_dialog.dart';

enum PomodoroPhase { work, shortBreak, longBreak }

extension PomodoroPhaseExtension on PomodoroPhase {
  String get displayName {
    switch (this) {
      case PomodoroPhase.work:
        return 'Focus';
      case PomodoroPhase.shortBreak:
        return 'Short Break';
      case PomodoroPhase.longBreak:
        return 'Long Break';
    }
  }

  Color get color {
    switch (this) {
      case PomodoroPhase.work:
        return const Color(0xFFEF4444);
      case PomodoroPhase.shortBreak:
        return const Color(0xFF10B981);
      case PomodoroPhase.longBreak:
        return const Color(0xFF3B82F6);
    }
  }

  IconData get icon {
    switch (this) {
      case PomodoroPhase.work:
        return Icons.local_fire_department;
      case PomodoroPhase.shortBreak:
        return Icons.coffee;
      case PomodoroPhase.longBreak:
        return Icons.self_improvement;
    }
  }
}

class PomodoroTimerPage extends StatefulWidget {
  final StudySession? session;
  final int workMinutes;
  final int shortBreakMinutes;
  final int longBreakMinutes;
  final int pomodorosBeforeLongBreak;

  const PomodoroTimerPage({
    super.key,
    this.session,
    this.workMinutes = 25,
    this.shortBreakMinutes = 5,
    this.longBreakMinutes = 15,
    this.pomodorosBeforeLongBreak = 4,
  });

  @override
  State<PomodoroTimerPage> createState() => _PomodoroTimerPageState();
}

class _PomodoroTimerPageState extends State<PomodoroTimerPage>
    with TickerProviderStateMixin {
  final TimetableController _controller = TimetableController();
  Timer? _timer;
  bool _isRunning = false;
  bool _isPaused = false;
  PomodoroPhase _currentPhase = PomodoroPhase.work;
  int _completedPomodoros = 0;
  int _totalWorkSeconds = 0;
  late int _totalSecondsInPhase;
  late int _remainingSeconds;
  late int _workMinutes;
  late int _shortBreakMinutes;
  late int _longBreakMinutes;
  late int _pomodorosBeforeLongBreak;
  bool _settingsLocked = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _workMinutes = widget.workMinutes;
    _shortBreakMinutes = widget.shortBreakMinutes;
    _longBreakMinutes = widget.longBreakMinutes;
    _pomodorosBeforeLongBreak = widget.pomodorosBeforeLongBreak;
    _totalSecondsInPhase = _workMinutes * 60;
    _remainingSeconds = _totalSecondsInPhase;

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = true;
      _isPaused = false;
      _settingsLocked = true;
    });

    _pulseController.repeat(reverse: true);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
          if (_currentPhase == PomodoroPhase.work) _totalWorkSeconds++;
        } else {
          _onPhaseComplete();
        }
      });
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    _pulseController.stop();
    setState(() {
      _isPaused = true;
      _isRunning = false;
    });
  }

  void _resumeTimer() => _startTimer();

  void _onPhaseComplete() {
    _timer?.cancel();
    _pulseController.stop();
    HapticFeedback.heavyImpact();

    if (_currentPhase == PomodoroPhase.work) {
      _completedPomodoros++;
      _showWorkCompleteDialog();
    } else {
      _switchPhase(PomodoroPhase.work);
    }
  }

  void _showWorkCompleteDialog() {
    final isLongBreakNext = _completedPomodoros % _pomodorosBeforeLongBreak == 0;
    final breakLabel = isLongBreakNext ? 'Long Break' : 'Short Break';
    final breakMinutes = isLongBreakNext ? _longBreakMinutes : _shortBreakMinutes;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 28),
            const SizedBox(width: 12),
            const Text('Pomodoro Complete!', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You completed pomodoro $_completedPomodoros. ${isLongBreakNext ? 'Time for a long break!' : 'Take a short break.'}',
              style: const TextStyle(color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.save_alt, color: Color(0xFF10B981), size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Log this session to track your progress and update analytics',
                      style: TextStyle(color: Color(0xFF10B981), fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _finishSession();
            },
            child: const Text('Log Session & End'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _switchPhase(isLongBreakNext ? PomodoroPhase.longBreak : PomodoroPhase.shortBreak);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6)),
            child: Text('$breakLabel ($breakMinutes min)'),
          ),
        ],
      ),
    );
  }

  void _switchPhase(PomodoroPhase newPhase) {
    setState(() {
      _currentPhase = newPhase;
      _isRunning = false;
      _isPaused = false;
      _totalSecondsInPhase = switch (newPhase) {
        PomodoroPhase.work => _workMinutes * 60,
        PomodoroPhase.shortBreak => _shortBreakMinutes * 60,
        PomodoroPhase.longBreak => _longBreakMinutes * 60,
      };
      _remainingSeconds = _totalSecondsInPhase;
    });

    if (newPhase != PomodoroPhase.work) {
      _showBreakDialog(newPhase);
    } else {
      _showReturnToWorkDialog();
    }
  }

  void _showBreakDialog(PomodoroPhase phase) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        title: Row(
          children: [
            Icon(phase.icon, color: phase.color, size: 28),
            const SizedBox(width: 12),
            const Text('Break Time!', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          phase == PomodoroPhase.longBreak
              ? 'Great work! $_completedPomodoros pomodoros done. Take a longer break.'
              : 'Nice focus session! Take $_shortBreakMinutes minutes.',
          style: const TextStyle(color: Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _switchPhase(PomodoroPhase.work);
            },
            child: const Text('Skip Break'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _startTimer();
            },
            style: ElevatedButton.styleFrom(backgroundColor: phase.color),
            child: const Text('Start Break'),
          ),
        ],
      ),
    );
  }

  void _showReturnToWorkDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        title: Row(
          children: [
            Icon(PomodoroPhase.work.icon, color: PomodoroPhase.work.color, size: 28),
            const SizedBox(width: 12),
            const Text('Back to Focus!', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          'Break\'s over. Ready for pomodoro ${_completedPomodoros + 1}?',
          style: const TextStyle(color: Color(0xFF94A3B8)),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _startTimer();
            },
            style: ElevatedButton.styleFrom(backgroundColor: PomodoroPhase.work.color),
            child: const Text('Start Focus'),
          ),
        ],
      ),
    );
  }

  void _skipPhase() {
    _timer?.cancel();
    _pulseController.stop();
    if (_currentPhase == PomodoroPhase.work) {
      _completedPomodoros++;
      _showWorkCompleteDialog();
    } else {
      _switchPhase(PomodoroPhase.work);
    }
  }

  void _stopSession() {
    _timer?.cancel();
    _pulseController.stop();
    _showStopConfirmation();
  }

  void _showStopConfirmation() {
    final totalMinutes = (_totalWorkSeconds / 60).round();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        title: const Text('End Session?', style: TextStyle(color: Colors.white)),
        content: Text(
          'You\'ve completed $_completedPomodoros pomodoro${_completedPomodoros == 1 ? '' : 's'} ($totalMinutes minutes of focus).',
          style: const TextStyle(color: Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Keep Going'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _finishSession();
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('End & Log Session'),
          ),
        ],
      ),
    );
  }

  void _finishSession() {
    final totalMinutes = (_totalWorkSeconds / 60).round();
    final pageNavigator = Navigator.of(context);

    if (widget.session != null) {
      final updatedSession = widget.session!.copyWith(
        actualDurationMinutes: totalMinutes > 0 ? totalMinutes : 1,
      );

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => SessionCompletionDialog(
          session: updatedSession,
          onComplete: (completedSession) async {
            await _controller.updateStudySession(completedSession);
            if (!mounted) return;
            Navigator.of(dialogContext).pop();
            if (pageNavigator.canPop()) pageNavigator.pop();
          },
        ),
      );
    } else {
      _showSummaryAndClose(totalMinutes);
    }
  }

  void _showSummaryAndClose(int totalMinutes) {
    final pageNavigator = Navigator.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        title: const Text('Session Complete!', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.celebration, size: 48, color: Color(0xFFF59E0B)),
            const SizedBox(height: 16),
            Text(
              '$_completedPomodoros pomodoro${_completedPomodoros == 1 ? '' : 's'}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$totalMinutes minutes of focus time',
              style: const TextStyle(color: Color(0xFF94A3B8)),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              if (pageNavigator.canPop()) pageNavigator.pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showSettingsSheet() {
    if (_settingsLocked) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Timer Settings',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              _buildSettingSlider('Focus Duration', _workMinutes, 5, 60, 'min', PomodoroPhase.work.color, (val) {
                setSheetState(() => _workMinutes = val);
                setState(() {
                  _totalSecondsInPhase = _workMinutes * 60;
                  _remainingSeconds = _totalSecondsInPhase;
                });
              }),
              const SizedBox(height: 16),
              _buildSettingSlider('Short Break', _shortBreakMinutes, 1, 15, 'min', PomodoroPhase.shortBreak.color, (val) => setSheetState(() => _shortBreakMinutes = val)),
              const SizedBox(height: 16),
              _buildSettingSlider('Long Break', _longBreakMinutes, 5, 30, 'min', PomodoroPhase.longBreak.color, (val) => setSheetState(() => _longBreakMinutes = val)),
              const SizedBox(height: 16),
              _buildSettingSlider('Pomodoros before long break', _pomodorosBeforeLongBreak, 2, 6, '', const Color(0xFFF59E0B), (val) => setSheetState(() => _pomodorosBeforeLongBreak = val)),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingSlider(
      String label,
      int value,
      int min,
      int max,
      String suffix,
      Color color,
      ValueChanged<int> onChanged,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14)),
            Text('$value $suffix', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        Slider(
          value: value.toDouble(),
          min: min.toDouble(),
          max: max.toDouble(),
          divisions: max - min,
          activeColor: color,
          inactiveColor: color.withOpacity(0.2),
          onChanged: (val) => onChanged(val.round()),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = _totalSecondsInPhase > 0 ? 1.0 - (_remainingSeconds / _totalSecondsInPhase) : 0.0;
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    final timeString = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    final totalWorkMinutes = (_totalWorkSeconds / 60).round();

    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () {
                      if (_totalWorkSeconds > 0) {
                        _stopSession();
                      } else {
                        Navigator.pop(context);
                      }
                    },
                    icon: const Icon(Icons.close, color: Color(0xFF94A3B8)),
                  ),
                  if (widget.session != null)
                    Expanded(
                      child: Text(
                        widget.session!.title,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  IconButton(
                    onPressed: _settingsLocked ? null : _showSettingsSheet,
                    icon: Icon(Icons.tune, color: _settingsLocked ? const Color(0xFF334155) : const Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _currentPhase.color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _currentPhase.color.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_currentPhase.icon, color: _currentPhase.color, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    _currentPhase.displayName,
                    style: TextStyle(color: _currentPhase.color, fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            ScaleTransition(
              scale: _isRunning ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
              child: SizedBox(
                width: 260,
                height: 260,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 260,
                      height: 260,
                      child: CircularProgressIndicator(
                        value: 1.0,
                        strokeWidth: 8,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    SizedBox(
                      width: 260,
                      height: 260,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: progress),
                        duration: const Duration(milliseconds: 300),
                        builder: (context, value, child) => CircularProgressIndicator(
                          value: value,
                          strokeWidth: 8,
                          strokeCap: StrokeCap.round,
                          color: _currentPhase.color,
                        ),
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          timeString,
                          style: const TextStyle(
                            fontSize: 56,
                            fontWeight: FontWeight.w300,
                            color: Colors.white,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _currentPhase == PomodoroPhase.work ? 'Stay focused' : 'Relax',
                          style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pomodorosBeforeLongBreak, (index) {
                final isCompleted = index < _completedPomodoros % _pomodorosBeforeLongBreak;
                final isCurrent = index == _completedPomodoros % _pomodorosBeforeLongBreak && _currentPhase == PomodoroPhase.work;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  width: isCurrent ? 14 : 10,
                  height: isCurrent ? 14 : 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCompleted
                        ? PomodoroPhase.work.color
                        : isCurrent
                        ? PomodoroPhase.work.color.withOpacity(0.5)
                        : const Color(0xFF1E293B),
                    border: isCurrent ? Border.all(color: PomodoroPhase.work.color, width: 2) : null,
                  ),
                );
              }),
            ),
            const SizedBox(height: 8),
            Text(
              'Pomodoro ${_completedPomodoros + (_currentPhase == PomodoroPhase.work ? 1 : 0)}',
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMiniStat(Icons.local_fire_department, '$_completedPomodoros', 'Done', PomodoroPhase.work.color),
                  _buildMiniStat(Icons.timer, '$totalWorkMinutes', 'Minutes', const Color(0xFF3B82F6)),
                  _buildMiniStat(Icons.flag, '${_pomodorosBeforeLongBreak - (_completedPomodoros % _pomodorosBeforeLongBreak)}', 'To Break', const Color(0xFF10B981)),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (_isRunning || _isPaused)
                    _buildControlButton(Icons.skip_next, 'Skip', const Color(0xFF64748B), _skipPhase),
                  GestureDetector(
                    onTap: () {
                      if (_isRunning) {
                        _pauseTimer();
                      } else if (_isPaused) {
                        _resumeTimer();
                      } else {
                        _startTimer();
                      }
                    },
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _currentPhase.color,
                        boxShadow: [
                          BoxShadow(
                            color: _currentPhase.color.withOpacity(0.4),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(_isRunning ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 36),
                    ),
                  ),
                  if (_isRunning || _isPaused)
                    _buildControlButton(Icons.stop, 'End', const Color(0xFFEF4444), _stopSession),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.15),
              border: Border.all(color: color.withOpacity(0.4)),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(color: color, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
      ],
    );
  }
}