import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../controllers/timetable_controller.dart';
import '../models/study_session.dart';

class StudySessionDialog extends StatefulWidget {
  final StudySession? session;
  final DateTime? initialDate;
  final TimeOfDay? initialStartTime;
  final double? maxDurationMinutes;

  const StudySessionDialog({
    super.key,
    this.session,
    this.initialDate,
    this.initialStartTime,
    this.maxDurationMinutes,
  });

  @override
  State<StudySessionDialog> createState() => _StudySessionDialogState();
}

class _StudySessionDialogState extends State<StudySessionDialog> {
  final TimetableController _controller = TimetableController();
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  
  late DateTime _selectedDate;
  late TimeOfDay _startTime;
  late double _durationMinutes;
  late StudySessionType _selectedType;
  String? _selectedModuleCode;
  
  bool _hasConflict = false;
  String? _conflictMessage;

  @override
  void initState() {
    super.initState();
    
    if (widget.session != null) {
      // Edit mode
      _titleController.text = widget.session!.title;
      _selectedDate = DateTime(
        widget.session!.startTime.year,
        widget.session!.startTime.month,
        widget.session!.startTime.day,
      );
      _startTime = TimeOfDay.fromDateTime(widget.session!.startTime);
      _durationMinutes = widget.session!.durationMinutes.toDouble();
      _selectedType = widget.session!.type;
      _selectedModuleCode = widget.session!.moduleCode;
    } else {
      // Create mode
      _selectedDate = widget.initialDate ?? DateTime.now();
      
      if (widget.initialStartTime != null) {
        _startTime = widget.initialStartTime!;
      } else {
        final now = DateTime.now();
        // Round to nearest 15 minutes
        final roundedMinute = ((now.minute + 14) ~/ 15) * 15;
        _startTime = TimeOfDay(
          hour: now.minute > 45 ? now.hour + 1 : now.hour,
          minute: roundedMinute % 60,
        );
      }
      
      _durationMinutes = 60;
      _selectedType = StudySessionType.revision;
    }
    
    _checkConflict();
  }

  void _checkConflict() {
    final startDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _startTime.hour,
      _startTime.minute,
    );
    final endDateTime = startDateTime.add(Duration(minutes: _durationMinutes.toInt()));
    
    final hasConflict = _controller.hasConflict(
      startDateTime,
      endDateTime,
      excludeSessionId: widget.session?.id,
    );
    
    setState(() {
      _hasConflict = hasConflict;
      _conflictMessage = hasConflict 
        ? 'This time conflicts with another event or session'
        : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.session != null;
    final timeFormat = DateFormat('HH:mm');
    
    return AlertDialog(
      title: Text(isEdit ? 'Edit Study Session' : 'Create Study Session'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: StatefulBuilder(
            builder: (context, setDialogState) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title field
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    hintText: 'e.g., Review Chapter 3',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a title';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 16),
                
                // Date picker
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime.now().subtract(const Duration(days: 365)),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (date != null) {
                            setDialogState(() {
                              _selectedDate = date;
                            });
                            _checkConflict();
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Date',
                            prefixIcon: Icon(Icons.calendar_today),
                          ),
                          child: Text(
                            DateFormat('MMM d, yyyy').format(_selectedDate),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Time picker
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: _startTime,
                          );
                          if (time != null) {
                            setDialogState(() {
                              _startTime = time;
                            });
                            _checkConflict();
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Start Time',
                            prefixIcon: Icon(Icons.access_time),
                          ),
                          child: Text(
                            _startTime.format(context),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Duration slider
                Text(
                  'Duration: ${_durationMinutes.toInt()} minutes',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Slider(
                  value: _durationMinutes,
                  min: 30,
                  max: widget.maxDurationMinutes ?? 180,
                  divisions: ((widget.maxDurationMinutes ?? 180) - 30) ~/ 15,
                  label: '${_durationMinutes.toInt()} min',
                  onChanged: (value) {
                    // Round to nearest 15
                    final rounded = (value / 15).round() * 15;
                    setDialogState(() {
                      _durationMinutes = rounded.toDouble();
                    });
                    _checkConflict();
                  },
                ),
                
                const SizedBox(height: 16),
                
                // Session type
                Text(
                  'Session Type',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: StudySessionType.values.map((type) {
                    final isSelected = _selectedType == type;
                    return ChoiceChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            type.icon,
                            size: 16,
                            color: isSelected ? Colors.white : type.color,
                          ),
                          const SizedBox(width: 6),
                          Text(type.displayName),
                        ],
                      ),
                      selected: isSelected,
                      selectedColor: type.color,
                      onSelected: (selected) {
                        if (selected) {
                          setDialogState(() {
                            _selectedType = type;
                          });
                        }
                      },
                    );
                  }).toList(),
                ),
                
                const SizedBox(height: 16),
                
                // Module selection (optional)
                if (_controller.getModuleCodes().isNotEmpty) ...[
                  Text(
                    'Module (Optional)',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String?>(
                    value: _selectedModuleCode,
                    decoration: const InputDecoration(
                      hintText: 'Select a module',
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('None'),
                      ),
                      ..._controller.getModuleCodes().map((code) {
                        return DropdownMenuItem(
                          value: code,
                          child: Text(code),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setDialogState(() {
                        _selectedModuleCode = value;
                      });
                    },
                  ),
                ],
                
                // Conflict warning
                if (_hasConflict) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFEF4444).withOpacity(0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning,
                          color: Color(0xFFEF4444),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _conflictMessage ?? 'Time conflict detected',
                            style: const TextStyle(
                              color: Color(0xFFEF4444),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                // Time preview
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.schedule,
                        size: 16,
                        color: Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${timeFormat.format(DateTime(2024, 1, 1, _startTime.hour, _startTime.minute))} - ${timeFormat.format(DateTime(2024, 1, 1, _startTime.hour, _startTime.minute).add(Duration(minutes: _durationMinutes.toInt())))}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _hasConflict ? null : _saveSession,
          child: Text(isEdit ? 'Save' : 'Create'),
        ),
      ],
    );
  }

  Future<void> _saveSession() async {
    if (!_formKey.currentState!.validate()) return;

    final startDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _startTime.hour,
      _startTime.minute,
    );

    final session = StudySession(
      id: widget.session?.id,
      title: _titleController.text,
      type: _selectedType,
      startTime: startDateTime,
      durationMinutes: _durationMinutes.toInt(),
      isCompleted: widget.session?.isCompleted ?? false,
      moduleCode: _selectedModuleCode,
    );

    if (widget.session != null) {
      await _controller.updateStudySession(session);
    } else {
      await _controller.addStudySession(session);
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }
}
