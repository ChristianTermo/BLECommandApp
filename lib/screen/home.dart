import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class Home extends StatefulWidget {
  const Home({super.key, required this.title});
  final String title;

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  StreamSubscription? _scanSub;
  StreamSubscription? _adapterSub;

  Future<void> _ensurePermissions() async {
    if (!Platform.isAndroid) return;

    final res =
        await [
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.locationWhenInUse,
        ].request();

    final denied = res.entries.where((e) => !e.value.isGranted).toList();
    if (denied.isNotEmpty) {
      throw Exception("Permessi negati: $denied");
    }
  }

  Future<void> initializeBluetooth() async {
    if (await FlutterBluePlus.isSupported == false) {
      print("Bluetooth non supportato");
      return;
    }

    await _ensurePermissions();

    _adapterSub?.cancel();
    _adapterSub = FlutterBluePlus.adapterState.listen((state) async {
      print("adapter state: $state");
      if (state != BluetoothAdapterState.on) return;

      _scanSub?.cancel();
      _scanSub = FlutterBluePlus.scanResults.listen((results) {
        if (results.isEmpty) {
          print("scan batch vuoto");
          return;
        }
        ScanResult result =
            results.where((r) => r.device.platformName == ("SMART")).first;
        result.device.connect(license: License.free, autoConnect: false);
        for (final r in results) {
          print(
            "${r.device.remoteId} adv='${r.advertisementData.advName}' "
            "platformiooo='${r.device.platformName}' rssi=${r.rssi}",
          );
        }
      }, onError: (e) => print("scan error: $e"));

      print("START SCAN");
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
    });
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _adapterSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => {initializeBluetooth},

        child: const Icon(Icons.play_arrow),
      ),
      body: const Center(child: Text("Premi play per scansionare BLE")),
    );
  }
}
