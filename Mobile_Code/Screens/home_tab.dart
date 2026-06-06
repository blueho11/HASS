// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:hass_project/Screens/device_detail.dart';
import 'package:hass_project/constants/app_colors.dart';

class HomeTab extends StatelessWidget {
  final List<Map<String, dynamic>> devices;
  final void Function(int index, bool value) onToggle;
  final void Function(int index) onDelete;
  final double temperature;
  final double humidity;
  final bool isPaired;
  final String boardId;

  const HomeTab({
    super.key,
    required this.devices,
    required this.onToggle,
    required this.onDelete,
    this.temperature = 0,
    this.humidity    = 0,
    this.isPaired    = false,
    this.boardId     = '',
  });

  void _openDetail(BuildContext context, int index) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => DeviceDetailScreen(
        devices: devices,
        initialIndex: index,
        onToggle: onToggle,
        onDelete: onDelete,
        boardId: boardId,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark     = Theme.of(context).brightness == Brightness.dark;
    final Color card      = isDark ? AppColors.darkSurface : Colors.white;
    final Color? text     = Theme.of(context).textTheme.bodyLarge?.color;
    final Color? sub      = isDark ? Colors.white60 : Colors.grey[600];
    final int activeCount = devices.where((d) => d['isOn'] == true).length;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          sliver: SliverList(
            delegate: SliverChildListDelegate.fixed([

              // ── Not paired banner ─────────────────────────────────────────
              if (!isPaired) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.orange.shade300),
                  ),
                  child: Row(children: [
                    const Icon(Icons.link_off, color: Colors.orange),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'No board paired. Go to Settings and enter your board code.',
                        style: TextStyle(
                            color: Colors.orange.shade700, fontSize: 13),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 16),
              ],

              // ── Welcome ───────────────────────────────────────────────────
              Text('Welcome',
                  style: TextStyle(fontSize: 28,
                      fontWeight: FontWeight.w500, color: text)),
              const SizedBox(height: 20),

              // ── Stat cards ────────────────────────────────────────────────
              Row(children: [
                Expanded(child: RepaintBoundary(child: _StatCard(
                    title: 'Devices State', icon: Icons.devices,
                    value: '$activeCount Active',
                    card: card, text: text, sub: sub))),
                const SizedBox(width: 16),
                // Real temperature from ESP32
                Expanded(child: RepaintBoundary(child: _StatCard(
                    title: 'Temperature', icon: Icons.thermostat,
                    value: isPaired
                        ? '${temperature.toStringAsFixed(1)}°C'
                        : '--°C',
                    card: card, text: text, sub: sub))),
              ]),
              const SizedBox(height: 12),

              // ── Humidity card (from ESP32) ─────────────────────────────
              if (isPaired)
                RepaintBoundary(child: _HumidityCard(
                    humidity: humidity, card: card,
                    text: text, sub: sub, isDark: isDark)),

              const SizedBox(height: 12),

              // ── Total ────────────────────────────────────────────────────
              RepaintBoundary(child: _TotalCard(
                  devices: devices, card: card,
                  text: text, sub: sub, isDark: isDark)),
              const SizedBox(height: 16),

              // ── On/Off buttons ────────────────────────────────────────────
              Row(children: [
                Expanded(child: _GradBtn(
                  onPressed: () {
                    for (int i = 0; i < devices.length; i++) onToggle(i, true);
                  },
                )),
                const SizedBox(width: 12),
                Expanded(child: _GreyBtn(
                  isDark: isDark,
                  onPressed: () {
                    for (int i = 0; i < devices.length; i++) onToggle(i, false);
                  },
                )),
              ]),
              const SizedBox(height: 24),

              Text('Your Devices',
                  style: TextStyle(fontSize: 20,
                      fontWeight: FontWeight.bold, color: text)),
              const SizedBox(height: 16),
            ]),
          ),
        ),

        // ── Device grid ───────────────────────────────────────────────────
        if (devices.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.devices_other, size: 60,
                        color: isDark ? Colors.white30 : Colors.grey.shade300),
                    const SizedBox(height: 12),
                    Text(
                      isPaired
                          ? 'No devices added yet.\nGo to the + tab to add one.'
                          : 'Pair a board first in Settings.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: sub),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.85,
              ),
              delegate: SliverChildBuilderDelegate(
                (ctx, i) {
                  final d    = devices[i];
                  final isOn = d['isOn'] == true;
                  return RepaintBoundary(
                    child: _DeviceCard(
                      device: d, isOn: isOn, isDark: isDark,
                      card: card, text: text,
                      onToggle: (v) => onToggle(i, v),
                      onTap: () => _openDetail(ctx, i),
                    ),
                  );
                },
                childCount: devices.length,
              ),
            ),
          ),
      ],
    );
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _HumidityCard extends StatelessWidget {
  final double humidity;
  final Color card;
  final Color? text, sub;
  final bool isDark;
  const _HumidityCard({required this.humidity, required this.card,
      required this.text, required this.sub, required this.isDark});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity, padding: const EdgeInsets.all(16),
    margin: const EdgeInsets.only(bottom: 4),
    decoration: BoxDecoration(
      color: card, borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(isDark ? 0.3 : 0.07),
          blurRadius: 10, spreadRadius: 2)],
    ),
    child: Row(children: [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.water_drop_outlined, color: Colors.blue),
      ),
      const SizedBox(width: 16),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Humidity', style: TextStyle(color: sub, fontSize: 12)),
        Text('${humidity.toStringAsFixed(1)}%',
            style: TextStyle(fontSize: 22,
                fontWeight: FontWeight.bold, color: text)),
      ]),
    ]),
  );
}

class _TotalCard extends StatelessWidget {
  final List<Map<String, dynamic>> devices;
  final Color card;
  final Color? text, sub;
  final bool isDark;
  const _TotalCard({required this.devices, required this.card,
      required this.text, required this.sub, required this.isDark});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity, padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: card, borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(isDark ? 0.3 : 0.07),
          blurRadius: 10, spreadRadius: 2)],
    ),
    child: Row(children: [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: AppColors.gradientStart.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.devices_other, color: AppColors.gradientEnd),
      ),
      const SizedBox(width: 16),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Total Plant/Device', style: TextStyle(color: sub)),
        Text('${devices.length} / 4 Devices',
            style: TextStyle(fontSize: 22,
                fontWeight: FontWeight.bold, color: text)),
      ]),
    ]),
  );
}

class _StatCard extends StatelessWidget {
  final String title, value;
  final IconData icon;
  final Color card;
  final Color? text, sub;
  const _StatCard({required this.title, required this.value, required this.icon,
      required this.card, required this.text, required this.sub});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.07),
            blurRadius: 10, spreadRadius: 2)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: AppColors.gradientEnd, size: 28),
        const SizedBox(height: 8),
        Text(title, style: TextStyle(color: sub, fontSize: 12)),
        Text(value, style: TextStyle(
            fontSize: 20, fontWeight: FontWeight.bold, color: text)),
      ]),
    );
  }
}

class _GradBtn extends StatelessWidget {
  final VoidCallback onPressed;
  const _GradBtn({required this.onPressed});
  @override
  Widget build(BuildContext context) => Container(
    height: 48,
    decoration: BoxDecoration(
      gradient: AppColors.primaryGradient,
      borderRadius: BorderRadius.circular(30),
      boxShadow: [BoxShadow(color: AppColors.gradientEnd.withOpacity(0.3),
          blurRadius: 8, offset: const Offset(0, 4))],
    ),
    child: ElevatedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.power_settings_new, color: Colors.white, size: 20),
      label: const FittedBox(fit: BoxFit.scaleDown,
          child: Text('Turn On All', style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white))),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.transparent, shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        padding: const EdgeInsets.symmetric(horizontal: 12),
      ),
    ),
  );
}

class _GreyBtn extends StatelessWidget {
  final bool isDark;
  final VoidCallback onPressed;
  const _GreyBtn({required this.isDark, required this.onPressed});
  @override
  Widget build(BuildContext context) => Container(
    height: 48,
    decoration: BoxDecoration(
      color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
      borderRadius: BorderRadius.circular(30),
    ),
    child: ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(Icons.power_settings_new,
          color: isDark ? Colors.white70 : Colors.grey.shade600, size: 20),
      label: FittedBox(fit: BoxFit.scaleDown,
          child: Text('Turn Off All', style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.grey.shade700))),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.transparent, shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        padding: const EdgeInsets.symmetric(horizontal: 12),
      ),
    ),
  );
}

class _DeviceCard extends StatelessWidget {
  final Map<String, dynamic> device;
  final bool isOn, isDark;
  final Color card;
  final Color? text;
  final void Function(bool) onToggle;
  final VoidCallback onTap;
  const _DeviceCard({required this.device, required this.isOn,
      required this.isDark, required this.card, required this.text,
      required this.onToggle, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: card, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.07),
            blurRadius: 10, spreadRadius: 2)],
        border: Border.all(
            color: isOn ? AppColors.gradientEnd : Colors.transparent, width: 2),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Align(alignment: Alignment.topRight,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(10)),
            child: Text('S${device['slot']}',
                style: const TextStyle(color: Colors.white, fontSize: 10,
                    fontWeight: FontWeight.bold)),
          ),
        ),
        Icon(device['icon'] as IconData, size: 36,
            color: isOn ? AppColors.gradientEnd : Colors.grey),
        const SizedBox(height: 6),
        Text(device['name'] as String,
            style: TextStyle(fontWeight: FontWeight.w500,
                fontSize: 14, color: text),
            overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        Switch(value: isOn, onChanged: onToggle,
            activeColor: AppColors.gradientEnd,
            activeTrackColor: AppColors.gradientEnd.withOpacity(0.5)),
      ]),
    ),
  );
}