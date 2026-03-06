import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/event.dart';

class NextEventCard extends StatelessWidget {
  final CalendarEvent? event;
  final Function(CalendarEvent)? onLocationTap;

  const NextEventCard({
    super.key,
    this.event,
    this.onLocationTap,
  });

  @override
  Widget build(BuildContext context) {
    if (event == null) {
      return _buildNoEventCard();
    }

    final timeFormat = DateFormat('HH:mm');
    final dateFormat = DateFormat('EEEE, MMM d');
    final now = DateTime.now();
    
    final isToday = event!.startTime.year == now.year &&
                   event!.startTime.month == now.month &&
                   event!.startTime.day == now.day;
    
    final timeUntil = event!.startTime.difference(now);
    String timeUntilText;
    
    if (timeUntil.inMinutes < 0) {
      timeUntilText = 'In progress';
    } else if (timeUntil.inMinutes < 60) {
      timeUntilText = 'In ${timeUntil.inMinutes} minutes';
    } else if (timeUntil.inHours < 24) {
      timeUntilText = 'In ${timeUntil.inHours} hours';
    } else {
      timeUntilText = 'In ${timeUntil.inDays} days';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF3B82F6),
            const Color(0xFF8B5CF6).withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 14,
                      color: Colors.white,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Next Event',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                timeUntilText,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Event title
          Text(
            event!.title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          
          const SizedBox(height: 12),
          
          // Event details
          Row(
            children: [
              // Time
              Expanded(
                child: _buildDetailItem(
                  Icons.schedule,
                  '${timeFormat.format(event!.startTime)} - ${timeFormat.format(event!.endTime)}',
                ),
              ),
              
              // Date
              Expanded(
                child: _buildDetailItem(
                  Icons.calendar_today,
                  isToday ? 'Today' : dateFormat.format(event!.startTime),
                ),
              ),
            ],
          ),
          
          // Location (if available)
          if (event!.location != null && event!.location!.isNotEmpty) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => onLocationTap?.call(event!),
              child: Row(
                children: [
                  Icon(
                    Icons.location_on,
                    size: 16,
                    color: Colors.white.withOpacity(0.8),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      event!.location!,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.9),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    Icons.edit,
                    size: 14,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => onLocationTap?.call(event!),
              child: Row(
                children: [
                  Icon(
                    Icons.add_location,
                    size: 16,
                    color: Colors.white.withOpacity(0.6),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Add location',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.7),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNoEventCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF1E293B),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.event_available,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No upcoming events',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Import your timetable to see events',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: Colors.white.withOpacity(0.8),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withOpacity(0.9),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
