import 'package:flutter/material.dart';
import '../widgets/monitor_drawer.dart';
import 'home_screen.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const MonitorDrawer(),
      body: const HomeScreen(),
    );
  }
}
