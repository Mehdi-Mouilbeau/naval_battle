import 'dart:math';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import 'position.dart';
import 'ship.dart';

class ComputerAI {
  final Random _random = Random();
  final List<Position> _successfulHits = [];
  final List<Position> _potentialTargets = [];
  final List<Position> _allShots = [];
  final List<bool> _shotResults = [];

  late List<List<double>> _qValues;
  final double _learningRate = 0.1;
  final double _discountFactor = 0.9;
  final double _explorationRate = 0.2;
  final String _memoryFile = 'q_memory.json';

  ComputerAI() {
    _qValues = List.generate(10, (_) => List.generate(10, (_) => 0.0));
    _loadMemory();
  }

  /// Sauvegarde la mémoire des tirs avec SharedPreferences
  Future<void> _saveMemory() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> shotsData =
        _allShots.map((pos) => jsonEncode({'x': pos.x, 'y': pos.y})).toList();
    prefs.setStringList('pastShots', shotsData);
    prefs.setStringList('shotResults', _shotResults.map((b) => b.toString()).toList());
  }

  /// Charge la mémoire des tirs depuis SharedPreferences
  Future<void> _loadMemory() async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? shotsData = prefs.getStringList('pastShots');
    List<String>? resultsData = prefs.getStringList('shotResults');

    if (shotsData != null && resultsData != null) {
      _allShots.clear();
      _shotResults.clear();

      _allShots.addAll(shotsData
          .map((s) => jsonDecode(s))
          .map((json) => Position(json['x'], json['y']))
          .toList());
      _shotResults.addAll(resultsData.map((s) => s == 'true'));
    }
  }

  /// Réinitialise la mémoire
  Future<void> resetMemory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pastShots');
    await prefs.remove('shotResults');
    _allShots.clear();
    _shotResults.clear();
  }

  List<Ship> placeShips(int boardSize, List<int> shipLengths) {
    List<Ship> ships = [];
    List<List<bool>> board = List.generate(boardSize, (_) => List.generate(boardSize, (_) => false));

    for (int length in shipLengths) {
      bool placed = false;
      while (!placed) {
        int x = _random.nextInt(boardSize);
        int y = _random.nextInt(boardSize);
        bool isHorizontal = _random.nextBool();

        if (_canPlaceShip(board, x, y, length, isHorizontal, boardSize)) {
          Position start = Position(x, y);
          Position end = isHorizontal ? Position(x, y + length - 1) : Position(x + length - 1, y);
          _placeShipOnBoard(board, start, end);
          ships.add(Ship(start, end));
          placed = true;
        }
      }
    }
    return ships;
  }

  Position getNextShot(int boardSize) {
    if (_potentialTargets.isNotEmpty) {
      Position target = _potentialTargets.removeLast();
      _allShots.add(target);
      return target;
    }

    return _random.nextDouble() < _explorationRate
        ? _getRandomUntriedPosition(boardSize)
        : _getBestQValuePosition(boardSize);
  }

  void registerHitResult(Position shot, bool isHit) {
    double reward = isHit ? 1.0 : -1.0;
    _updateQValue(shot, reward);

    _allShots.add(shot);
    _shotResults.add(isHit);

    if (isHit) {
      _successfulHits.add(shot);
      _addSmartAdjacentTargets(shot);
    }
    _saveMemory();
  }

  bool _canPlaceShip(List<List<bool>> board, int x, int y, int length, bool isHorizontal, int boardSize) {
    if (isHorizontal && y + length > boardSize) return false;
    if (!isHorizontal && x + length > boardSize) return false;
    for (int i = 0; i < length; i++) {
      if (board[x + (isHorizontal ? 0 : i)][y + (isHorizontal ? i : 0)]) return false;
    }
    return true;
  }

  void _placeShipOnBoard(List<List<bool>> board, Position start, Position end) {
    if (start.x == end.x) {
      for (int y = start.y; y <= end.y; y++) {
        board[start.x][y] = true;
      }
    } else {
      for (int x = start.x; x <= end.x; x++) {
        board[x][start.y] = true;
      }
    }
  }

  Position _getRandomUntriedPosition(int boardSize) {
    List<Position> availablePositions = [];
    for (int x = 0; x < boardSize; x++) {
      for (int y = 0; y < boardSize; y++) {
        Position pos = Position(x, y);
        if (!_isPositionShot(pos)) {
          availablePositions.add(pos);
        }
      }
    }
    return availablePositions[_random.nextInt(availablePositions.length)];
  }

  Position _getBestQValuePosition(int boardSize) {
    double maxQValue = -double.infinity;
    List<Position> bestPositions = [];

    for (int x = 0; x < boardSize; x++) {
      for (int y = 0; y < boardSize; y++) {
        Position pos = Position(x, y);
        if (!_isPositionShot(pos)) {
          double qValue = _qValues[x][y];
          if (qValue > maxQValue) {
            maxQValue = qValue;
            bestPositions = [pos];
          } else if (qValue == maxQValue) {
            bestPositions.add(pos);
          }
        }
      }
    }

    return bestPositions.isEmpty ? _getRandomUntriedPosition(boardSize) : bestPositions[_random.nextInt(bestPositions.length)];
  }

  void _updateQValue(Position pos, double reward) {
    _qValues[pos.x][pos.y] += _learningRate * (reward - _qValues[pos.x][pos.y]);
  }

  void _addSmartAdjacentTargets(Position hit) {
    List<Position> adjacentPositions = [
      Position(hit.x - 1, hit.y),
      Position(hit.x + 1, hit.y),
      Position(hit.x, hit.y - 1),
      Position(hit.x, hit.y + 1),
    ];
    for (var pos in adjacentPositions) {
      if (_isValidPosition(pos) && !_isPositionShot(pos) && !_potentialTargets.contains(pos)) {
        _potentialTargets.add(pos);
      }
    }
  }

  bool _isValidPosition(Position pos) => pos.x >= 0 && pos.x < 10 && pos.y >= 0 && pos.y < 10;
  bool _isPositionShot(Position pos) => _allShots.contains(pos);
}
