// metrics_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class MetricsScreen extends StatefulWidget {
  const MetricsScreen({super.key});

  @override
  _MetricsScreenState createState() => _MetricsScreenState();
}

class _MetricsScreenState extends State<MetricsScreen> {
  final DatabaseReference tempRef = FirebaseDatabase.instance.ref(
    'metrics/temperature',
  );
  final DatabaseReference distRef = FirebaseDatabase.instance.ref(
    'metrics/distance',
  );

  double temperature = 0.0;
  int distance = 0;

  @override
  void initState() {
    super.initState();

    // ✅ Temperature listener with safe casting
    tempRef.onValue.listen((event) {
      final value = event.snapshot.value;
      if (value is num) {
        setState(() {
          temperature = value.toDouble();
        });
      }
    });

    // ✅ Distance listener with safe casting
    distRef.onValue.listen((event) {
      final value = event.snapshot.value;
      if (value is num) {
        setState(() {
          distance = value.toInt();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Sensor Metrics')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              "Temperature: ${temperature.toStringAsFixed(1)} °C",
              style: TextStyle(fontSize: 22),
            ),
            SizedBox(height: 20),
            Text("Distance: $distance cm", style: TextStyle(fontSize: 22)),
          ],
        ),
      ),
    );
  }
}
