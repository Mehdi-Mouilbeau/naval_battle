import 'package:flutter/material.dart';
import 'package:naval_battle/model/game_mode.dart';
import 'package:naval_battle/model/game_state.dart';
import 'package:naval_battle/model/position.dart';
import 'package:naval_battle/services/ble_service.dart';
import 'package:provider/provider.dart';
import '../widgets/game_board.dart';

class GameScreen extends StatefulWidget {
  final BleService bleService;
  final bool isHost;
  final GameMode gameMode;

  const GameScreen({
    super.key,
    required this.bleService,
    required this.isHost,
    required this.gameMode,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  @override
  void initState() {
    super.initState();
    
    if (widget.gameMode == GameMode.bluetooth) {
      // Écoute des messages Bluetooth si en mode Bluetooth
      widget.bleService.onShotReceived = (Position shot) {
        Provider.of<GameState>(context, listen: false).receiveShot(shot);
      };

      widget.bleService.onHitResponseReceived = (Position pos, bool hit) {
        Provider.of<GameState>(context, listen: false).receiveHitResponse(pos, hit);
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Naval Battle'),
        actions: [
          Consumer<GameState>(
            builder: (context, gameState, child) {
              return IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => gameState.restartGame(),
                tooltip: 'Restart Game',
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Consumer<GameState>(
          builder: (context, gameState, child) {
            return gameState.isPlacingShips
                ? _buildPlacementPhase(context, gameState)
                : _buildBattlePhase(context, gameState);
          },
        ),
      ),
    );
  }

  Widget _buildPlacementPhase(BuildContext context, GameState gameState) {
    final maxWidth = MediaQuery.of(context).size.width;
    final maxBoardSize = maxWidth * 0.9;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Text(
                'Tap cells to place ship (${gameState.remainingShips.first} cells)',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(
              width: maxBoardSize,
              height: maxBoardSize,
              child: GameBoard(
                board: gameState.playerBoard,
                shots: gameState.computerShots,
                onTapCell: gameState.handleCellTap,
              ),
            ),
            const SizedBox(height: 20),
            if (gameState.remainingShips.isNotEmpty)
              Text(
                'Remaining ships: ${gameState.remainingShips.join(', ')}',
                style: const TextStyle(fontSize: 16),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBattlePhase(BuildContext context, GameState gameState) {
    final maxWidth = MediaQuery.of(context).size.width;
    final maxBoardSize = maxWidth * 0.9;
    final playerBoardSize = maxBoardSize * 0.75; // Réduction de 25%

    final stats = gameState.getAccuracyStats();

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            if (gameState.isGameOver)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  gameState.playerWon ? 'You Won!' : 'Opponent Won!',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'Opponent\'s Board',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(
              width: maxBoardSize,
              height: maxBoardSize,
              child: GameBoard(
                board: gameState.computerBoard,
                shots: gameState.playerShots,
                hideShips: true,
                onTapCell: (x, y) {
                  if (!gameState.isPlacingShips) {
                    _sendShot(x, y, gameState);
                  }
                },
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatCard(
                    'Your Accuracy',
                    '${stats['playerAccuracy']!.toStringAsFixed(1)}%',
                    Icons.person,
                    Colors.blue,
                  ),
                  _buildStatCard(
                    'Opponent Accuracy',
                    '${stats['computerAccuracy']!.toStringAsFixed(1)}%',
                    Icons.computer,
                    Colors.red,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Your Board',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(
              width: playerBoardSize,
              height: playerBoardSize,
              child: GameBoard(
                board: gameState.playerBoard,
                shots: gameState.computerShots,
                onTapCell: (_, __) {},
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _sendShot(int x, int y, GameState gameState) {
    final shot = Position(x, y);
    gameState.fireShot(shot);
    
    // Si en mode Bluetooth, envoyez la position via Bluetooth
    if (widget.gameMode == GameMode.bluetooth) {
      widget.bleService.sendShot(shot);
    }
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    widget.bleService.dispose();
    super.dispose();
  }
}
