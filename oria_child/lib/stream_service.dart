import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

const _captureChannel = MethodChannel('oria.capture/service');

class StreamService {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  final IO.Socket socket;
  final String targetId;

  StreamService(this.socket, this.targetId);

  Future<void> startCamera() async {
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': {'facingMode': 'user', 'width': 640, 'height': 480, 'frameRate': 30}
    });
    await _createPeerConnection();
    await _sendOffer();
  }

  Future<void> startMic() async {
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': {'echoCancellation': true, 'noiseSuppression': true},
      'video': false
    });
    await _createPeerConnection();
    await _sendOffer();
  }

  Future<void> startScreen() async {
    try {
      await _captureChannel.invokeMethod('start_screen');
      await Future.delayed(const Duration(milliseconds: 500));
      _localStream = await navigator.mediaDevices.getDisplayMedia({
        'video': {'width': 1280, 'height': 720, 'frameRate': 30},
        'audio': true
      });
      await _createPeerConnection();
      await _sendOffer();
    } catch (e) {
      try {
        _localStream = await navigator.mediaDevices.getDisplayMedia({'video': true});
        await _createPeerConnection();
        await _sendOffer();
      } catch (e2) {
        print('SCREEN ERROR: $e2');
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

    _localStream!.getTracks().forEach((track) {
      _peerConnection!.addTrack(track, _localStream!);
    });

    _peerConnection!.onIceCandidate = (candidate) {
      if (candidate.candidate != null) {
        socket.emit('signal', {
          'target': targetId,
          'type': 'candidate',
          'data': candidate.toMap()
        });
      }
    };
  }

  Future<void> _sendOffer() async {
    final offer = await _peerConnection!.createOffer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': true
    });
    await _peerConnection!.setLocalDescription(offer);
    socket.emit('signal', {
      'target': targetId,
      'type': 'offer',
      'data': offer.toMap()
    });
  }

  void handleSignal(Map<String, dynamic> msg) async {
    if (_peerConnection == null) return;
    try {
      if (msg['type'] == 'answer') {
        await _peerConnection!.setRemoteDescription(
          RTCSessionDescription(msg['data']['sdp'], msg['data']['type'])
        );
      } else if (msg['type'] == 'candidate') {
        await _peerConnection!.addCandidate(
          RTCIceCandidate(msg['data']['candidate'], msg['data']['sdpMid'], msg['data']['sdpMLineIndex'])
        );
      }
    } catch (e) {
      print('SIGNAL ERROR: $e');
    }
  }

  Future<void> stop() async {
    _localStream?.getTracks().forEach((t) => t.stop());
    await _localStream?.dispose();
    await _peerConnection?.close();
    _localStream = null;
    _peerConnection = null;
  }
}