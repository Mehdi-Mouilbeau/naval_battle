import 'package:flutter/foundation.dart';
import 'ship.dart';
import 'position.dart';
import 'computer_ai.dart';

class GameState extends ChangeNotifier {
  final int boardSize = 10;
  late List<List<bool>> playerBoard;
  late List<List<bool>> computerBoard;
  late List<List<bool>> playerShots;
  late List<List<bool>> computerShots;
  late List<Ship> ships;
  late ComputerAI computerAI;
  late bool isPlacingShips;
  late List<int> remainingShips;
  late bool isGameOver;
  late bool playerWon;
  late List<Position> currentShipCells;

  GameState() {
    _initializeGame();
  }

  void _initializeGame() {
    playerBoard = List.generate(10, (i) => List.generate(10, (j) => false));
    computerBoard = List.generate(10, (i) => List.generate(10, (j) => false));
    playerShots = List.generate(10, (i) => List.generate(10, (j) => false));
    computerShots = List.generate(10, (i) => List.generate(10, (j) => false));
    ships = [];
    computerAI = ComputerAI();
    isPlacingShips = true;
    remainingShips = [5, 4, 3, 3, 2];
    isGameOver = false;
    playerWon = false;
    currentShipCells = [];
    _initializeComputerBoard();
  }

  void _initializeComputerBoard() {
    final computerShips = computerAI.placeShips(boardSize, [5, 4, 3, 3, 2]);
    for (var ship in computerShips) {
      if (ship.start.x == ship.end.x) {
        for (int y = ship.start.y; y <= ship.end.y; y++) {
          computerBoard[ship.start.x][y] = true;
        }
      } else {
        for (int x = ship.start.x; x <= ship.end.x; x++) {
          computerBoard[x][ship.start.y] = true;
        }
      }
    }
  }

  void restartGame() {
    _initializeGame();
    notifyListeners();
  }

  bool _isAdjacentToExistingShip(int x, int y) {
    // Check all adjacent cells including diagonals
    for (int i = -1; i <= 1; i++) {
      for (int j = -1; j <= 1; j++) {
        int newX = x + i;
        int newY = y + j;

        // Skip if out of bounds
        if (newX < 0 || newX >= boardSize || newY < 0 || newY >= boardSize) {
          continue;
        }

        // Skip the current cell being checked
        if (i == 0 && j == 0) {
          continue;
        }

        // Check if there's a ship cell that's not part of the current ship
        if (playerBoard[newX][newY] &&
            !currentShipCells.any((cell) => cell.x == newX && cell.y == newY)) {
          return true;
        }
      }
    }
    return false;
  }

  bool _isAdjacentToCurrentShip(int x, int y) {
    if (currentShipCells.isEmpty) return true;

    // Check if the new cell is adjacent to any cell in the current ship
    for (var cell in currentShipCells) {
      // Check horizontal and vertical adjacency (not diagonal)
      if ((cell.x == x && (cell.y == y - 1 || cell.y == y + 1)) ||
          (cell.y == y && (cell.x == x - 1 || cell.x == x + 1))) {
        return true;
      }
    }

    return false;
  }

  bool canPlaceShipCell(int x, int y, int shipLength) {
    // Check if the cell is already occupied by another ship
    if (playerBoard[x][y] &&
        !currentShipCells.any((cell) => cell.x == x && cell.y == y)) {
      return false;
    }

    // Check if the cell is adjacent to another ship
    if (_isAdjacentToExistingShip(x, y)) {
      return false;
    }

    // For the first cell, no additional checks needed
    if (currentShipCells.isEmpty) return true;

    // Check if the new cell is adjacent to the current ship
    if (!_isAdjacentToCurrentShip(x, y)) {
      return false;
    }

    final firstCell = currentShipCells[0];
    bool isHorizontal = currentShipCells.length > 1
        ? currentShipCells.every((cell) => cell.x == firstCell.x)
        : (x == firstCell.x || y == firstCell.y);
    bool isVertical = currentShipCells.length > 1
        ? currentShipCells.every((cell) => cell.y == firstCell.y)
        : (x == firstCell.x || y == firstCell.y);

    // If we already have multiple cells, enforce the direction
    if (currentShipCells.length > 1) {
      if (isHorizontal && x != firstCell.x) return false;
      if (isVertical && y != firstCell.y) return false;
    }

    // Check if adding this cell would exceed the ship length
    if (isHorizontal) {
      int minY =
          currentShipCells.map((p) => p.y).reduce((a, b) => a < b ? a : b);
      int maxY =
          currentShipCells.map((p) => p.y).reduce((a, b) => a > b ? a : b);

      // If the new cell is outside the current range, check if it would make the ship too long
      if (y < minY) {
        if (maxY - y + 1 > shipLength) return false;
      } else if (y > maxY) {
        if (y - minY + 1 > shipLength) return false;
      }
    }

    if (isVertical) {
      int minX =
          currentShipCells.map((p) => p.x).reduce((a, b) => a < b ? a : b);
      int maxX =
          currentShipCells.map((p) => p.x).reduce((a, b) => a > b ? a : b);

      // If the new cell is outside the current range, check if it would make the ship too long
      if (x < minX) {
        if (maxX - x + 1 > shipLength) return false;
      } else if (x > maxX) {
        if (x - minX + 1 > shipLength) return false;
      }
    }

    return true;
  }

  void handleCellTap(int x, int y) {
    if (!isPlacingShips || remainingShips.isEmpty) return;

    final position = Position(x, y);

    // If the cell is already part of the current ship, remove it and all subsequent cells
    if (currentShipCells.any((cell) => cell.x == x && cell.y == y)) {
      int index =
          currentShipCells.indexWhere((cell) => cell.x == x && cell.y == y);
      for (int i = currentShipCells.length - 1; i >= index; i--) {
        var cell = currentShipCells[i];
        playerBoard[cell.x][cell.y] = false;
        currentShipCells.removeAt(i);
      }
      notifyListeners();
      return;
    }

    // Check if we can place a new cell
    if (currentShipCells.isEmpty) {
      if (!playerBoard[x][y]) {
        currentShipCells.add(position);
        playerBoard[x][y] = true;
      }
    } else {
      if (canPlaceShipCell(x, y, remainingShips[0]) && !playerBoard[x][y]) {
        currentShipCells.add(position);
        playerBoard[x][y] = true;

        if (currentShipCells.length == remainingShips[0]) {
          ships.add(Ship(currentShipCells.first, currentShipCells.last));
          remainingShips.removeAt(0);
          currentShipCells.clear();

          if (remainingShips.isEmpty) {
            isPlacingShips = false;
          }
        }
      }
    }

    notifyListeners();
  }

  bool fireShot(Position pos) {
    if (isPlacingShips || playerShots[pos.x][pos.y] || isGameOver) return false;

    playerShots[pos.x][pos.y] = true;
    final isHit = computerBoard[pos.x][pos.y];

    _computerTurn();

    _checkGameOver();
    notifyListeners();
    return isHit;
  }

  void _computerTurn() {
    final shot = computerAI.getNextShot(boardSize);
    final isHit = playerBoard[shot.x][shot.y];
    computerShots[shot.x][shot.y] = true;
    computerAI.registerHitResult(shot, isHit);
  }

  void _checkGameOver() {
    bool allComputerShipsHit = true;
    bool allPlayerShipsHit = true;

    for (int i = 0; i < boardSize; i++) {
      for (int j = 0; j < boardSize; j++) {
        if (computerBoard[i][j] && !playerShots[i][j]) {
          allComputerShipsHit = false;
        }
        if (playerBoard[i][j] && !computerShots[i][j]) {
          allPlayerShipsHit = false;
        }
      }
    }

    if (allComputerShipsHit || allPlayerShipsHit) {
      isGameOver = true;
      playerWon = allComputerShipsHit;
    }
  }
}
