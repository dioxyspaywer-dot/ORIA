import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:ui';

// ⚠️ Mets ton URL Render ici quand tu l'auras
// Pour l'instant, cette valeur temporaire permet la compilation
const String SERVER_URL = 'https://placeholder.onrender.com';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
      // ✅ CORRECTION DÉFINITIVE : onStart (confirmé par la doc officielle v5.x)
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
    ),
  );
  await service.startService();
}

@pragma('vm:entry-point')
void onStart(ServiceInstance instance) async {
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
      'deviceName': deviceName,
    });
  });

  socket.on('execute_command', (action) {
    print('📡 Commande reçue: $action');
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
              Text("ORIA Activé",
                  style: TextStyle(color: Colors.grey[700], fontSize: 18)),
              const SizedBox(height: 10),
              Text("Service en arrière-plan actif.",
                  style: TextStyle(color: Colors.grey[800], fontSize: 12)),
              const SizedBox(height: 30),
              Text("Vous pouvez fermer cette fenêtre.",
                  style: TextStyle(color: Colors.grey[900], fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }
}