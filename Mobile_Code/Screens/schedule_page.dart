// ignore_for_file: deprecated_member_use

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:hass_project/constants/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Firebase structure:
//   live/boards/{boardId}/schedules/{ruleId}/
//     type:    "daily" | "weekly"
//     days:    ["Mon","Wed","Fri"]   ← only for weekly
//     time:    "08:30"               ← 24h format, ESP32 uses this
//     action:  true | false          ← true=ON false=OFF
//     devices: ["s1","s2"]           ← slot keys
//     enabled: true
// ─────────────────────────────────────────────────────────────────────────────

class SchedulePage extends StatefulWidget {
  final List<Map<String, dynamic>> devices;
  final String boardId;

  const SchedulePage({
    super.key,
    required this.devices,
    required this.boardId,
  });

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  // ── Form state ─────────────────────────────────────────────────────────────
  TimeOfDay _time    = TimeOfDay.now();
  String    _type    = 'daily';   // 'daily' | 'weekly'
  bool      _action  = true;      // true=ON false=OFF

  final Map<String, bool> _days = {
    'Sun': false, 'Mon': false, 'Tue': false, 'Wed': false,
    'Thu': false, 'Fri': false, 'Sat': false,
  };

  // device slot key → selected
  final Map<String, bool> _selectedDevices = {};

  // ── Saved rules from Firebase ──────────────────────────────────────────────
  List<Map<String, dynamic>> _rules = [];
  bool _loading = true;

  late final DatabaseReference _ref;

  @override
  void initState() {
    super.initState();
    _ref = FirebaseDatabase.instanceFor(
      app: FirebaseDatabase.instance.app,
      databaseURL: 'https://hass-c6f0e-default-rtdb.firebaseio.com',
    ).ref('live/boards/${widget.boardId}/schedules');

    // Init device selection map
    for (final d in widget.devices) {
      _selectedDevices['s${d['slot']}'] = false;
    }

    _loadRules();
  }

  // ── Load rules from Firebase ───────────────────────────────────────────────
  Future<void> _loadRules() async {
    try {
      final snap = await _ref.get();
      final list = <Map<String, dynamic>>[];
      if (snap.exists && snap.value != null) {
        final map = Map<String, dynamic>.from(snap.value as Map);
        map.forEach((key, val) {
          final rule = Map<String, dynamic>.from(val as Map);
          rule['id'] = key;
          list.add(rule);
        });
      }
      setState(() { _rules = list; _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
      debugPrint('Load schedules error: $e');
    }
  }

  // ── Save new rule to Firebase ──────────────────────────────────────────────
  Future<void> _saveRule() async {
    final selectedSlots = _selectedDevices.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();

    if (selectedSlots.isEmpty) {
      _snack('Select at least one device.', Colors.orange);
      return;
    }

    if (_type == 'weekly') {
      final anyDay = _days.values.any((v) => v);
      if (!anyDay) {
        _snack('Select at least one day.', Colors.orange);
        return;
      }
    }

    final timeStr =
        '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}';

    final rule = {
      'type':    _type,
      'time':    timeStr,
      'action':  _action,
      'devices': selectedSlots,
      'enabled': true,
      if (_type == 'weekly')
        'days': _days.entries
            .where((e) => e.value)
            .map((e) => e.key)
            .toList(),
    };

    try {
      final id = 'sch_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999)}';
      await _ref.child(id).set(rule);
      _snack('Schedule saved! ESP32 will execute it automatically.', Colors.green);
      _loadRules();
    } catch (e) {
      _snack('Failed to save: $e', Colors.red);
    }
  }

  // ── Delete rule from Firebase ──────────────────────────────────────────────
  Future<void> _deleteRule(String id) async {
    try {
      await _ref.child(id).remove();
      _snack('Schedule deleted.', Colors.red.shade400);
      _loadRules();
    } catch (e) {
      _snack('Failed to delete: $e', Colors.red);
    }
  }

  // ── Toggle enable/disable ─────────────────────────────────────────────────
  Future<void> _toggleEnabled(String id, bool current) async {
    try {
      await _ref.child(id).update({'enabled': !current});
      _loadRules();
    } catch (e) {
      debugPrint('Toggle error: $e');
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: ColorScheme.fromSeed(seedColor: AppColors.gradientEnd)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _time = picked);
  }

  String _fmtTime(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final p = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $p';
  }

  // Convert "08:30" → display string
  String _fmtTimeStr(String t) {
    final parts = t.split(':');
    if (parts.length != 2) return t;
    int h = int.tryParse(parts[0]) ?? 0;
    final m = parts[1];
    final p = h >= 12 ? 'PM' : 'AM';
    h = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$h:$m $p';
  }

  String _deviceName(String slotKey) {
    final slot = int.tryParse(slotKey.replaceAll('s', ''));
    final d = widget.devices.firstWhere(
        (d) => d['slot'] == slot,
        orElse: () => {'name': slotKey});
    return d['name'] as String;
  }

  void _snack(String msg, Color color) =>
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: color));

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final card    = isDark ? AppColors.darkSurface : Colors.white;
    final text    = Theme.of(context).textTheme.bodyLarge?.color;
    final sub     = isDark ? Colors.white60 : Colors.grey[600];
    final border  = isDark ? Colors.grey.shade600 : Colors.grey.shade300;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Schedule',
            style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── ESP32 info banner ─────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade300),
                    ),
                    child: Row(children: [
                      const Icon(Icons.memory, color: Colors.green, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(
                        'Schedules are executed by ESP32 — works even when app is closed.',
                        style: TextStyle(color: Colors.green.shade700, fontSize: 12),
                      )),
                    ]),
                  ),
                  const SizedBox(height: 20),

                  // ── Time picker ───────────────────────────────────────────
                  _sectionTitle('Time', text),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: _pickTime,
                    child: _infoCard(
                      icon: Icons.access_time,
                      label: 'Start Time',
                      value: _fmtTime(_time),
                      card: card, text: text, sub: sub,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Repeat type ───────────────────────────────────────────
                  _sectionTitle('Repeat', text),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _typeBtn('Daily', 'daily', isDark)),
                    const SizedBox(width: 12),
                    Expanded(child: _typeBtn('Specific Days', 'weekly', isDark)),
                  ]),

                  if (_type == 'weekly') ...[
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: _days.keys.map((day) {
                        final on = _days[day]!;
                        return GestureDetector(
                          onTap: () => setState(() => _days[day] = !on),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: on ? AppColors.primaryGradient : null,
                              color: on
                                  ? null
                                  : (isDark
                                      ? Colors.grey.shade800
                                      : Colors.grey.shade100),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: on ? Colors.transparent : border),
                            ),
                            child: Text(day,
                                style: TextStyle(
                                    color: on ? Colors.white : text,
                                    fontWeight: on
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    fontSize: 13)),
                          ),
                        );
                      }).toList(),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // ── Action ────────────────────────────────────────────────
                  _sectionTitle('Action', text),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _actionBtn('Turn ON', true, isDark)),
                    const SizedBox(width: 12),
                    Expanded(child: _actionBtn('Turn OFF', false, isDark)),
                  ]),
                  const SizedBox(height: 20),

                  // ── Devices ───────────────────────────────────────────────
                  _sectionTitle('Apply to Devices', text),
                  const SizedBox(height: 10),
                  _cardWrap(card, isDark,
                    widget.devices.isEmpty
                        ? Text('No devices added yet.',
                            style: TextStyle(color: sub))
                        : Column(
                            children: widget.devices.map((d) {
                              final key = 's${d['slot']}';
                              final chk = _selectedDevices[key] ?? false;
                              return CheckboxListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                value: chk,
                                onChanged: (v) => setState(
                                    () => _selectedDevices[key] = v!),
                                activeColor: AppColors.gradientEnd,
                                secondary: Icon(d['icon'] as IconData,
                                    color: chk
                                        ? AppColors.gradientEnd
                                        : Colors.grey),
                                title: Text(d['name'] as String,
                                    style: TextStyle(color: text)),
                                subtitle: Text('Slot ${d['slot']}',
                                    style: TextStyle(
                                        color: AppColors.gradientEnd,
                                        fontSize: 11)),
                              );
                            }).toList(),
                          ),
                  ),
                  const SizedBox(height: 24),

                  // ── Save button ───────────────────────────────────────────
                  _gradBtn('Save Schedule', Icons.save_alt, _saveRule),

                  // ── Saved rules ───────────────────────────────────────────
                  if (_rules.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    _sectionTitle('Active Schedules (${_rules.length})', text),
                    const SizedBox(height: 10),
                    ..._rules.map((rule) {
                      final id      = rule['id'] as String;
                      final enabled = rule['enabled'] == true;
                      final time    = _fmtTimeStr(rule['time'] as String? ?? '');
                      final type    = rule['type'] as String? ?? 'daily';
                      final action  = rule['action'] == true ? 'Turn ON' : 'Turn OFF';
                      final devList = (rule['devices'] as List? ?? [])
                          .map((s) => _deviceName(s as String))
                          .join(', ');
                      final days = type == 'weekly'
                          ? (rule['days'] as List? ?? []).join(', ')
                          : 'Every day';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: enabled
                                ? AppColors.gradientEnd.withOpacity(0.5)
                                : border,
                          ),
                          boxShadow: [BoxShadow(
                              color: Colors.black
                                  .withOpacity(isDark ? 0.2 : 0.05),
                              blurRadius: 8)],
                        ),
                        child: Row(children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                                gradient: enabled
                                    ? AppColors.primaryGradient
                                    : null,
                                color: enabled ? null : Colors.grey.shade400,
                                borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.schedule,
                                color: Colors.white, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('$time  ·  $action',
                                  style: TextStyle(
                                      color: text,
                                      fontWeight: FontWeight.bold)),
                              Text(days,
                                  style: TextStyle(
                                      color: sub, fontSize: 12)),
                              Text(devList,
                                  style: TextStyle(
                                      color: AppColors.gradientEnd,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500)),
                            ],
                          )),
                          // Enable/disable toggle
                          Switch(
                            value: enabled,
                            onChanged: (_) => _toggleEnabled(id, enabled),
                            activeColor: AppColors.gradientEnd,
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.red),
                            onPressed: () => _deleteRule(id),
                          ),
                        ]),
                      );
                    }),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  // ── Helper widgets ─────────────────────────────────────────────────────────

  Widget _typeBtn(String label, String value, bool isDark) {
    final selected = _type == value;
    return GestureDetector(
      onTap: () => setState(() => _type = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: selected ? AppColors.primaryGradient : null,
          color: selected
              ? null
              : (isDark ? Colors.grey.shade800 : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: selected
                  ? Colors.transparent
                  : (isDark
                      ? Colors.grey.shade600
                      : Colors.grey.shade300)),
        ),
        child: Center(
          child: Text(label,
              style: TextStyle(
                  color: selected ? Colors.white : null,
                  fontWeight:
                      selected ? FontWeight.bold : FontWeight.normal)),
        ),
      ),
    );
  }

  Widget _actionBtn(String label, bool value, bool isDark) {
    final selected = _action == value;
    return GestureDetector(
      onTap: () => setState(() => _action = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: selected ? AppColors.primaryGradient : null,
          color: selected
              ? null
              : (isDark ? Colors.grey.shade800 : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: selected
                  ? Colors.transparent
                  : (isDark
                      ? Colors.grey.shade600
                      : Colors.grey.shade300)),
        ),
        child: Center(
          child: Text(label,
              style: TextStyle(
                  color: selected ? Colors.white : null,
                  fontWeight:
                      selected ? FontWeight.bold : FontWeight.normal)),
        ),
      ),
    );
  }

  Widget _infoCard({
    required IconData icon,
    required String label,
    required String value,
    required Color card,
    required Color? text,
    required Color? sub,
    required bool isDark,
  }) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.gradientEnd.withOpacity(0.5)),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
              blurRadius: 8)],
        ),
        child: Row(children: [
          Icon(icon, color: AppColors.gradientEnd),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 12, color: sub)),
            Text(value,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: text)),
          ]),
        ]),
      );

  Widget _sectionTitle(String t, Color? c) =>
      Text(t, style: TextStyle(
          fontSize: 18, fontWeight: FontWeight.bold, color: c));

  Widget _cardWrap(Color bg, bool isDark, Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(isDark ? 0.25 : 0.06),
          blurRadius: 10)],
    ),
    child: child,
  );

  Widget _gradBtn(String label, IconData icon, VoidCallback onPressed) =>
      Container(
        width: double.infinity, height: 55,
        decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(30)),
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, color: Colors.white),
          label: Text(label,
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30)),
          ),
        ),
      );
}