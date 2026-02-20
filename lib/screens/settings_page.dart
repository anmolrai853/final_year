import 'package:flutter/material.dart';
import '../services/storage_service.dart';

final _storage = StorageService();

class SettingsPage extends StatefulWidget {
  final void Function(ThemeMode) onThemeChanged;
  const SettingsPage({super.key, required this.onThemeChanged});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Map<String, dynamic> _settings = {};
  bool _loaded = false;

  final _nameCtrl = TextEditingController();
  final _uniCtrl  = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _uniCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final s = await _storage.loadSettings();
    setState(() {
      _settings      = s;
      _nameCtrl.text = s['name']       ?? '';
      _uniCtrl.text  = s['university'] ?? '';
      _loaded        = true;
    });
  }

  Future<void> _save() async {
    await _storage.saveSettings(_settings);
  }

  void _set(String key, dynamic value) {
    setState(() => _settings[key] = value);
    _save();
    if (key == 'themeMode') widget.onThemeChanged(_themeMode);
  }

  ThemeMode get _themeMode {
    switch (_settings['themeMode']) {
      case 'light':  return ThemeMode.light;
      case 'system': return ThemeMode.system;
      default:       return ThemeMode.dark;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(
        backgroundColor: Color(0xFF020617),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      appBar: AppBar(
        backgroundColor: const Color(0xFF020617),
        elevation: 0,
        title: const Text('Settings',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // ── Profile ─────────────────────────────────────────
          _sectionHeader('Profile'),
          _card(children: [
            _textField(_nameCtrl, 'Your name',
                Icons.person_outline,
                onDone: (v) => _set('name', v)),
            const Divider(color: Colors.white10, height: 1),
            _textField(_uniCtrl, 'University',
                Icons.school_outlined,
                onDone: (v) => _set('university', v)),
          ]),
          const SizedBox(height: 20),

          // ── Appearance ───────────────────────────────────────
          _sectionHeader('Appearance'),
          _card(children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              child: Row(children: [
                const Icon(Icons.palette_outlined,
                    color: Colors.white54, size: 20),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Theme',
                      style: TextStyle(
                          color: Colors.white, fontSize: 14)),
                ),
                SegmentedButton<String>(
                  style: SegmentedButton.styleFrom(
                    foregroundColor: Colors.white,
                    selectedForegroundColor: Colors.white,
                    selectedBackgroundColor:
                    const Color(0xFF3B82F6),
                    side:
                    const BorderSide(color: Colors.white12),
                  ),
                  segments: const [
                    ButtonSegment(
                        value: 'dark',
                        label: Text('Dark',
                            style: TextStyle(fontSize: 12))),
                    ButtonSegment(
                        value: 'light',
                        label: Text('Light',
                            style: TextStyle(fontSize: 12))),
                    ButtonSegment(
                        value: 'system',
                        label: Text('System',
                            style: TextStyle(fontSize: 12))),
                  ],
                  selected: {_settings['themeMode'] as String},
                  onSelectionChanged: (s) =>
                      _set('themeMode', s.first),
                ),
              ]),
            ),
          ]),
          const SizedBox(height: 20),

          // ── Study Defaults ───────────────────────────────────
          _sectionHeader('Study Defaults'),
          _card(children: [
            _sliderRow(
              icon: Icons.timer_outlined,
              label: 'Default session length',
              value: (_settings['defaultSessionMins'] as int)
                  .toDouble(),
              min: 15, max: 120, divisions: 21,
              display:
              '${_settings['defaultSessionMins']} min',
              onChanged: (v) =>
                  _set('defaultSessionMins', v.toInt()),
            ),
            const Divider(color: Colors.white10, height: 1),
            _sliderRow(
              icon: Icons.notifications_outlined,
              label: 'Study reminder',
              value: (_settings['studyReminderMins'] as int)
                  .toDouble(),
              min: 5, max: 60, divisions: 11,
              display:
              '${_settings['studyReminderMins']} min before',
              onChanged: (v) =>
                  _set('studyReminderMins', v.toInt()),
            ),
            const Divider(color: Colors.white10, height: 1),
            _sliderRow(
              icon: Icons.directions_walk,
              label: '"Leave now" alert',
              value:
              (_settings['lateAlertMins'] as int).toDouble(),
              min: 5, max: 30, divisions: 5,
              display:
              '${_settings['lateAlertMins']} min before lecture',
              onChanged: (v) => _set('lateAlertMins', v.toInt()),
            ),
          ]),
          const SizedBox(height: 20),

          // ── Notifications ────────────────────────────────────
          _sectionHeader('Notifications'),
          _card(children: [
            _toggleRow(
              icon: Icons.alarm_outlined,
              label: 'Study session reminders',
              subtitle: 'Notify before planned sessions',
              value: _settings['notifyStudyReminder'] as bool,
              onChanged: (v) =>
                  _set('notifyStudyReminder', v),
            ),
            const Divider(color: Colors.white10, height: 1),
            _toggleRow(
              icon: Icons.replay_outlined,
              label: 'Spaced repetition alerts',
              subtitle: 'Notify when nodes are due for review',
              value: _settings['notifySpacedRep'] as bool,
              onChanged: (v) => _set('notifySpacedRep', v),
            ),
            const Divider(color: Colors.white10, height: 1),
            _toggleRow(
              icon: Icons.wb_sunny_outlined,
              label: 'Daily summary',
              subtitle: 'Morning overview of today\'s schedule',
              value: _settings['notifyDailySummary'] as bool,
              onChanged: (v) =>
                  _set('notifyDailySummary', v),
            ),
          ]),
          const SizedBox(height: 20),

          // ── Data ─────────────────────────────────────────────
          _sectionHeader('Data'),
          _card(children: [
            _actionRow(
              icon: Icons.download_outlined,
              label: 'Export all data',
              subtitle: 'Save a backup JSON file',
              color: Colors.white,
              onTap: _exportData,
            ),
            const Divider(color: Colors.white10, height: 1),
            _actionRow(
              icon: Icons.upload_outlined,
              label: 'Import data',
              subtitle: 'Restore from a backup file',
              color: Colors.white,
              onTap: _importData,
            ),
            const Divider(color: Colors.white10, height: 1),
            _actionRow(
              icon: Icons.delete_outline,
              label: 'Clear all data',
              subtitle: 'Permanently delete everything',
              color: Colors.redAccent,
              onTap: _confirmClear,
            ),
          ]),
          const SizedBox(height: 20),

          // ── About ────────────────────────────────────────────
          _sectionHeader('About'),
          _card(children: [
            _infoRow('App', 'Smart Student Navigator'),
            const Divider(color: Colors.white10, height: 1),
            _infoRow('Version', '1.0.0'),
          ]),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Reusable row widgets ─────────────────────────────────────

  Widget _sectionHeader(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 8, left: 4),
    child: Text(title.toUpperCase(),
        style: const TextStyle(
            color: Colors.white38,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2)),
  );

  Widget _card({required List<Widget> children}) => Container(
    decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(14)),
    child: Column(children: children),
  );

  Widget _toggleRow({
    required IconData icon,
    required String label,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) =>
      SwitchListTile(
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        secondary: Icon(icon, color: Colors.white54, size: 20),
        title: Text(label,
            style:
            const TextStyle(color: Colors.white, fontSize: 14)),
        subtitle: Text(subtitle,
            style: const TextStyle(
                color: Colors.white38, fontSize: 12)),
        value: value,
        activeColor: const Color(0xFF3B82F6),
        onChanged: onChanged,
      );

  Widget _sliderRow({
    required IconData icon,
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String display,
    required ValueChanged<double> onChanged,
  }) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(icon, color: Colors.white54, size: 20),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(label,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 14))),
                Text(display,
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 12)),
              ]),
              Slider(
                value: value,
                min: min, max: max, divisions: divisions,
                activeColor: const Color(0xFF3B82F6),
                inactiveColor: Colors.white10,
                onChanged: onChanged,
              ),
            ]),
      );

  Widget _textField(
      TextEditingController ctrl,
      String label,
      IconData icon, {
        required ValueChanged<String> onDone,
      }) =>
      Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 4),
        child: Row(children: [
          Icon(icon, color: Colors.white54, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: ctrl,
              style: const TextStyle(
                  color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                labelText: label,
                labelStyle: const TextStyle(
                    color: Colors.white38, fontSize: 13),
                border: InputBorder.none,
              ),
              onSubmitted: onDone,
              onEditingComplete: () => onDone(ctrl.text),
            ),
          ),
        ]),
      );

  Widget _actionRow({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) =>
      ListTile(
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16),
        leading: Icon(icon, color: color, size: 20),
        title: Text(label,
            style: TextStyle(color: color, fontSize: 14)),
        subtitle: Text(subtitle,
            style: const TextStyle(
                color: Colors.white38, fontSize: 12)),
        onTap: onTap,
      );

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(
        horizontal: 16, vertical: 14),
    child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  color: Colors.white54, fontSize: 14)),
          Text(value,
              style: const TextStyle(
                  color: Colors.white, fontSize: 14)),
        ]),
  );

  // ── Actions ──────────────────────────────────────────────────

  Future<void> _exportData() async {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Wire up share_plus to export data as JSON')),
      );
    }
  }

  Future<void> _importData() async {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Wire up file_picker to import a backup')),
      );
    }
  }

  void _confirmClear() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear all data?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
            'This permanently deletes all sessions, graphs, history and settings. This cannot be undone.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              await _storage.clearAllData();
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('All data cleared.')),
                );
              }
            },
            child: const Text('Delete everything',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
