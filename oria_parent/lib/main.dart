import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:google_fonts/google_fonts.dart';

const String SERVER_URL = 'https://oria-server-tzc1.onrender.com';

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
    socket = IO.io(SERVER_URL, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
      'reconnection': true,
      'reconnectionDelay': 5000,
    });
    socket.on('connect', (_) { setState(() => connected = true); socket.emit('get_devices'); });
    socket.on('disconnect', (_) => setState(() => connected = false));
    socket.on('device_list', (data) => setState(() => devices = List<Map<String, dynamic>>.from(data)));
    socket.on('device_list_updated', (_) => socket.emit('get_devices'));
  }

  Future<void> _rename(String id, String name) async {
    final c = TextEditingController(text: name);
    await showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Renommer'),
      content: TextField(controller: c, decoration: const InputDecoration(labelText: 'Nom personnalisé')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
        FilledButton(onPressed: () { if (c.text.isNotEmpty) { socket.emit('rename_device', {'deviceId': id, 'newName': c.text}); Navigator.pop(ctx); } }, child: const Text('OK')),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Row(children: [const Text('Appareils'), const Spacer(), Icon(connected ? Icons.cloud_done : Icons.cloud_off, size: 20)])),
      body: !connected
          ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(), SizedBox(height: 16), Text('Connexion au serveur...\n(Réveil en cours ~30s)', textAlign: TextAlign.center)]))
          : devices.isEmpty
              ? const Center(child: Text('Aucun appareil.\nInstallez "oria" sur un téléphone.'))
              : RefreshIndicator(onRefresh: () async => socket.emit('get_devices'), child: ListView.builder(padding: const EdgeInsets.all(16), itemCount: devices.length, itemBuilder: (_, i) {
                  final d = devices[i];
                  final online = d['status'] == 'online';
                  return Card(margin: const EdgeInsets.only(bottom: 12), child: ListTile(
                    leading: CircleAvatar(backgroundColor: online ? Colors.green : Colors.grey, child: Icon(online ? Icons.check : Icons.close, color: Colors.white)),
                    title: Text(d['customName'] ?? d['deviceName'] ?? 'Inconnu'),
                    subtitle: Text(online ? 'En ligne' : 'Hors ligne'),
                    trailing: const Icon(Icons.chevron_right),
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
  void cmd(String a) {
    widget.socket.emit('command', {'targetId': widget.device['deviceId'], 'action': a});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Demande "$a" envoyée...')));
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.devices, size: 80, color: Colors.indigo), const SizedBox(height: 20), Text(widget.device['customName'] ?? widget.device['deviceName'], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)), const SizedBox(height: 8), Text(widget.device['status'] == 'online' ? '🟢 En ligne' : '⚪ Hors ligne')])),
      Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Container(width: double.infinity, height: 300, color: Colors.black87, child: const Center(child: Text('Flux vidéo\n(Appuyer ci-dessous)', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54)))), const SizedBox(height: 24), FilledButton.icon(onPressed: () => cmd('start_camera'), icon: const Icon(Icons.play_arrow), label: const Text('DEMANDER CAMÉRA'), style: FilledButton.styleFrom(minimumSize: const Size(250, 50)))])),
      Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.graphic_eq, size: 100, color: Colors.indigo), const SizedBox(height: 24), FilledButton.icon(onPressed: () => cmd('start_mic'), icon: const Icon(Icons.play_arrow), label: const Text('DEMANDER MICRO'), style: FilledButton.styleFrom(minimumSize: const Size(250, 50)))])),
      Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Container(width: double.infinity, height: 400, color: Colors.black87, child: const Center(child: Text('Flux écran\n(Appuyer ci-dessous)', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54)))), const SizedBox(height: 24), FilledButton.icon(onPressed: () => cmd('start_screen'), icon: const Icon(Icons.play_arrow), label: const Text('DEMANDER ÉCRAN'), style: FilledButton.styleFrom(minimumSize: const Size(250, 50)))])),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(widget.device['customName'] ?? widget.device['deviceName'])),
      body: pages[idx],
      bottomNavigationBar: NavigationBar(selectedIndex: idx, onDestinationSelected: (i) => setState(() => idx = i), destinations: const [
        NavigationDestination(icon: Icon(Icons.info), label: 'Infos'),
        NavigationDestination(icon: Icon(Icons.videocam), label: 'Caméra'),
        NavigationDestination(icon: Icon(Icons.mic), label: 'Micro'),
        NavigationDestination(icon: Icon(Icons.phone_android), label: 'Écran'),
      ]),
    );
  }
}