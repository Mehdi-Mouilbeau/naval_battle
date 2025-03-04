import 'dart:math';
import 'position.dart';
import 'ship.dart';

class ComputerAI {
  final Random _random = Random();
  final List<Position> _successfulHits = [];
  final List<Position> _potentialTargets = [];
  final List<Position> _allShots = []; // Garde une trace de tous les tirs

  List<Ship> placeShips(int boardSize, List<int> shipLengths) {
    List<Ship> ships = [];
    List<List<bool>> board = List.generate(
      boardSize,
      (i) => List.generate(boardSize, (j) => false),
    );

    for (int length in shipLengths) {
      bool placed = false;
      while (!placed) {
        int x = _random.nextInt(boardSize);
        int y = _random.nextInt(boardSize);
        bool isHorizontal = _random.nextBool();

        if (_canPlaceShip(board, x, y, length, isHorizontal, boardSize)) {
          Position start = Position(x, y);
          Position end = Position(
            isHorizontal ? x : x + length - 1,
            isHorizontal ? y + length - 1 : y,
          );

          _placeShipOnBoard(board, start, end);
          ships.add(Ship(start, end));
          placed = true;
        }
      }
    }

    return ships;
  }

  bool _canPlaceShip(List<List<bool>> board, int x, int y, int length,
      bool isHorizontal, int boardSize) {
    if (isHorizontal) {
      if (y + length > boardSize) return false;
      for (int i = 0; i < length; i++) {
        if (board[x][y + i]) return false;
      }
    } else {
      if (x + length > boardSize) return false;
      for (int i = 0; i < length; i++) {
        if (board[x + i][y]) return false;
      }
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

  Position getNextShot(int boardSize) {
    // D'abord, vérifier si nous avons des cibles potentielles basées sur des hits précédents
    if (_potentialTargets.isNotEmpty) {
      Position target = _potentialTargets.removeLast();
      _allShots.add(target); // Ajouter à la liste des tirs
      return target;
    }

    // Sinon, utiliser la stratégie du damier avec un mécanisme de secours
    int maxAttempts = 100; // Limite pour éviter une boucle infinie
    int attempts = 0;
    
    while (attempts < maxAttempts) {
      int x = _random.nextInt(boardSize);
      int y = _random.nextInt(boardSize);
      Position pos = Position(x, y);
      
      // Vérifier que la case respecte le motif damier et n'a pas déjà été ciblée
      if ((x + y) % 2 == 0 && !_isPositionShot(pos)) {
        _allShots.add(pos); // Ajouter à la liste des tirs
        return pos;
      }
      
      attempts++;
    }
    
    // Si nous n'avons pas trouvé de position valide avec le motif damier,
    // choisir n'importe quelle position non ciblée
    for (int x = 0; x < boardSize; x++) {
      for (int y = 0; y < boardSize; y++) {
        Position pos = Position(x, y);
        if (!_isPositionShot(pos)) {
          _allShots.add(pos); // Ajouter à la liste des tirs
          return pos;
        }
      }
    }
    
    // Fallback au cas où toutes les positions ont été ciblées (ne devrait jamais arriver)
    return Position(0, 0);
  }

  void registerHitResult(Position shot, bool isHit) {
    if (isHit) {
      _successfulHits.add(shot);
      _addSmartAdjacentTargets(shot);
    }
  }

  void _addSmartAdjacentTargets(Position hit) {
    if (_successfulHits.length >= 2) {
      // Vérifier si deux hits sont alignés
      Position lastHit = _successfulHits[_successfulHits.length - 2];

      if (lastHit.x == hit.x) {
        // Alignement vertical -> Ne tester que haut/bas
        _addPotentialTarget(Position(hit.x, hit.y - 1));
        _addPotentialTarget(Position(hit.x, hit.y + 1));
      } else if (lastHit.y == hit.y) {
        // Alignement horizontal -> Ne tester que gauche/droite
        _addPotentialTarget(Position(hit.x - 1, hit.y));
        _addPotentialTarget(Position(hit.x + 1, hit.y));
      } else {
        // Pas alignés, ajouter les 4 directions
        _addPotentialTarget(Position(hit.x - 1, hit.y));
        _addPotentialTarget(Position(hit.x + 1, hit.y));
        _addPotentialTarget(Position(hit.x, hit.y - 1));
        _addPotentialTarget(Position(hit.x, hit.y + 1));
      }
    } else {
      // Premier hit -> Ajouter les 4 directions possibles
      _addPotentialTarget(Position(hit.x - 1, hit.y));
      _addPotentialTarget(Position(hit.x + 1, hit.y));
      _addPotentialTarget(Position(hit.x, hit.y - 1));
      _addPotentialTarget(Position(hit.x, hit.y + 1));
    }
  }

  void _addPotentialTarget(Position pos) {
    if (_isValidPosition(pos) && !_isPositionShot(pos) && 
        !_potentialTargets.any((p) => p.x == pos.x && p.y == pos.y)) {
      _potentialTargets.add(pos);
    }
  }

  bool _isValidPosition(Position pos) {
    return pos.x >= 0 && pos.x < 10 && pos.y >= 0 && pos.y < 10;
  }

  bool _isPositionShot(Position pos) {
    return _allShots.any((p) => p.x == pos.x && p.y == pos.y);
  }
}