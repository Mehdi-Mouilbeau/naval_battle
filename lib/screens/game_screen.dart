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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxBoardSize = constraints.maxWidth * 0.9;
            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    Consumer<GameState>(
                      builder: (context, gameState, child) {
                        return Column(
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
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Text(
                                gameState.isPlacingShips 
                                    ? 'Tap cells to place ship (${gameState.remainingShips.first} cells)' 
                                    : 'Your Board',
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                            ),
                            SizedBox(
                              width: maxBoardSize,
                              height: maxBoardSize,
                              child: GameBoard(
                                board: gameState.playerBoard,
                                shots: gameState.computerShots,
                                onTapCell: gameState.isPlacingShips 
                                    ? gameState.handleCellTap
                                    : (_, __) {},
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'Computer\'s Board',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}