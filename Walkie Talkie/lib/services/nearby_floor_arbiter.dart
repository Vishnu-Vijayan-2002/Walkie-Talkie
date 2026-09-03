import 'dart:async';
import 'package:flutter/foundation.dart';
import 'nearby_mesh_service.dart';

/// Floor state for the distributed offline mesh.
enum MeshFloorState {
  idle,
  requesting,   // We sent a request, waiting for responses
  speaking,     // We hold the floor
  peerSpeaking, // A remote peer holds the floor
  denied,       // Our request was overridden by a lower-clock request
}

/// Who currently holds the speaking floor in the mesh.
class MeshFloorHolder {
  final String deviceId;
  final String callsign;
  final String floorToken;
  final int lamportClock;  // Lower = higher priority
  final DateTime acquiredAt;

  const MeshFloorHolder({
    required this.deviceId,
    required this.callsign,
    required this.floorToken,
    required this.lamportClock,
    required this.acquiredAt,
  });
}

/// NearbyFloorArbiter — distributed floor control for offline mesh.
///
/// Algorithm (based on Lamport mutual exclusion):
///   1. Requester broadcasts FloorRequest(clock=T, deviceId=X)
///   2. All peers compare T with current floor state:
///      - If idle → respond FloorGranted
///      - If speaking (T_holder < T) → respond FloorBusy
///      - If tie on clock → break with deviceId lexicographic order
///   3. Requester collects responses:
///      - All granted → win floor, broadcast FloorBusy
///      - Any busy → deny self, broadcast FloorDenied
///   4. On release → broadcast FloorReleased
///
/// Peer count > 0 required. If no peers, self-grant immediately (solo mode).
class NearbyFloorArbiter extends ChangeNotifier {
  final NearbyMeshService _mesh;

  MeshFloorState _floorState = MeshFloorState.idle;
  MeshFloorState get floorState => _floorState;

  MeshFloorHolder? _currentHolder;
  MeshFloorHolder? get currentHolder => _currentHolder;

  String? _localDeviceId;
  String? _localCallsign;
  String? _currentRoomId;

  // Pending request tracking
  String? _pendingToken;
  int _pendingClock = 0;
  Timer? _requestTimeoutTimer;
  int _grantedCount = 0;
  int _deniedCount = 0;

  // Safety cutoff: 60s max transmission (mirrors online server TTL)
  static const int _maxTransmissionSeconds = 60;
  Timer? _safetyTimer;
  int _transmissionSeconds = 0;
  int get transmissionSeconds => _transmissionSeconds;

  // Callbacks for PttController to react to
  void Function()? onFloorGranted;
  void Function()? onFloorReleased;
  void Function(String peerCallsign)? onFloorBusy;
  void Function(String reason)? onFloorDenied;
  void Function(String peerCallsign, int queuePosition)? onHandRaised;

  NearbyFloorArbiter({required NearbyMeshService mesh}) : _mesh = mesh {
    _mesh.onMessageReceived = _handleMeshMessage;
  }

  void initialize({
    required String deviceId,
    required String callsign,
    required String roomId,
  }) {
    _localDeviceId = deviceId;
    _localCallsign = callsign;
    _currentRoomId = roomId;
    _floorState = MeshFloorState.idle;
    _currentHolder = null;
    _transmissionSeconds = 0;
  }

  // ─────────────────────────────────────────────────────────────────
  // Local User Actions
  // ─────────────────────────────────────────────────────────────────

  Future<void> requestFloor() async {
    if (_localDeviceId == null || _currentRoomId == null) return;
    if (_floorState != MeshFloorState.idle) return;

    // Solo mode: no peers → self-grant immediately
    if (_mesh.peerCount == 0) {
      _selfGrant();
      return;
    }

    _pendingToken = 'mesh_${_localDeviceId}_${DateTime.now().millisecondsSinceEpoch}';
    _pendingClock = _mesh.nextClock;
    _grantedCount = 0;
    _deniedCount = 0;
    _setFloorState(MeshFloorState.requesting);

    await _mesh.broadcast(MeshMessage(
      type: MeshMessageType.floorRequest,
      senderDeviceId: _localDeviceId!,
      senderCallsign: _localCallsign!,
      roomId: _currentRoomId!,
      lamportClock: _pendingClock,
      floorToken: _pendingToken,
    ));

    // Wait up to 800ms for all peer responses before deciding
    _requestTimeoutTimer?.cancel();
    _requestTimeoutTimer = Timer(const Duration(milliseconds: 800), _resolveRequest);

    debugPrint('[FloorArbiter] Sent floor request T=$_pendingClock');
  }

  Future<void> releaseFloor() async {
    if (_floorState != MeshFloorState.speaking) return;
    final token = _currentHolder?.floorToken ?? '';
    _safetyTimer?.cancel();
    _transmissionSeconds = 0;
    _currentHolder = null;
    _setFloorState(MeshFloorState.idle);

    await _mesh.broadcast(MeshMessage(
      type: MeshMessageType.floorReleased,
      senderDeviceId: _localDeviceId!,
      senderCallsign: _localCallsign!,
      roomId: _currentRoomId!,
      lamportClock: _mesh.nextClock,
      floorToken: token,
    ));
    onFloorReleased?.call();
    debugPrint('[FloorArbiter] Floor released');
  }

  Future<void> raiseHand() async {
    if (_localDeviceId == null || _currentRoomId == null) return;
    await _mesh.broadcast(MeshMessage(
      type: MeshMessageType.raiseHand,
      senderDeviceId: _localDeviceId!,
      senderCallsign: _localCallsign!,
      roomId: _currentRoomId!,
      lamportClock: _mesh.nextClock,
    ));
  }

  Future<void> cancelHand() async {
    if (_localDeviceId == null || _currentRoomId == null) return;
    await _mesh.broadcast(MeshMessage(
      type: MeshMessageType.handCancelled,
      senderDeviceId: _localDeviceId!,
      senderCallsign: _localCallsign!,
      roomId: _currentRoomId!,
      lamportClock: _mesh.nextClock,
    ));
  }

  // ─────────────────────────────────────────────────────────────────
  // Inbound Mesh Message Handler
  // ─────────────────────────────────────────────────────────────────

  void _handleMeshMessage(MeshPeer peer, MeshMessage message) {
    if (message.roomId != _currentRoomId) return;
    if (message.senderDeviceId == _localDeviceId) return;

    switch (message.type) {
      case MeshMessageType.floorRequest:
        _handleInboundRequest(message);
        break;

      case MeshMessageType.floorGranted:
        // Tally a grant vote for our pending request
        if (_floorState == MeshFloorState.requesting &&
            message.targetDeviceId == _localDeviceId) {
          _grantedCount++;
          _tryResolveEarly();
        }
        break;

      case MeshMessageType.floorBusy:
        if (_floorState == MeshFloorState.requesting) {
          // A peer is already speaking — abort our request
          _deniedCount++;
          _tryResolveEarly();
        } else {
          // Update floor holder info
          _currentHolder = MeshFloorHolder(
            deviceId: message.senderDeviceId,
            callsign: message.senderCallsign,
            floorToken: message.floorToken ?? '',
            lamportClock: message.lamportClock,
            acquiredAt: DateTime.now(),
          );
          _setFloorState(MeshFloorState.peerSpeaking);
          onFloorBusy?.call(message.senderCallsign);
        }
        break;

      case MeshMessageType.floorDenied:
        if (message.targetDeviceId == _localDeviceId) {
          _requestTimeoutTimer?.cancel();
          _setFloorState(MeshFloorState.idle);
          onFloorDenied?.call('Floor busy — another peer has priority');
        }
        break;

      case MeshMessageType.floorReleased:
        if (_currentHolder?.deviceId == message.senderDeviceId) {
          _currentHolder = null;
          _setFloorState(MeshFloorState.idle);
          onFloorReleased?.call();
        }
        break;

      case MeshMessageType.raiseHand:
        final currentHandCount = 0; // Simplified — just notify
        onHandRaised?.call(message.senderCallsign, currentHandCount + 1);
        break;

      case MeshMessageType.peerHeartbeat:
        // Already handled by NearbyMeshService liveness tracking
        break;

      default:
        break;
    }
  }

  /// When we receive a floor request from a remote peer, decide if we grant or deny.
  Future<void> _handleInboundRequest(MeshMessage request) async {
    final targetId = request.senderDeviceId;
    final targetEndpoint = _mesh.connectedPeers
        .where((p) => p.deviceId == targetId)
        .map((p) => p.endpointId)
        .firstOrNull;

    if (targetEndpoint == null) return;

    // Determine if we should grant:
    // - Floor is idle → grant
    // - We are speaking → deny
    // - We are also requesting → compare (clock, deviceId) — lower wins
    bool shouldGrant;

    if (_floorState == MeshFloorState.idle) {
      shouldGrant = true;
    } else if (_floorState == MeshFloorState.speaking ||
        _floorState == MeshFloorState.peerSpeaking) {
      shouldGrant = false;
    } else if (_floorState == MeshFloorState.requesting) {
      // Tie-break: lower Lamport clock wins; on tie use lexicographic deviceId
      final weWin = (_pendingClock < request.lamportClock) ||
          (_pendingClock == request.lamportClock &&
              _localDeviceId!.compareTo(request.senderDeviceId) < 0);
      shouldGrant = !weWin; // If we win, deny the peer
    } else {
      shouldGrant = true;
    }

    final response = MeshMessage(
      type: shouldGrant ? MeshMessageType.floorGranted : MeshMessageType.floorBusy,
      senderDeviceId: _localDeviceId!,
      senderCallsign: _localCallsign!,
      roomId: _currentRoomId!,
      lamportClock: _mesh.nextClock,
      targetDeviceId: targetId,
      floorToken: request.floorToken,
    );

    await _mesh.sendTo(targetEndpoint, response);
    debugPrint('[FloorArbiter] Responded to $targetId: ${shouldGrant ? "GRANTED" : "BUSY"}');
  }

  // ─────────────────────────────────────────────────────────────────
  // Request Resolution
  // ─────────────────────────────────────────────────────────────────

  void _tryResolveEarly() {
    final totalPeers = _mesh.peerCount;
    // If all peers responded
    if (_grantedCount + _deniedCount >= totalPeers) {
      _requestTimeoutTimer?.cancel();
      _resolveRequest();
    }
  }

  void _resolveRequest() {
    if (_floorState != MeshFloorState.requesting) return;

    if (_deniedCount > 0) {
      // Floor is busy — we lost
      _setFloorState(MeshFloorState.idle);
      onFloorDenied?.call('Floor busy');
      debugPrint('[FloorArbiter] Request denied — $_deniedCount peers busy');
    } else {
      // All peers granted → we win the floor
      _grantFloor();
    }
  }

  void _selfGrant() {
    // Solo offline mode
    debugPrint('[FloorArbiter] Solo mode — self-granting floor');
    _grantFloor();
  }

  void _grantFloor() {
    _currentHolder = MeshFloorHolder(
      deviceId: _localDeviceId!,
      callsign: _localCallsign!,
      floorToken: _pendingToken ?? 'local',
      lamportClock: _pendingClock,
      acquiredAt: DateTime.now(),
    );
    _setFloorState(MeshFloorState.speaking);
    _transmissionSeconds = 0;
    _startSafetyTimer();

    // Announce to all peers that we are now speaking
    _mesh.broadcast(MeshMessage(
      type: MeshMessageType.floorBusy,
      senderDeviceId: _localDeviceId!,
      senderCallsign: _localCallsign!,
      roomId: _currentRoomId!,
      lamportClock: _mesh.nextClock,
      floorToken: _currentHolder!.floorToken,
    )).ignore();

    onFloorGranted?.call();
    debugPrint('[FloorArbiter] Floor GRANTED to us at T=$_pendingClock');
  }

  void _startSafetyTimer() {
    _safetyTimer?.cancel();
    _safetyTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _transmissionSeconds++;
      if (_transmissionSeconds >= _maxTransmissionSeconds) {
        debugPrint('[FloorArbiter] Safety cutoff — auto-releasing after 60s');
        releaseFloor();
      }
      notifyListeners();
    });
  }

  void _setFloorState(MeshFloorState state) {
    if (_floorState == state) return;
    _floorState = state;
    debugPrint('[FloorArbiter] State → $state');
    notifyListeners();
  }

  @override
  void dispose() {
    _requestTimeoutTimer?.cancel();
    _safetyTimer?.cancel();
    super.dispose();
  }
}
