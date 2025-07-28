import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import 'dart:math' as math;

/// A data point with a timestamp (x) and a value (y).
class DataPoint {
  final double x;
  final double y;
  DataPoint(this.x, this.y);
}

class MetricsScreen extends StatefulWidget {
  const MetricsScreen({super.key});

  @override
  MetricsScreenState createState() => MetricsScreenState();
}

class MetricsScreenState extends State<MetricsScreen>
    with SingleTickerProviderStateMixin {
  late final DatabaseReference _db;
  double temperature = 0.0;
  int distance = 0;
  int lastLogTimestamp = 0;
  String bulbStatus = 'Unknown';
  String fanStatus = 'Unknown';

  final List<DataPoint> temperatureData = [];
  static const int _maxDataPoints = 24;

  late final AnimationController _blinkController;
  late final Animation<double> _blinkAnimation;
  
  // Stream subscriptions for proper disposal
  StreamSubscription? _temperatureSubscription;
  StreamSubscription? _bulbStatusSubscription;
  StreamSubscription? _fanStatusSubscription;
  StreamSubscription? _logsSubscription;

  @override
  void initState() {
    super.initState();
    _db = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL:
          'https://the-sess-default-rtdb.europe-west1.firebasedatabase.app',
    ).ref();

    _listenToFirebase();
    _listenToTemperatureLogs();
    _loadInitialStatus();

    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _blinkAnimation =
        Tween<double>(begin: 1.0, end: 0.2).animate(_blinkController);
  }

  @override
  void dispose() {
    // Cancel all stream subscriptions to prevent memory leaks
    _temperatureSubscription?.cancel();
    _bulbStatusSubscription?.cancel();
    _fanStatusSubscription?.cancel();
    _logsSubscription?.cancel();
    
    _blinkController.dispose();
    super.dispose();
  }

  void _loadInitialStatus() {
    // Load initial bulb status
    _db.child('status/bulb').once().then((event) {
      final v = event.snapshot.value;
      print('Initial bulb status: $v (type: ${v.runtimeType})');
      if (v is String) {
        setState(() => bulbStatus = v);
        print('Initial bulb status set to: $bulbStatus');
      }
    });

    // Load initial fan status
    _db.child('status/fan').once().then((event) {
      final v = event.snapshot.value;
      print('Initial fan status: $v (type: ${v.runtimeType})');
      if (v is String) {
        setState(() => fanStatus = v);
        print('Initial fan status set to: $fanStatus');
      }
    });
  }

  void _listenToFirebase() {
    _temperatureSubscription = _db.child('temperature').onValue.listen((event) {
      final v = event.snapshot.value;
      if (v is num && mounted) setState(() => temperature = v.toDouble());
    });

    _bulbStatusSubscription = _db.child('status/bulb').onValue.listen((event) {
      final v = event.snapshot.value;
      print('Bulb status received: $v (type: ${v.runtimeType})');
      if (v is String && mounted) {
        setState(() => bulbStatus = v);
        print('Bulb status updated to: $bulbStatus');
      }
    });

    _fanStatusSubscription = _db.child('status/fan').onValue.listen((event) {
      final v = event.snapshot.value;
      print('Fan status received: $v (type: ${v.runtimeType})');
      if (v is String && mounted) {
        setState(() => fanStatus = v);
        print('Fan status updated to: $fanStatus');
      }
    });
  }

void _listenToTemperatureLogs() {
  double? baseTimestamp;

  _logsSubscription = _db.child('logs').limitToLast(_maxDataPoints * 2).onValue.listen((event) {
    final data = (event.snapshot.value as Map?)?.cast<String, dynamic>();
    if (data == null) return;

    final List<DataPoint> newTemperatureData = [];
    int latestDistance = distance;
    int latestTimestamp = lastLogTimestamp;

    data.forEach((key, value) {
      if (value is Map) {
        final casted = Map<String, dynamic>.from(value);
        
        // Process temperature data
        if (casted.containsKey('temperature') && casted.containsKey('timestamp')) {
          final timestamp = (casted['timestamp'] as num).toDouble();
          final temp = (casted['temperature'] as num).toDouble();

          baseTimestamp ??= timestamp;
          final x = (timestamp - baseTimestamp!) / 60;

          newTemperatureData.add(DataPoint(x, temp));
          
          if (timestamp > latestTimestamp) {
            latestTimestamp = timestamp.toInt();
          }
        }
        
        // Process distance data
        if (casted.containsKey('distance')) {
          final distanceValue = (casted['distance'] as num).toDouble();
          latestDistance = distanceValue.toInt();
        }
      }
    });

    // Sort by timestamp and keep only the latest points
    newTemperatureData.sort((a, b) => a.x.compareTo(b.x));
    if (newTemperatureData.length > _maxDataPoints) {
      newTemperatureData.removeRange(0, newTemperatureData.length - _maxDataPoints);
    }

    if (!mounted) return;
    setState(() {
      temperatureData.clear();
      temperatureData.addAll(newTemperatureData);
      distance = latestDistance;
      lastLogTimestamp = latestTimestamp;
    });
  });
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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildChartSection(
              'Temperature Analytics',
              temperatureData,
              Colors.red,
              '°C',
              Icons.thermostat_outlined,
            ),
            const SizedBox(height: 24),
            FadeTransition(
              opacity: _blinkAnimation,
              child: Center(
                child: Text(
                  presenceText,
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: presenceColor,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Last update: ${lastLogTimestamp > 0 ? DateTime.now().toString().substring(0, 19) : 'No data yet'}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatusCard('Bulb', bulbStatus, Icons.lightbulb),
                _buildStatusCard('Fan', fanStatus, Icons.air),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartSection(
    String title,
    List<DataPoint> data,
    Color color,
    String unit,
    IconData icon,
  ) {
    // Get the visible data points (last N points)
    final visibleData = data.takeLast(_maxDataPoints).toList();
    
    // Calculate min/max for the visible window
    final minX = visibleData.isEmpty ? 0.0 : 0.0; // Always start from 0 for visible window
    final maxX = visibleData.isEmpty ? 1.0 : (_maxDataPoints - 1).toDouble(); // Always end at N-1
    final minY = visibleData.isEmpty ? 0.0 : visibleData.map((e) => e.y).reduce(math.min);
    final maxY = visibleData.isEmpty ? 1.0 : visibleData.map((e) => e.y).reduce(math.max);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 12),
                Text(title,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Current: ${visibleData.isEmpty ? '--' : visibleData.last.y.toStringAsFixed(1)}$unit',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: color),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${visibleData.length} points',
                    style: TextStyle(fontSize: 12, color: color),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Range: ${minY.toStringAsFixed(1)}$unit - ${maxY.toStringAsFixed(1)}$unit',
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                                  child: CustomPaint(
                    size: const Size(double.infinity, 200),
                    painter: _LineChartPainter(
                      data: visibleData,
                      color: color,
                      minX: minX,
                      maxX: maxX,
                      minY: minY,
                      maxY: maxY,
                      maxDataPoints: _maxDataPoints,
                    ),
                  ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(String label, String status, IconData icon) {
    final isOn = status == 'ON';
    final iconColor = isOn ? Colors.green : Colors.red;
    return Container(
      width: 140,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: iconColor, width: 2),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: iconColor.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 36),
          const SizedBox(height: 12),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Text(status, style: TextStyle(color: iconColor, fontSize: 18, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<DataPoint> data;
  final Color color;
  final double minX, maxX, minY, maxY;
  final int maxDataPoints;

  _LineChartPainter({
    required this.data,
    required this.color,
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
    required this.maxDataPoints,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withOpacity(0.3),
          color.withOpacity(0.05),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final gridPaint = Paint()
      ..color = Colors.grey.shade200
      ..strokeWidth = 1;

    final axisPaint = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 2;

    final textStyle = TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500);

    // Draw grid lines
    for (int i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    for (int i = 1; i < 4; i++) {
      final x = size.width * i / 4;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    // Draw axes
    canvas.drawLine(Offset(0, 0), Offset(0, size.height), axisPaint);
    canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height), axisPaint);

    // Draw Y-axis labels
    final yLabelInterval = (maxY - minY) / 4;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (int i = 0; i <= 4; i++) {
      final yValue = minY + i * yLabelInterval;
      final y = size.height - (yValue - minY) / (maxY - minY) * size.height;
      textPainter.text = TextSpan(text: yValue.toStringAsFixed(1), style: textStyle);
      textPainter.layout();
      textPainter.paint(canvas, Offset(8, y - 8));
    }

         // Draw X-axis labels (time points)
     for (int i = 0; i <= 4; i++) {
       final x = size.width * i / 4;
       final timeLabel = i == 0 ? '0' : i == 4 ? '${maxDataPoints - 1}' : '${((maxDataPoints - 1) * i / 4).round()}';
       textPainter.text = TextSpan(text: timeLabel, style: textStyle);
       textPainter.layout();
       textPainter.paint(canvas, Offset(x - 8, size.height + 8));
     }

         // Create normalized points for the visible window
     final points = <Offset>[];
     for (int i = 0; i < data.length; i++) {
       final normalizedX = i.toDouble(); // Normalize X to 0, 1, 2, ..., N-1
       final dx = normalizedX / (maxDataPoints - 1) * size.width;
       final dy = size.height - (data[i].y - minY) / (maxY - minY) * size.height;
       points.add(Offset(dx, dy));
     }

    if (points.isNotEmpty) {
      // Draw filled area
      final fillPath = Path()..moveTo(points.first.dx, size.height);
      for (var p in points) {
        fillPath.lineTo(p.dx, p.dy);
      }
      fillPath.lineTo(points.last.dx, size.height);
      fillPath.close();
      canvas.drawPath(fillPath, fillPaint);

      // Draw line
      final linePath = Path()..moveTo(points.first.dx, points.first.dy);
      for (var p in points.skip(1)) {
        linePath.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(linePath, paint);

      // Draw data points
      final pointPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      
      for (var p in points) {
        canvas.drawCircle(p, 3, pointPaint);
        canvas.drawCircle(p, 3, Paint()..color = Colors.white..strokeWidth = 1..style = PaintingStyle.stroke);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

extension<T> on List<T> {
  List<T> takeLast(int n) => skip(length - n.clamp(0, length)).toList();
}
