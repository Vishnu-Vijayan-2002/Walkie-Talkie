import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart';

/// ConnectX wire protocol for mesh messages — kept small for BLE bandwidth.
enum MeshMessageType {
  floorRequest,   // "I want to speak"
  floorGranted,   // "You may speak" (winner echoes to all)
  floorBusy,      // "Peer X is speaking" (broadcast)
  floorReleased,  // "Floor is free" (broadcast)
  floorDenied,    // "Request rejected — collision"
  raiseHand,      // "I want to speak but floor is taken"
  handCancelled,  // "Nevermind"
  peerHeartbeat,  // Liveness ping (every 5 s)
  audioChunk,     // Opus audio payload (future: step 9b)
}

class MeshMessage {
  final MeshMessageType type;
  final String senderDeviceId;
  final String senderCallsign;
  final String roomId;
  final int lamportClock;     // For floor arbitration ordering
  final String? floorToken;
  final String? targetDeviceId;
  final Uint8List? audioPayload; // null for signaling messages
  final Map<String, dynamic> extra;

  MeshMessage({
    required this.type,
    required this.senderDeviceId,
    required this.senderCallsign,
    required this.roomId,
    required this.lamportClock,
    this.floorToken,
    this.targetDeviceId,
    this.audioPayload,
    this.extra = const {},
  });

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'senderId': senderDeviceId,
        'callsign': senderCallsign,
        'room': roomId,
        'clock': lamportClock,
        if (floorToken != null) 'token': floorToken,
        if (targetDeviceId != null) 'target': targetDeviceId,
        if (extra.isNotEmpty) 'extra': extra,
      };

  Uint8List toBytes() => Uint8List.fromList(utf8.encode(jsonEncode(toJson())));

  factory MeshMessage.fromBytes(Uint8List bytes) {
    final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    return MeshMessage(
      type: MeshMessageType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => MeshMessageType.peerHeartbeat,
      ),
      senderDeviceId: json['senderId'] as String,
      senderCallsign: json['callsign'] as String,
      roomId: json['room'] as String,
      lamportClock: json['clock'] as int,
      floorToken: json['token'] as String?,
      targetDeviceId: json['target'] as String?,
      extra: (json['extra'] as Map<String, dynamic>?) ?? {},
    );
  }
}

/// A discovered nearby peer.
class MeshPeer {
  final String endpointId;
  final String deviceId;       // CX-XXXXX hardware callsign
  final String callsign;       // Display name
  final bool isConnected;
  final DateTime lastSeen;

  const MeshPeer({
    required this.endpointId,
    required this.deviceId,
    required this.callsign,
    required this.isConnected,
    required this.lastSeen,
  });

  MeshPeer copyWith({bool? isConnected, DateTime? lastSeen}) => MeshPeer(
        endpointId: endpointId,
        deviceId: deviceId,
        callsign: callsign,
        isConnected: isConnected ?? this.isConnected,
        lastSeen: lastSeen ?? this.lastSeen,
      );
}

/// NearbyMeshService — Google Nearby Connections API wrapper.
///
/// Automatically selects the best transport layer:
///   1. Wi-Fi Direct  (highest bandwidth, ~250 Mbps) — preferred for audio
///   2. Wi-Fi Aware   (medium bandwidth, ~50 Mbps)
///   3. BLE           (low bandwidth, ~1 Mbps) — fallback for discovery
///
/// Usage:
///   await service.startMesh(deviceId, callsign, roomId);
///   service.onMessageReceived = (peer, msg) { ... };
///   await service.broadcast(message);
///   await service.stopMesh();
class NearbyMeshService extends ChangeNotifier {
  static const String _serviceId = 'com.connectx.mesh';
  static const Strategy _strategy = Strategy.P2P_CLUSTER;

  String? _localDeviceId;
  String? _localCallsign;
  String? _currentRoomId;

  bool _isRunning = false;
  bool get isRunning => _isRunning;

  final Map<String, MeshPeer> _peers = {};  // endpointId → MeshPeer
  List<MeshPeer> get connectedPeers =>
      _peers.values.where((p) => p.isConnected).toList();
  int get peerCount => connectedPeers.length;

  // Callbacks — wired by NearbyFloorArbiter and PttController
  void Function(MeshPeer peer, MeshMessage message)? onMessageReceived;
  void Function(MeshPeer peer)? onPeerConnected;
  void Function(String endpointId)? onPeerDisconnected;

  Timer? _heartbeatTimer;
  Timer? _cleanupTimer;
  int _lamportClock = 0;

  int get nextClock {
    _lamportClock++;
    return _lamportClock;
  }

  int updateClock(int incoming) {
    _lamportClock = incoming > _lamportClock ? incoming + 1 : _lamportClock + 1;
    return _lamportClock;
  }

  Future<void> startMesh({
    required String deviceId,
    required String callsign,
    required String roomId,
  }) async {
    if (_isRunning) return;

    _localDeviceId = deviceId;
    _localCallsign = callsign;
    _currentRoomId = roomId;
    _lamportClock = 0;
    _peers.clear();

    try {
      // Start advertising so other peers can find us
      await Nearby().startAdvertising(
        _endpointName(deviceId, callsign),
        _strategy,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
        serviceId: _serviceId,
      );

      // Start discovering other advertising devices
      await Nearby().startDiscovery(
        _endpointName(deviceId, callsign),
        _strategy,
        onEndpointFound: _onEndpointFound,
        onEndpointLost: _onEndpointLost,
        serviceId: _serviceId,
      );

      _isRunning = true;
      _startHeartbeat();
      _startPeerCleanup();

      debugPrint('[Mesh] Started advertising + discovery in room $roomId');
      notifyListeners();
    } catch (e) {
      debugPrint('[Mesh] Error starting mesh: $e');
    }
  }

  Future<void> stopMesh() async {
    if (!_isRunning) return;
    _heartbeatTimer?.cancel();
    _cleanupTimer?.cancel();

    await Nearby().stopAdvertising();
    await Nearby().stopDiscovery();
    await Nearby().stopAllEndpoints();

    _peers.clear();
    _isRunning = false;
    debugPrint('[Mesh] Stopped');
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────
  // Message Sending
  // ─────────────────────────────────────────────────────────────────

  /// Broadcast a message to every connected peer.
  Future<void> broadcast(MeshMessage message) async {
    final bytes = message.toBytes();
    final connected = connectedPeers.map((p) => p.endpointId).toList();
    for (final endpointId in connected) {
      await _sendBytes(endpointId, bytes);
    }
  }

  /// Send a message to one specific peer.
  Future<void> sendTo(String endpointId, MeshMessage message) async {
    await _sendBytes(endpointId, message.toBytes());
  }

  Future<void> _sendBytes(String endpointId, Uint8List bytes) async {
    try {
      await Nearby().sendBytesPayload(endpointId, bytes);
    } catch (e) {
      debugPrint('[Mesh] Send error to $endpointId: $e');
      _markDisconnected(endpointId);
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // Nearby Connections Callbacks
  // ─────────────────────────────────────────────────────────────────

  void _onEndpointFound(String endpointId, String endpointName, String serviceId) {
    debugPrint('[Mesh] Endpoint found: $endpointId ($endpointName)');
    // Only connect peers that are in the same room
    final (deviceId, callsign, roomId) = _parseEndpointName(endpointName);
    if (roomId != _currentRoomId) {
      debugPrint('[Mesh] Ignoring peer from different room: $roomId');
      return;
    }
    _peers[endpointId] = MeshPeer(
      endpointId: endpointId,
      deviceId: deviceId,
      callsign: callsign,
      isConnected: false,
      lastSeen: DateTime.now(),
    );
    // Initiate connection
    Nearby().requestConnection(
      _endpointName(_localDeviceId!, _localCallsign!),
      endpointId,
      onConnectionInitiated: _onConnectionInitiated,
      onConnectionResult: _onConnectionResult,
      onDisconnected: _onDisconnected,
    ).catchError((Object e) {
      debugPrint('[Mesh] Connection request error: $e');
      return false;
    });
  }

  void _onEndpointLost(String? endpointId) {
    if (endpointId == null) return;
    debugPrint('[Mesh] Endpoint lost: $endpointId');
    _markDisconnected(endpointId);
  }

  void _onConnectionInitiated(String endpointId, ConnectionInfo info) {
    debugPrint('[Mesh] Connection initiated with $endpointId — auto-accepting');
    Nearby().acceptConnection(
      endpointId,
      onPayLoadRecieved: _onPayloadReceived,
      onPayloadTransferUpdate: (endpointId, update) {},
    ).catchError((Object e) {
      debugPrint('[Mesh] Accept connection error: $e');
      return false;
    });
  }

  void _onConnectionResult(String endpointId, Status status) {
    if (status == Status.CONNECTED) {
      debugPrint('[Mesh] Connected to peer $endpointId');
      final existing = _peers[endpointId];
      if (existing != null) {
        _peers[endpointId] = existing.copyWith(
          isConnected: true,
          lastSeen: DateTime.now(),
        );
        onPeerConnected?.call(_peers[endpointId]!);
      }
      notifyListeners();
    } else {
      debugPrint('[Mesh] Connection to $endpointId failed: $status');
      _peers.remove(endpointId);
      notifyListeners();
    }
  }

  void _onDisconnected(String endpointId) {
    debugPrint('[Mesh] Peer disconnected: $endpointId');
    _markDisconnected(endpointId);
  }

  void _onPayloadReceived(String endpointId, Payload payload) {
    if (payload.type != PayloadType.BYTES || payload.bytes == null) return;
    try {
      final message = MeshMessage.fromBytes(Uint8List.fromList(payload.bytes!));
      updateClock(message.lamportClock);

      // Update peer liveness
      if (_peers.containsKey(endpointId)) {
        _peers[endpointId] = _peers[endpointId]!.copyWith(lastSeen: DateTime.now());
      }

      final peer = _peers[endpointId];
      if (peer != null) {
        onMessageReceived?.call(peer, message);
      }
    } catch (e) {
      debugPrint('[Mesh] Error parsing payload from $endpointId: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // Liveness
  // ─────────────────────────────────────────────────────────────────

  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_isRunning || _localDeviceId == null || _currentRoomId == null) return;
      final hb = MeshMessage(
        type: MeshMessageType.peerHeartbeat,
        senderDeviceId: _localDeviceId!,
        senderCallsign: _localCallsign!,
        roomId: _currentRoomId!,
        lamportClock: nextClock,
      );
      broadcast(hb).ignore();
    });
  }

  void _startPeerCleanup() {
    _cleanupTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      final cutoff = DateTime.now().subtract(const Duration(seconds: 20));
      final stale = _peers.entries
          .where((e) => e.value.isConnected && e.value.lastSeen.isBefore(cutoff))
          .map((e) => e.key)
          .toList();
      for (final id in stale) {
        debugPrint('[Mesh] Removing stale peer $id');
        _markDisconnected(id);
      }
    });
  }

  void _markDisconnected(String endpointId) {
    if (_peers.containsKey(endpointId)) {
      _peers[endpointId] = _peers[endpointId]!.copyWith(isConnected: false);
      onPeerDisconnected?.call(endpointId);
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────

  /// Endpoint name encodes deviceId::callsign::roomId for room scoping.
  String _endpointName(String deviceId, String callsign) =>
      '$deviceId::$callsign::${_currentRoomId ?? ""}';

  (String deviceId, String callsign, String roomId) _parseEndpointName(String name) {
    final parts = name.split('::');
    if (parts.length >= 3) return (parts[0], parts[1], parts[2]);
    return (name, name, '');
  }

  @override
  void dispose() {
    stopMesh();
    super.dispose();
  }
}
