import 'package:flutter/material.dart';
import 'package:naval_battle/model/game_mode.dart';
import 'package:naval_battle/model/game_state.dart';
import 'package:naval_battle/model/position.dart';
import 'package:provider/provider.dart';
import '../widgets/game_board.dart';
import '../services/ble_service.dart';

class GameScreen extends StatefulWidget {
  final GameMode gameMode;
  final BleService? bleService;
  final bool isHost;

  const GameScreen({
    super.key, 
    this.gameMode = GameMode.singlePlayer,
    this.bleService,
    this.isHost = false,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late GameState gameState;
  bool isMyTurn = true;

  @override
  void initState() {
    super.initState();
    gameState = GameState();
    
    if (widget.gameMode == GameMode.bluetooth && widget.bleService != null) {
      _setupBluetoothListeners();
      isMyTurn = widget.isHost;
    }
  }

  void _setupBluetoothListeners() {
    widget.bleService!.onShotReceived = (Position shot) {
      if (!gameState.isPlacingShips) {
        final isHit = gameState.playerBoard[shot.x][shot.y];
        widget.bleService!.sendHitResponse(isHit);
        setState(() => isMyTurn = true);
      }
    };

    widget.bleService!.onHitResponseReceived = (Position shot, bool isHit) {
      if (!gameState.isPlacingShips) {
        setState(() {
          gameState.playerShots[shot.x][shot.y] = true;
          if (isHit) {
            gameState.playerHits++;
            gameState.computerBoard[shot.x][shot.y] = true;
          } else {
            gameState.playerMisses++;
          }
          isMyTurn = false;
        });
      }
    };
  }

  @override
  void dispose() {
    widget.bleService?.dispose();
    super.dispose();
  }

  void _handleShot(int x, int y) {
    if (!isMyTurn || gameState.isPlacingShips || gameState.isGameOver) return;

    if (widget.gameMode == GameMode.bluetooth) {
      final shot = Position(x, y);
      widget.bleService?.sendShot(shot);
      setState(() => isMyTurn = false);
    } else {
      setState(() {
        gameState.fireShot(Position(x, y));
      });
    }
  }

  void _handleCellTap(int x, int y) {
    setState(() {
      gameState.handleCellTap(x, y);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: gameState,
      child: Consumer<GameState>(
        builder: (context, gameState, child) {
          final maxWidth = MediaQuery.of(context).size.width;
          final maxBoardSize = maxWidth * 0.9;
          final playerBoardSize = maxBoardSize * 0.75;
          
          return Scaffold(
            appBar: AppBar(
              title: const Text('Naval Battle'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () {
                    setState(() {
                      gameState.restartGame(resetAI: true);
                    });
                  },
                  tooltip: 'Restart Game',
                ),
              ],
            ),
            body: SafeArea(
              child: gameState.isPlacingShips 
                  ? _buildPlacementPhase(context, maxBoardSize, gameState)
                  : _buildBattlePhase(context, maxBoardSize, playerBoardSize, gameState),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlacementPhase(BuildContext context, double maxBoardSize, GameState gameState) {
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
                onTapCell: _handleCellTap,
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

  Widget _buildBattlePhase(BuildContext context, double maxBoardSize, double playerBoardSize, GameState gameState) {
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
                  gameState.playerWon ? 'You Won!' : 'Computer Won!',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
            if (!isMyTurn && widget.gameMode == GameMode.bluetooth)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Waiting for opponent...',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
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
                onTapCell: _handleShot,
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
                    widget.gameMode == GameMode.bluetooth ? 'Opponent Accuracy' : 'AI Accuracy', 
                    '${stats['computerAccuracy']!.toStringAsFixed(1)}%',
                    widget.gameMode == GameMode.bluetooth ? Icons.person_outline : Icons.computer,
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
}