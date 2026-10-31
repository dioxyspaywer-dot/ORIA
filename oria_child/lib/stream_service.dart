import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class StreamService {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  final IO.Socket socket;
  final String targetId;

  StreamService(this.socket, this.targetId);

  Future<void> startCamera() async {
    print('📷 Démarrage caméra...');
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': {'facingMode': 'user', 'width': 640, 'height': 480, 'frameRate': 30}
    });
    print('📷 Stream créé: ${_localStream!.getTracks().length} tracks');
    await _createPeerConnection();
    await _sendOffer();
  }

  Future<void> startMic() async {
    print('🎤 Démarrage micro...');
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': {'echoCancellation': true, 'noiseSuppression': true},
      'video': false
    });
    print('🎤 Stream créé: ${_localStream!.getTracks().length} tracks');
    await _createPeerConnection();
    await _sendOffer();
  }

  Future<void> startScreen() async {
    print('📱 Démarrage capture écran...');
    try {
      // getDisplayMedia demande automatiquement la permission MediaProjection
      _localStream = await navigator.mediaDevices.getDisplayMedia({
        'video': {'width': 1280, 'height': 720, 'frameRate': 30},
        'audio': true
      });
      print('📱 Stream écran créé: ${_localStream!.getTracks().length} tracks');
      await _createPeerConnection();
      await _sendOffer();
    } catch (e) {
      print('❌ Erreur capture écran: $e');
      // Fallback: essayer sans audio si ça échoue
      try {
        _localStream = await navigator.mediaDevices.getDisplayMedia({'video': true});
        await _createPeerConnection();
        await _sendOffer();
      } catch (e2) {
        print('❌ Erreur fallback écran: $e2');
      }
    }
  }

  Future<void> _createPeerConnection() async {
    _peerConnection = await createPeerConnection({
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'}
      ]
    });

    // ✅ Ajouter TOUS les tracks (audio + vidéo)
    _localStream!.getTracks().forEach((track) {
      print('➕ Ajout track: ${track.kind}');
      _peerConnection!.addTrack(track, _localStream!);
    });

    _peerConnection!.onIceCandidate = (candidate) {
      if (candidate.candidate != null) {
        socket.emit('signal', {
          'target': targetId,
          'payload': {'type': 'candidate', 'data': candidate.toMap()}
        });
      }
    };

    _peerConnection!.onConnectionState = (state) {
      print('🔗 État connexion: $state');
    };
  }

  Future<void> _sendOffer() async {
    final offer = await _peerConnection!.createOffer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': true
    });
    await _peerConnection!.setLocalDescription(offer);
    print('📤 Offre envoyée');
    socket.emit('signal', {
      'target': targetId,
      'payload': {'type': 'offer', 'data': offer.toMap()}
    });
  }

  void handleSignal(Map<String, dynamic> data) async {
    if (_peerConnection == null) return;
    try {
      if (data['type'] == 'answer') {
        print('📥 Réponse reçue');
        await _peerConnection!.setRemoteDescription(
          RTCSessionDescription(data['data']['sdp'], data['data']['type'])
        );
      } else if (data['type'] == 'candidate') {
        await _peerConnection!.addCandidate(
          RTCIceCandidate(data['data']['candidate'], data['data']['sdpMid'], data['data']['sdpMLineIndex'])
        );
      }
    } catch (e) {
      print('❌ Erreur signal: $e');
    }
  }

  Future<void> stop() async {
    print('🛑 Arrêt stream...');
    _localStream?.getTracks().forEach((t) => t.stop());
    await _localStream?.dispose();
    await _peerConnection?.close();
    _localStream = null;
    _peerConnection = null;
  }
}