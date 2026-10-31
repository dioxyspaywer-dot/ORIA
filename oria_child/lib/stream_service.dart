import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class StreamService {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  final IO.Socket socket;
  final String targetId;

  StreamService(this.socket, this.targetId);

  Future<void> startCamera() async {
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': {'facingMode': 'user', 'width': 640, 'height': 480}
    });
    await _createPeerConnection();
    _sendOffer();
  }

  Future<void> startMic() async {
    _localStream = await navigator.mediaDevices.getUserMedia({'audio': true, 'video': false});
    await _createPeerConnection();
    _sendOffer();
  }

  Future<void> startScreen() async {
    // Capture d'écran via MediaProjection (nécessite permission utilisateur une fois)
    _localStream = await navigator.mediaDevices.getDisplayMedia({'video': true, 'audio': false});
    await _createPeerConnection();
    _sendOffer();
  }

  Future<void> _createPeerConnection() async {
    _peerConnection = await createPeerConnection({
      'iceServers': [{'urls': 'stun:stun.l.google.com:19302'}]
    });

    _localStream!.getTracks().forEach((track) {
      _peerConnection!.addTrack(track, _localStream!);
    });

    _peerConnection!.onIceCandidate = (candidate) {
      socket.emit('signal', {
        'target': targetId,
        'payload': {'type': 'candidate', 'data': candidate.toMap()}
      });
    };
  }

  Future<void> _sendOffer() async {
    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);
    socket.emit('signal', {
      'target': targetId,
      'payload': {'type': 'offer', 'data': offer.toMap()}
    });
  }

  void handleSignal(Map<String, dynamic> data) async {
    if (_peerConnection == null) return;
    if (data['type'] == 'answer') {
      await _peerConnection!.setRemoteDescription(RTCSessionDescription(data['data']['sdp'], data['data']['type']));
    } else if (data['type'] == 'candidate') {
      await _peerConnection!.addCandidate(RTCIceCandidate(data['data']['candidate'], data['data']['sdpMid'], data['data']['sdpMLineIndex']));
    }
  }

  Future<void> stop() async {
    _localStream?.getTracks().forEach((t) => t.stop());
    _localStream?.dispose();
    _peerConnection?.close();
    _localStream = null;
    _peerConnection = null;
  }
}