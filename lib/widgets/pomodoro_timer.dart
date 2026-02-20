import 'dart:async';
import 'package:flutter/material.dart';

class PomodoroTimer extends StatefulWidget {
  final String moduleName;
  const PomodoroTimer({super.key, required this.moduleName});

  @override
  State<PomodoroTimer> createState() => _PomodoroTimerState();
}

class _PomodoroTimerState extends State<PomodoroTimer>
    with SingleTickerProviderStateMixin {

  static const int _focusMins        = 25;
  static const int _shortBreak       = 5;
  static const int _longBreak        = 15;
  static const int _cyclesBeforeLong = 4;

  Timer? _timer;
  int  _secondsLeft  = _focusMins * 60;
  int  _cycleCount   = 0;
  bool _isRunning    = false;
  bool _isFocusMode  = true;

  late AnimationController _pulseCtrl;
  late Animation<double>   _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 1));
    _pulseAnim = Tween(begin: 1.0, end: 1.05).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _start() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_secondsLeft == 0) {
        _onTimerEnd();
      } else {
        setState(() => _secondsLeft--);
      }
    });
    setState(() => _isRunning = true);
    _pulseCtrl.repeat(reverse: true);
  }

  void _pause() {
    _timer?.cancel();
    setState(() => _isRunning = false);
    _pulseCtrl.stop();
  }

  void _reset() {
    _timer?.cancel();
    setState(() {
      _isRunning   = false;
      _isFocusMode = true;
      _secondsLeft = _focusMins * 60;
      _cycleCount  = 0;
    });
    _pulseCtrl.stop();
  }

  void _onTimerEnd() {
    _timer?.cancel();
    _pulseCtrl.stop();

    if (_isFocusMode) {
      _cycleCount++;
      final isLong = _cycleCount % _cyclesBeforeLong == 0;
      setState(() {
        _isFocusMode = false;
        _secondsLeft = (isLong ? _longBreak : _shortBreak) * 60;
        _isRunning   = false;
      });
      _showEndDialog(
        title: isLong ? '🎉 Long break!' : '☕ Short break!',
        message: isLong
            ? 'You completed $_cycleCount cycles. Take $_longBreak minutes.'
            : 'Good work! Take $_shortBreak minutes.',
      );
    } else {
      setState(() {
        _isFocusMode = true;
        _secondsLeft = _focusMins * 60;
        _isRunning   = false;
      });
      _showEndDialog(
        title: '🎯 Break over!',
        message: 'Ready for the next focus session?',
      );
    }
  }

  void _showEndDialog({required String title, required String message}) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(context); _start(); },
            child: const Text('Start next',
                style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Rest',
                style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );
  }

  String get _timeLabel {
    final m = _secondsLeft ~/ 60;
    final s = _secondsLeft  % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  double get _progress {
    final total = _isFocusMode
        ? _focusMins * 60
        : (_cycleCount % _cyclesBeforeLong == 0 ? _longBreak : _shortBreak) * 60;
    return 1 - (_secondsLeft / total);
  }

  Color get _modeColor =>
      _isFocusMode ? const Color(0xFF3B82F6) : const Color(0xFF10B981);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [

        Container(
          width: 40, height: 4,
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(999)),
        ),

        Text(widget.moduleName,
            style: const TextStyle(color: Colors.white54, fontSize: 13)),
        const SizedBox(height: 4),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: _modeColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _isFocusMode ? 'Focus' : 'Break',
            style: TextStyle(
                color: _modeColor, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 28),

        ScaleTransition(
          scale: _isRunning
              ? _pulseAnim
              : const AlwaysStoppedAnimation(1.0),
          child: SizedBox(
            width: 180, height: 180,
            child: Stack(alignment: Alignment.center, children: [
              SizedBox(
                width: 180, height: 180,
                child: CircularProgressIndicator(
                  value: _progress,
                  strokeWidth: 8,
                  backgroundColor: Colors.white10,
                  valueColor: AlwaysStoppedAnimation(_modeColor),
                ),
              ),
              Text(_timeLabel,
                  style: const TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ]),
          ),
        ),
        const SizedBox(height: 8),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_cyclesBeforeLong, (i) => Container(
            width: 8, height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < (_cycleCount % _cyclesBeforeLong)
                  ? _modeColor
                  : Colors.white12,
            ),
          )),
        ),
        const SizedBox(height: 28),

        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(
            onPressed: _reset,
            icon: const Icon(Icons.refresh,
                color: Colors.white38, size: 28),
          ),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: _isRunning ? _pause : _start,
            child: Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: _modeColor,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(
                    color: _modeColor.withOpacity(0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 4))],
              ),
              child: Icon(
                _isRunning ? Icons.pause : Icons.play_arrow,
                color: Colors.white, size: 32,
              ),
            ),
          ),
          const SizedBox(width: 16),
          IconButton(
            onPressed: _onTimerEnd,
            icon: const Icon(Icons.skip_next,
                color: Colors.white38, size: 28),
          ),
        ]),
        const SizedBox(height: 8),

        Text(
          'Cycle ${(_cycleCount % _cyclesBeforeLong) + 1} of $_cyclesBeforeLong',
          style: const TextStyle(color: Colors.white38, fontSize: 12),
        ),
      ]),
    );
  }
}
