import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:naval_battle/model/game_mode.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/ble_service.dart';
import 'game_screen.dart';

class BleSetupScreen extends StatefulWidget {
  final BleService bleService;
  const BleSetupScreen({Key? key, required this.bleService}) : super(key: key);

  @override
  State<BleSetupScreen> createState() => _BleSetupScreenState();
}

class _BleSetupScreenState extends State<BleSetupScreen> {
  final BleService _bleService = BleService();
  List<BluetoothDevice> _devices = [];
  bool _isScanning = false;
  bool _isHost = false;

  @override
  void initState() {
    super.initState();
    _initBle();
  }

  Future<void> _initBle() async {
    await Permission.bluetooth.request();
    await Permission.bluetoothConnect.request();
    await Permission.bluetoothScan.request();
    await Permission.bluetoothAdvertise.request();
    await Permission.location.request();
    
    bool isOn = await FlutterBluePlus.isSupported;
    if (!isOn) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bluetooth is not supported on this device')),
        );
      }
      return;
    }
  }

  Future<void> _startScan() async {
    setState(() {
      _isScanning = true;
      _devices.clear();
    });

    try {
      List<BluetoothDevice> devices = await _bleService.scanForDevices();
      if (mounted) {
        setState(() {
          _devices = devices;
          _isScanning = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error scanning: $e')),
        );
        setState(() => _isScanning = false);
      }
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
  setState(() => _isScanning = true);

  bool connected = await _bleService.connect(device, asHost: _isHost);

  if (mounted) {
    setState(() => _isScanning = false);

    if (connected) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => GameScreen(
            bleService: _bleService,
            isHost: _isHost,
            gameMode: GameMode.bluetooth,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to connect')),
      );
    }
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bluetooth LE Setup')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const Text('Host Game: '),
                Switch(
                  value: _isHost,
                  onChanged: (value) => setState(() => _isHost = value),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: _isScanning ? null : _startScan,
            child: Text(_isScanning ? 'Scanning...' : 'Scan for Devices'),
          ),
          Expanded(
            child: _isScanning
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _devices.length,
                    itemBuilder: (context, index) {
                      final device = _devices[index];
                      return ListTile(
                        title: Text(device.platformName),
                        subtitle: Text(device.remoteId.toString()),
                        onTap: () => _connectToDevice(device),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}