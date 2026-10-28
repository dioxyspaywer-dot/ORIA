import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:ui';

// ⚠️ REMPLACE PAR TON URL RENDER RÉELLE
const String SERVER_URL = 'https://ton-url-render.onrender.com';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Demander toutes les permissions au premier lancement
  await [
    Permission.camera,
    Permission.microphone,
    Permission.location,
    Permission.notification,
  ].request();

  await initializeService();
  runApp(const OriaChildApp());
}

Future<void> initializeService() async {
  final service = FlutterBackgroundService();
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStartCommand: onStartCommand,
      autoStart: true,
      isForegroundMode: true,
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(autoStart: true),
  );
  await service.startService();
}

@pragma('vm:entry-point')
void onStartCommand(ServiceInstance instance) async {
  DartPluginRegistrant.ensureInitialized();

  final deviceInfo = DeviceInfoPlugin();
  final androidInfo = await deviceInfo.androidInfo;
  final deviceId = androidInfo.id;
  final deviceName = androidInfo.model;

  final socket = IO.io(SERVER_URL, <String, dynamic>{
    'transports': ['websocket'],
    'autoConnect': false,
  });

  socket.connect();

  socket.on('connect', (_) {
    print('✅ Connecté au serveur ORIA');
    socket.emit('register_child', {
      'deviceId': deviceId,
      'deviceName': deviceName
    });
  });

  socket.on('execute_command', (action) {
    print('📡 Commande reçue: $action');
    // Ici, on activerait le flux caméra/micro/écran via WebRTC
    // Pour la V1, on loggue juste la commande
  });

  socket.on('disconnect', (_) {
    print('❌ Déconnecté du serveur');
  });
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.visibility_off, color: Colors.grey[800], size: 100),
              const SizedBox(height: 20),
              Text("ORIA Activé", style: TextStyle(color: Colors.grey[700], fontSize: 18)),
              const SizedBox(height: 10),
              Text("Service en arrière-plan actif.", style: TextStyle(color: Colors.grey[800], fontSize: 12)),
              const SizedBox(height: 30),
              Text("Vous pouvez fermer cette fenêtre.", style: TextStyle(color: Colors.grey[900], fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }
}
