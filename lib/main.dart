import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const NavalBattleApp());
}

class NavalBattleApp extends StatelessWidget {
  const NavalBattleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Naval Battle',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const HomeScreen(),
    );
  }
}