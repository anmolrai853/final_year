// lib/widgets/event_location_dialog.dart

import 'package:flutter/material.dart';
import '../controllers/timetable_controller.dart';
import '../models/event.dart';
import '../navigation_state.dart';
import '../pages/home_screen.dart' as hs;

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

  @override
  void initState() {
    super.initState();
    _locationController.text = widget.event.location ?? '';
    _isEditing =
        widget.event.location == null || widget.event.location!.isEmpty;
  }

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final moduleColor = _controller.getModuleColor(widget.event.moduleCode);
    final hasLocation =
        widget.event.location != null && widget.event.location!.isNotEmpty;

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
            _buildDetailRow('Duration', _formatDuration(widget.event.duration)),
            if (widget.event.moduleCode != null)
              _buildDetailRow('Module', widget.event.moduleCode!),

            const Divider(height: 24, color: Color(0xFF1E293B)),

            if (_isEditing) ...[
              TextField(
                controller: _locationController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Location',
                  hintText: 'e.g., Park Building, Portsmouth',
                  prefixIcon: Icon(Icons.location_on),
                ),
                autofocus: true,
              ),
            ] else ...[
              Row(
                children: [
                  const Icon(Icons.location_on,
                      size: 20, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.event.location ?? 'No location set',
                      style: TextStyle(
                        fontSize: 16,
                        color: hasLocation
                            ? Colors.white
                            : const Color(0xFF64748B),
                        fontStyle: hasLocation
                            ? FontStyle.normal
                            : FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),

              // Navigate button — only when location is set
              if (hasLocation) ...[
                const SizedBox(height: 16),
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
          ],
        ),
      ),
      actions: [
        if (_isEditing) ...[
          TextButton(
            onPressed: () {
              if (hasLocation) {
                setState(() {
                  _isEditing = false;
                  _locationController.text = widget.event.location!;
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
      name: widget.event.location!,
      address: widget.event.location!,
    );
    Navigator.pop(context);
    hs.homeScreenKey.currentState?.navigateToMap(destination);
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
                style: const TextStyle(
                    fontSize: 14, color: Colors.white)),
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
    if (location.isNotEmpty) {
      await _controller.updateEventLocation(widget.event.id, location);
    }
    if (mounted) Navigator.pop(context);
  }
}