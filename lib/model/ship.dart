import 'position.dart';

class Ship {
  final Position start;
  final Position end;
  bool isSunk = false;

  Ship(this.start, this.end);

  int get length {
    return (start.x - end.x).abs() + (start.y - end.y).abs() + 1;
  }
}