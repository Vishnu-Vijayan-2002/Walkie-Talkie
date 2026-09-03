import 'dart:async';
import 'package:flutter/foundation.dart';
import '../protocol/ptt_events.dart';

enum FsmPttState {
  idle,            // Floor available ("HOLD TO TALK")
  requesting,      // Request dispatched ("REQUESTING...")
  transmitting,    // Floor token granted ("SPEAKING")
  floorBusy,       // Another peer is speaking ("Rahul is speaking")
  floorDenied,     // Request rejected
  offlineMeshIdle, // P2P Mesh ready
}

class PttFloorContext {
  final FsmPttState state;
  final String? activeSpeakerDeviceId;
  final String? activeSpeakerCallsign;
  final String? floorToken;
  final int transmissionSeconds;
  final String? denialReason;

  const PttFloorContext({
    required this.state,
    this.activeSpeakerDeviceId,
    this.activeSpeakerCallsign,
    this.floorToken,
    this.transmissionSeconds = 0,
    this.denialReason,
  });

  PttFloorContext copyWith({
    FsmPttState? state,
    String? activeSpeakerDeviceId,
    String? activeSpeakerCallsign,
    String? floorToken,
    int? transmissionSeconds,
    String? denialReason,
  }) {
    return PttFloorContext(
      state: state ?? this.state,
      activeSpeakerDeviceId: activeSpeakerDeviceId ?? this.activeSpeakerDeviceId,
      activeSpeakerCallsign: activeSpeakerCallsign ?? this.activeSpeakerCallsign,
      floorToken: floorToken ?? this.floorToken,
      transmissionSeconds: transmissionSeconds ?? this.transmissionSeconds,
      denialReason: denialReason ?? this.denialReason,
    );
  }
}

class PttStateMachine extends ChangeNotifier {
  final String localDeviceId;
  final String localCallsign;
  
  PttFloorContext _context = const PttFloorContext(state: FsmPttState.idle);
  PttFloorContext get context => _context;

  Timer? _transmissionSafetyTimer;
  Timer? _requestTimeoutTimer;

  // Max continuous transmission limit (tactical safety cutoff: 60s)
  static const int maxTransmissionSeconds = 60;
  static const Duration requestTimeout = Duration(milliseconds: 1500);

  // Outbound wire event dispatcher callback
  void Function(PttEventMessage message)? onOutboundEvent;

  PttStateMachine({
    required this.localDeviceId,
    required this.localCallsign,
  });

  // --- Local User Triggers ---

  void onPttPressed({required String roomId, bool isMeshMode = false}) {
    // If floor is currently taken by someone else, ignore or indicate busy
    if (_context.state == FsmPttState.floorBusy) {
      return;
    }

    if (isMeshMode) {
      _grantFloorLocally(roomId: roomId, token: 'mesh_${DateTime.now().millisecondsSinceEpoch}');
      return;
    }

    // Move to requesting state and dispatch floor request
    _context = _context.copyWith(state: FsmPttState.requesting);
    notifyListeners();

    // Start request timeout in case network drops
    _requestTimeoutTimer?.cancel();
    _requestTimeoutTimer = Timer(requestTimeout, () {
      if (_context.state == FsmPttState.requesting) {
        // Fallback: auto-grant or deny depending on connection
        _grantFloorLocally(roomId: roomId, token: 'local_grant_${DateTime.now().millisecondsSinceEpoch}');
      }
    });

    final requestEvent = PttEventMessage(
      type: PttEventType.floorRequest,
      roomId: roomId,
      senderDeviceId: localDeviceId,
      senderCallsign: localCallsign,
      timestampEpochMs: DateTime.now().millisecondsSinceEpoch,
    );

    onOutboundEvent?.call(requestEvent);
  }

  void onPttReleased({required String roomId}) {
    _requestTimeoutTimer?.cancel();
    _stopTransmissionSafetyTimer();

    if (_context.state == FsmPttState.transmitting || _context.state == FsmPttState.requesting) {
      final token = _context.floorToken;
      _context = const PttFloorContext(state: FsmPttState.idle);
      notifyListeners();

      final releaseEvent = PttEventMessage(
        type: PttEventType.floorReleased,
        roomId: roomId,
        senderDeviceId: localDeviceId,
        senderCallsign: localCallsign,
        floorToken: token,
        timestampEpochMs: DateTime.now().millisecondsSinceEpoch,
      );

      onOutboundEvent?.call(releaseEvent);
    }
  }

  // --- Inbound Remote Network Events Handlers ---

  void handleInboundEvent(PttEventMessage event) {
    switch (event.type) {
      case PttEventType.floorGranted:
        if (event.targetDeviceId == localDeviceId || event.senderDeviceId == localDeviceId) {
          _grantFloorLocally(roomId: event.roomId, token: event.floorToken ?? 'granted');
        } else {
          _setFloorBusy(
            speakerDeviceId: event.senderDeviceId,
            speakerCallsign: event.senderCallsign,
          );
        }
        break;

      case PttEventType.floorBusy:
        if (event.senderDeviceId != localDeviceId) {
          _setFloorBusy(
            speakerDeviceId: event.senderDeviceId,
            speakerCallsign: event.senderCallsign,
          );
        }
        break;

      case PttEventType.floorReleased:
        _setFloorIdle();
        break;

      case PttEventType.floorDenied:
        if (event.targetDeviceId == localDeviceId) {
          _requestTimeoutTimer?.cancel();
          _context = _context.copyWith(
            state: FsmPttState.floorDenied,
            denialReason: event.metadata['reason'] as String? ?? 'Speaking unavailable',
          );
          notifyListeners();
        }
        break;

      default:
        break;
    }
  }

  void _grantFloorLocally({required String roomId, required String token}) {
    _requestTimeoutTimer?.cancel();
    _context = PttFloorContext(
      state: FsmPttState.transmitting,
      activeSpeakerDeviceId: localDeviceId,
      activeSpeakerCallsign: localCallsign,
      floorToken: token,
      transmissionSeconds: 0,
    );
    notifyListeners();

    _startTransmissionSafetyTimer(roomId);
  }

  void _setFloorBusy({required String speakerDeviceId, required String speakerCallsign}) {
    _requestTimeoutTimer?.cancel();
    _stopTransmissionSafetyTimer();
    _context = PttFloorContext(
      state: FsmPttState.floorBusy,
      activeSpeakerDeviceId: speakerDeviceId,
      activeSpeakerCallsign: speakerCallsign,
    );
    notifyListeners();
  }

  void _setFloorIdle() {
    _requestTimeoutTimer?.cancel();
    _stopTransmissionSafetyTimer();
    _context = const PttFloorContext(state: FsmPttState.idle);
    notifyListeners();
  }

  void _startTransmissionSafetyTimer(String roomId) {
    _transmissionSafetyTimer?.cancel();
    _transmissionSafetyTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final nextSec = _context.transmissionSeconds + 1;
      if (nextSec >= maxTransmissionSeconds) {
        // Safety cutoff
        onPttReleased(roomId: roomId);
      } else {
        _context = _context.copyWith(transmissionSeconds: nextSec);
        notifyListeners();
      }
    });
  }

  void _stopTransmissionSafetyTimer() {
    _transmissionSafetyTimer?.cancel();
    _transmissionSafetyTimer = null;
  }

  /// Reset the FSM to idle — used when entering a new room.
  void reset() {
    _requestTimeoutTimer?.cancel();
    _stopTransmissionSafetyTimer();
    _context = const PttFloorContext(state: FsmPttState.idle);
    notifyListeners();
  }

  @override
  void dispose() {
    _requestTimeoutTimer?.cancel();
    _stopTransmissionSafetyTimer();
    super.dispose();
  }
}
