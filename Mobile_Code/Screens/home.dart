// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:hass_project/constants/app_colors.dart';
import 'package:hass_project/Screens/home_tab.dart';
import 'package:hass_project/Screens/add_tab.dart';
import 'package:hass_project/Screens/settings.dart';
import 'package:hass_project/Screens/device_detail.dart';
import 'package:hass_project/Screens/profile_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Firebase structure (with "live" root node):
//
//   live/users/{uid}/pairedBoard: "ABC1234"    ← which board this user controls
//
//   live/boards/ABC1234/
//     state/    s1: false  s2: true            ← ESP32 reads this
//     devices/  s1: "Lamp" s2: "Fan"           ← device names
//     sensor/   temperature: 27.5               ← ESP32 writes this
//     status/   online: true                     ← ESP32 heartbeat
// ─────────────────────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int    _tab       = 1;
  bool   _loading   = true;
  String _boardId   = '';    // the pairing code e.g. "ABC1234"
  bool   _isPaired  = false; // false = no board paired yet

  final List<Map<String, dynamic>> _devices = [];

  // Sensor data from ESP32
  double _temperature = 0;
  double _humidity    = 0;
  bool   _boardOnline = false;

  late final FirebaseDatabase _db;
  late final String _uid;

  DatabaseReference? _stateRef;   // live/boards/{boardId}/state
  DatabaseReference? _namesRef;   // live/boards/{boardId}/devices
  DatabaseReference? _sensorRef;  // live/boards/{boardId}/sensor
  DatabaseReference? _statusRef;  // live/boards/{boardId}/status

  StreamSubscription<DatabaseEvent>? _stateSub;
  StreamSubscription<DatabaseEvent>? _sensorSub;
  StreamSubscription<DatabaseEvent>? _statusSub;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    _uid = FirebaseAuth.instance.currentUser!.uid;
    _db  = FirebaseDatabase.instanceFor(
      app: FirebaseDatabase.instance.app,
      databaseURL: 'https://hass-c6f0e-default-rtdb.firebaseio.com',
    );

    _loadPairedBoard();
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _sensorSub?.cancel();
    _statusSub?.cancel();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  // ── Step 1: Check if user already has a paired board ─────────────────────
  Future<void> _loadPairedBoard() async {
    try {
      // 👇 added "live/" prefix
      final snap = await _db.ref('live/users/$_uid/pairedBoard').get();
      if (snap.exists && snap.value != null) {
        final code = snap.value as String;
        if (code.isNotEmpty) {
          await _connectToBoard(code);
          return;
        }
      }
    } catch (e) {
      debugPrint('Load paired board error: $e');
    }

    // No board paired yet
    setState(() {
      _isPaired = false;
      _loading  = false;
    });
  }

  // ── Step 2: Connect to a board by its ID ─────────────────────────────────
  Future<void> _connectToBoard(String boardId) async {
    // Cancel old subscriptions
    await _stateSub?.cancel();
    await _sensorSub?.cancel();
    await _statusSub?.cancel();

    _boardId   = boardId.trim().toUpperCase();
    // 👇 all references now start with "live/boards/"
    _stateRef  = _db.ref('live/boards/$_boardId/state');
    _namesRef  = _db.ref('live/boards/$_boardId/devices');
    _sensorRef = _db.ref('live/boards/$_boardId/sensor');
    _statusRef = _db.ref('live/boards/$_boardId/status');

    await _loadDevices();
    _listenToState();
    _listenToSensor();
    _listenToStatus();

    setState(() => _isPaired = true);
  }

  // ── Load device names + states from Firebase ─────────────────────────────
  Future<void> _loadDevices() async {
    try {
      final namesSnap = await _namesRef!.get();
      final stateSnap = await _stateRef!.get();

      _devices.clear();

      if (namesSnap.exists && namesSnap.value != null) {
        final names  = Map<String, dynamic>.from(namesSnap.value as Map);
        final states = stateSnap.exists && stateSnap.value != null
            ? Map<String, dynamic>.from(stateSnap.value as Map)
            : <String, dynamic>{};

        for (final entry in names.entries) {
          final key  = entry.key as String;
          final slot = int.tryParse(key.replaceAll('s', ''));
          if (slot == null) continue;

          _devices.add({
            'name':     entry.value as String? ?? key,
            'slot':     slot,
            'isOn':     states[key] == true,
            'icon':     Icons.devices,
            'category': 'Light',
            'power':    0,
          });
        }
        _devices.sort((a, b) =>
            (a['slot'] as int).compareTo(b['slot'] as int));
      }
    } catch (e) {
      debugPrint('Load devices error: $e');
    }

    setState(() => _loading = false);
  }

  // ── Listen: state changes (ESP32 or another user toggles) ────────────────
  void _listenToState() {
    _stateSub = _stateRef!.onValue.listen((event) {
      final raw = event.snapshot.value;
      if (raw == null || !mounted) return;

      final map    = Map<String, dynamic>.from(raw as Map);
      bool changed = false;

      for (final entry in map.entries) {
        final slot = int.tryParse(
            (entry.key as String).replaceAll('s', ''));
        if (slot == null) continue;

        final newState = entry.value == true;
        final idx = _devices.indexWhere((d) => d['slot'] == slot);
        if (idx != -1 && _devices[idx]['isOn'] != newState) {
          _devices[idx]['isOn'] = newState;
          changed = true;
        }
      }

      if (changed && mounted) setState(() {});
    });
  }

  // ── Listen: sensor data from ESP32 ───────────────────────────────────────
  void _listenToSensor() {
    _sensorSub = _sensorRef!.onValue.listen((event) {
      final raw = event.snapshot.value;
      if (raw == null || !mounted) return;
      final map = Map<String, dynamic>.from(raw as Map);
      setState(() {
        _temperature = (map['temperature'] as num?)?.toDouble() ?? 0;
        _humidity    = (map['humidity']    as num?)?.toDouble() ?? 0;
      });
    });
  }

  // ── Listen: board online status ───────────────────────────────────────────
  void _listenToStatus() {
    _statusSub = _statusRef!.onValue.listen((event) {
      final raw = event.snapshot.value;
      if (raw == null || !mounted) return;
      final map = Map<String, dynamic>.from(raw as Map);
      setState(() => _boardOnline = map['online'] == true);
    });
  }

  // ── Called from SettingsTab when user pairs a board ───────────────────────
  Future<bool> pairBoard(String code) async {
    if (code.trim().isEmpty) return false;

    final boardId = code.trim().toUpperCase();

    // Check board exists in Firebase (under "live/boards/")
    try {
      // 👇 added "live/"
      final snap = await _db.ref('live/boards/$boardId').get();
      if (!snap.exists) return false; // board not found

      // Save to user's profile (under "live/users/")
      await _db.ref('live/users/$_uid/pairedBoard').set(boardId);

      // Connect
      setState(() => _loading = true);
      await _connectToBoard(boardId);
      return true;
    } catch (e) {
      debugPrint('Pair board error: $e');
      return false;
    }
  }

  // ── Called from SettingsTab to unpair ────────────────────────────────────
  Future<void> unpairBoard() async {
    await _stateSub?.cancel();
    await _sensorSub?.cancel();
    await _statusSub?.cancel();
    // 👇 added "live/"
    await _db.ref('live/users/$_uid/pairedBoard').remove();
    setState(() {
      _boardId  = '';
      _isPaired = false;
      _devices.clear();
    });
  }

  // ── Firebase writes ───────────────────────────────────────────────────────
  Future<void> _writeState(int slot, bool value) async {
    try { await _stateRef!.update({'s$slot': value}); }
    catch (e) { debugPrint('State write error: $e'); }
  }

  Future<void> _writeName(int slot, String name) async {
    try { await _namesRef!.update({'s$slot': name}); }
    catch (e) { debugPrint('Name write error: $e'); }
  }

  Future<void> _deleteFromFirebase(int slot) async {
    try {
      await _namesRef!.child('s$slot').remove();
      await _stateRef!.update({'s$slot': false});
    } catch (e) { debugPrint('Delete error: $e'); }
  }

  // ── Device mutations ──────────────────────────────────────────────────────
  void _addDevice(Map<String, dynamic> d) {
    if (!_isPaired) {
      _snack('Pair a board first in Settings.', Colors.orange);
      return;
    }
    if (_devices.length >= 4) {
      _snack('Maximum 4 devices reached.', Colors.red);
      return;
    }
    setState(() {
      _devices.add({...d, 'isOn': false});
      _devices.sort((a, b) => (a['slot'] as int).compareTo(b['slot'] as int));
    });
    _writeName(d['slot'] as int, d['name'] as String);
    _writeState(d['slot'] as int, false);
  }

  void _toggleDevice(int index, bool value) {
    setState(() => _devices[index]['isOn'] = value);
    _writeState(_devices[index]['slot'] as int, value);
  }

  void _deleteDevice(int index) {
    final String name = _devices[index]['name'] as String;
    final int    slot = _devices[index]['slot'] as int;
    setState(() => _devices.removeAt(index));
    _deleteFromFirebase(slot);
    _snack('"$name" removed.', Colors.red.shade400);
  }

  void _snack(String msg, Color color) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));

  void _openProfile() => Navigator.push(
      context, MaterialPageRoute(builder: (_) => const ProfilePage()));

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading...'),
          ],
        )),
      );
    }

    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Builder(builder: (ctx) => IconButton(
          icon: Icon(Icons.menu,
              color: isDark ? Colors.white : Colors.black),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        )),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('HASS', style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black)),
            if (_isPaired) ...[
              const SizedBox(width: 8),
              // Board online indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _boardOnline
                      ? Colors.green.withOpacity(0.15)
                      : Colors.grey.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: _boardOnline ? Colors.green : Colors.grey,
                      width: 1),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 6, height: 6,
                    decoration: BoxDecoration(
                      color: _boardOnline ? Colors.green : Colors.grey,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _boardOnline ? _boardId : 'Offline',
                    style: TextStyle(
                        fontSize: 11,
                        color: _boardOnline ? Colors.green : Colors.grey,
                        fontWeight: FontWeight.w600),
                  ),
                ]),
              ),
            ],
          ],
        ),
        centerTitle: true,
        actions: [
          GestureDetector(
            onTap: _openProfile,
            child: CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.gradientEnd,
              child: Text(_letter(user),
                  style: const TextStyle(color: Colors.white,
                      fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),

      drawer: _Drawer(
        user: user,
        boardId: _boardId,
        isPaired: _isPaired,
        onHome:    () { setState(() => _tab = 1); },
        onProfile: _openProfile,
        onDetail: () {
          if (_devices.isEmpty) {
            _snack('No devices available.', Colors.orange);
            return;
          }
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => DeviceDetailScreen(
              devices: _devices,
              initialIndex: 0,
              onToggle: _toggleDevice,
              onDelete: _deleteDevice,
              boardId: _boardId,
            ),
          ));
        },
        onAdd:      () { setState(() => _tab = 0); },
        onSettings: () { setState(() => _tab = 2); },
        onLogout: () async {
          await _stateSub?.cancel();
          await _sensorSub?.cancel();
          await _statusSub?.cancel();
          await FirebaseAuth.instance.signOut();
          if (context.mounted) {
            Navigator.pushReplacementNamed(context, '/signin');
          }
        },
      ),

      body: IndexedStack(
        index: _tab,
        children: [
          RepaintBoundary(
            child: AddTab(
              onAddDevice:  _addDevice,
              currentCount: _devices.length,
              devices:      _devices,
            ),
          ),
          RepaintBoundary(
            child: HomeTab(
              devices:     _devices,
              onToggle:    _toggleDevice,
              onDelete:    _deleteDevice,
              temperature: _temperature,
              humidity:    _humidity,
              isPaired:    _isPaired,
              boardId:     _boardId,
            ),
          ),
          RepaintBoundary(
            child: SettingsTab(
              boardId:    _boardId,
              isPaired:   _isPaired,
              onPair:     pairBoard,
              onUnpair:   unpairBoard,
            ),
          ),
        ],
      ),

      bottomNavigationBar: RepaintBoundary(
        child: CurvedNavigationBar(
          index: _tab,
          items: const <Widget>[
            Icon(Icons.add_circle_outline, size: 40, color: Colors.black54),
            Icon(Icons.home,               size: 40, color: Colors.black54),
            Icon(Icons.settings,           size: 35, color: Colors.black54),
          ],
          color: Colors.white,
          buttonBackgroundColor: Colors.white,
          backgroundColor: Colors.transparent,
          animationCurve: Curves.easeInOut,
          animationDuration: const Duration(milliseconds: 300),
          onTap: (int i) => setState(() => _tab = i),
          letIndexChange: (int _) => true,
        ),
      ),
    );
  }

  String _letter(User? user) {
    if (user?.displayName?.isNotEmpty == true) {
      return user!.displayName![0].toUpperCase();
    }
    if (user?.email?.isNotEmpty == true) return user!.email![0].toUpperCase();
    return '?';
  }
}

// ── Drawer ────────────────────────────────────────────────────────────────────
class _Drawer extends StatelessWidget {
  final User? user;
  final String boardId;
  final bool isPaired;
  final VoidCallback onHome, onProfile, onDetail, onAdd, onSettings, onLogout;

  const _Drawer({
    required this.user,
    required this.boardId,
    required this.isPaired,
    required this.onHome, required this.onProfile, required this.onDetail,
    required this.onAdd,  required this.onSettings, required this.onLogout,
  });

  String _letter() {
    if (user?.displayName?.isNotEmpty == true) {
      return user!.displayName![0].toUpperCase();
    }
    if (user?.email?.isNotEmpty == true) return user!.email![0].toUpperCase();
    return '?';
  }

  @override
  Widget build(BuildContext context) => Drawer(
    child: Container(
      color: AppColors.background(context),
      child: ListView(padding: EdgeInsets.zero, children: [
        DrawerHeader(
          decoration: BoxDecoration(gradient: AppColors.primaryGradient),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white.withOpacity(0.25),
                child: Text(_letter(), style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold,
                    fontSize: 22)),
              ),
              const SizedBox(height: 10),
              Text(user?.displayName ?? 'HASS User',
                  style: const TextStyle(color: Colors.white,
                      fontSize: 16, fontWeight: FontWeight.bold)),
              Text(user?.email ?? '',
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
              if (isPaired) ...[
                const SizedBox(height: 4),
                Text('Board: $boardId',
                    style: const TextStyle(
                        color: Colors.white60, fontSize: 11)),
              ],
            ],
          ),
        ),
        ListTile(leading: const Icon(Icons.home_outlined),      title: const Text('Home'),          onTap: () { Navigator.pop(context); onHome(); }),
        ListTile(leading: const Icon(Icons.person_outline),     title: const Text('Profile'),        onTap: () { Navigator.pop(context); onProfile(); }),
        ListTile(leading: const Icon(Icons.info_outline),       title: const Text('Device Details'), onTap: () { Navigator.pop(context); onDetail(); }),
        ListTile(leading: const Icon(Icons.add_circle_outline), title: const Text('Add Device'),     onTap: () { Navigator.pop(context); onAdd(); }),
        ListTile(leading: const Icon(Icons.settings_outlined),  title: const Text('Settings'),       onTap: () { Navigator.pop(context); onSettings(); }),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.logout, color: Colors.red),
          title: const Text('Logout',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500)),
          onTap: onLogout,
        ),
      ]),
    ),
  );
}