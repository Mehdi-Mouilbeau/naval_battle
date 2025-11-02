import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart' as frb;
import 'package:naval_battle/model/position.dart';


class BleService {
  final frb.FlutterReactiveBle _ble = frb.FlutterReactiveBle();

  void startAdvertising() async {
    final characteristic = frb.QualifiedCharacteristic(
      serviceId: frb.Uuid.parse("0000180D-0000-1000-8000-00805F9B34FB"),
      characteristicId: frb.Uuid.parse("00002A37-0000-1000-8000-00805F9B34FB"),
      deviceId: "host-device",
    );

    _ble.writeCharacteristicWithoutResponse(characteristic, value: [0x01]);
    print("📡 Bluetooth Advertising Started");
  }
  static const String SERVICE_UUID = "45DAD860-E7A7-4037-8B79-F0331E6C78AB";
  static const String CHARACTERISTIC_UUID =
      "45DAD861-E7A7-4037-8B79-F0331E6C78AB";

  fbp.BluetoothDevice? connectedDevice;
  fbp.BluetoothCharacteristic? characteristic;
  StreamSubscription? characteristicSubscription;

  Function(Position)? onShotReceived;
  Function(Position, bool)? onHitResponseReceived;
  bool isHost = false;

  Future<List<fbp.BluetoothDevice>> scanForDevices() async {
  List<fbp.BluetoothDevice> devices = [];

  try {
    await fbp.FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));

    await for (final result in fbp.FlutterBluePlus.scanResults) {
      for (fbp.ScanResult r in result) { 
        if (!devices.contains(r.device)) {
          devices.add(r.device);
        }
      }
    }
  } finally {
    await fbp.FlutterBluePlus.stopScan();
  }

  return devices;
}

//  Stream<frb.DiscoveredDevice> scanForDevices() {
//     return _ble.scanForDevices(
//       withServices: [Uuid.parse("0000180D-0000-1000-8000-00805F9B34FB")],
//       scanMode: ScanMode.lowLatency,
//     );
//   }

  Future<bool> connect(fbp.BluetoothDevice device, {required bool asHost}) async {
    try {
      isHost = asHost;
      await device.connect();
      connectedDevice = device;

      List<fbp.BluetoothService> services = await device.discoverServices();
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
