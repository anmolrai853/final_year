import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../controllers/timetable_controller.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import 'dart:convert';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TimetableController _controller = TimetableController();
  final StorageService _storageService = StorageService();
  final NotificationService _notificationService = NotificationService();

  bool _isLoading = false;

  // Notification preferences (loaded from storage)
  late NotificationPreferences _notifPrefs;
  bool _notifPrefsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadNotificationPrefs();
  }

  void _loadNotificationPrefs() {
    final saved = _storageService.loadNotificationPrefs();
    if (saved != null) {
      _notifPrefs = NotificationPreferences.fromJson(saved);
    } else {
      _notifPrefs = NotificationPreferences();
    }
    setState(() => _notifPrefsLoaded = true);
  }

  Future<void> _saveNotificationPrefs() async {
    await _storageService.saveNotificationPrefs(_notifPrefs.toJson());
    // Reschedule all notifications with new preferences
    await _notificationService.rescheduleAll(
      events: _storageService.loadCalendarEvents(),
      sessions: _storageService.loadStudySessions(),
      deadlines: _storageService.loadDeadlines(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Text(
                'Settings',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 24),

              // Timetable section
              _buildSectionTitle('Timetable'),
              const SizedBox(height: 12),
              _buildSettingCard(
                icon: Icons.upload_file,
                title: 'Import .ics File',
                subtitle: 'Upload your university timetable',
                onTap: _importIcsFile,
                isLoading: _isLoading,
              ),
              _buildSettingCard(
                icon: Icons.refresh,
                title: 'Refresh Timetable',
                subtitle: 'Reload events from saved data',
                onTap: _refreshTimetable,
              ),

              const SizedBox(height: 24),

              // Notifications section
              if (_notifPrefsLoaded) ...[
                _buildSectionTitle('Notifications'),
                const SizedBox(height: 12),
                _buildNotificationSettings(),
                const SizedBox(height: 24),
              ],

              // Data section
              _buildSectionTitle('Data Management'),
              const SizedBox(height: 12),
              _buildSettingCard(
                icon: Icons.delete_outline,
                title: 'Clear Study Sessions',
                subtitle: 'Delete all study session data',
                onTap: _clearStudySessions,
                isDestructive: true,
              ),
              _buildSettingCard(
                icon: Icons.delete_forever,
                title: 'Clear All Data',
                subtitle: 'Delete all app data including timetable',
                onTap: _clearAllData,
                isDestructive: true,
              ),

              const SizedBox(height: 24),

              // About section
              _buildSectionTitle('About'),
              const SizedBox(height: 12),
              _buildInfoCard(
                icon: Icons.info_outline,
                title: 'Student Planner',
                subtitle: 'Version 1.0.0',
              ),
              _buildInfoCard(
                icon: Icons.code,
                title: 'Built with Flutter',
                subtitle: 'Using icalendar_parser & shared_preferences',
              ),

              const SizedBox(height: 32),

              // Stats
              _buildStatsSection(),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== NOTIFICATION SETTINGS ====================

  Widget _buildNotificationSettings() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Class reminders
          _buildNotificationToggle(
            icon: Icons.school,
            title: 'Class Reminders',
            subtitle: _notifPrefs.classRemindersEnabled
                ? '${_notifPrefs.classReminderMinutes} min before class'
                : 'Disabled',
            value: _notifPrefs.classRemindersEnabled,
            onChanged: (val) {
              setState(() => _notifPrefs.classRemindersEnabled = val);
              _saveNotificationPrefs();
            },
            onTap: _notifPrefs.classRemindersEnabled
                ? () => _showReminderTimePicker(
              'Class Reminder',
              _notifPrefs.classReminderMinutes,
                  (minutes) {
                setState(() => _notifPrefs.classReminderMinutes = minutes);
                _saveNotificationPrefs();
              },
            )
                : null,
          ),

          const Divider(color: Color(0xFF1E293B), height: 1, indent: 16, endIndent: 16),

          // Study session reminders
          _buildNotificationToggle(
            icon: Icons.menu_book,
            title: 'Study Session Reminders',
            subtitle: _notifPrefs.sessionRemindersEnabled
                ? '${_notifPrefs.sessionReminderMinutes} min before session'
                : 'Disabled',
            value: _notifPrefs.sessionRemindersEnabled,
            onChanged: (val) {
              setState(() => _notifPrefs.sessionRemindersEnabled = val);
              _saveNotificationPrefs();
            },
            onTap: _notifPrefs.sessionRemindersEnabled
                ? () => _showReminderTimePicker(
              'Session Reminder',
              _notifPrefs.sessionReminderMinutes,
                  (minutes) {
                setState(() => _notifPrefs.sessionReminderMinutes = minutes);
                _saveNotificationPrefs();
              },
            )
                : null,
          ),

          const Divider(color: Color(0xFF1E293B), height: 1, indent: 16, endIndent: 16),

          // Deadline warnings
          _buildNotificationToggle(
            icon: Icons.flag,
            title: 'Deadline Warnings',
            subtitle: _notifPrefs.deadlineRemindersEnabled
                ? 'At ${_notifPrefs.deadlineReminderDays.map((d) => d == 1 ? "1 day" : "$d days").join(", ")} before'
                : 'Disabled',
            value: _notifPrefs.deadlineRemindersEnabled,
            onChanged: (val) {
              setState(() => _notifPrefs.deadlineRemindersEnabled = val);
              _saveNotificationPrefs();
            },
            onTap: _notifPrefs.deadlineRemindersEnabled
                ? () => _showDeadlineWarningPicker()
                : null,
          ),

          // Test notification button
          const Divider(color: Color(0xFF1E293B), height: 1, indent: 16, endIndent: 16),
          ListTile(
            leading: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.notifications_active, color: Color(0xFF10B981)),
            ),
            title: const Text('Test Notification', style: TextStyle(color: Colors.white)),
            subtitle: const Text('Send a test to verify it works', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
            onTap: _sendTestNotification,
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationToggle({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFF3B82F6).withOpacity(0.2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: const Color(0xFF3B82F6)),
      ),
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
      subtitle: GestureDetector(
        onTap: onTap,
        child: Text(
          subtitle + (onTap != null ? '  ✎' : ''),
          style: TextStyle(
            color: onTap != null ? const Color(0xFF3B82F6) : const Color(0xFF94A3B8),
            fontSize: 13,
          ),
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFF3B82F6),
      ),
    );
  }

  void _showReminderTimePicker(String title, int currentMinutes, ValueChanged<int> onChanged) {
    final options = [5, 10, 15, 20, 30, 45, 60];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: options.map((mins) {
            final isSelected = mins == currentMinutes;
            return ListTile(
              title: Text(
                '$mins minutes before',
                style: TextStyle(color: isSelected ? const Color(0xFF3B82F6) : Colors.white),
              ),
              trailing: isSelected ? const Icon(Icons.check, color: Color(0xFF3B82F6)) : null,
              onTap: () {
                onChanged(mins);
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showDeadlineWarningPicker() {
    final allOptions = [1, 3, 7, 14];
    var selected = List<int>.from(_notifPrefs.deadlineReminderDays);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          title: const Text('Deadline Warnings', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Send warnings before deadlines at:',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              ),
              const SizedBox(height: 12),
              ...allOptions.map((days) {
                final isSelected = selected.contains(days);
                return CheckboxListTile(
                  value: isSelected,
                  title: Text(
                    days == 1 ? '1 day before' : '$days days before',
                    style: const TextStyle(color: Colors.white),
                  ),
                  activeColor: const Color(0xFF3B82F6),
                  onChanged: (val) {
                    setDialogState(() {
                      if (val == true) {
                        selected.add(days);
                      } else {
                        selected.remove(days);
                      }
                    });
                  },
                );
              }),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                selected.sort();
                setState(() => _notifPrefs.deadlineReminderDays = selected);
                _saveNotificationPrefs();
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendTestNotification() async {
    final granted = await _notificationService.requestPermissions();
    if (!granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification permission denied. Please enable in system settings.'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
      }
      return;
    }

    // Schedule a notification 3 seconds from now using the plugin directly
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.show(
      0,
      'Test Notification',
      'Notifications are working! You\'ll get reminders for classes, sessions, and deadlines.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'test_channel',
          'Test Notifications',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Test notification sent!'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    }
  }

  // ==================== EXISTING SETTINGS WIDGETS ====================

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Color(0xFF94A3B8),
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildSettingCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isLoading = false,
    bool isDestructive = false,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: const Color(0xFF0F172A),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: isDestructive
                ? const Color(0xFFEF4444).withOpacity(0.2)
                : const Color(0xFF3B82F6).withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: isLoading
              ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)))))
              : Icon(icon, color: isDestructive ? const Color(0xFFEF4444) : const Color(0xFF3B82F6)),
        ),
        title: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: isDestructive ? const Color(0xFFEF4444) : Colors.white)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
        trailing: const Icon(Icons.chevron_right, color: Color(0xFF64748B)),
        onTap: isLoading ? null : onTap,
      ),
    );
  }

  Widget _buildInfoCard({required IconData icon, required String title, required String subtitle}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: const Color(0xFF0F172A),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: const Color(0xFF64748B)),
        ),
        title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
      ),
    );
  }

  Widget _buildStatsSection() {
    final sessions = _storageService.loadStudySessions();
    final maps = _storageService.loadKnowledgeMaps();
    final events = _storageService.loadCalendarEvents();
    final deadlines = _storageService.loadDeadlines();

    int totalNodes = 0;
    for (final map in maps) {
      final data = _storageService.getKnowledgeGraphData(map.id);
      totalNodes += data?.nodes.length ?? 0;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Statistics', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('Events', '${events.length}', Icons.event),
              _buildStatItem('Sessions', '${sessions.length}', Icons.menu_book),
              _buildStatItem('Deadlines', '${deadlines.length}', Icons.flag),
              _buildStatItem('Maps', '${maps.length}', Icons.account_tree),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF3B82F6), size: 24),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
      ],
    );
  }

  // ==================== ACTIONS ====================

  Future<void> _importIcsFile() async {
    setState(() => _isLoading = true);

    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['ics'], withData: true);

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes == null) throw Exception('File bytes are null');
        final content = utf8.decode(file.bytes!);
        if (!content.contains('BEGIN:VCALENDAR')) throw Exception('File does not appear to be a valid ICS file');

        await _controller.loadFromIcs(content);

        // Schedule class notifications for imported events
        final events = _storageService.loadCalendarEvents();
        await _notificationService.rescheduleAll(
          events: events,
          sessions: _storageService.loadStudySessions(),
          deadlines: _storageService.loadDeadlines(),
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Timetable imported successfully!'), backgroundColor: Color(0xFF10B981)),
          );
        }
      }
    } catch (e, stackTrace) {
      debugPrint('Import error: $e');
      debugPrint('Stack: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error importing file: $e'), backgroundColor: const Color(0xFFEF4444), duration: const Duration(seconds: 5)),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshTimetable() async {
    await _controller.refresh();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Timetable refreshed'), backgroundColor: Color(0xFF3B82F6)),
      );
    }
  }

  Future<void> _clearStudySessions() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Study Sessions'),
        content: const Text('Are you sure you want to delete all study sessions? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), style: TextButton.styleFrom(foregroundColor: const Color(0xFFEF4444)), child: const Text('Delete')),
        ],
      ),
    );

    if (confirmed == true) {
      await _storageService.clearStudySessions();
      await _controller.refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All study sessions deleted'), backgroundColor: Color(0xFFEF4444)),
        );
      }
    }
  }

  Future<void> _clearAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data'),
        content: const Text('Are you sure you want to delete ALL data including timetable, study sessions, and knowledge maps? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), style: TextButton.styleFrom(foregroundColor: const Color(0xFFEF4444)), child: const Text('Delete All')),
        ],
      ),
    );

    if (confirmed == true) {
      await _notificationService.cancelAll();
      await _controller.clearAllData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All data cleared'), backgroundColor: Color(0xFFEF4444)),
        );
      }
    }
  }
}