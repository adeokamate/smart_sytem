
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
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
  Timer? _esp32StatusTimer;
  late final FirebaseDatabase _db;
  late final DatabaseReference _bulbCmdRef;
  late final DatabaseReference _fanCmdRef;
  late final DatabaseReference _bulbStatusRef;
  late final DatabaseReference _fanStatusRef;
  late final DatabaseReference _logsRef;

  String _bulbStatus = 'Unknown';
  String _fanStatus = 'Unknown';
  bool _isLoading = false;

  // Threshold settings
  double _temperatureThreshold = 25.0;
  double _distanceThreshold = 15.0;
  bool _showThresholdSettings = false;

  final List<FlSpot> _tempSpots = [];
  List<DateTime> _timeLabels = [];

  @override
  void initState() {
    super.initState();
    _initDB();
    _startPeriodicStatusCheck();
    _fetchTemperatureLogs();
    _startGraphPeriodicUpdate();
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
    _loadThresholds();
  }

  Future<void> _fetchTemperatureLogs() async {
    final cutoff = DateTime.now()
        .subtract(const Duration(minutes: 30))
        .millisecondsSinceEpoch
        .toDouble();

    try {
      final snapshot =
          await _logsRef.orderByChild('timestamp').startAt(cutoff).get();
      final data = (snapshot.value as Map?)?.cast<String, dynamic>();
      if (data == null) {
        if (!mounted) return;
        setState(() {
          _tempSpots.clear();
          _timeLabels.clear();
        });
        return;
      }

      final List<FlSpot> tempSpots = [];
      final List<DateTime> times = [];

      int index = 0;
      data.forEach((key, value) {
        if (value is Map) {
          final casted = Map<String, dynamic>.from(value);
          if (casted.containsKey('temperature') &&
              casted.containsKey('timestamp')) {
            final ts = (casted['timestamp'] as num?)?.toInt() ?? 0;
            final temp = (casted['temperature'] as num?)?.toDouble() ?? 0.0;
            if (ts >= cutoff) {
              tempSpots.add(FlSpot(index.toDouble(), temp));
              times.add(DateTime.fromMillisecondsSinceEpoch(ts));
              index++;
            }
          }
        }
      });

      if (!mounted) return;
      setState(() {
        _tempSpots.clear();
        _tempSpots.addAll(tempSpots);
        _timeLabels = times;
      });
    } catch (e) {
      print('❌ Error fetching temperature logs: $e');
    }
  }

  void _startGraphPeriodicUpdate() {
    _graphUpdateTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _fetchTemperatureLogs();
    });
  }

  Future<void> _loadThresholds() async {
    try {
      final tempSnapshot = await _db.ref('settings/temperatureThreshold').get();
      final distSnapshot = await _db.ref('settings/distanceThreshold').get();

      if (mounted) {
        setState(() {
          if (tempSnapshot.value != null) {
            _temperatureThreshold = (tempSnapshot.value as num).toDouble();
          }
          if (distSnapshot.value != null) {
            _distanceThreshold = (distSnapshot.value as num).toDouble();
          }
        });
      }
    } catch (e) {
      print('❌ Error loading thresholds: $e');
    }
  }

  Future<void> _saveThresholds() async {
    try {
      await _db.ref('settings/temperatureThreshold').set(_temperatureThreshold);
      await _db.ref('settings/distanceThreshold').set(_distanceThreshold);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Threshold settings saved successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error saving settings: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
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
          // Threshold Settings
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.tune, color: Colors.blue),
                      const SizedBox(width: 8),
                      const Text(
                        'Automatic Mode Settings',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(_showThresholdSettings
                            ? Icons.expand_less
                            : Icons.expand_more),
                        onPressed: () {
                          setState(() {
                            _showThresholdSettings = !_showThresholdSettings;
                          });
                        },
                      ),
                    ],
                  ),
                  if (_showThresholdSettings) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.thermostat,
                            color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        const Text('Temperature Threshold:'),
                        const Spacer(),
                        Text('${_temperatureThreshold.toStringAsFixed(1)}°C'),
                      ],
                    ),
                    Slider(
                      value: _temperatureThreshold,
                      min: 15.0,
                      max: 40.0,
                      divisions: 50,
                      onChanged: (value) {
                        setState(() {
                          _temperatureThreshold = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.straighten,
                            color: Colors.orange, size: 20),
                        const SizedBox(width: 8),
                        const Text('Distance Threshold:'),
                        const Spacer(),
                        Text('${_distanceThreshold.toStringAsFixed(0)}cm'),
                      ],
                    ),
                    Slider(
                      value: _distanceThreshold,
                      min: 5.0,
                      max: 50.0,
                      divisions: 45,
                      onChanged: (value) {
                        setState(() {
                          _distanceThreshold = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _saveThresholds,
                      icon: const Icon(Icons.save),
                      label: const Text('Save Settings'),
                    ),
                  ]
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Device Status
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
          const SizedBox(height: 24),

          // Temperature Graph
          if (_tempSpots.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.show_chart, color: Colors.red),
                        SizedBox(width: 8),
                        Text(
                          'Temperature (last 30 minutes)',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 200,
                      child: LineChart(
                        LineChartData(
                          minY: _tempSpots.map((e) => e.y).reduce(math.min) - 1,
                          maxY: _tempSpots.map((e) => e.y).reduce(math.max) + 1,
                          lineBarsData: [
                            LineChartBarData(
                              spots: _tempSpots,
                              isCurved: true,
                              color: Colors.red,
                              barWidth: 3,
                              dotData: FlDotData(show: false),
                            ),
                          ],
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: true),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                interval: (_tempSpots.length / 4)
                                    .clamp(1, 10)
                                    .toDouble(),
                                getTitlesWidget: (value, meta) {
                                  final index = value.toInt();
                                  if (index < 0 ||
                                      index >= _timeLabels.length) {
                                    return const SizedBox();
                                  }
                                  final date = _timeLabels[index];
                                  final label =
                                      "${date.hour}:${date.minute.toString().padLeft(2, '0')}";
                                  return SideTitleWidget(
                                    axisSide: meta.axisSide,
                                    child: Text(label,
                                        style: const TextStyle(fontSize: 10)),
                                  );
                                },
                              ),
                            ),
                          ),
                          gridData: FlGridData(show: true),
                          borderData: FlBorderData(show: true),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _statusCheckTimer?.cancel();
    _graphUpdateTimer?.cancel();
    _esp32StatusTimer?.cancel();
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
                const Spacer(),
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

                final isButtonEnabled = !isLoading;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: ElevatedButton(
                      onPressed:
                          isButtonEnabled ? () => onPressed(value) : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            isButtonEnabled ? bg : Colors.grey.shade300,
                        foregroundColor: isButtonEnabled
                            ? Colors.white
                            : Colors.grey.shade600,
                        elevation: isButtonEnabled ? 2 : 0,
                      ),
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
