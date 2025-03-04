import 'package:flutter/material.dart';

class GameBoard extends StatelessWidget {
  final List<List<bool>> board;
  final List<List<bool>>? shots;
  final Function(int x, int y) onTapCell;
  final bool hideShips;

  const GameBoard({
    super.key,
    required this.board,
    this.shots,
    required this.onTapCell,
    this.hideShips = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/oceangrid.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 10,
        ),
        itemCount: 100,
        itemBuilder: (context, index) {
          final x = index ~/ 10;
          final y = index % 10;
          final hasShip = board[x][y];
          final isShot = shots?[x][y] ?? false;

          return GestureDetector(
            onTap: () => onTapCell(x, y),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black.withOpacity(0.3), width: 0.5),
                color: _getCellColor(hasShip, isShot),
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getCellColor(bool hasShip, bool isShot) {
    if (!isShot) {
      // Si le navire est présent et qu'on ne doit pas le cacher
      if (hasShip && !hideShips) {
        return Colors.grey.withOpacity(0.7);
      }
      // Sinon, cellule transparente pour voir l'image de fond
      return Colors.transparent;
    }
    // Si la cellule a été touchée
    return hasShip ? Colors.red.withOpacity(0.7) : Colors.white.withOpacity(0.3);
  }
}