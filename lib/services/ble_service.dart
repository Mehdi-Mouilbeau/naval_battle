import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:naval_battle/model/position.dart';

class BleService {
  static const String SERVICE_UUID = "45DAD860-E7A7-4037-8B79-F0331E6C78AB";
  static const String CHARACTERISTIC_UUID =
      "45DAD861-E7A7-4037-8B79-F0331E6C78AB";

  BluetoothDevice? connectedDevice;
  BluetoothCharacteristic? characteristic;
  StreamSubscription? characteristicSubscription;

  Function(Position)? onShotReceived;
  Function(Position, bool)? onHitResponseReceived;
  bool isHost = false;

  Future<List<BluetoothDevice>> scanForDevices() async {
    List<BluetoothDevice> devices = [];

    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));

      await for (final result in FlutterBluePlus.scanResults) {
        for (ScanResult r in result) {
          if (!devices.contains(r.device)) {
            devices.add(r.device);
          }
        }
      }
    } finally {
      await FlutterBluePlus.stopScan();
    }

    return devices;
  }

  Future<bool> connect(BluetoothDevice device, {required bool asHost}) async {
    try {
      isHost = asHost;
      await device.connect();
      connectedDevice = device;

      List<BluetoothService> services = await device.discoverServices();
      for (var service in services) {
        if (service.uuid.toString() == SERVICE_UUID) {
          for (var char in service.characteristics) {
            if (char.uuid.toString() == CHARACTERISTIC_UUID) {
              characteristic = char;
              await _setupCharacteristic();
              return true;
            }
          }
        }
      }

      return false;
    } catch (e) {
      print('Error connecting: $e');
      return false;
    }
  }

  Future<void> _setupCharacteristic() async {
    if (characteristic == null) return;

    await characteristic!.setNotifyValue(true);
    characteristicSubscription =
        characteristic!.onValueReceived.listen((value) {
      _handleReceivedData(value);
    });
  }

  void _handleReceivedData(List<int> data) {
    String message = utf8.decode(data);
    Map<String, dynamic> messageData = jsonDecode(message);

    if (messageData['type'] == 'shot') {
      onShotReceived?.call(Position(messageData['x'], messageData['y']));
    } else if (messageData['type'] == 'hit_response') {
      onHitResponseReceived?.call(Position(messageData['x'], messageData['y']), messageData['hit']);
    }
  }

  Future<void> sendShot(Position shot) async {
    if (characteristic == null) return;

    Map<String, dynamic> message = {
      'type': 'shot',
      'x': shot.x,
      'y': shot.y,
    };

    await characteristic!.write(
      utf8.encode(jsonEncode(message)),
      withoutResponse: true,
    );
  }

  Future<void> sendHitResponse(bool isHit) async {
    if (characteristic == null) return;

    Map<String, dynamic> message = {
      'type': 'hit_response',
      'hit': isHit,
    };

    await characteristic!.write(
      utf8.encode(jsonEncode(message)),
      withoutResponse: true,
    );
  }


  void dispose() {
  characteristicSubscription?.cancel();
  connectedDevice?.disconnect();
}

}
