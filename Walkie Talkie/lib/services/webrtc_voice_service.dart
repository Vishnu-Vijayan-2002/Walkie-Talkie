import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'signalr_service.dart';

/// WebRtcVoiceService — High-performance, low-latency Push-To-Talk voice engine.
///
/// Features:
/// - Single-speaker half-duplex Opus audio streaming
/// - WebRTC peer-to-peer audio mesh with STUN fallback
/// - SignalR SDP / ICE candidate relay
/// - Hardware echo cancellation, noise suppression, and auto gain control
/// - Instant mic track mute/unmute floor synchronization
class WebRtcVoiceService extends ChangeNotifier {
  final ConnectXSignalRService _signalR;
  final Map<String, RTCPeerConnection> _peerConnections = {};

  MediaStream? _localStream;
  MediaStreamTrack? _localAudioTrack;

  String? _currentRoomId;
  String? _localDeviceId;

  bool _isTransmitting = false;
  bool get isTransmitting => _isTransmitting;

  bool _isMicInitialized = false;
  bool get isMicInitialized => _isMicInitialized;

  // Remote audio streams for playback
  final Map<String, MediaStream> _remoteStreams = {};

  // Standard STUN servers for NAT traversal
  final Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},
    ],
    'sdpSemantics': 'unified-plan',
  };

  WebRtcVoiceService({required ConnectXSignalRService signalR}) : _signalR = signalR {
    _registerSignalRListeners();
  }

  /// Initialize local audio capture with tactical walkie-talkie audio constraints
  Future<void> initializeAudio({required String localDeviceId}) async {
    _localDeviceId = localDeviceId;

    try {
      final Map<String, dynamic> mediaConstraints = {
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
          'highpassFilter': true,
          'channelCount': 1,
          'sampleRate': 48000,
        },
        'video': false,
      };

      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      if (_localStream!.getAudioTracks().isNotEmpty) {
        _localAudioTrack = _localStream!.getAudioTracks().first;
        // Default to muted (mic OFF) until floor is explicitly granted
        _localAudioTrack!.enabled = false;
        _isMicInitialized = true;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[WebRTC] Error initializing local audio: $e');
    }
  }

  /// Called when joining a room to set up signaling context
  void setCurrentRoom(String roomId) {
    _currentRoomId = roomId;
    _cleanupPeerConnections();
  }

  // ─────────────────────────────────────────────────────────────────
  // Floor Control Integration (Unmute / Mute Mic Track)
  // ─────────────────────────────────────────────────────────────────

  /// PTT floor granted — unmute mic and transmit audio
  void startTransmitting() {
    if (_localAudioTrack != null) {
      _localAudioTrack!.enabled = true;
      _isTransmitting = true;
      debugPrint('[WebRTC] Microphone UNMUTED — Transmitting voice to room $_currentRoomId');
      notifyListeners();
    }
  }

  /// PTT floor released — mute mic and stop transmission
  void stopTransmitting() {
    if (_localAudioTrack != null) {
      _localAudioTrack!.enabled = false;
      _isTransmitting = false;
      debugPrint('[WebRTC] Microphone MUTED — Ceased transmission');
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // WebRTC Peer Connection Lifecycle & Signaling
  // ─────────────────────────────────────────────────────────────────

  Future<RTCPeerConnection> _getOrCreatePeerConnection(String remoteDeviceId) async {
    if (_peerConnections.containsKey(remoteDeviceId)) {
      return _peerConnections[remoteDeviceId]!;
    }

    final pc = await createPeerConnection(_iceServers);

    // Add local mic track if available
    if (_localStream != null && _localAudioTrack != null) {
      await pc.addTrack(_localAudioTrack!, _localStream!);
    }

    pc.onIceCandidate = (RTCIceCandidate candidate) {
      if (_currentRoomId != null && _localDeviceId != null) {
        _signalR.sendIceCandidate(
          _currentRoomId!,
          _localDeviceId!,
          remoteDeviceId,
          candidate.candidate ?? '',
          candidate.sdpMid ?? '',
          candidate.sdpMLineIndex ?? 0,
        );
      }
    };

    pc.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        final stream = event.streams[0];
        _remoteStreams[remoteDeviceId] = stream;
        debugPrint('[WebRTC] Received remote audio stream from peer: $remoteDeviceId');
        notifyListeners();
      }
    };

    pc.onConnectionState = (RTCPeerConnectionState state) {
      debugPrint('[WebRTC] Peer $remoteDeviceId connection state: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateClosed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        _peerConnections.remove(remoteDeviceId);
        _remoteStreams.remove(remoteDeviceId);
      }
    };

    _peerConnections[remoteDeviceId] = pc;
    return pc;
  }

  /// Initiate a WebRTC offer to a newly joined room peer
  Future<void> connectToPeer(String remoteDeviceId) async {
    if (_currentRoomId == null || _localDeviceId == null || remoteDeviceId == _localDeviceId) {
      return;
    }

    try {
      final pc = await _getOrCreatePeerConnection(remoteDeviceId);
      final offer = await pc.createOffer({'offerToReceiveAudio': 1, 'offerToReceiveVideo': 0});
      await pc.setLocalDescription(offer);

      await _signalR.sendWebRtcOffer(
        _currentRoomId!,
        _localDeviceId!,
        remoteDeviceId,
        offer.sdp ?? '',
      );
      debugPrint('[WebRTC] Dispatched SDP Offer to peer $remoteDeviceId');
    } catch (e) {
      debugPrint('[WebRTC] Error connecting to peer $remoteDeviceId: $e');
    }
  }

  void _registerSignalRListeners() {
    _signalR.onWebRtcOffer = (roomId, senderDeviceId, sdp) async {
      if (senderDeviceId == _localDeviceId || roomId != _currentRoomId) return;

      try {
        final pc = await _getOrCreatePeerConnection(senderDeviceId);
        await pc.setRemoteDescription(RTCSessionDescription(sdp, 'offer'));

        final answer = await pc.createAnswer({'offerToReceiveAudio': 1, 'offerToReceiveVideo': 0});
        await pc.setLocalDescription(answer);

        await _signalR.sendWebRtcAnswer(
          roomId,
          _localDeviceId!,
          senderDeviceId,
          answer.sdp ?? '',
        );
        debugPrint('[WebRTC] Replied with SDP Answer to peer $senderDeviceId');
      } catch (e) {
        debugPrint('[WebRTC] Error handling SDP Offer from $senderDeviceId: $e');
      }
    };

    _signalR.onWebRtcAnswer = (roomId, senderDeviceId, sdp) async {
      if (senderDeviceId == _localDeviceId || roomId != _currentRoomId) return;

      try {
        final pc = _peerConnections[senderDeviceId];
        if (pc != null) {
          await pc.setRemoteDescription(RTCSessionDescription(sdp, 'answer'));
          debugPrint('[WebRTC] Applied SDP Answer from peer $senderDeviceId');
        }
      } catch (e) {
        debugPrint('[WebRTC] Error handling SDP Answer from $senderDeviceId: $e');
      }
    };

    _signalR.onIceCandidate = (roomId, senderDeviceId, candidateStr, sdpMid, sdpMLineIndex) async {
      if (senderDeviceId == _localDeviceId || roomId != _currentRoomId) return;

      try {
        final pc = _peerConnections[senderDeviceId];
        if (pc != null) {
          final candidate = RTCIceCandidate(candidateStr, sdpMid, sdpMLineIndex);
          await pc.addCandidate(candidate);
        }
      } catch (e) {
        debugPrint('[WebRTC] Error applying ICE candidate from $senderDeviceId: $e');
      }
    };

    _signalR.onMemberJoined = (roomId, deviceId, data) {
      if (roomId == _currentRoomId && deviceId != _localDeviceId) {
        // As a host/existing member, establish WebRTC link with the newcomer
        connectToPeer(deviceId);
      }
    };

    _signalR.onMemberLeft = (roomId, deviceId, data) {
      final pc = _peerConnections.remove(deviceId);
      pc?.close();
      _remoteStreams.remove(deviceId);
      notifyListeners();
    };
  }

  void _cleanupPeerConnections() {
    for (final pc in _peerConnections.values) {
      pc.close();
    }
    _peerConnections.clear();
    _remoteStreams.clear();
  }

  @override
  void dispose() {
    _cleanupPeerConnections();
    _localAudioTrack?.stop();
    _localStream?.dispose();
    super.dispose();
  }
}
