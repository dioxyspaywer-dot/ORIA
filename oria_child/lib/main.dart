import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:device_info_plus/device_info_plus.dart';
import 'stream_service.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

const String SERVER_URL = 'https://oria-server-tzc1.onrender.com';

final List<String> _logs = [];
void log(String msg) {
  final line = '${DateTime.now().toString().substring(11, 19)} $msg';
  _logs.insert(0, line);
  if (_logs.length > 30) _logs.removeLast();
  print('[ORIA] $line');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  log('App demarree (MODE PREMIER PLAN)');

  await [
    Permission.camera,
    Permission.microphone,
    Permission.notification,
  ].request();
  log('Permissions demandees');

  runApp(const OriaChildApp());
}

class OriaChildApp extends StatefulWidget {
  const OriaChildApp({super.key});
  @override
  State<OriaChildApp> createState() => _OriaChildAppState();
}

class _OriaChildAppState extends State<OriaChildApp> {
  late IO.Socket socket;
  StreamService? streamService;
  bool connected = false;
  String deviceId = '';
  String deviceName = '';
  RTCVideoRenderer? localRenderer;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final deviceInfo = DeviceInfoPlugin();
    final androidInfo = await deviceInfo.androidInfo;
    deviceId = androidInfo.id;
    deviceName = '${androidInfo.manufacturer} ${androidInfo.model}';
    log('Device: $deviceName ($deviceId)');

    localRenderer = RTCVideoRenderer();
    await localRenderer!.initialize();

    socket = IO.io(SERVER_URL, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
      'reconnection': true,
      'reconnectionDelay': 3000,
    });

    socket.on('connect', (_) {
      setState(() => connected = true);
      log('CONNECTE AU SERVEUR');
      socket.emit('register_child', {'deviceId': deviceId, 'deviceName': deviceName});
      log('ENREGISTRE: $deviceName');
    });

    socket.on('disconnect', (_) => setState(() => connected = false));

    socket.on('execute_command', (data) async {
      final action = data['action'];
      log('COMMANDE RECUE: $action');
      await _handleCommand(action);
      setState(() {});
    });

    socket.on('signal', (msg) {
      log('SIGNAL RECU: ${msg['type']}');
      streamService?.handleSignal(msg);
    });

    socket.on('connect_error', (_) => log('ERREUR CONNEXION...'));
  }

  Future<void> _handleCommand(String action) async {
    try {
      if (action == 'start_camera') {
        await streamService?.stop();
        streamService = StreamService(socket, 'parent-main');
        await streamService!.startCamera();
        // Afficher localement pour debug
        if (streamService!.localStream != null) {
          localRenderer!.srcObject = streamService!.localStream;
        }
        log('CAMERA DEMARREE (locale + remote)');
      } else if (action == 'start_mic') {
        await streamService?.stop();
        streamService = StreamService(socket, 'parent-main');
        await streamService!.startMic();
        log('MICRO DEMARRE');
      } else if (action == 'start_screen') {
        await streamService?.stop();
        streamService = StreamService(socket, 'parent-main');
        await streamService!.startScreen();
        if (streamService!.localStream != null) {
          localRenderer!.srcObject = streamService!.localStream;
        }
        log('ECRAN DEMARRE');
      } else if (action == 'stop_stream') {
        await streamService?.stop();
        streamService = null;
        localRenderer!.srcObject = null;
        log('STREAM ARRETE');
      }
    } catch (e) {
      log('ERREUR: $e');
    }
  }

  @override
  void dispose() {
    streamService?.stop();
    localRenderer?.dispose();
    socket.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          title: Text(connected ? 'ORIA - En ligne' : 'ORIA - Hors ligne',
              style: TextStyle(color: connected ? Colors.green : Colors.red)),
        ),
        body: Column(
          children: [
            // Preview locale pour debug
            SizedBox(
              height: 200,
              child: localRenderer != null && localRenderer!.srcObject != null
                  ? RTCVideoView(localRenderer!, mirror: true)
                  : Container(color: Colors.grey[900], child: const Center(child: Text('Preview locale', style: TextStyle(color: Colors.grey)))),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(onPressed: () => _handleCommand('start_camera'), child: const Text('Test Camera')),
                  ElevatedButton(onPressed: () => _handleCommand('start_mic'), child: const Text('Test Mic')),
                  ElevatedButton(onPressed: () => _handleCommand('stop_stream'), child: const Text('Stop')),
                ],
              ),
            ),
            const Divider(color: Colors.grey),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: _logs.length,
                itemBuilder: (_, i) => Text(
                  _logs[i],
                  style: TextStyle(
                    color: _logs[i].contains('ERREUR') ? Colors.red :
                           _logs[i].contains('DEMARRE') || _logs[i].contains('CONNECTE') ? Colors.green :
                           _logs[i].contains('COMMANDE') ? Colors.yellow : Colors.grey[400],
                    fontSize: 11, fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}