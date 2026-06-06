// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:hass_project/Screens/if_then_page.dart';
import 'package:hass_project/Screens/schedule_page.dart';
import 'package:hass_project/Screens/timer_page.dart';
import 'package:hass_project/constants/app_colors.dart';

class ControlDeviceScreen extends StatelessWidget {
  final List<Map<String, dynamic>> devices;
  final int currentDeviceIndex;
  final String boardId; // ← needed to write rules to Firebase

  const ControlDeviceScreen({
    super.key,
    required this.devices,
    required this.currentDeviceIndex,
    required this.boardId,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Map<String, dynamic>? device =
        devices.isNotEmpty ? devices[currentDeviceIndex] : null;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('HASS',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black)),
            Text('HOME SYSTEM',
                style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white70 : Colors.grey)),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (device != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.gradientEnd.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: AppColors.gradientEnd),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(device['icon'] as IconData,
                        color: AppColors.gradientEnd, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      '${device['name']}  ·  Slot ${device['slot']}',
                      style: TextStyle(
                          color: AppColors.gradientEnd,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            Text('Control Options',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.bodyLarge?.color)),
            const SizedBox(height: 20),
            Expanded(
              child: ListView(
                children: [
                  _OptionCard(
                    title: 'Schedule',
                    icon: Icons.schedule,
                    description:
                        'Automate devices by day & time — runs even when app is closed.',
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(
                            builder: (_) => SchedulePage(
                                  devices: devices,
                                  boardId: boardId,
                                ))),
                  ),
                  const SizedBox(height: 16),
                  _OptionCard(
                    title: 'If-Then',
                    icon: Icons.device_thermostat,
                    description:
                        'Trigger actions when DHT22 reads a specific temperature or humidity.',
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(
                            builder: (_) => IfThenPage(
                                  devices: devices,
                                  boardId: boardId,
                                ))),
                  ),
                  const SizedBox(height: 16),
                  _OptionCard(
                    title: 'Timer',
                    icon: Icons.timer_outlined,
                    description:
                        'Set a countdown to turn a device on or off automatically.',
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(
                            builder: (_) => TimerPage(
                                  devices: devices,
                                  boardId: boardId,
                                ))),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String description;
  final VoidCallback onTap;

  const _OptionCard({
    required this.title,
    required this.icon,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color card  = isDark ? AppColors.darkSurface : Colors.white;
    final Color? text = Theme.of(context).textTheme.bodyLarge?.color;
    final Color? sub  = isDark ? Colors.white60 : Colors.grey[600];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.07),
            blurRadius: 12, spreadRadius: 2)],
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: text)),
              const SizedBox(height: 4),
              Text(description, style: TextStyle(fontSize: 13, color: sub)),
            ],
          )),
          Icon(Icons.arrow_forward_ios,
              size: 16,
              color: isDark ? Colors.white38 : Colors.grey.shade400),
        ]),
      ),
    );
  }
}