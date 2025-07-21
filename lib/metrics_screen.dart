import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:math' as math;

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

  // Lists to store historical data for graphs
  List<DataPoint> temperatureData = [];
  List<DataPoint> distanceData = [];

  // Counter for x-axis (time points)
  int timeCounter = 0;

  // Maximum number of data points to display
  final int maxDataPoints = 20;

  @override
  void initState() {
    super.initState();

    // Temperature listener with safe casting
    tempRef.onValue.listen((event) {
      final value = event.snapshot.value;
      if (value is num) {
        setState(() {
          temperature = value.toDouble();
          _addTemperatureDataPoint(temperature);
        });
      }
    });

    // Distance listener with safe casting
    distRef.onValue.listen((event) {
      final value = event.snapshot.value;
      if (value is num) {
        setState(() {
          distance = value.toInt();
          _addDistanceDataPoint(distance.toDouble());
        });
      }
    });
  }

  void _addTemperatureDataPoint(double temp) {
    temperatureData.add(DataPoint(timeCounter.toDouble(), temp));

    // Keep only the last maxDataPoints
    if (temperatureData.length > maxDataPoints) {
      temperatureData.removeAt(0);
    }
  }

  void _addDistanceDataPoint(double dist) {
    distanceData.add(DataPoint(timeCounter.toDouble(), dist));

    // Keep only the last maxDataPoints
    if (distanceData.length > maxDataPoints) {
      distanceData.removeAt(0);
    }

    timeCounter++;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sensor Metrics Analytics'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Current values display
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildMetricCard(
                  'Temperature',
                  '${temperature.toStringAsFixed(1)} °C',
                  Icons.thermostat,
                  Colors.red.shade400,
                ),
                _buildMetricCard(
                  'Distance',
                  '$distance cm',
                  Icons.straighten,
                  Colors.blue.shade400,
                ),
              ],
            ),

            const SizedBox(height: 30),

            // Temperature Line Graph
            _buildChartSection(
              'Temperature Analytics',
              temperatureData,
              Colors.red,
              '°C',
              Icons.thermostat_outlined,
            ),

            const SizedBox(height: 30),

            // Distance Line Graph
            _buildChartSection(
              'Distance Analytics',
              distanceData,
              Colors.blue,
              'cm',
              Icons.straighten,
            ),
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
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
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
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 250,
            child: data.isEmpty
                ? Center(
                    child: Text(
                      'Waiting for data...',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 16,
                      ),
                    ),
                  )
                : CustomPaint(
                    size: const Size(double.infinity, 250),
                    painter: LineChartPainter(
                      data: data,
                      color: color,
                      unit: unit,
                    ),
                  ),
          ),
        ],
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

  LineChartPainter({
    required this.data,
    required this.color,
    required this.unit,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = color.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    final gridPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1.0;

    // Calculate bounds
    double minY = data.map((e) => e.y).reduce(math.min);
    double maxY = data.map((e) => e.y).reduce(math.max);
    double minX = data.map((e) => e.x).reduce(math.min);
    double maxX = data.map((e) => e.x).reduce(math.max);

    // Add padding
    double yPadding = (maxY - minY) * 0.1;
    minY -= yPadding;
    maxY += yPadding;

    // Draw grid lines
    for (int i = 0; i <= 5; i++) {
      double y = size.height * i / 5;
      canvas.drawLine(
        Offset(40, y),
        Offset(size.width - 20, y),
        gridPaint,
      );
    }

    for (int i = 0; i <= 10; i++) {
      double x = 40 + (size.width - 60) * i / 10;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        gridPaint,
      );
    }

    // Convert data points to screen coordinates
    List<Offset> points = data.map((point) {
      double x = 40 + (point.x - minX) / (maxX - minX) * (size.width - 60);
      double y = size.height - (point.y - minY) / (maxY - minY) * size.height;
      return Offset(x, y);
    }).toList();

    // Draw filled area
    if (points.length > 1) {
      Path fillPath = Path();
      fillPath.moveTo(points.first.dx, size.height);
      for (var point in points) {
        fillPath.lineTo(point.dx, point.dy);
      }
      fillPath.lineTo(points.last.dx, size.height);
      fillPath.close();
      canvas.drawPath(fillPath, fillPaint);
    }

    // Draw line
    if (points.length > 1) {
      Path linePath = Path();
      linePath.moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        linePath.lineTo(points[i].dx, points[i].dy);
      }
      canvas.drawPath(linePath, paint);
    }

    // Draw data points
    final pointPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

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

    // Draw Y-axis labels
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    for (int i = 0; i <= 5; i++) {
      double value = minY + (maxY - minY) * (5 - i) / 5;
      textPainter.text = TextSpan(
        text: '${value.toStringAsFixed(0)}$unit',
        style: TextStyle(
          color: Colors.grey.shade600,
          fontSize: 10,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(5, size.height * i / 5 - textPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
