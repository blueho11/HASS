// ignore_for_file: deprecated_member_use

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:hass_project/constants/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Firebase structure:
//   live/boards/{boardId}/ifthen/{ruleId}/
//     sensor:    "temperature" | "humidity"
//     condition: ">"  | "<"  | "="
//     threshold: 35.0
//     device:    "s1"
//     action:    true | false
//     enabled:   true
// ─────────────────────────────────────────────────────────────────────────────

class IfThenPage extends StatefulWidget {
  final List<Map<String, dynamic>> devices;
  final String boardId;

  const IfThenPage({
    super.key,
    required this.devices,
    required this.boardId,
  });

  @override
  State<IfThenPage> createState() => _IfThenPageState();
}

class _IfThenPageState extends State<IfThenPage> {
  // ── Form state ─────────────────────────────────────────────────────────────
  String   _sensor    = 'temperature';   // 'temperature' | 'humidity'
  String   _condition = '>';             // '>' | '<' | '='
  double   _threshold = 30.0;
  String?  _device;                      // slot key e.g. "s1"
  bool     _action    = false;           // true=ON false=OFF

  final _thresholdCtrl = TextEditingController(text: '30');

  // ── Rules from Firebase ────────────────────────────────────────────────────
  List<Map<String, dynamic>> _rules   = [];
  bool                       _loading = true;

  late final DatabaseReference _ref;

  @override
  void initState() {
    super.initState();
    _ref = FirebaseDatabase.instanceFor(
      app: FirebaseDatabase.instance.app,
      databaseURL: 'https://hass-c6f0e-default-rtdb.firebaseio.com',
    ).ref('live/boards/${widget.boardId}/ifthen');

    if (widget.devices.isNotEmpty) {
      _device = 's${widget.devices.first['slot']}';
    }

    _loadRules();
  }

  @override
  void dispose() {
    _thresholdCtrl.dispose();
    super.dispose();
  }

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
      debugPrint('Load if-then error: $e');
    }
  }

  Future<void> _saveRule() async {
    if (_device == null) {
      _snack('Select a device.', Colors.orange);
      return;
    }

    final threshold = double.tryParse(_thresholdCtrl.text);
    if (threshold == null) {
      _snack('Enter a valid number for threshold.', Colors.orange);
      return;
    }

    final rule = {
      'sensor':    _sensor,
      'condition': _condition,
      'threshold': threshold,
      'device':    _device,
      'action':    _action,
      'enabled':   true,
    };

    try {
      final id = 'ift_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999)}';
      await _ref.child(id).set(rule);
      _snack('If-Then rule saved! ESP32 will execute it automatically.', Colors.green);
      _loadRules();
    } catch (e) {
      _snack('Failed to save: $e', Colors.red);
    }
  }

  Future<void> _deleteRule(String id) async {
    try {
      await _ref.child(id).remove();
      _snack('Rule deleted.', Colors.red.shade400);
      _loadRules();
    } catch (e) {
      _snack('Delete failed: $e', Colors.red);
    }
  }

  Future<void> _toggleEnabled(String id, bool current) async {
    try {
      await _ref.child(id).update({'enabled': !current});
      _loadRules();
    } catch (e) {
      debugPrint('Toggle error: $e');
    }
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
    final label  = isDark ? Colors.white70 : Colors.grey.shade700;
    final border = isDark ? Colors.grey.shade600 : Colors.grey.shade300;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('If-Then Rules',
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
                        'If-Then rules run on ESP32 every 5 seconds using the DHT22 sensor.',
                        style: TextStyle(
                            color: Colors.green.shade700, fontSize: 12),
                      )),
                    ]),
                  ),
                  const SizedBox(height: 20),

                  // ── Sensor ────────────────────────────────────────────────
                  _sectionTitle('IF Sensor', text),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _sensorBtn(
                        'Temperature', 'temperature', Icons.thermostat, isDark)),
                    const SizedBox(width: 12),
                    Expanded(child: _sensorBtn(
                        'Humidity', 'humidity', Icons.water_drop_outlined, isDark)),
                  ]),
                  const SizedBox(height: 20),

                  // ── Condition + Threshold ─────────────────────────────────
                  _sectionTitle('Condition', text),
                  const SizedBox(height: 10),
                  Row(children: [
                    // Condition selector
                    Expanded(
                      flex: 1,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: border),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _condition,
                            dropdownColor: card,
                            style: TextStyle(
                                color: AppColors.gradientEnd,
                                fontWeight: FontWeight.bold,
                                fontSize: 22),
                            items: ['>', '<', '='].map((c) =>
                                DropdownMenuItem(
                                    value: c,
                                    child: Text(c))).toList(),
                            onChanged: (v) =>
                                setState(() => _condition = v!),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Threshold input
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _thresholdCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        style: TextStyle(color: text),
                        decoration: InputDecoration(
                          labelText: _sensor == 'temperature'
                              ? 'Temperature (°C)'
                              : 'Humidity (%)',
                          labelStyle: TextStyle(color: label),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14)),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: border)),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                  color: AppColors.gradientEnd, width: 2)),
                          filled: true, fillColor: card,
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 20),

                  // ── Device ────────────────────────────────────────────────
                  _sectionTitle('THEN — Control Device', text),
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

                  // ── Action ────────────────────────────────────────────────
                  _sectionTitle('Action', text),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _actionBtn('Turn ON', true, isDark)),
                    const SizedBox(width: 12),
                    Expanded(child: _actionBtn('Turn OFF', false, isDark)),
                  ]),
                  const SizedBox(height: 24),

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
                        const Icon(Icons.preview,
                            color: AppColors.gradientEnd, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(
                          'IF $_sensor $_condition ${_thresholdCtrl.text}  →  '
                          '${_action ? "Turn ON" : "Turn OFF"} ${_deviceName(_device!)}',
                          style: TextStyle(
                              color: AppColors.gradientEnd,
                              fontWeight: FontWeight.w600),
                        )),
                      ]),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Save button ───────────────────────────────────────────
                  _gradBtn('Save Rule', Icons.save_alt, _saveRule),

                  // ── Saved rules ───────────────────────────────────────────
                  if (_rules.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    _sectionTitle('Active Rules (${_rules.length})', text),
                    const SizedBox(height: 10),
                    ..._rules.map((rule) {
                      final id        = rule['id'] as String;
                      final enabled   = rule['enabled'] == true;
                      final sensor    = rule['sensor'] as String? ?? '';
                      final condition = rule['condition'] as String? ?? '';
                      final threshold = rule['threshold'];
                      final device    = rule['device'] as String? ?? '';
                      final action    = rule['action'] == true
                          ? 'Turn ON' : 'Turn OFF';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: enabled
                                  ? AppColors.gradientEnd.withOpacity(0.5)
                                  : border),
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
                                color: enabled
                                    ? null
                                    : Colors.grey.shade400,
                                borderRadius:
                                    BorderRadius.circular(10)),
                            child: const Icon(
                                Icons.device_thermostat,
                                color: Colors.white, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'IF $sensor $condition $threshold',
                                style: TextStyle(
                                    color: text,
                                    fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '$action  ${_deviceName(device)}',
                                style: TextStyle(
                                    color: AppColors.gradientEnd,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500),
                              ),
                            ],
                          )),
                          Switch(
                            value: enabled,
                            onChanged: (_) =>
                                _toggleEnabled(id, enabled),
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

  Widget _sensorBtn(
      String label, String value, IconData icon, bool isDark) {
    final selected = _sensor == value;
    return GestureDetector(
      onTap: () => setState(() => _sensor = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
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
        child: Column(children: [
          Icon(icon,
              color: selected ? Colors.white : AppColors.gradientEnd,
              size: 24),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  color: selected ? Colors.white : null,
                  fontWeight:
                      selected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13)),
        ]),
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