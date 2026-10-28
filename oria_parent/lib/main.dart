import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:google_fonts/google_fonts.dart';

// ⚠️ REMPLACE PAR TON URL RENDER RÉELLE
const String SERVER_URL = 'https://ton-url-render.onrender.com';

void main() => runApp(const OriaParentApp());

class OriaParentApp extends StatelessWidget {
  const OriaParentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
        textTheme: GoogleFonts.poppinsTextTheme(),
        brightness: Brightness.dark,
      ),
      home: const ParentHome(),
    );
  }
}

class ParentHome extends StatefulWidget {
  const ParentHome({super.key});
  @override State<ParentHome> createState() => _ParentHomeState();
}

class _ParentHomeState extends State<ParentHome> {
  late IO.Socket socket;
  List<Map<String, dynamic>> devices = [];
  int currentIndex = 0;
  Map<String, dynamic>? selectedDevice;

  @override
  void initState() {
    super.initState();
    socket = IO.io(SERVER_URL, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
    });

    socket.on('connect', (_) {
      debugPrint('✅ Connecté au serveur ORIA');
      socket.emit('get_devices');
    });

    socket.on('device_list', (data) {
      setState(() => devices = List<Map<String, dynamic>>.from(data));
    });

    socket.on('device_list_updated', (_) => socket.emit('get_devices'));
  }

  void sendCommand(String action) {
    if (selectedDevice == null) return;
    socket.emit('command', {
      'targetId': selectedDevice!['deviceId'],
      'action': action,
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Commande "$action" envoyée'), duration: const Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DevicesPage(devices: devices, onSelect: (d) => setState(() => selectedDevice = d)),
      CameraControlPage(onCapture: () => sendCommand('capture_photo')),
      MicControlPage(onListen: () => sendCommand('start_mic')),
      ScreenControlPage(onCapture: () => sendCommand('capture_screen')),
    ];

    return Scaffold(
      body: pages[currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (i) => setState(() => currentIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.devices), label: 'Appareils'),
          NavigationDestination(icon: Icon(Icons.videocam), label: 'Caméra'),
          NavigationDestination(icon: Icon(Icons.mic), label: 'Micro'),
          NavigationDestination(icon: Icon(Icons.phone_android), label: 'Écran'),
        ],
      ),
    );
  }

  @override
  void dispose() {
    socket.disconnect();
    super.dispose();
  }
}

// --- ÉCRAN APPAREILS ---
class DevicesPage extends StatelessWidget {
  final List<Map<String, dynamic>> devices;
  final Function(Map<String, dynamic>) onSelect;

  const DevicesPage({super.key, required this.devices, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes Enfants')),
      body: devices.isEmpty
          ? const Center(child: Text('Aucun appareil connecté.\nInstallez "oria" sur le téléphone de l\'enfant.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: devices.length,
              itemBuilder: (_, i) {
                final d = devices[i];
                final isOnline = d['status'] == 'online';
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isOnline ? Colors.green : Colors.grey,
                      child: Icon(isOnline ? Icons.check : Icons.close, color: Colors.white),
                    ),
                    title: Text(d['deviceName'] ?? 'Inconnu'),
                    subtitle: Text(isOnline ? 'En ligne' : 'Hors ligne'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => onSelect(d),
                  ),
                );
              },
            ),
    );
  }
}

// --- ÉCRAN CAMÉRA ---
class CameraControlPage extends StatelessWidget {
  final VoidCallback onCapture;
  const CameraControlPage({super.key, required this.onCapture});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Caméra Directe')),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: Colors.black87,
              child: const Center(child: Text('Flux vidéo en direct\n(WebRTC)', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54))),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              onPressed: onCapture,
              icon: const Icon(Icons.camera_alt),
              label: const Text('Prendre Photo'),
              style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
            ),
          ),
        ],
      ),
    );
  }
}

// --- ÉCRAN MICRO ---
class MicControlPage extends StatelessWidget {
  final VoidCallback onListen;
  const MicControlPage({super.key, required this.onListen});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Écoute Directe')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.graphic_eq, size: 100, color: Colors.indigo),
            const SizedBox(height: 20),
            const Text('Appuyez pour écouter en direct', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 30),
            FilledButton.icon(
              onPressed: onListen,
              icon: const Icon(Icons.mic),
              label: const Text('Commencer l\'écoute'),
              style: FilledButton.styleFrom(minimumSize: const Size(200, 50)),
            ),
          ],
        ),
      ),
    );
  }
}

// --- ÉCRAN ÉCRAN ---
class ScreenControlPage extends StatelessWidget {
  final VoidCallback onCapture;
  const ScreenControlPage({super.key, required this.onCapture});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Écran en Direct')),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: Colors.black87,
              child: const Center(child: Text('Flux écran en direct\n(WebRTC)', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54))),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              onPressed: onCapture,
              icon: const Icon(Icons.screenshot),
              label: const Text('Capture d\'Écran'),
              style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
            ),
          ),
        ],
      ),
    );
  }
}
