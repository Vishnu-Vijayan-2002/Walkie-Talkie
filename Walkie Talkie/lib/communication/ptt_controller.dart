import 'dart:async';
import 'package:flutter/foundation.dart';
import 'state_machine/ptt_state_machine.dart';
import '../models/models.dart';
import '../services/signalr_service.dart';
import '../services/device_identity_service.dart';
import '../core/services/audio_feedback.dart';

/// PttController — the single orchestrator between:
///   [PttStateMachine]   (deterministic floor FSM)
///   [ConnectXSignalRService] (real-time server transport)
///   [AppState]          (UI state, notified via callback)
///
/// Usage:
import '../services/webrtc_voice_service.dart';

/// PttController — the single orchestrator between:
///   [PttStateMachine]   (deterministic floor FSM)
///   [ConnectXSignalRService] (real-time server transport)
///   [WebRtcVoiceService] (Opus audio stream transmission)
///   [AppState]          (UI state, notified via callback)
class PttController extends ChangeNotifier {
  final ConnectXSignalRService _hub;
  final WebRtcVoiceService _voiceService;
  PttStateMachine? _fsm;

  String? _activeRoomId;
  String? _deviceId;
  String? _callsign;
  String? _currentFloorToken;

  PttState _pttState = PttState.idle;
  PttState get pttState => _pttState;

  String? _activeSpeakerCallsign;
  String? get activeSpeakerCallsign => _activeSpeakerCallsign;

  bool _isHandRaised = false;
  bool get isHandRaised => _isHandRaised;

  // Queue of who has their hand raised: list of (deviceId, callsign, position)
  final List<RaisedHand> _raisedHandQueue = [];
  List<RaisedHand> get raisedHandQueue => List.unmodifiable(_raisedHandQueue);

  int _transmissionSeconds = 0;
  int get transmissionSeconds => _transmissionSeconds;
  Timer? _transmissionTimer;

  // Callback so AppState can propagate changes to all listeners
  VoidCallback? onStateChanged;

  PttController({
    required ConnectXSignalRService hub,
    required WebRtcVoiceService voiceService,
  })  : _hub = hub,
        _voiceService = voiceService {
    _wireHubCallbacks();
  }

  Future<void> initialize() async {
    final identity = await DeviceIdentityService.getOrCreateIdentity();
    _deviceId = identity.deviceUuid;
    _callsign = identity.displayName.isNotEmpty ? identity.displayName : identity.hardwareCallsign;

    _fsm = PttStateMachine(
      localDeviceId: _deviceId!,
      localCallsign: _callsign!,
    );
    _fsm!.addListener(_onFsmChanged);

    // Initialize WebRTC microphone input
    await _voiceService.initializeAudio(localDeviceId: _deviceId!);

    // Start the SignalR connection (non-blocking; retries automatically)
    unawaited(_hub.connect());
  }

  Future<void> joinRoom(String roomId) async {
    if (_deviceId == null || _callsign == null) return;
    _activeRoomId = roomId;
    _raisedHandQueue.clear();
    _isHandRaised = false;
    _currentFloorToken = null;

    _voiceService.setCurrentRoom(roomId);
    _fsm?.reset();
    _setPttState(PttState.idle);

    await _hub.joinRoom(roomId, _deviceId!, _callsign!);
  }

  Future<void> leaveRoom() async {
    if (_activeRoomId == null || _deviceId == null) return;
    await _hub.leaveRoom(_activeRoomId!, _deviceId!);
    _activeRoomId = null;
    _currentFloorToken = null;
    _transmissionTimer?.cancel();
    _setPttState(PttState.idle);
  }

  // ──────────────────────────────────────────────────────────────────────
  // PTT Press & Release
  // ──────────────────────────────────────────────────────────────────────

  Future<void> pressPtt() async {
    if (_activeRoomId == null || _deviceId == null) return;

    if (_pttState == PttState.floorBusy) {
      // Cannot speak — offer raise hand feedback
      AudioFeedbackService.pttDenied();
      return;
    }

    AudioFeedbackService.pttPressed();
    _setPttState(PttState.requesting);
    _fsm?.onPttPressed(roomId: _activeRoomId!, isMeshMode: false);

    await _hub.requestFloor(_activeRoomId!, _deviceId!, _callsign!);
  }

  Future<void> releasePtt() async {
    if (_activeRoomId == null || _deviceId == null) return;
    if (_pttState != PttState.speaking) return;

    AudioFeedbackService.pttReleased();
    _voiceService.stopTransmitting();
    final token = _currentFloorToken ?? '';
    _currentFloorToken = null;
    _transmissionTimer?.cancel();

    _fsm?.onPttReleased(roomId: _activeRoomId!);
    await _hub.releaseFloor(_activeRoomId!, _deviceId!, token);
    _setPttState(PttState.idle);
    _activeSpeakerCallsign = null;
  }

  // ──────────────────────────────────────────────────────────────────────
  // Raise Hand / Floor Queue
  // ──────────────────────────────────────────────────────────────────────

  Future<void> raiseHand() async {
    if (_activeRoomId == null || _deviceId == null) return;
    if (_isHandRaised) return;

    AudioFeedbackService.handRaised();
    _isHandRaised = true;
    await _hub.raiseHand(_activeRoomId!, _deviceId!, _callsign!);
    notifyListeners();
    onStateChanged?.call();
  }

  Future<void> cancelHand() async {
    if (_activeRoomId == null || _deviceId == null) return;
    _isHandRaised = false;
    await _hub.cancelRaiseHand(_activeRoomId!, _deviceId!);
    notifyListeners();
    onStateChanged?.call();
  }

  /// Moderator action: give the speaking floor to a queued member.
  Future<void> giveFloor(RaisedHand hand) async {
    if (_activeRoomId == null) return;
    AudioFeedbackService.floorGranted();
    await _hub.giveFloor(_activeRoomId!, hand.memberId, hand.memberName);
  }

  /// Broadcast a high-priority emergency alert to the room.
  Future<void> sendEmergencyAlert(String roomId, String deviceId, String details) async {
    await _hub.sendEmergencyAlert(roomId, deviceId, details);
  }

  // ──────────────────────────────────────────────────────────────────────
  // Inbound: Wire SignalR callbacks → FSM events → UI state
  // ──────────────────────────────────────────────────────────────────────

  void _wireHubCallbacks() {
    _hub.onFloorGranted = (event) {
      _currentFloorToken = event.floorToken;
      _activeSpeakerCallsign = _callsign;
      _isHandRaised = false;
      _fsm?.handleInboundEvent(event);
      _setPttState(PttState.speaking);
      _voiceService.startTransmitting();
      _startTransmissionTimer();
      AudioFeedbackService.pttPressed();
    };

    _hub.onFloorBusy = (event) {
      if (event.senderDeviceId == _deviceId) return; // our own grant, handled above
      _activeSpeakerCallsign = event.senderCallsign;
      _currentFloorToken = null;
      _fsm?.handleInboundEvent(event);
      _setPttState(PttState.floorBusy);
    };

    _hub.onFloorReleased = (event) {
      _activeSpeakerCallsign = null;
      _currentFloorToken = null;
      _transmissionTimer?.cancel();
      _voiceService.stopTransmitting();
      _fsm?.handleInboundEvent(event);
      _setPttState(PttState.idle);
      AudioFeedbackService.pttReleased();
    };

    _hub.onFloorDenied = (event) {
      _fsm?.handleInboundEvent(event);
      _setPttState(PttState.denied);
      AudioFeedbackService.pttDenied();
      // Auto-reset to idle after 1.5 seconds
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (_pttState == PttState.denied) {
          _setPttState(PttState.idle);
        }
      });
    };

    _hub.onHandRaised = (event) {
      // Add to local queue if not already present
      final alreadyQueued = _raisedHandQueue.any((rh) => rh.memberId == event.senderDeviceId);
      if (!alreadyQueued) {
        _raisedHandQueue.add(RaisedHand(
          id: 'rh_${event.senderDeviceId}_${event.timestampEpochMs}',
          memberId: event.senderDeviceId,
          memberName: event.senderCallsign,
          requestedAt: DateTime.fromMillisecondsSinceEpoch(event.timestampEpochMs),
        ));
        _raisedHandQueue.sort((a, b) => a.requestedAt.compareTo(b.requestedAt));
      }
      notifyListeners();
      onStateChanged?.call();
    };

    _hub.onHandCancelled = (event) {
      _raisedHandQueue.removeWhere((rh) => rh.memberId == event.senderDeviceId);
      if (event.senderDeviceId == _deviceId) {
        _isHandRaised = false;
      }
      notifyListeners();
      onStateChanged?.call();
    };

    _hub.onMemberMuted = (roomId, deviceId, data) {
      if (deviceId == _deviceId && data['isMuted'] == true) {
        // We have been muted by a moderator — release floor if speaking
        if (_pttState == PttState.speaking) {
          releasePtt();
        }
        _setPttState(PttState.idle);
      }
      onStateChanged?.call();
    };

    _hub.onMemberBanned = (roomId, deviceId, data) {
      if (deviceId == _deviceId) {
        leaveRoom();
      }
      onStateChanged?.call();
    };
  }

  void _onFsmChanged() {
    _transmissionSeconds = _fsm?.context.transmissionSeconds ?? 0;
    notifyListeners();
  }

  void _setPttState(PttState state) {
    if (_pttState == state) return;
    _pttState = state;
    notifyListeners();
    onStateChanged?.call();
  }

  void _startTransmissionTimer() {
    _transmissionSeconds = 0;
    _transmissionTimer?.cancel();
    _transmissionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _transmissionSeconds++;
      // Safety cutoff at 60 seconds (mirrors server-side Redis TTL)
      if (_transmissionSeconds >= 60) {
        releasePtt();
      }
      notifyListeners();
      onStateChanged?.call();
    });
  }

  @override
  void dispose() {
    _transmissionTimer?.cancel();
    _fsm?.removeListener(_onFsmChanged);
    _fsm?.dispose();
    super.dispose();
  }
}
