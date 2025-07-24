import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ControlPage extends StatefulWidget {
  const ControlPage({super.key});

  @override
  State<ControlPage> createState() => _ControlPageState();
}

class _ControlPageState extends State<ControlPage> {
  late final FirebaseDatabase _db;
  late final DatabaseReference _bulbCmdRef;
  late final DatabaseReference _fanCmdRef;
  late final DatabaseReference _bulbStatusRef;
  late final DatabaseReference _fanStatusRef;
  late final DatabaseReference _temperatureRef;

  String _bulbStatus = 'Unknown';
  String _fanStatus = 'Unknown';
  double _currentTemperature = 0.0;
  bool _isLoading = false;
  final List<double> _tempHistory = [];
  bool _isArduinoConnected = false;

  @override
  void initState() {
    super.initState();
    _initDB();
    _setupListeners();
    _generateTempHistory();
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
    _temperatureRef = _db.ref('sensors/temperature');
  }

  void _setupListeners() {
    _bulbStatusRef.onValue.listen((event) {
      if (mounted) {
        setState(() {
          _bulbStatus = event.snapshot.value.toString();
          _isArduinoConnected = true;
        });
      }
    });

    _fanStatusRef.onValue.listen((event) {
      if (mounted) {
        setState(() {
          _fanStatus = event.snapshot.value.toString();
          _isArduinoConnected = true;
        });
      }
    });

    _temperatureRef.onValue.listen((event) {
      if (mounted) {
        final temp = double.tryParse(event.snapshot.value.toString()) ?? 0.0;
        setState(() {
          _currentTemperature = temp;
          _tempHistory.add(temp);
          if (_tempHistory.length > 24) _tempHistory.removeAt(0);
          _isArduinoConnected = true;
        });
      }
    });
  }

  void _generateTempHistory() {
    for (var i = 0; i < 24; i++) {
      _tempHistory.add(20 + (i % 12) * 0.5 + (i % 3));
    }
  }

  Future<void> _setDevice(
    DatabaseReference reference,
    String label,
    String value,
  ) async {
    setState(() => _isLoading = true);
    try {
      await reference.set(value);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$label: $value'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final maxTemp = _tempHistory.isNotEmpty
        ? _tempHistory.reduce((a, b) => a > b ? a : b)
        : _currentTemperature;
    final minTemp = _tempHistory.isNotEmpty
        ? _tempHistory.reduce((a, b) => a < b ? a : b)
        : _currentTemperature;

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
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isArduinoConnected ? Icons.wifi : Icons.wifi_off,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  _isArduinoConnected ? 'Arduino Connected' : 'Offline',
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Temperature: ${_currentTemperature.toStringAsFixed(1)}°C',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Range: ${minTemp.toStringAsFixed(1)}°C - ${maxTemp.toStringAsFixed(1)}°C',
                      style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.withAlpha((0.6 * 255).round())),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 100,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: _tempHistory.map((temp) {
                          final height =
                              ((temp - minTemp) / (maxTemp - minTemp)) * 80 +
                                  20;
                          return Expanded(
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              height: height,
                              decoration: BoxDecoration(
                                color: temp > 25
                                    ? Colors.red.withAlpha(255)
                                    : Colors.blue.withAlpha(255),
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(2)),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('24h ago', style: TextStyle(fontSize: 12)),
                        Text('Now', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _DeviceStatus(
                      icon: Icons.lightbulb,
                      label: 'Bulb',
                      status: _bulbStatus,
                      activeColor: Colors.orange,
                    ),
                    _DeviceStatus(
                      icon: Icons.air,
                      label: 'Fan',
                      status: _fanStatus,
                      activeColor: Colors.green,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _DeviceControl(
              icon: Icons.lightbulb,
              label: 'Bulb',
              onPressed: (value) => _setDevice(_bulbCmdRef, 'Bulb', value),
              isLoading: _isLoading,
            ),
            const SizedBox(height: 16),
            _DeviceControl(
              icon: Icons.air,
              label: 'Fan',
              onPressed: (value) => _setDevice(_fanCmdRef, 'Fan', value),
              isLoading: _isLoading,
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceStatus extends StatelessWidget {
  const _DeviceStatus({
    required this.icon,
    required this.label,
    required this.status,
    required this.activeColor,
  });

  final IconData icon;
  final String label;
  final String status;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: status == 'ON'
                ? activeColor.withAlpha((0.2 * 255).round())
                : Colors.grey.withAlpha((0.2 * 255).round()),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 40,
            color: status == 'ON' ? activeColor : Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        Text('$label: $status',
            style: const TextStyle(fontWeight: FontWeight.bold)),
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
                    size: 24,
                    color: label == 'Bulb' ? Colors.orange : Colors.green),
                const SizedBox(width: 8),
                Text('$label Control',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: ['ON', 'OFF', 'AUTO'].map((value) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: ElevatedButton(
                      onPressed: isLoading ? null : () => onPressed(value),
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
