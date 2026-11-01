import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:wakelock_plus/wakelock_plus.dart';

class StreamService {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  final IO.Socket socket;
  final String targetId; // Ex: 'parent-main'

  StreamService(this.socket, this.targetId);

  Future<void> startCamera() async {
    await WakelockPlus.enable();
    print('📷 [STREAM] START_CAMERA');
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': {'facingMode': 'user', 'width': 640, 'height': 480, 'frameRate': 30}
    });
    print('📷 [STREAM] TRACKS_CREATED: ${_localStream!.getTracks().length}');
    await _createPeerConnection();
    await _sendOffer();
  }

  Future<void> startMic() async {
    await WakelockPlus.enable();
    print('🎤 [STREAM] START_MIC');
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': {'echoCancellation': true, 'noiseSuppression': true},
      'video': false
    });
    print('🎤 [STREAM] TRACKS_CREATED: ${_localStream!.getTracks().length}');
    await _createPeerConnection();
    await _sendOffer();
  }

  Future<void> startScreen() async {
    await WakelockPlus.enable();
    print('📱 [STREAM] START_SCREEN');
    try {
      _localStream = await navigator.mediaDevices.getDisplayMedia({
        'video': {'width': 1280, 'height': 720, 'frameRate': 30},
        'audio': true
      });
      print('📱 [STREAM] SCREEN_TRACKS: ${_localStream!.getTracks().length}');
      await _createPeerConnection();
      await _sendOffer();
    } catch (e) {
      print('❌ [STREAM] SCREEN_ERROR: $e');
      try {
        _localStream = await navigator.mediaDevices.getDisplayMedia({'video': true});
        await _createPeerConnection();
        await _sendOffer();
      } catch (e2) {
        print('❌ [STREAM] SCREEN_FALLBACK_ERROR: $e2');
        await WakelockPlus.disable();
      }
    }
  }

  Future<void> _createPeerConnection() async {
    print('🔗 [WEBRTC] CREATE_PEER_CONNECTION');
    _peerConnection = await createPeerConnection({
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'}
      ]
    });

    _localStream!.getTracks().forEach((track) {
      print('➕ [WEBRTC] ADD_TRACK: ${track.kind}');
      _peerConnection!.addTrack(track, _localStream!);
    });

    _peerConnection!.onIceCandidate = (candidate) {
      if (candidate.candidate != null) {
        // ✅ Format uniforme: { target, type, data }
        socket.emit('signal', {
          'target': targetId,
          'type': 'candidate',
          'data': candidate.toMap()
        });
      }
    };

    _peerConnection!.onConnectionState = (state) {
      print('🔗 [WEBRTC] CONNECTION_STATE: $state');
    };

    _peerConnection!.onIceConnectionState = (state) {
      print('🧊 [WEBRTC] ICE_STATE: $state');
    };
  }

  Future<void> _sendOffer() async {
    final offer = await _peerConnection!.createOffer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': true
    });
    await _peerConnection!.setLocalDescription(offer);
    print('📤 [WEBRTC] OFFER_SENT → $targetId');
    // ✅ Format uniforme: { target, type, data }
    socket.emit('signal', {
      'target': targetId,
      'type': 'offer',
      'data': offer.toMap()
    });
  }

  // ✅ Format uniforme reçu: { target, type, data }
  void handleSignal(Map<String, dynamic> msg) async {
    if (_peerConnection == null) return;
    final type = msg['type'];
    final data = msg['data'];
    try {
      if (type == 'answer') {
        print('📥 [WEBRTC] ANSWER_RECEIVED');
        await _peerConnection!.setRemoteDescription(RTCSessionDescription(data['sdp'], data['type']));
      } else if (type == 'candidate') {
        print('📥 [WEBRTC] CANDIDATE_RECEIVED');
        await _peerConnection!.addCandidate(RTCIceCandidate(data['candidate'], data['sdpMid'], data['sdpMLineIndex']));
      }
    } catch (e) {
      print('❌ [WEBRTC] SIGNAL_ERROR: $e');
    }
  }

  Future<void> stop() async {
    print('🛑 [STREAM] STOP + WAKELOCK_DISABLE');
    await WakelockPlus.disable();
    _localStream?.getTracks().forEach((t) => t.stop());
    await _localStream?.dispose();
    await _peerConnection?.close();
    _localStream = null;
    _peerConnection = null;
  }
}