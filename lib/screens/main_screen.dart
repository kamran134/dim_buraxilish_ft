import 'package:flutter/material.dart';
import '../widgets/app_drawer.dart';
import 'home_screen.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      body: const HomeScreen(),
    );
  }
}
