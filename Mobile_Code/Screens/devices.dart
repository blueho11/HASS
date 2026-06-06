// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:hass_project/Screens/control_device.dart';
import 'package:hass_project/constants/app_colors.dart';

class DevicesScreen extends StatelessWidget {
  const DevicesScreen({super.key});

  static final List<Map<String, dynamic>> _demo = [
    {'name': 'Computer', 'icon': Icons.computer,  'isOn': false, 'category': 'Computer', 'power': 120, 'slot': 1},
    {'name': 'Lamp 1',   'icon': Icons.lightbulb, 'isOn': true,  'category': 'Light',    'power': 60,  'slot': 2},
    {'name': 'Fan',      'icon': Icons.air,       'isOn': false, 'category': 'Fan',      'power': 75,  'slot': 3},
    {'name': 'TV',       'icon': Icons.tv,        'isOn': true,  'category': 'T.V',      'power': 90,  'slot': 4},
  ];

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('HASS',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black)),
          Text('HOME SYSTEM',
              style: TextStyle(fontSize: 12,
                  color: isDark ? Colors.white70 : Colors.grey)),
        ]),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Devices',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge?.color)),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.builder(
              itemCount: _demo.length,
              itemBuilder: (ctx, i) {
                final d    = _demo[i];
                final isOn = d['isOn'] == true;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    onTap: () => Navigator.push(ctx, MaterialPageRoute(
                      builder: (_) => ControlDeviceScreen(
                        devices: _demo,
                        currentDeviceIndex: i, boardId: '',
                      ),
                    )),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isOn
                            ? AppColors.gradientEnd.withOpacity(0.2)
                            : Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(d['icon'] as IconData,
                          color: isOn ? AppColors.gradientEnd : Colors.grey),
                    ),
                    title: Text(d['name'] as String),
                    subtitle: Text(
                        '${isOn ? "On" : "Off"}  ·  Slot ${d['slot']}'),
                    trailing: Switch(
                      value: isOn,
                      onChanged: (_) {},
                      activeColor: AppColors.gradientEnd,
                    ),
                  ),
                );
              },
            ),
          ),
        ]),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/add-device'),
        backgroundColor: AppColors.gradientEnd,
        child: const Icon(Icons.add),
      ),
    );
  }
}