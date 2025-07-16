// control_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';

class ControlPage extends StatefulWidget {
  const ControlPage({super.key});

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
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              '$title Status: $status',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              children: [
                ElevatedButton(
                  onPressed: () => onCommand("ON"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  child: const Text("ON"),
                ),
                ElevatedButton(
                  onPressed: () => onCommand("OFF"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text("OFF"),
                ),
                ElevatedButton(
                  onPressed: () => onCommand("AUTO"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                  ),
                  child: const Text("AUTO"),
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
      appBar: AppBar(
        title: const Text('THE SMART ENERGY SAVING DASHBOARD'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
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
