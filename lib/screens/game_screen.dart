import 'package:flutter/material.dart';
import 'package:naval_battle/model/game_state.dart';
import 'package:naval_battle/model/position.dart';
import 'package:provider/provider.dart';
import '../widgets/game_board.dart';

class GameScreen extends StatelessWidget {
  const GameScreen({super.key});

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
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'Computer\'s Board',
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
                    gameState.fireShot(Position(x, y));
                  }
                },
              ),
            ),
            const SizedBox(height: 20),
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
}