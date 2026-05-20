// lib/widgets/event_location_dialog.dart

import 'package:flutter/material.dart';
import '../controllers/timetable_controller.dart';
import '../models/event.dart';
import '../navigation_state.dart';
import '../pages/home_screen.dart';

class EventLocationDialog extends StatefulWidget {
  final CalendarEvent event;

  const EventLocationDialog({
    super.key,
    required this.event,
  });

  @override
  State<EventLocationDialog> createState() => _EventLocationDialogState();
}

class _EventLocationDialogState extends State<EventLocationDialog> {
  final TimetableController _controller = TimetableController();
  final _locationController = TextEditingController();
  bool _isEditing = false;

  // The currently saved location — updated after a successful save
  String? _savedLocation;

  @override
  void initState() {
    super.initState();
    // Load from the event_locations table first, fall back to event.location
    _savedLocation = _controller.getEventLocation(widget.event.id)
        ?? widget.event.location;
    _locationController.text = _savedLocation ?? '';
    _isEditing = _savedLocation == null || _savedLocation!.isEmpty;
  }

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  bool get _hasLocation =>
      _savedLocation != null && _savedLocation!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final moduleColor = _controller.getModuleColor(widget.event.moduleCode);

    return AlertDialog(
      backgroundColor: const Color(0xFF0F172A),
      title: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: moduleColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.event.title,
              style: const TextStyle(fontSize: 18, color: Colors.white),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Start', _formatTime(widget.event.startTime)),
            _buildDetailRow('End', _formatTime(widget.event.endTime)),
            _buildDetailRow(
                'Duration', _formatDuration(widget.event.duration)),
            if (widget.event.moduleCode != null)
              _buildDetailRow('Module', widget.event.moduleCode!),

            const Divider(height: 24, color: Color(0xFF1E293B)),

            // Location section
            if (_isEditing) ...[
              const Text(
                'Building location',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _locationController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText:
                  'e.g. Richmond Building, Portsmouth',
                  prefixIcon: Icon(Icons.location_on),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 8),
              // Hint box
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: const Color(0xFF3B82F6).withOpacity(0.3)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline,
                        size: 14, color: Color(0xFF3B82F6)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Include the city to get accurate directions. '
                            'For example:\n'
                            '• Richmond Building, Portsmouth\n'
                            '• Portland Building, Portsmouth\n'
                            '• Lion Gate Building, Portsmouth',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF94A3B8),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Row(
                children: [
                  const Icon(Icons.location_on,
                      size: 20, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _savedLocation!,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Navigate button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _navigateToLocation(context),
                  icon: const Icon(Icons.directions, size: 18),
                  label: const Text('Navigate to this building'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (_isEditing) ...[
          TextButton(
            onPressed: () {
              if (_hasLocation) {
                // Cancel edit — restore saved value
                setState(() {
                  _isEditing = false;
                  _locationController.text = _savedLocation!;
                });
              } else {
                Navigator.pop(context);
              }
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: _saveLocation,
            child: const Text('Save'),
          ),
        ] else ...[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () => setState(() => _isEditing = true),
            child: const Text('Edit Location'),
          ),
        ],
      ],
    );
  }

  void _navigateToLocation(BuildContext context) {
    final destination = MapDestination(
      name: _savedLocation!,
      address: _savedLocation!,
    );
    Navigator.pop(context);
    homeScreenKey.currentState?.navigateToMap(destination);
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF94A3B8))),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 14, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (hours > 0 && minutes > 0) return '${hours}h ${minutes}m';
    if (hours > 0) return '${hours}h';
    return '${minutes}m';
  }

  Future<void> _saveLocation() async {
    final location = _locationController.text.trim();
    if (location.isEmpty) return;

    await _controller.updateEventLocation(widget.event.id, location);

    // Update local state so the dialog immediately shows the new value
    // and the Navigate button uses the updated address
    setState(() {
      _savedLocation = location;
      _isEditing = false;
    });
  }
}