import 'package:flutter/material.dart';
import 'package:naval_battle/model/game_mode.dart'; 
import 'game_screen.dart'; 
import 'package:naval_battle/services/ble_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final BleService _bleService = BleService();
    final bool _isHost = true; 

    return Scaffold(
      appBar: AppBar(
        title: const Text('Naval Battle'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GameScreen(
                      gameMode: GameMode.singlePlayer,
                      bleService: _bleService,
                      isHost:
                          false,
                    ),
                  ),
                );
              },
              child: const Text('Single Player'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GameScreen(
                      gameMode: GameMode.bluetooth, // Mode Bluetooth
                      bleService: _bleService, // Service BLE
                      isHost: _isHost, // Détermine si on est l'hôte ou non
                    ),
                  ),
                );
              },
              child: const Text('Bluetooth LE Multiplayer'),
            ),
          ],
        ),
      ),
    );
  }
}
