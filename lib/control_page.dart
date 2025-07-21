import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ControlPage extends StatefulWidget {
  const ControlPage({super.key});

  @override
  _ControlPageState createState() => _ControlPageState();
}

class _ControlPageState extends State<ControlPage> {
  final DatabaseReference bulbCmdRef =
      FirebaseDatabase.instance.ref('devices/bulb');
  final DatabaseReference fanCmdRef =
      FirebaseDatabase.instance.ref('devices/fan');
  final DatabaseReference bulbStatusRef =
      FirebaseDatabase.instance.ref('status/bulb');
  final DatabaseReference fanStatusRef =
      FirebaseDatabase.instance.ref('status/fan');
  final DatabaseReference temperatureRef =
      FirebaseDatabase.instance.ref('sensors/temperature');

  String bulbStatus = 'Unknown';
  String fanStatus = 'Unknown';
  double currentTemperature = 0.0;
  bool isLoading = false;
  List<double> tempHistory = [];
  bool isArduinoConnected = false;

  @override
  void initState() {
    super.initState();
    _setupListeners();
    _generateTempHistory();
  }

  void _setupListeners() {
    bulbStatusRef.onValue.listen((event) {
      if (mounted) {
        setState(() {
          bulbStatus = event.snapshot.value.toString();
          isArduinoConnected = true;
        });
      }
    });

    fanStatusRef.onValue.listen((event) {
      if (mounted) {
        setState(() {
          fanStatus = event.snapshot.value.toString();
          isArduinoConnected = true;
        });
      }
    });

    temperatureRef.onValue.listen((event) {
      if (mounted) {
        setState(() {
          currentTemperature =
              double.tryParse(event.snapshot.value.toString()) ?? 0.0;
          tempHistory.add(currentTemperature);
          if (tempHistory.length > 24) tempHistory.removeAt(0);
          isArduinoConnected = true;
        });
      }
    });
  }

  void _generateTempHistory() {
    for (int i = 0; i < 24; i++) {
      tempHistory.add(20 + (i % 12) * 0.5 + (i % 3));
    }
  }

  Future<void> setBulb(String value) async {
    setState(() => isLoading = true);
    try {
      await bulbCmdRef.set(value);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bulb: $value'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
    setState(() => isLoading = false);
  }

  Future<void> setFan(String value) async {
    setState(() => isLoading = true);
    try {
      await fanCmdRef.set(value);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fan: $value'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
    setState(() => isLoading = false);
  }

  Widget _buildConnectionStatus() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isArduinoConnected ? Colors.green : Colors.red,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isArduinoConnected ? Icons.wifi : Icons.wifi_off,
            color: Colors.white,
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(
            isArduinoConnected ? 'Arduino Connected' : 'Arduino Offline',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleChart() {
    if (tempHistory.isEmpty) return const SizedBox();

    double maxTemp = tempHistory.reduce((a, b) => a > b ? a : b);
    double minTemp = tempHistory.reduce((a, b) => a < b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Temperature: ${currentTemperature.toStringAsFixed(1)}°C',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(
                'Range: ${minTemp.toStringAsFixed(1)}°C - ${maxTemp.toStringAsFixed(1)}°C',
                style: TextStyle(fontSize: 14, color: Colors.grey[600])),
            const SizedBox(height: 16),
            Container(
              height: 100,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: tempHistory.map((temp) {
                  double normalizedHeight =
                      ((temp - minTemp) / (maxTemp - minTemp)) * 80 + 20;
                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      height: normalizedHeight,
                      decoration: BoxDecoration(
                        color: temp > 25 ? Colors.red : Colors.blue,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Home Control'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: _buildConnectionStatus(),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Temperature Chart
            _buildSimpleChart(),

            const SizedBox(height: 16),

            // Device Status
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Device Status',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: bulbStatus == 'ON'
                                    ? Colors.yellow.withOpacity(0.2)
                                    : Colors.grey.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.lightbulb,
                                color: bulbStatus == 'ON'
                                    ? Colors.orange
                                    : Colors.grey,
                                size: 40,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text('Bulb: $bulbStatus',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: fanStatus == 'ON'
                                    ? Colors.green.withOpacity(0.2)
                                    : Colors.grey.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.air,
                                color: fanStatus == 'ON'
                                    ? Colors.green
                                    : Colors.grey,
                                size: 40,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text('Fan: $fanStatus',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Bulb Controls
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.lightbulb,
                            size: 24, color: Colors.orange),
                        const SizedBox(width: 8),
                        Text('Bulb Control',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isLoading ? null : () => setBulb("ON"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text("ON"),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isLoading ? null : () => setBulb("OFF"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text("OFF"),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isLoading ? null : () => setBulb("AUTO"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text("AUTO"),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Fan Controls
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.air, size: 24, color: Colors.green),
                        const SizedBox(width: 8),
                        Text('Fan Control',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isLoading ? null : () => setFan("ON"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text("ON"),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isLoading ? null : () => setFan("OFF"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text("OFF"),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isLoading ? null : () => setFan("AUTO"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text("AUTO"),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
