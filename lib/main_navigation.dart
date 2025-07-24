// lib/main_navigation.dart
import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'control_page.dart';
import 'metrics_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  MainNavigationState createState() => MainNavigationState();
}

class MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const ControlPage(),
    const MetricsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Colors.blue,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.power), label: "Control"),
          BottomNavigationBarItem(
            icon: Icon(Icons.thermostat),
            label: "Metrics",
          ),
        ],
      ),
    );
  }
}
