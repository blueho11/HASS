// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:hass_project/constants/app_colors.dart';
import 'package:hass_project/Screens/control_device.dart';


class DeviceDetailScreen extends StatefulWidget {
  final List<Map<String, dynamic>> devices;
  final int initialIndex;
  final void Function(int index, bool value) onToggle;
  final void Function(int index) onDelete;
  final String boardId;

  const DeviceDetailScreen({
    super.key,
    required this.devices,
    required this.initialIndex,
    required this.onToggle,
    required this.onDelete,
    required this.boardId,
  });

  @override
  State<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends State<DeviceDetailScreen> {
  late PageController _ctrl;
  late int _idx;

  @override
  void initState() {
    super.initState();
    _idx  = widget.initialIndex;
    _ctrl = PageController(initialPage: _idx);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _prev() {
    if (_idx > 0) {
      _ctrl.previousPage(
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  void _next() {
    if (_idx < widget.devices.length - 1) {
      _ctrl.nextPage(
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  Future<void> _askDelete() async {
    if (widget.devices.isEmpty) return;
    final dev = widget.devices[_idx];

    final bool? yes = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final bool dark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: dark ? AppColors.darkSurface : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade400),
            const SizedBox(width: 8),
            const Text('Delete Device', style: TextStyle(fontWeight: FontWeight.bold)),
          ]),
          content: Text('Delete "${dev['name']}" from Slot ${dev['slot']}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style: TextStyle(color: dark ? Colors.white60 : Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade400,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Delete', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (yes == true) {
      final int toDelete = _idx;
      widget.onDelete(toDelete);                          // tell HomeScreen
      if (widget.devices.isEmpty) {
        if (mounted) Navigator.pop(context);
      } else {
        setState(() => _idx = _idx.clamp(0, widget.devices.length - 1));
        _ctrl.jumpToPage(_idx);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Device Details',
            style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold)),
        actions: [
          if (widget.devices.isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete_outline,
                  color: Colors.red.shade400, size: 26),
              tooltip: 'Delete device',
              onPressed: _askDelete,
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(children: [

        // ── PageView ─────────────────────────────────────────────────────────
        Expanded(
          child: Stack(children: [
            PageView.builder(
              controller: _ctrl,
              onPageChanged: (i) => setState(() => _idx = i),
              itemCount: widget.devices.length,
              itemBuilder: (_, i) =>
                  _DevicePage(device: widget.devices[i]),
            ),
            if (_idx > 0)
              _Arrow(left: true, onTap: _prev),
            if (widget.devices.isNotEmpty &&
                _idx < widget.devices.length - 1)
              _Arrow(left: false, onTap: _next),
          ]),
        ),

        // ── Bottom bar ───────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [

            // Delete button
            Expanded(
              flex: 1,
              child: SizedBox(
                height: 55,
                child: OutlinedButton.icon(
                  onPressed: widget.devices.isNotEmpty ? _askDelete : null,
                  icon: Icon(Icons.delete_outline,
                      color: Colors.red.shade400, size: 20),
                  label: Text('Delete',
                      style: TextStyle(
                          color: Colors.red.shade400,
                          fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.red.shade300),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Control button
            Expanded(
              flex: 2,
              child: Container(
                height: 55,
                decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(30)),
                child: ElevatedButton(
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(
                          builder: (_) => ControlDeviceScreen(
                                devices: widget.devices,
                                currentDeviceIndex: _idx,
                                boardId: widget.boardId,
                              ))),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                  ),
                  child: const Text('CONTROL',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ── Page content ──────────────────────────────────────────────────────────────
class _DevicePage extends StatelessWidget {
  final Map<String, dynamic> device;
  const _DevicePage({required this.device});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color card  = isDark ? AppColors.darkSurface : Colors.white;
    final Color? text = Theme.of(context).textTheme.bodyLarge?.color;
    final bool isOn   = device['isOn'] == true;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [

        // Slot badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(20)),
          child: Text('Slot ${device['slot'] ?? '-'}',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14)),
        ),
        const SizedBox(height: 20),

        // Icon
        Container(
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: card, shape: BoxShape.circle,
            boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
                blurRadius: 20, spreadRadius: 5)],
          ),
          child: Icon(device['icon'] as IconData,
              size: 80,
              color: isOn ? AppColors.gradientEnd : Colors.grey),
        ),
        const SizedBox(height: 20),

        Text(device['name'] as String,
            style: TextStyle(
                fontSize: 32, fontWeight: FontWeight.bold, color: text)),
        const SizedBox(height: 20),

        // Info card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: card, borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.07),
                blurRadius: 10)],
          ),
          child: Column(children: [
            _Row(label: 'Slot',     value: 'Slot ${device['slot'] ?? '-'}', icon: Icons.electrical_services, text: text, isDark: isDark),
            _Div(isDark), 
            _Row(label: 'State',    value: isOn ? 'On' : 'Off',              icon: Icons.power_settings_new,   text: text, isDark: isDark),
            _Div(isDark),
            _Row(label: 'Category', value: device['category'] as String? ?? '-', icon: Icons.category_outlined, text: text, isDark: isDark),
            _Div(isDark),
            _Row(label: 'Power',    value: '${device['power']} W',           icon: Icons.electric_bolt,        text: text, isDark: isDark),
          ]),
        ),
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color? text;
  final bool isDark;
  const _Row({required this.label, required this.value, required this.icon, required this.text, required this.isDark});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(children: [
      Icon(icon, color: AppColors.gradientEnd, size: 20),
      const SizedBox(width: 16),
      Text(label, style: TextStyle(fontSize: 16, color: isDark ? Colors.white60 : Colors.grey[600])),
      const Spacer(),
      Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: text)),
    ]),
  );
}

class _Div extends StatelessWidget {
  final bool isDark;
  const _Div(this.isDark);
  @override
  Widget build(BuildContext context) =>
      Divider(color: isDark ? Colors.white24 : Colors.grey.shade300);
}

class _Arrow extends StatelessWidget {
  final bool left;
  final VoidCallback onTap;
  const _Arrow({required this.left, required this.onTap});

  @override
  Widget build(BuildContext context) => Positioned(
    left: left ? 15 : null,
    right: left ? null : 15,
    top: 0, bottom: 0,
    child: Center(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient, shape: BoxShape.circle,
            boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Icon(
              left ? Icons.arrow_back_ios : Icons.arrow_forward_ios,
              color: Colors.white, size: 20),
        ),
      ),
    ),
  );
}