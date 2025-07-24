import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:math' as math;

class MetricsScreen extends StatefulWidget {
  const MetricsScreen({super.key});

  @override
  MetricsScreenState createState() => MetricsScreenState();
}

class MetricsScreenState extends State<MetricsScreen>
    with SingleTickerProviderStateMixin {
  final DatabaseReference _database = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
        'https://the-sess-default-rtdb.europe-west1.firebasedatabase.app',
  ).ref();

  double temperature = 0.0;
  int distance = 0;
  bool bulbState = false;
  bool fanState = false;

  List<DataPoint> temperatureData = [];
  int timeCounter = 0;
  final int maxDataPoints = 20;

  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;

  @override
  void initState() {
    super.initState();
    _setupListeners();

    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _blinkAnimation = Tween(begin: 1.0, end: 0.2).animate(_blinkController);
  }

  @override
  void dispose() {
    _blinkController.dispose();
    super.dispose();
  }

  void _setupListeners() {
    _database.child('metrics/temperature').onValue.listen((event) {
      final value = event.snapshot.value;
      if (value is num) {
        setState(() {
          temperature = value.toDouble();
          _addTemperatureDataPoint(temperature);
        });
      }
    });

    _database.child('metrics/distance').onValue.listen((event) {
      final value = event.snapshot.value;
      if (value is num) {
        setState(() {
          distance = value.toInt();
        });
      }
    });

    _database.child('devices/bulb/state').onValue.listen((event) {
      final value = event.snapshot.value;
      if (value is bool) {
        setState(() {
          bulbState = value;
        });
      }
    });

    _database.child('devices/fan/state').onValue.listen((event) {
      final value = event.snapshot.value;
      if (value is bool) {
        setState(() {
          fanState = value;
        });
      }
    });
  }

  void _addTemperatureDataPoint(double temp) {
    temperatureData.add(DataPoint(timeCounter.toDouble(), temp));
    if (temperatureData.length > maxDataPoints) {
      temperatureData.removeAt(0);
    }
    timeCounter++;
  }

  @override
  Widget build(BuildContext context) {
    final isPresent = distance < 15;
    final presenceColor = isPresent ? Colors.green : Colors.red;
    final presenceText = isPresent ? 'Present' : 'Absent';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Energy System'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildMetricCard(
                  'Temperature',
                  '${temperature.toStringAsFixed(1)} °C',
                  Icons.thermostat,
                  Colors.red.shade400,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildDeviceCard(
                    'Bulb', bulbState, Icons.lightbulb, Colors.yellow.shade600),
                _buildDeviceCard(
                    'Fan', fanState, Icons.air, Colors.blue.shade600),
              ],
            ),
            const SizedBox(height: 30),
            _buildChartSection(
              'Temperature Analytics',
              temperatureData,
              Colors.red,
              '°C',
              Icons.thermostat_outlined,
            ),
            const SizedBox(height: 30),
            _buildPresenceIndicator(presenceText, presenceColor),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(
      String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withAlpha(30),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(80)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 8),
            Text(title,
                style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceCard(
      String title, bool state, IconData icon, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: state ? color.withAlpha(30) : Colors.grey.withAlpha(30),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: state ? color.withAlpha(80) : Colors.grey.withAlpha(80)),
        ),
        child: Column(
          children: [
            Icon(icon, color: state ? color : Colors.grey, size: 30),
            const SizedBox(height: 8),
            Text(title,
                style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(state ? 'ON' : 'OFF',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: state ? color : Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildChartSection(String title, List<DataPoint> data, Color color,
      String unit, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withAlpha(30),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 8),
              Text(title,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800)),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 250,
            child: data.isEmpty
                ? Center(
                    child: Text('Waiting for data...',
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 16)),
                  )
                : CustomPaint(
                    size: const Size(double.infinity, 250),
                    painter:
                        LineChartPainter(data: data, color: color, unit: unit),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresenceIndicator(String status, Color color) {
    return FadeTransition(
      opacity: _blinkAnimation,
      child: Center(
        child: Text(
          status,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }
}

class DataPoint {
  final double x;
  final double y;
  DataPoint(this.x, this.y);
}

class LineChartPainter extends CustomPainter {
  final List<DataPoint> data;
  final Color color;
  final String unit;

  LineChartPainter(
      {required this.data, required this.color, required this.unit});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = color.withAlpha(50)
      ..style = PaintingStyle.fill;

    final gridPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1.0;

    double minY = data.map((e) => e.y).reduce(math.min);
    double maxY = data.map((e) => e.y).reduce(math.max);
    double minX = data.map((e) => e.x).reduce(math.min);
    double maxX = data.map((e) => e.x).reduce(math.max);

    if (maxY == minY) {
      maxY += 1;
      minY -= 1;
    }
    if (maxX == minX) {
      maxX += 1;
    }

    double yPadding = (maxY - minY) * 0.1;
    minY -= yPadding;
    maxY += yPadding;

    for (int i = 0; i <= 5; i++) {
      double y = size.height * i / 5;
      canvas.drawLine(Offset(40, y), Offset(size.width - 20, y), gridPaint);
    }

    for (int i = 0; i <= 10; i++) {
      double x = 40 + (size.width - 60) * i / 10;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    List<Offset> points = data.map((point) {
      double x = 40 + (point.x - minX) / (maxX - minX) * (size.width - 60);
      double y = size.height - (point.y - minY) / (maxY - minY) * size.height;
      return Offset(x, y);
    }).toList();

    if (points.length > 1) {
      Path fillPath = Path();
      fillPath.moveTo(points.first.dx, size.height);
      for (var point in points) {
        fillPath.lineTo(point.dx, point.dy);
      }
      fillPath.lineTo(points.last.dx, size.height);
      fillPath.close();
      canvas.drawPath(fillPath, fillPaint);

      Path linePath = Path();
      linePath.moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        linePath.lineTo(points[i].dx, points[i].dy);
      }
      canvas.drawPath(linePath, paint);
    }

    final pointPaint = Paint()..color = color;
    for (var point in points) {
      canvas.drawCircle(point, 4, pointPaint);
      canvas.drawCircle(
          point,
          4,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
    }

    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    for (int i = 0; i <= 5; i++) {
      double value = minY + (maxY - minY) * (5 - i) / 5;
      textPainter.text = TextSpan(
        text: '${value.toStringAsFixed(0)}$unit',
        style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(
          canvas, Offset(5, size.height * i / 5 - textPainter.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
