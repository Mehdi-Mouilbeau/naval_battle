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

  Future<void> _saveMemory() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> shotsData =
        _allShots.map((pos) => jsonEncode({'x': pos.x, 'y': pos.y})).toList();
    prefs.setStringList('pastShots', shotsData);
    prefs.setStringList('shotResults', _shotResults.map((b) => b.toString()).toList());
  }

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

  Future<void> resetMemory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pastShots');
    await prefs.remove('shotResults');
    _allShots.clear();
    _shotResults.clear();
    _successfulHits.clear();
    _potentialTargets.clear();
    _qValues = List.generate(10, (_) => List.generate(10, (_) => 0.0));
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
    Position target;
    
    if (_potentialTargets.isNotEmpty) {
      // Trouver une cible potentielle qui n'a pas encore été tirée
      int index = _potentialTargets.length - 1;
      while (index >= 0) {
        target = _potentialTargets[index];
        if (!_isPositionShot(target)) {
          _potentialTargets.removeAt(index);
          return target;
        }
        index--;
        _potentialTargets.removeAt(index);
      }
    }

    // Si pas de cibles potentielles valides, choisir une nouvelle position
    return _random.nextDouble() < _explorationRate
        ? _getRandomUntriedPosition(boardSize)
        : _getBestQValuePosition(boardSize);
  }

  void registerHitResult(Position shot, bool isHit) {
    if (!_allShots.any((pos) => pos.x == shot.x && pos.y == shot.y)) {
      _allShots.add(shot);
      _shotResults.add(isHit);
    }

    double reward = isHit ? 1.0 : -1.0;
    _updateQValue(shot, reward);

    if (isHit) {
      _successfulHits.add(shot);
      _addSmartAdjacentTargets(shot);
      
      // Vérifier si un navire a été coulé
      bool shipSunk = _checkIfShipSunk(shot);
      if (shipSunk) {
        _updateQValue(shot, 5.0); // Récompense supplémentaire
      }
    }

    _saveMemory();
  }

  bool _checkIfShipSunk(Position hitPos) {
    int horizontalCount = 1;
    int x = hitPos.x - 1;
    while (x >= 0 && _successfulHits.any((p) => p.x == x && p.y == hitPos.y)) {
      horizontalCount++;
      x--;
    }
    x = hitPos.x + 1;
    while (x < 10 && _successfulHits.any((p) => p.x == x && p.y == hitPos.y)) {
      horizontalCount++;
      x++;
    }
    
    int verticalCount = 1;
    int y = hitPos.y - 1;
    while (y >= 0 && _successfulHits.any((p) => p.x == hitPos.x && p.y == y)) {
      verticalCount++;
      y--;
    }
    y = hitPos.y + 1;
    while (y < 10 && _successfulHits.any((p) => p.x == hitPos.x && p.y == y)) {
      verticalCount++;
      y++;
    }
    
    return horizontalCount >= 3 || verticalCount >= 3;
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
    if (availablePositions.isEmpty) {
      // Si toutes les positions ont été tirées (ne devrait jamais arriver)
      return Position(0, 0);
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

    return bestPositions.isEmpty 
        ? _getRandomUntriedPosition(boardSize) 
        : bestPositions[_random.nextInt(bestPositions.length)];
  }

  void _updateQValue(Position pos, double reward) {
    _qValues[pos.x][pos.y] += _learningRate * (reward - _qValues[pos.x][pos.y]);
    
    // Propager la récompense aux cases adjacentes
    List<Position> adjacentPositions = [
      Position(pos.x - 1, pos.y),
      Position(pos.x + 1, pos.y),
      Position(pos.x, pos.y - 1),
      Position(pos.x, pos.y + 1),
    ];
    
    for (var adjPos in adjacentPositions) {
      if (_isValidPosition(adjPos)) {
        _qValues[adjPos.x][adjPos.y] += _learningRate * reward * _discountFactor;
      }
    }
  }

  void _addSmartAdjacentTargets(Position hit) {
    if (_successfulHits.length >= 2) {
      Position lastHit = _successfulHits[_successfulHits.length - 2];
      
      if (lastHit.x == hit.x) {
        // Alignement vertical
        _addPotentialTarget(Position(hit.x, hit.y - 1));
        _addPotentialTarget(Position(hit.x, hit.y + 1));
      } else if (lastHit.y == hit.y) {
        // Alignement horizontal
        _addPotentialTarget(Position(hit.x - 1, hit.y));
        _addPotentialTarget(Position(hit.x + 1, hit.y));
      } else {
        // Pas d'alignement, tester les 4 directions
        _addAllAdjacentTargets(hit);
      }
    } else {
      _addAllAdjacentTargets(hit);
    }
  }

  void _addAllAdjacentTargets(Position hit) {
    _addPotentialTarget(Position(hit.x - 1, hit.y));
    _addPotentialTarget(Position(hit.x + 1, hit.y));
    _addPotentialTarget(Position(hit.x, hit.y - 1));
    _addPotentialTarget(Position(hit.x, hit.y + 1));
  }

  void _addPotentialTarget(Position pos) {
    if (_isValidPosition(pos) && !_isPositionShot(pos) && 
        !_potentialTargets.any((p) => p.x == pos.x && p.y == pos.y)) {
      _potentialTargets.add(pos);
    }
  }

  bool _isValidPosition(Position pos) => 
      pos.x >= 0 && pos.x < 10 && pos.y >= 0 && pos.y < 10;

  bool _isPositionShot(Position pos) => 
      _allShots.any((p) => p.x == pos.x && p.y == pos.y);
}