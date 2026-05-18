import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../controllers/timetable_controller.dart';
import '../models/deadline.dart';

class DeadlineDialog extends StatefulWidget {
  final Deadline? deadline; // null = create, non-null = edit

  const DeadlineDialog({
    super.key,
    this.deadline,
  });

  @override
  State<DeadlineDialog> createState() => _DeadlineDialogState();
}

class _DeadlineDialogState extends State<DeadlineDialog> {
  final TimetableController _controller = TimetableController();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _estimatedHoursController;

  late DateTime _dueDate;
  late TimeOfDay _dueTime;
  late DeadlinePriority _priority;
  late DeadlineStatus _status;
  String? _selectedModuleCode;

  bool get isEdit => widget.deadline != null;

  @override
  void initState() {
    super.initState();
    final d = widget.deadline;
    _titleController = TextEditingController(text: d?.title ?? '');
    _descriptionController = TextEditingController(text: d?.description ?? '');
    _estimatedHoursController = TextEditingController(
      text: d != null && d.estimatedHours > 0
          ? d.estimatedHours.toString()
          : '',
    );
    _dueDate = d?.dueDate ?? DateTime.now().add(const Duration(days: 7));
    _dueTime = d != null
        ? TimeOfDay.fromDateTime(d.dueDate)
        : const TimeOfDay(hour: 23, minute: 59);
    _priority = d?.priority ?? DeadlinePriority.medium;
    _status = d?.status ?? DeadlineStatus.todo;
    _selectedModuleCode = d?.moduleCode;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _estimatedHoursController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEE, MMM d, yyyy');

    return AlertDialog(
      backgroundColor: const Color(0xFF0F172A),
      title: Text(
        isEdit ? 'Edit Deadline' : 'New Deadline',
        style: const TextStyle(color: Colors.white),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                TextFormField(
                  controller: _titleController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    hintText: 'e.g., Distributed Systems Coursework',
                    prefixIcon: Icon(Icons.assignment),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a title';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Description
                TextFormField(
                  controller: _descriptionController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Description (Optional)',
                    hintText: 'Details, requirements, notes...',
                    prefixIcon: Icon(Icons.notes),
                  ),
                  maxLines: 3,
                ),

                const SizedBox(height: 16),

                // Due Date
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: GestureDetector(
                        onTap: _pickDate,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Due Date',
                            prefixIcon: Icon(Icons.calendar_today),
                          ),
                          child: Text(
                            dateFormat.format(_dueDate),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: GestureDetector(
                        onTap: _pickTime,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Time',
                            prefixIcon: Icon(Icons.access_time),
                          ),
                          child: Text(
                            _dueTime.format(context),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Priority
                const Text(
                  'Priority',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: DeadlinePriority.values.map((p) {
                    final isSelected = _priority == p;
                    return ChoiceChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(p.icon, size: 16, color: isSelected ? Colors.white : p.color),
                          const SizedBox(width: 6),
                          Text(p.displayName),
                        ],
                      ),
                      selected: isSelected,
                      selectedColor: p.color,
                      onSelected: (_) => setState(() => _priority = p),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),

                // Status (only show when editing)
                if (isEdit) ...[
                  const Text(
                    'Status',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: DeadlineStatus.values.map((s) {
                      final isSelected = _status == s;
                      return ChoiceChip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(s.icon, size: 16, color: isSelected ? Colors.white : s.color),
                            const SizedBox(width: 6),
                            Text(s.displayName),
                          ],
                        ),
                        selected: isSelected,
                        selectedColor: s.color,
                        onSelected: (_) => setState(() => _status = s),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],

                // Estimated Hours
                TextFormField(
                  controller: _estimatedHoursController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Estimated Hours (Optional)',
                    hintText: 'e.g., 10',
                    prefixIcon: Icon(Icons.hourglass_empty),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value != null && value.isNotEmpty) {
                      final parsed = double.tryParse(value);
                      if (parsed == null || parsed < 0) {
                        return 'Enter a valid number';
                      }
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Module selection
                if (_controller.getModuleCodes().isNotEmpty) ...[
                  DropdownButtonFormField<String?>(
                    value: _selectedModuleCode,
                    decoration: const InputDecoration(
                      labelText: 'Module (Optional)',
                      prefixIcon: Icon(Icons.school),
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
                      setState(() => _selectedModuleCode = value);
                    },
                  ),
                ],

                // Due date preview
                const SizedBox(height: 16),
                _buildDuePreview(),
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
        if (isEdit)
          TextButton(
            onPressed: _delete,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFEF4444),
            ),
            child: const Text('Delete'),
          ),
        TextButton(
          onPressed: _save,
          child: Text(isEdit ? 'Save' : 'Create'),
        ),
      ],
    );
  }

  Widget _buildDuePreview() {
    final fullDueDate = DateTime(
      _dueDate.year,
      _dueDate.month,
      _dueDate.day,
      _dueTime.hour,
      _dueTime.minute,
    );
    final remaining = fullDueDate.difference(DateTime.now());
    final isOverdue = remaining.isNegative;

    String text;
    if (isOverdue) {
      text = '${-remaining.inDays} days overdue';
    } else if (remaining.inDays == 0) {
      text = 'Due today — ${remaining.inHours} hours left';
    } else if (remaining.inDays == 1) {
      text = 'Due tomorrow';
    } else {
      text = '${remaining.inDays} days remaining';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isOverdue
            ? const Color(0xFFEF4444).withOpacity(0.15)
            : const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8),
        border: isOverdue
            ? Border.all(color: const Color(0xFFEF4444).withOpacity(0.5))
            : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isOverdue ? Icons.warning : Icons.schedule,
            size: 16,
            color: isOverdue ? const Color(0xFFEF4444) : const Color(0xFF94A3B8),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: isOverdue ? const Color(0xFFEF4444) : Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _dueTime,
    );
    if (picked != null) {
      setState(() => _dueTime = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final fullDueDate = DateTime(
      _dueDate.year,
      _dueDate.month,
      _dueDate.day,
      _dueTime.hour,
      _dueTime.minute,
    );

    final hours = double.tryParse(_estimatedHoursController.text) ?? 0;

    final deadline = Deadline(
      id: widget.deadline?.id,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      moduleCode: _selectedModuleCode,
      dueDate: fullDueDate,
      priority: _priority,
      status: _status,
      estimatedHours: hours,
      createdAt: widget.deadline?.createdAt ?? DateTime.now(),
      completedAt: _status == DeadlineStatus.completed
          ? (widget.deadline?.completedAt ?? DateTime.now())
          : null,
    );

    if (isEdit) {
      await _controller.updateDeadline(deadline);
    } else {
      await _controller.addDeadline(deadline);
    }

    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        title: const Text('Delete Deadline', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to delete "${widget.deadline!.title}"?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFEF4444)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _controller.deleteDeadline(widget.deadline!.id);
      if (mounted) Navigator.pop(context);
    }
  }
}