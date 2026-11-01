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
      // ✅ Parent s'enregistre et rejoint sa salle
      socket.emit('register_parent', PARENT_ID);
      socket.emit('get_devices');
      print('✅ [PARENT] CONNECTED + REGISTERED');
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
              : RefreshIndicator(onRefresh: () async => socket.emit('get_devices'), child: ListView.builder(padding: const EdgeInsets.all(16), itemCount: devices.length, itemBuilder: (_, i) {
                  final d = devices[i]; final online = d['status'] == 'online';
                  return Card(margin: const EdgeInsets.only(bottom: 12), child: ListTile(
                    leading: CircleAvatar(backgroundColor: online ? Colors.green : Colors.grey, child: Icon(online ? Icons.check : Icons.close, color: Colors.white)),
                    title: Text(d['customName'] ?? d['deviceName'] ?? 'Inconnu'), subtitle: Text(online ? 'En ligne' : 'Hors ligne'), trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DashboardScreen(device: d, socket: socket))),
                    onLongPress: () => _rename(d['_id'], d['customName'] ?? d['deviceName']),
                  ));
                })),
    );
  }
  @override void dispose() { socket.disconnect(); super.dispose(); }
}

class DashboardScreen extends StatefulWidget {
  final Map<String, dynamic> device;
  final IO.Socket socket;
  const DashboardScreen({super.key, required this.device, required this.socket});
  @override State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int idx = 0;
  RTCVideoRenderer? _renderer;
  RTCPeerConnection? _pc;
  bool streaming = false;
  // ✅ Référence pour nettoyer l'écouteur signal
  Function? _signalListener;

  @override void initState() { super.initState(); _initRenderer(); }
  Future<void> _initRenderer() async { _renderer = RTCVideoRenderer(); await _renderer!.initialize(); }

  Future<void> _startStream(String type) async {
    // ✅ Nettoyer toute session précédente
    _cleanupSession();

    final requestId = DateTime.now().millisecondsSinceEpoch.toString();
    widget.socket.emit('command', {'targetId': widget.device['deviceId'], 'action': type, 'requestId': requestId});
    setState(() => streaming = true);
    print('📡 [PARENT] COMMAND_SENT: $type (req:$requestId)');

    _pc = await createPeerConnection({
      'iceServers': [{'urls': 'stun:stun.l.google.com:19302'}, {'urls': 'stun:stun1.l.google.com:19302'}]
    });

    _pc!.onTrack = (event) {
      print('📥 [PARENT] REMOTE_TRACK_RECEIVED: ${event.track.kind}');
      if (event.streams.isNotEmpty) {
        _renderer!.srcObject = event.streams[0];
        _renderer!.muted = false;
      }
    };

    _pc!.onIceCandidate = (c) {
      if (c.candidate != null) {
        widget.socket.emit('signal', {'target': widget.device['deviceId'], 'type': 'candidate', 'data': c.toMap()});
      }
    };

    _pc!.onConnectionState = (state) => print('🔗 [PARENT] CONNECTION_STATE: $state');
    _pc!.onIceConnectionState = (state) => print('🧊 [PARENT] ICE_STATE: $state');

    // ✅ Écouteur avec référence pour nettoyage + format uniforme
    _signalListener = (msg) async {
      // ✅ CORRECTION: lire msg['type'] directement (pas msg['payload']['type'])
      final sigType = msg['type'];
      final sigData = msg['data'];
      try {
        if (sigType == 'offer') {
          print('📥 [PARENT] OFFER_RECEIVED');
          await _pc!.setRemoteDescription(RTCSessionDescription(sigData['sdp'], sigData['type']));
          final answer = await _pc!.createAnswer();
          await _pc!.setLocalDescription(answer);
          widget.socket.emit('signal', {'target': widget.device['deviceId'], 'type': 'answer', 'data': answer.toMap()});
          print('📤 [PARENT] ANSWER_SENT');
        } else if (sigType == 'candidate') {
          print('📥 [PARENT] CANDIDATE_RECEIVED');
          await _pc!.addCandidate(RTCIceCandidate(sigData['candidate'], sigData['sdpMid'], sigData['sdpMLineIndex']));
        }
      } catch (e) {
        print('❌ [PARENT] SIGNAL_ERROR: $e');
      }
    };
    widget.socket.on('signal', _signalListener!);
  }

  // ✅ Nettoyage complet de la session
  void _cleanupSession() {
    if (_signalListener != null) {
      widget.socket.off('signal', _signalListener);
      _signalListener = null;
    }
    _pc?.close();
    _pc = null;
    _renderer?.srcObject = null;
    streaming = false;
  }

  void _stopStream() {
    widget.socket.emit('command', {'targetId': widget.device['deviceId'], 'action': 'stop_stream'});
    _cleanupSession();
    setState(() {});
    print('🛑 [PARENT] STREAM_STOPPED');
  }

  @override void dispose() { _cleanupSession(); _renderer?.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final pages = [
      Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.devices, size: 80, color: Colors.indigo), const SizedBox(height: 20), Text(widget.device['customName'] ?? widget.device['deviceName'], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)), const SizedBox(height: 8), Text(widget.device['status'] == 'online' ? '🟢 En ligne' : '⚪ Hors ligne')])),
      Column(children: [Expanded(child: streaming && _renderer != null ? RTCVideoView(_renderer!) : Container(color: Colors.black87, child: const Center(child: Text('Caméra inactive', style: TextStyle(color: Colors.white54))))), Padding(padding: const EdgeInsets.all(16), child: streaming ? FilledButton.icon(onPressed: _stopStream, icon: const Icon(Icons.stop), label: const Text('ARRÊTER'), style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: Colors.red)) : FilledButton.icon(onPressed: () => _startStream('start_camera'), icon: const Icon(Icons.play_arrow), label: const Text('DEMANDER CAMÉRA'), style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 50))))]),
      Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.center, children: [Icon(streaming ? Icons.mic : Icons.mic_none, size: 100, color: streaming ? Colors.green : Colors.indigo), const SizedBox(height: 16), if (streaming) Text('🔊 Écoute en cours...', style: TextStyle(color: Colors.green[300], fontSize: 16)), const SizedBox(height: 24), streaming ? FilledButton.icon(onPressed: _stopStream, icon: const Icon(Icons.stop), label: const Text('ARRÊTER'), style: FilledButton.styleFrom(minimumSize: const Size(250, 50), backgroundColor: Colors.red)) : FilledButton.icon(onPressed: () => _startStream('start_mic'), icon: const Icon(Icons.play_arrow), label: const Text('DEMANDER MICRO'), style: FilledButton.styleFrom(minimumSize: const Size(250, 50)))])),
      Column(children: [Expanded(child: streaming && _renderer != null ? RTCVideoView(_renderer!) : Container(color: Colors.black87, child: const Center(child: Text('Écran inactif', style: TextStyle(color: Colors.white54))))), Padding(padding: const EdgeInsets.all(16), child: streaming ? FilledButton.icon(onPressed: _stopStream, icon: const Icon(Icons.stop), label: const Text('ARRÊTER'), style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: Colors.red)) : FilledButton.icon(onPressed: () => _startStream('start_screen'), icon: const Icon(Icons.play_arrow), label: const Text('DEMANDER ÉCRAN'), style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 50))))]),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(widget.device['customName'] ?? widget.device['deviceName'])),
      body: pages[idx],
      bottomNavigationBar: NavigationBar(selectedIndex: idx, onDestinationSelected: (i) { if (streaming) _stopStream(); setState(() => idx = i); }, destinations: const [
        NavigationDestination(icon: Icon(Icons.info), label: 'Infos'),
        NavigationDestination(icon: Icon(Icons.videocam), label: 'Caméra'),
        NavigationDestination(icon: Icon(Icons.mic), label: 'Micro'),
        NavigationDestination(icon: Icon(Icons.phone_android), label: 'Écran'),
      ]),
    );
  }
}