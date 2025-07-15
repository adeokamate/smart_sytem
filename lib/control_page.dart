// control_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class ControlPage extends StatefulWidget {
  @override
  _ControlPageState createState() => _ControlPageState();
}

class _ControlPageState extends State<ControlPage> {
  final DatabaseReference bulbCmdRef = FirebaseDatabase.instance.ref(
    'devices/bulb',
  );
  final DatabaseReference fanCmdRef = FirebaseDatabase.instance.ref(
    'devices/fan',
  );
  final DatabaseReference bulbStatusRef = FirebaseDatabase.instance.ref(
    'status/bulb',
  );
  final DatabaseReference fanStatusRef = FirebaseDatabase.instance.ref(
    'status/fan',
  );

  String bulbStatus = 'Unknown';
  String fanStatus = 'Unknown';

  Future<void> setBulb(String value) async {
    await bulbCmdRef.set(value);
  }

  Future<void> setFan(String value) async {
    await fanCmdRef.set(value);
  }

  @override
  void initState() {
    super.initState();

    bulbStatusRef.onValue.listen((event) {
      final status = event.snapshot.value;
      if (status != null) {
        setState(() {
          bulbStatus = status.toString();
        });
      }
    });

    fanStatusRef.onValue.listen((event) {
      final status = event.snapshot.value;
      if (status != null) {
        setState(() {
          fanStatus = status.toString();
        });
      }
    });
  }

  Widget buildDeviceControl({
    required String title,
    required String status,
    required void Function(String) onCommand,
  }) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              '$title Status: $status',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Wrap(
              spacing: 12,
              children: [
                ElevatedButton(
                  onPressed: () => onCommand("ON"),
                  child: Text("ON"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                ),
                ElevatedButton(
                  onPressed: () => onCommand("OFF"),
                  child: Text("OFF"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                ),
                ElevatedButton(
                  onPressed: () => onCommand("AUTO"),
                  child: Text("AUTO"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                  ),
                ),
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
      appBar: AppBar(title: Text('Smart Home Manual Control')),
      body: ListView(
        children: [
          buildDeviceControl(
            title: 'Bulb',
            status: bulbStatus,
            onCommand: setBulb,
          ),
          buildDeviceControl(
            title: 'Fan',
            status: fanStatus,
            onCommand: setFan,
          ),
        ],
      ),
    );
  }
}
