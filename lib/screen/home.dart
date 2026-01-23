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
          Permission.bluetooth,
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.locationWhenInUse,
        ].request();

    final denied = res.entries.where((e) => !e.value.isGranted).toList();
    if (denied.isNotEmpty) {
      throw Exception("Permessi negati: $denied");
    }
  }

  Future<ScanResult> initializeBluetoothAndFindSmart() async {
    if (await FlutterBluePlus.isSupported == false) {
      throw Exception("Bluetooth non supportato");
    }

    await _ensurePermissions();
    print("dispositivo sssss");
    await FlutterBluePlus.turnOn();
    final BluetoothAdapterState state = await FlutterBluePlus.adapterState
        .firstWhere((s) => s == BluetoothAdapterState.on)
        .timeout(Duration(seconds: 5));

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
    print("dispositivo aaaaa");

    try {
      /*  final sub = FlutterBluePlus.scanResults.listen((list) {
        for (final r in list) {
          print(
            "id=${r.device.remoteId} platform='${r.device.platformName}' adv='${r.advertisementData.advName}' rssi=${r.rssi}",
          );
        }
      });*/
      List<BluetoothDevice> bluetoothDevices = FlutterBluePlus.connectedDevices;
      print("ooooo ${bluetoothDevices.isEmpty}");
      for (var bluetoothDevice in bluetoothDevices) {
        print("advname: ${bluetoothDevice.advName}");
      }
      final List<ScanResult> results = await FlutterBluePlus.scanResults
          .firstWhere(
            (list) => list.any((r) => r.device.platformName == "SMART"),
          );

      final ScanResult result = results.firstWhere(
        (r) => r.device.platformName == "SMART",
      );
      print("remoteId: ${result.device.remoteId}");

      return result;
    } finally {
      await FlutterBluePlus.stopScan();
    }
  }

  Future<void> connectDevice(ScanResult device) async {
    device.device.connect(
      license: License.free,
      timeout: Duration(seconds: 10),
    );
  }

  Future<void> disconnectDevice(ScanResult device) async {
    device.device.disconnect(queue: true);
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _adapterSub?.cancel();
    super.dispose();
  }

  Future<void> showPairingDialog({
    required BuildContext context,
    required ScanResult device,
    required ImageProvider lockerImage,
    required Future<void> Function() onPair,
  }) async {
    final titleText =
        device.advertisementData.advName.isNotEmpty
            ? device.advertisementData.advName
            : (device.device.platformName.isNotEmpty
                ? device.device.platformName
                : "Locker");

    // 0xBF = ~75% alpha
    const barrier = Color(0xBF000000);

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "pairing",
      barrierColor: barrier,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, __, ___) {
        return SafeArea(
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 340,
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0E0E0E),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: const Color(0xFFFFFFFF).withAlpha(26),
                  ), // ~10%
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 24,
                      spreadRadius: 2,
                      color: const Color(0xFF000000).withAlpha(179), // ~70%
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFFFF).withAlpha(36),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 14),

                    Container(
                      height: 190,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFF161616),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: const Color(0xFFFFFFFF).withAlpha(20),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image(image: lockerImage, fit: BoxFit.cover),
                      ),
                    ),

                    const SizedBox(height: 16),

                    Text(
                      titleText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Pronto per associare",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: const Color(0xFFFFFFFF).withAlpha(179),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w400,
                      ),
                    ),

                    const SizedBox(height: 18),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: TextButton(
                        onPressed: () async {
                          Navigator.of(context).pop();
                          await onPair();
                        },
                        style: ButtonStyle(
                          backgroundColor: const WidgetStatePropertyAll(
                            Color(0xFFFF9000),
                          ),
                          overlayColor: WidgetStatePropertyAll(
                            const Color(0xFFFFFFFF).withAlpha(20),
                          ),
                          alignment: Alignment.center,
                          shape: WidgetStatePropertyAll(
                            RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                        child: const Text(
                          "Associa",
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (_, animation, __, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween(begin: 0.96, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          try {
            final device = await initializeBluetoothAndFindSmart();

            if (!context.mounted) return;

            await showPairingDialog(
              context: context,
              device: device,
              lockerImage: const AssetImage("assets/locker.png"),
              onPair: () => connectDevice(device),
            );
          } catch (e) {
            if (!context.mounted) return;
            showDialog(
              context: context,
              builder:
                  (context) => AlertDialog(
                    title: const Text("Errore"),
                    content: Text(e.toString()),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text("OK"),
                      ),
                    ],
                  ),
            );
          }
        },
        child: const Icon(Icons.play_arrow),
      ),
      body: const Center(child: Text("Premi play per scansionare BLE")),
    );
  }
}
