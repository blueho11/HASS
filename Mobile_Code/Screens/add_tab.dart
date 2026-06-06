// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:hass_project/constants/app_colors.dart';

class AddTab extends StatefulWidget {
  final void Function(Map<String, dynamic>) onAddDevice;
  final int currentCount;
  final List<Map<String, dynamic>> devices;

  const AddTab({
    super.key,
    required this.onAddDevice,
    required this.currentCount,
    required this.devices,
  });

  @override
  State<AddTab> createState() => _AddTabState();
}

class _AddTabState extends State<AddTab> {
  final _formKey   = GlobalKey<FormState>();
  final _namCtrl   = TextEditingController();
  String _category = 'Light';
  IconData _icon   = Icons.lightbulb;

  static const List<Map<String, dynamic>> _cats = [
    {'name': 'Light',      'icon': Icons.lightbulb},
    {'name': 'Fan',        'icon': Icons.air},
    {'name': 'Computer',   'icon': Icons.computer},
    {'name': 'T.V',        'icon': Icons.tv},
    {'name': 'Air-cooling','icon': Icons.ac_unit},
    {'name': 'Motors',     'icon': Icons.electrical_services},
    {'name': 'Door',       'icon': Icons.door_front_door},
  ];

  int? _nextSlot() {
    final used = widget.devices.map((d) => d['slot'] as int).toSet();
    for (int s = 1; s <= 4; s++) {
      if (!used.contains(s)) return s;
    }
    return null;
  }

  void _add() {
    if (_formKey.currentState!.validate()) {
      final slot = _nextSlot()!;
      widget.onAddDevice({
        'name': _namCtrl.text.trim(),
        'icon': _icon,
        'category': _category,
        'power': 0,
        'slot': slot,
      });
      _namCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Device added to Slot $slot'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  void dispose() { _namCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final bool isDark    = Theme.of(context).brightness == Brightness.dark;
    final Color card     = isDark ? AppColors.darkSurface : Colors.white;
    final Color? text    = Theme.of(context).textTheme.bodyLarge?.color;
    final Color border   = isDark ? Colors.grey.shade600 : Colors.grey.shade300;
    final Color label    = isDark ? Colors.white70 : Colors.grey.shade700;
    final int? nextSlot  = _nextSlot();
    final bool canAdd    = widget.currentCount < 4 && nextSlot != null;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              Text('Add New Device',
                  style: TextStyle(
                      fontSize: 28, fontWeight: FontWeight.bold, color: text)),
              const SizedBox(height: 8),
              Text('${widget.currentCount}/4 devices used',
                  style: TextStyle(
                      fontSize: 16,
                      color: widget.currentCount >= 4
                          ? Colors.red
                          : Colors.grey[600])),
              const SizedBox(height: 20),

              // ── Slot indicator ───────────────────────────────────────────
              if (canAdd) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AppColors.gradientEnd, width: 1.5),
                  ),
                  child: Row(children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          shape: BoxShape.circle),
                      child: Center(
                        child: Text('$nextSlot',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Slot $nextSlot',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: text)),
                      Text('Next available slot',
                          style: TextStyle(fontSize: 12, color: label)),
                    ]),
                  ]),
                ),
                const SizedBox(height: 16),
              ],

              // ── Slot overview ────────────────────────────────────────────
              if (widget.devices.isNotEmpty) ...[
                Text('Slots',
                    style: TextStyle(
                        fontSize: 14,
                        color: label,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Row(children: List.generate(4, (i) {
                  final slot = i + 1;
                  final match = widget.devices
                      .where((d) => d['slot'] == slot)
                      .toList();
                  final used  = match.isNotEmpty;
                  return Expanded(child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: used
                          ? AppColors.gradientEnd.withOpacity(0.15)
                          : (isDark
                              ? AppColors.darkSurface
                              : Colors.grey.shade100),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: used ? AppColors.gradientEnd : border),
                    ),
                    child: Column(children: [
                      Text('S$slot',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: used
                                  ? AppColors.gradientEnd
                                  : label)),
                      if (used)
                        Text(match.first['name'] as String,
                            style: TextStyle(fontSize: 9, color: label),
                            overflow: TextOverflow.ellipsis),
                    ]),
                  ));
                })),
                const SizedBox(height: 20),
              ],

              // ── Name field ───────────────────────────────────────────────
              TextFormField(
                controller: _namCtrl,
                style: TextStyle(color: text),
                decoration: InputDecoration(
                  labelText: 'Device Name',
                  labelStyle: TextStyle(color: label),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: border)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                          color: AppColors.gradientEnd, width: 2)),
                  prefixIcon: Icon(Icons.devices, color: label),
                  filled: true, fillColor: card,
                ),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Enter device name' : null,
              ),
              const SizedBox(height: 20),

              // ── Category ─────────────────────────────────────────────────
              Text('Category',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: text)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _category,
                    isExpanded: true,
                    dropdownColor: card,
                    iconEnabledColor: label,
                    style: TextStyle(color: text, fontSize: 15),
                    items: _cats.map((c) => DropdownMenuItem<String>(
                      value: c['name'] as String,
                      child: Row(children: [
                        Icon(c['icon'] as IconData,
                            size: 20, color: AppColors.gradientEnd),
                        const SizedBox(width: 8),
                        Text(c['name'] as String,
                            style: TextStyle(color: text)),
                      ]),
                    )).toList(),
                    onChanged: (v) => setState(() {
                      _category = v!;
                      _icon = _cats.firstWhere(
                          (c) => c['name'] == v)['icon'] as IconData;
                    }),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── Icon preview ─────────────────────────────────────────────
              Text('Selected Icon',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: text)),
              const SizedBox(height: 8),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: card, shape: BoxShape.circle,
                    boxShadow: [BoxShadow(
                        color: Colors.black
                            .withOpacity(isDark ? 0.3 : 0.1),
                        blurRadius: 10)],
                  ),
                  child: Icon(_icon, size: 50, color: AppColors.gradientEnd),
                ),
              ),
              const SizedBox(height: 30),

              // ── Add button ───────────────────────────────────────────────
              Container(
                width: double.infinity, height: 55,
                decoration: BoxDecoration(
                  gradient: canAdd ? AppColors.primaryGradient : null,
                  color: canAdd ? null : Colors.grey,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: ElevatedButton(
                  onPressed: canAdd ? _add : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                  ),
                  child: Text(
                    canAdd
                        ? 'Add Device to Slot $nextSlot'
                        : 'All Slots Full',
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}