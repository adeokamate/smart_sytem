import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
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
  static const _historyDuration = Duration(hours: 24);
  Timer? _arduinoTimeout;

  @override
  void initState() {
    super.initState();
    _initDB();
    _setupListeners();
  }

  void _initDB() {
    _db = kIsWeb
        ? FirebaseDatabase.instanceFor(
            app: FirebaseDatabase.instance.app,
            databaseURL: 'https://the-sess-default-rtdb.firebaseio.com',
          )
        : FirebaseDatabase.instance;

    _bulbCmdRef = _db.ref('devices/bulb');
    _fanCmdRef = _db.ref('devices/fan');
    _bulbStatusRef = _db.ref('status/bulb');
    _fanStatusRef = _db.ref('status/fan');
    _logsRef = _db.ref('logs');
  }

  void _setupListeners() {
    _bulbStatusRef.onValue.listen((event) {
      if (!mounted) return;
      setState(() => _bulbStatus = event.snapshot.value?.toString() ?? 'Unknown');
    });

    _fanStatusRef.onValue.listen((event) {
      if (!mounted) return;
      setState(() => _fanStatus = event.snapshot.value?.toString() ?? 'Unknown');
    });

    // Use only onValue listener for logs - more reliable than onChildAdded
    _logsRef.limitToLast(100).onValue.listen((event) {
     final data = (event.snapshot.value as Map?)?.cast<String, dynamic>();
      if (data == null) return;

      final List<FlSpot> tempSpots = [];
      final cutoff = DateTime.now().subtract(_historyDuration).millisecondsSinceEpoch.toDouble();
      
     data.forEach((key, value) {
  if (value is Map) {
    final casted = Map<String, dynamic>.from(value);
    if (casted.containsKey('temperature') && casted.containsKey('timestamp')) {
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
    });
  }

  Future<void> _setDevice(DatabaseReference ref, String label, String value) async {
    print('Button pressed: $label = $value'); // Debug print
    print('Firebase path: ${ref.path}'); // Debug print
    
    setState(() => _isLoading = true);
    try {
      print('Attempting to write to Firebase...'); // Debug print
      await ref.set(value);
      print('Successfully wrote to Firebase: $label = $value'); // Debug print
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$label set to $value'),
        backgroundColor: Colors.green,
      ));
    } catch (e) {
      print('Error writing to Firebase: $e'); // Debug print
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error setting $label: $e'),
        backgroundColor: Colors.red,
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
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Temperature (last 24h)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 200,
                    child: LineChart(
                      LineChartData(
                        minX: _tempSpots.isEmpty ? 0 : _tempSpots.first.x,
                        maxX: _tempSpots.isEmpty ? 1 : _tempSpots.last.x,
                        minY: 0,
                        maxY: (_tempSpots.isEmpty
                                ? 0
                                : _tempSpots.map((e) => e.y).reduce(math.max)) +
                            5,
                        gridData: FlGridData(show: true),
                        titlesData: FlTitlesData(
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: _tempSpots.isEmpty
                                  ? 1
                                  : (_tempSpots.last.x - _tempSpots.first.x) /
                                      4,
                              getTitlesWidget: (value, _) {
                                final dt = DateTime.fromMillisecondsSinceEpoch(value.toInt());
                                final label = DateFormat.Hm().format(dt);
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(label, style: const TextStyle(fontSize: 10)),
                                );
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: true, interval: 5),
                          ),
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            spots: _tempSpots,
                            isCurved: true,
                            dotData: FlDotData(show: false),
                            belowBarData: BarAreaData(show: false),
                            color: Colors.red,
                            barWidth: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
  mainAxisAlignment: MainAxisAlignment.spaceAround,
  children: [
    Expanded(
      child: _DeviceStatus(icon: Icons.lightbulb, label: 'Bulb', status: _bulbStatus),
    ),
    Expanded(
      child: _DeviceStatus(icon: Icons.air, label: 'Fan', status: _fanStatus),
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
    _arduinoTimeout?.cancel();
    super.dispose();
  }
}

class _DeviceStatus extends StatelessWidget {
  const _DeviceStatus({required this.icon, required this.label, required this.status});

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
        Text('$label: $status', style: TextStyle(fontWeight: FontWeight.bold, color: color)),
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
            Row(children: [
              Icon(icon, color: label == 'Bulb' ? Colors.orange : Colors.blue),
              const SizedBox(width: 8),
              Text('$label Control', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))
            ]),
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
                          backgroundColor: bg, foregroundColor: Colors.white),
                      child: Text(value),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
