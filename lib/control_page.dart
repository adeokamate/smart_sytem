import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:math' as math;

class ControlPage extends StatefulWidget {
  const ControlPage({super.key});

  @override
  ControlPageState createState() => ControlPageState();
}

class ControlPageState extends State<ControlPage> {
  Timer? _graphUpdateTimer;
  Timer? _statusCheckTimer;
  late final FirebaseDatabase _db;
  late final DatabaseReference _bulbCmdRef;
  late final DatabaseReference _fanCmdRef;
  late final DatabaseReference _bulbStatusRef;
  late final DatabaseReference _fanStatusRef;
  late final DatabaseReference _logsRef;

  String _bulbStatus = 'Unknown';
  String _fanStatus = 'Unknown';
  bool _isLoading = false;
  bool _isArduinoConnected = false;

  final List<FlSpot> _tempSpots = [];

  @override
  void initState() {
    super.initState();
    _initDB();
    _checkFirebaseConnection();
    _startPeriodicStatusCheck();
    _fetchTemperatureLogs(); // Fetch logs for last 2 hours on load
    _startGraphPeriodicUpdate(); // Update graph every 2 hours
  }

  void _initDB() {
    _db = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL:
          'https://the-sess-default-rtdb.europe-west1.firebasedatabase.app',
    );

    _bulbCmdRef = _db.ref('devices/bulb');
    _fanCmdRef = _db.ref('devices/fan');
    _bulbStatusRef = _db.ref('status/bulb');
    _fanStatusRef = _db.ref('status/fan');
    _logsRef = _db.ref('logs');
  }

  Future<void> _fetchTemperatureLogs() async {
    final cutoff = DateTime.now()
        .subtract(const Duration(hours: 2))
        .millisecondsSinceEpoch
        .toDouble();
    try {
      final snapshot =
          await _logsRef.orderByChild('timestamp').startAt(cutoff).get();
      final data = (snapshot.value as Map?)?.cast<String, dynamic>();
      print('Fetched logs: $data');
      if (data == null) {
        if (!mounted) return;
        setState(() {
          _tempSpots.clear();
        });
        return;
      }

      final List<FlSpot> tempSpots = [];
      data.forEach((key, value) {
        if (value is Map) {
          final casted = Map<String, dynamic>.from(value);
          if (casted.containsKey('temperature') &&
              casted.containsKey('timestamp')) {
            final ts = (casted['timestamp'] as num?)?.toDouble() ?? 0.0;
            final temp = (casted['temperature'] as num?)?.toDouble() ?? 0.0;
            if (ts >= cutoff) {
              tempSpots.add(FlSpot(ts, temp));
            }
          }
        }
      });

      tempSpots.sort((a, b) => a.x.compareTo(b.x));
      if (!mounted) return;
      setState(() {
        _tempSpots.clear();
        _tempSpots.addAll(tempSpots);
      });
    } catch (e) {
      print('❌ Error fetching temperature logs: $e');
    }
  }

  void _startGraphPeriodicUpdate() {
    _graphUpdateTimer = Timer.periodic(const Duration(hours: 2), (timer) {
      _fetchTemperatureLogs();
    });
  }

  void _checkFirebaseConnection() async {
    print('🔍 Checking Firebase connection...');
    print('🔍 Database URL: ${_db.app.options.databaseURL}');
    try {
      final snapshot = await _db.ref('.info/connected').get();
      final connected = snapshot.value as bool? ?? false;
      print('🔍 Firebase connected: $connected');
      if (mounted) {
        setState(() => _isArduinoConnected = connected);
      }
    } catch (e) {
      print('❌ Error checking Firebase connection: $e');
      if (mounted) setState(() => _isArduinoConnected = false);
    }
  }

  void _startPeriodicStatusCheck() {
    _statusCheckTimer =
        Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (!mounted) return;
      try {
        final bulbSnapshot = await _bulbStatusRef.get();
        final fanSnapshot = await _fanStatusRef.get();
        final newBulbStatus = bulbSnapshot.value?.toString() ?? 'Unknown';
        final newFanStatus = fanSnapshot.value?.toString() ?? 'Unknown';
        if (newBulbStatus != _bulbStatus || newFanStatus != _fanStatus) {
          setState(() {
            _bulbStatus = newBulbStatus;
            _fanStatus = newFanStatus;
          });
        }
      } catch (e) {
        print('❌ Error in periodic status check: $e');
      }
    });
  }

  Future<void> _setDevice(
      DatabaseReference ref, String label, String value) async {
    setState(() {
      _isLoading = true;
      if (label == 'Bulb') {
        _bulbStatus = value;
      } else if (label == 'Fan') {
        _fanStatus = value;
      }
    });

    try {
      await ref.set(value).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception(
              'Firebase write operation timed out after 10 seconds');
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('✅ $label set to $value'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 1),
      ));
    } catch (e) {
      if (mounted) {
        setState(() {
          if (label == 'Bulb') {
            _bulbStatus = 'Unknown';
          } else if (label == 'Fan') {
            _fanStatus = 'Unknown';
          }
        });
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('❌ Error setting $label: ${e.toString()}'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ));
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Home Control'),
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _isArduinoConnected ? Colors.green : Colors.red,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(
                  _isArduinoConnected ? Icons.wifi : Icons.wifi_off,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  _isArduinoConnected ? 'Connected' : 'Offline',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (!mounted) return;
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ...existing code...
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Expanded(
                    child: _DeviceStatus(
                        icon: Icons.lightbulb,
                        label: 'Bulb',
                        status: _bulbStatus),
                  ),
                  Expanded(
                    child: _DeviceStatus(
                        icon: Icons.air, label: 'Fan', status: _fanStatus),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _DeviceControl(
            icon: Icons.lightbulb,
            label: 'Bulb',
            onPressed: (v) => _setDevice(_bulbCmdRef, 'Bulb', v),
            isLoading: _isLoading,
          ),
          const SizedBox(height: 16),
          _DeviceControl(
            icon: Icons.air,
            label: 'Fan',
            onPressed: (v) => _setDevice(_fanCmdRef, 'Fan', v),
            isLoading: _isLoading,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _statusCheckTimer?.cancel();
    _graphUpdateTimer?.cancel();
    super.dispose();
  }
}

class _DeviceStatus extends StatelessWidget {
  const _DeviceStatus(
      {required this.icon, required this.label, required this.status});

  final IconData icon;
  final String label;
  final String status;

  @override
  Widget build(BuildContext context) {
    final isOn = status == 'ON';
    final color = isOn ? Colors.green : Colors.red;
    return Column(
      children: [
        Icon(icon, color: color, size: 40),
        const SizedBox(height: 8),
        Text('$label: $status',
            style: TextStyle(fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}

class _DeviceControl extends StatelessWidget {
  const _DeviceControl({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.isLoading,
  });

  final IconData icon;
  final String label;
  final ValueChanged<String> onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon,
                    color: label == 'Bulb' ? Colors.orange : Colors.blue),
                const SizedBox(width: 8),
                Text('$label Control',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: ['ON', 'OFF', 'AUTO'].map((value) {
                Color bg;
                switch (value) {
                  case 'ON':
                    bg = Colors.green;
                    break;
                  case 'OFF':
                    bg = Colors.red;
                    break;
                  default:
                    bg = Colors.orange;
                }
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: ElevatedButton(
                      onPressed: isLoading ? null : () => onPressed(value),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: bg,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(value),
                    ),
                  ),
                );
              }).toList(), // <-- This is required!
            ),
          ],
        ),
      ),
    );
  }
}
