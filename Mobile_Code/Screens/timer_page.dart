// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:hass_project/constants/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Firebase structure:
//   live/boards/{boardId}/timers/{timerId}/
//     device:      "s1"
//     action:      false         ← what to do when timer fires (true=ON false=OFF)
//     duration:    1800          ← seconds (e.g. 30 min)
//     triggeredAt: 1712345678    ← unix timestamp when started
//     active:      true          ← ESP32 checks this, sets false when done
//
// ESP32 checks every 30s:
//   if active==true AND (now - triggeredAt) >= duration → execute action → active=false
// ─────────────────────────────────────────────────────────────────────────────

class TimerPage extends StatefulWidget {
  final List<Map<String, dynamic>> devices;
  final String boardId;

  const TimerPage({
    super.key,
    required this.devices,
    required this.boardId,
  });

  @override
  State<TimerPage> createState() => _TimerPageState();
}

class _TimerPageState extends State<TimerPage> {
  // ── Form state ─────────────────────────────────────────────────────────────
  String? _device;
  bool    _action   = false;   // false=Turn OFF  true=Turn ON
  int     _value    = 30;
  String  _unit     = 'Minutes';   // 'Seconds' | 'Minutes' | 'Hours'

  // ── Active timers from Firebase ────────────────────────────────────────────
  List<Map<String, dynamic>> _timers  = [];
  bool                       _loading = true;

  late final DatabaseReference _ref;
  Timer? _uiTick; // updates countdown display every second

  @override
  void initState() {
    super.initState();
    _ref = FirebaseDatabase.instanceFor(
      app: FirebaseDatabase.instance.app,
      databaseURL: 'https://hass-c6f0e-default-rtdb.firebaseio.com',
    ).ref('live/boards/${widget.boardId}/timers');

    if (widget.devices.isNotEmpty) {
      _device = 's${widget.devices.first['slot']}';
    }

    _loadTimers();

    // Refresh countdown every second
    _uiTick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _uiTick?.cancel();
    super.dispose();
  }

  Future<void> _loadTimers() async {
    try {
      final snap = await _ref.get();
      final list = <Map<String, dynamic>>[];
      if (snap.exists && snap.value != null) {
        final map = Map<String, dynamic>.from(snap.value as Map);
        map.forEach((key, val) {
          final timer = Map<String, dynamic>.from(val as Map);
          timer['id'] = key;
          if (timer['active'] == true) list.add(timer);
        });
      }
      setState(() { _timers = list; _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
      debugPrint('Load timers error: $e');
    }
  }

  // ── Start timer — saves to Firebase, ESP32 will execute when done ──────────
  Future<void> _startTimer() async {
    if (_device == null) {
      _snack('Select a device.', Colors.orange);
      return;
    }

    final durationSec = _toDurationSeconds(_value, _unit);
    final triggeredAt =
        DateTime.now().millisecondsSinceEpoch ~/ 1000; // unix timestamp

    final timer = {
      'device':      _device,
      'action':      _action,
      'duration':    durationSec,
      'triggeredAt': triggeredAt,
      'active':      true,
    };

    try {
      final id = 'tmr_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999)}';
      await _ref.child(id).set(timer);
      _snack(
        'Timer started! ESP32 will execute in ${_fmtDuration(durationSec)}.',
        Colors.green,
      );
      _loadTimers();
    } catch (e) {
      _snack('Failed to start: $e', Colors.red);
    }
  }

  // ── Cancel timer ──────────────────────────────────────────────────────────
  Future<void> _cancelTimer(String id) async {
    try {
      await _ref.child(id).remove();
      _snack('Timer cancelled.', Colors.orange);
      _loadTimers();
    } catch (e) {
      _snack('Cancel failed: $e', Colors.red);
    }
  }

  int _toDurationSeconds(int value, String unit) {
    switch (unit) {
      case 'Seconds': return value;
      case 'Hours':   return value * 3600;
      default:        return value * 60;  // Minutes
    }
  }

  // ── Remaining seconds for display ─────────────────────────────────────────
  int _remainingSeconds(Map<String, dynamic> timer) {
    final triggeredAt = (timer['triggeredAt'] as int?) ?? 0;
    final duration    = (timer['duration']    as int?) ?? 0;
    final now         = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final elapsed     = now - triggeredAt;
    final remaining   = duration - elapsed;
    return remaining < 0 ? 0 : remaining;
  }

  String _fmtDuration(int seconds) {
    if (seconds <= 0) return '0s';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) return '${h}h ${m}m ${s}s';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card   = isDark ? AppColors.darkSurface : Colors.white;
    final text   = Theme.of(context).textTheme.bodyLarge?.color;
    final sub    = isDark ? Colors.white60 : Colors.grey[600];
    final border = isDark ? Colors.grey.shade600 : Colors.grey.shade300;

    final durationSec = _toDurationSeconds(_value, _unit);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Timer',
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

                  // ── Info banner ───────────────────────────────────────────
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
                        'Timers are executed by ESP32 — works even when app is closed.',
                        style: TextStyle(
                            color: Colors.green.shade700, fontSize: 12),
                      )),
                    ]),
                  ),
                  const SizedBox(height: 20),

                  // ── Device selector ───────────────────────────────────────
                  _sectionTitle('Device', text),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _device,
                        isExpanded: true,
                        dropdownColor: card,
                        hint: Text('Select device',
                            style: TextStyle(color: sub)),
                        style: TextStyle(color: text, fontSize: 15),
                        items: widget.devices.map((d) {
                          final key = 's${d['slot']}';
                          return DropdownMenuItem(
                            value: key,
                            child: Row(children: [
                              Icon(d['icon'] as IconData,
                                  size: 18, color: AppColors.gradientEnd),
                              const SizedBox(width: 8),
                              Text(d['name'] as String,
                                  style: TextStyle(color: text)),
                              Text('  · Slot ${d['slot']}',
                                  style: TextStyle(
                                      color: sub, fontSize: 12)),
                            ]),
                          );
                        }).toList(),
                        onChanged: (v) => setState(() => _device = v),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Duration picker ───────────────────────────────────────
                  _sectionTitle('Countdown Duration', text),
                  const SizedBox(height: 10),
                  Row(children: [
                    // Value
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: border),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _value,
                            dropdownColor: card,
                            isExpanded: true,
                            style: TextStyle(
                                color: text,
                                fontSize: 16,
                                fontWeight: FontWeight.bold),
                            items: _durationValues().map((v) =>
                                DropdownMenuItem(
                                    value: v,
                                    child: Text('$v'))).toList(),
                            onChanged: (v) =>
                                setState(() => _value = v!),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Unit
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: border),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _unit,
                            dropdownColor: card,
                            isExpanded: true,
                            style: TextStyle(color: text, fontSize: 15),
                            items: ['Seconds', 'Minutes', 'Hours']
                                .map((u) => DropdownMenuItem(
                                    value: u, child: Text(u)))
                                .toList(),
                            onChanged: (v) {
                              setState(() {
                                _unit  = v!;
                                _value = _durationValues().first;
                              });
                            },
                          ),
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 20),

                  // ── Action ────────────────────────────────────────────────
                  _sectionTitle('When timer ends', text),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _actionBtn('Turn ON', true, isDark)),
                    const SizedBox(width: 12),
                    Expanded(child: _actionBtn('Turn OFF', false, isDark)),
                  ]),
                  const SizedBox(height: 20),

                  // ── Preview ───────────────────────────────────────────────
                  if (_device != null) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.gradientEnd.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: AppColors.gradientEnd.withOpacity(0.4)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.timer,
                            color: AppColors.gradientEnd, size: 20),
                        const SizedBox(width: 10),
                        Expanded(child: Text(
                          'In ${_fmtDuration(durationSec)} → '
                          '${_action ? "Turn ON" : "Turn OFF"} '
                          '${_deviceName(_device!)}',
                          style: TextStyle(
                              color: AppColors.gradientEnd,
                              fontWeight: FontWeight.w600),
                        )),
                      ]),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Start button ──────────────────────────────────────────
                  _gradBtn('Start Timer', Icons.timer, _startTimer),

                  // ── Active timers ─────────────────────────────────────────
                  if (_timers.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    _sectionTitle('Running Timers (${_timers.length})', text),
                    const SizedBox(height: 10),
                    ..._timers.map((timer) {
                      final id        = timer['id'] as String;
                      final device    = timer['device'] as String? ?? '';
                      final action    = timer['action'] == true
                          ? 'Turn ON' : 'Turn OFF';
                      final remaining = _remainingSeconds(timer);
                      final total     = (timer['duration'] as int?) ?? 1;
                      final progress  = remaining / total;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: AppColors.gradientEnd.withOpacity(0.4)),
                          boxShadow: [BoxShadow(
                              color: Colors.black
                                  .withOpacity(isDark ? 0.2 : 0.05),
                              blurRadius: 8)],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                    gradient: AppColors.primaryGradient,
                                    borderRadius:
                                        BorderRadius.circular(10)),
                                child: const Icon(Icons.timer,
                                    color: Colors.white, size: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${_deviceName(device)}  ·  $action',
                                    style: TextStyle(
                                        color: text,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    'Remaining: ${_fmtDuration(remaining)}',
                                    style: TextStyle(
                                        color: AppColors.gradientEnd,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16),
                                  ),
                                ],
                              )),
                              IconButton(
                                icon: const Icon(Icons.cancel_outlined,
                                    color: Colors.red),
                                tooltip: 'Cancel timer',
                                onPressed: () => _cancelTimer(id),
                              ),
                            ]),
                            const SizedBox(height: 10),
                            // Progress bar
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: progress.clamp(0.0, 1.0),
                                minHeight: 8,
                                backgroundColor: isDark
                                    ? Colors.grey.shade700
                                    : Colors.grey.shade200,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(
                                        AppColors.gradientEnd),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  // ── Duration value options based on unit ───────────────────────────────────
  List<int> _durationValues() {
    switch (_unit) {
      case 'Seconds':
        return [10, 15, 20, 30, 45];
      case 'Hours':
        return [1, 2, 3, 4, 6, 8, 12, 24];
      default: // Minutes
        return [1, 2, 5, 10, 15, 20, 30, 45, 60, 90, 120];
    }
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

  Widget _sectionTitle(String t, Color? c) =>
      Text(t, style: TextStyle(
          fontSize: 18, fontWeight: FontWeight.bold, color: c));

  Widget _gradBtn(
          String label, IconData icon, VoidCallback onPressed) =>
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