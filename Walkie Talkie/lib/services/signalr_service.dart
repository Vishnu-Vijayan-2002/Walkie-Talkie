import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:signalr_netcore/signalr_client.dart';
import '../communication/protocol/ptt_events.dart';

/// Represents the live connection status of the SignalR hub.
enum HubConnectionStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

/// Callback fired when any PTT floor event arrives from the server.
typedef FloorEventCallback = void Function(PttEventMessage event);

/// Callback fired when presence (member joined/left/muted/banned) changes.
typedef PresenceCallback = void Function(String roomId, String deviceId, Map<String, dynamic> data);
typedef WebRtcSdpCallback = void Function(String roomId, String senderDeviceId, String sdp);
typedef WebRtcIceCandidateCallback = void Function(String roomId, String senderDeviceId, String candidate, String sdpMid, int sdpMLineIndex);

/// Room Join Request Callbacks
typedef RoomSearchResultCallback = void Function(String roomId, String roomName, String creatorName, int memberCount, bool found);
typedef IncomingJoinRequestCallback = void Function(String roomId, String requesterDeviceId, String requesterCallsign);
typedef JoinApprovedCallback = void Function(String roomId, String roomName, String creatorName, int memberCount);
typedef JoinDeclinedCallback = void Function(String roomId, String reason);

/// ConnectXSignalRService — the single, persistent SignalR connection to PttHub.
///
/// Responsibilities:
///   - Maintain a single HubConnection to the backend.
///   - Dispatch outgoing actions: JoinRoom, RequestFloor, ReleaseFloor, RaiseHand, GiveFloor.
///   - Route inbound server messages into typed [PttEventMessage] callbacks.
///   - Relay WebRTC SDP Offers, Answers, and ICE candidates.
///   - Expose a [statusStream] for connection health monitoring.
class ConnectXSignalRService extends ChangeNotifier {
  static const String _defaultHubUrl = 'http://10.120.69.98:5211/hubs/ptt'; // Real device → PC on LAN

  HubConnection? _connection;
  HubConnectionStatus _status = HubConnectionStatus.disconnected;
  HubConnectionStatus get status => _status;

  final _statusController = StreamController<HubConnectionStatus>.broadcast();
  Stream<HubConnectionStatus> get statusStream => _statusController.stream;

  /// Registered listeners for inbound floor events
  FloorEventCallback? onFloorGranted;
  FloorEventCallback? onFloorBusy;
  FloorEventCallback? onFloorReleased;
  FloorEventCallback? onFloorDenied;
  FloorEventCallback? onHandRaised;
  FloorEventCallback? onHandCancelled;

  PresenceCallback? onMemberJoined;
  PresenceCallback? onMemberLeft;
  PresenceCallback? onMemberMuted;
  PresenceCallback? onMemberBanned;
  PresenceCallback? onEmergencyBroadcast;

  /// WebRTC Voice Signaling Listeners
  WebRtcSdpCallback? onWebRtcOffer;
  WebRtcSdpCallback? onWebRtcAnswer;
  WebRtcIceCandidateCallback? onIceCandidate;

  /// Room Join Request Listeners
  RoomSearchResultCallback? onRoomSearchResult;
  IncomingJoinRequestCallback? onIncomingJoinRequest;
  JoinApprovedCallback? onJoinApproved;
  JoinDeclinedCallback? onJoinDeclined;

  ConnectXSignalRService();

  Future<void> connect({String? hubUrl}) async {
    final url = hubUrl ?? _defaultHubUrl;

    if (_status == HubConnectionStatus.connected || _status == HubConnectionStatus.connecting) {
      return;
    }

    _setStatus(HubConnectionStatus.connecting);

    _connection = HubConnectionBuilder()
        .withUrl(url)
        .withAutomaticReconnect(retryDelays: [2000, 5000, 10000, 30000])
        .build();

    _connection!.onreconnecting(({error}) {
      debugPrint('[SignalR] Reconnecting… $error');
      _setStatus(HubConnectionStatus.reconnecting);
    });

    _connection!.onreconnected(({connectionId}) {
      debugPrint('[SignalR] Reconnected. connectionId=$connectionId');
      _setStatus(HubConnectionStatus.connected);
    });

    _connection!.onclose(({error}) {
      debugPrint('[SignalR] Connection closed. $error');
      _setStatus(HubConnectionStatus.disconnected);
    });

    _registerServerHandlers();

    try {
      await _connection!.start();
      _setStatus(HubConnectionStatus.connected);
      debugPrint('[SignalR] Connected to $url');
    } catch (e) {
      debugPrint('[SignalR] Connection failed: $e');
      _setStatus(HubConnectionStatus.error);
    }
  }

  Future<void> disconnect() async {
    await _connection?.stop();
    _setStatus(HubConnectionStatus.disconnected);
  }

  void _setStatus(HubConnectionStatus s) {
    _status = s;
    _statusController.add(s);
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────
  // Outbound Hub Invocations
  // ─────────────────────────────────────────────────────────────────

  Future<void> joinRoom(String roomId, String deviceId, String callsign) async {
    await _invoke('JoinRoom', [roomId, deviceId, callsign]);
  }

  Future<void> leaveRoom(String roomId, String deviceId) async {
    await _invoke('LeaveRoom', [roomId, deviceId]);
  }

  Future<void> requestFloor(String roomId, String deviceId, String callsign) async {
    await _invoke('RequestFloor', [roomId, deviceId, callsign]);
  }

  Future<void> releaseFloor(String roomId, String deviceId, String floorToken) async {
    await _invoke('ReleaseFloor', [roomId, deviceId, floorToken]);
  }

  Future<void> raiseHand(String roomId, String deviceId, String callsign) async {
    await _invoke('RaiseHand', [roomId, deviceId, callsign]);
  }

  Future<void> cancelRaiseHand(String roomId, String deviceId) async {
    await _invoke('CancelRaiseHand', [roomId, deviceId]);
  }

  // ─────────────────────────────────────────────────────────────────
  // Room Join Request Invocations
  // ─────────────────────────────────────────────────────────────────

  Future<void> searchRoom(String roomId, String requesterDeviceId) async {
    await _invoke('SearchRoom', [roomId, requesterDeviceId]);
  }

  Future<void> requestJoin(String roomId, String requesterDeviceId, String requesterCallsign) async {
    await _invoke('RequestJoin', [roomId, requesterDeviceId, requesterCallsign]);
  }

  Future<void> approveJoin(String roomId, String approverDeviceId, String requesterDeviceId) async {
    await _invoke('ApproveJoin', [roomId, approverDeviceId, requesterDeviceId]);
  }

  Future<void> declineJoin(String roomId, String declinerDeviceId, String requesterDeviceId) async {
    await _invoke('DeclineJoin', [roomId, declinerDeviceId, requesterDeviceId]);
  }

  /// Makes a locally-created room discoverable by other devices connected to
  /// this hub.  Room creation is offline-first, so this is deliberately a
  /// lightweight realtime registration rather than a prerequisite for saving
  /// the room locally.
  Future<void> registerRoomCreator(
    String roomId,
    String creatorDeviceId,
    String roomName,
    String creatorName,
  ) async {
    await _invoke('RegisterRoomCreator', [roomId, creatorDeviceId, roomName, creatorName]);
  }

  Future<void> giveFloor(String roomId, String targetDeviceId, String targetCallsign) async {
    await _invoke('GiveFloor', [roomId, targetDeviceId, targetCallsign]);
  }

  Future<void> sendEmergencyAlert(String roomId, String deviceId, String details) async {
    await _invoke('EmergencyAlert', [roomId, deviceId, details]);
  }

  // ─────────────────────────────────────────────────────────────────
  // WebRTC Signaling Invocations
  // ─────────────────────────────────────────────────────────────────

  Future<void> sendWebRtcOffer(String roomId, String senderDeviceId, String targetDeviceId, String sdp) async {
    await _invoke('SendWebRtcOffer', [roomId, senderDeviceId, targetDeviceId, sdp]);
  }

  Future<void> sendWebRtcAnswer(String roomId, String senderDeviceId, String targetDeviceId, String sdp) async {
    await _invoke('SendWebRtcAnswer', [roomId, senderDeviceId, targetDeviceId, sdp]);
  }

  Future<void> sendIceCandidate(String roomId, String senderDeviceId, String targetDeviceId, String candidate, String sdpMid, int sdpMLineIndex) async {
    await _invoke('SendIceCandidate', [roomId, senderDeviceId, targetDeviceId, candidate, sdpMid, sdpMLineIndex]);
  }

  Future<void> _invoke(String method, List<Object> args) async {
    if (_connection == null || _status != HubConnectionStatus.connected) {
      debugPrint('[SignalR] Cannot invoke $method — not connected (status: $_status)');
      return;
    }
    try {
      await _connection!.invoke(method, args: args);
    } catch (e) {
      debugPrint('[SignalR] Error invoking $method: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // Inbound Server Handlers
  // ─────────────────────────────────────────────────────────────────

  void _registerServerHandlers() {
    _on('OnFloorGranted', (List<Object?>? args) {
      if (args == null || args.length < 3) return;
      onFloorGranted?.call(PttEventMessage(
        type: PttEventType.floorGranted,
        roomId: args[0] as String,
        senderDeviceId: args[1] as String,
        senderCallsign: '',
        floorToken: args[2] as String,
        timestampEpochMs: DateTime.now().millisecondsSinceEpoch,
      ));
    });

    _on('OnFloorBusy', (List<Object?>? args) {
      if (args == null || args.length < 3) return;
      onFloorBusy?.call(PttEventMessage(
        type: PttEventType.floorBusy,
        roomId: args[0] as String,
        senderDeviceId: args[1] as String,
        senderCallsign: args[2] as String,
        timestampEpochMs: DateTime.now().millisecondsSinceEpoch,
      ));
    });

    _on('OnFloorReleased', (List<Object?>? args) {
      if (args == null || args.isEmpty) return;
      onFloorReleased?.call(PttEventMessage(
        type: PttEventType.floorReleased,
        roomId: args[0] as String,
        senderDeviceId: '',
        senderCallsign: '',
        timestampEpochMs: DateTime.now().millisecondsSinceEpoch,
      ));
    });

    _on('OnFloorDenied', (List<Object?>? args) {
      if (args == null || args.length < 2) return;
      onFloorDenied?.call(PttEventMessage(
        type: PttEventType.floorDenied,
        roomId: args[0] as String,
        senderDeviceId: '',
        senderCallsign: '',
        deniedReason: args[1] as String,
        timestampEpochMs: DateTime.now().millisecondsSinceEpoch,
      ));
    });

    _on('OnHandRaised', (List<Object?>? args) {
      if (args == null || args.length < 4) return;
      onHandRaised?.call(PttEventMessage(
        type: PttEventType.raiseHand,
        roomId: args[0] as String,
        senderDeviceId: args[1] as String,
        senderCallsign: args[2] as String,
        queuePosition: args[3] as int?,
        timestampEpochMs: DateTime.now().millisecondsSinceEpoch,
      ));
    });

    _on('OnHandCancelled', (List<Object?>? args) {
      if (args == null || args.length < 2) return;
      onHandCancelled?.call(PttEventMessage(
        type: PttEventType.floorReleased,
        roomId: args[0] as String,
        senderDeviceId: args[1] as String,
        senderCallsign: '',
        timestampEpochMs: DateTime.now().millisecondsSinceEpoch,
      ));
    });

    _on('OnMemberJoined', (List<Object?>? args) {
      if (args == null || args.length < 3) return;
      onMemberJoined?.call(args[0] as String, args[1] as String, {'callsign': args[2]});
    });

    _on('OnMemberLeft', (List<Object?>? args) {
      if (args == null || args.length < 2) return;
      onMemberLeft?.call(args[0] as String, args[1] as String, {});
    });

    _on('OnMemberMuted', (List<Object?>? args) {
      if (args == null || args.length < 3) return;
      onMemberMuted?.call(args[0] as String, args[1] as String, {'isMuted': args[2]});
    });

    _on('OnMemberBanned', (List<Object?>? args) {
      if (args == null || args.length < 3) return;
      onMemberBanned?.call(args[0] as String, args[1] as String, {'reason': args[2]});
    });

    _on('OnEmergencyBroadcast', (List<Object?>? args) {
      if (args == null || args.length < 3) return;
      onEmergencyBroadcast?.call(args[0] as String, args[1] as String, {'details': args[2]});
    });

    // WebRTC Signaling Handlers
    _on('OnWebRtcOffer', (List<Object?>? args) {
      if (args == null || args.length < 3) return;
      onWebRtcOffer?.call(args[0] as String, args[1] as String, args[2] as String);
    });

    _on('OnWebRtcAnswer', (List<Object?>? args) {
      if (args == null || args.length < 3) return;
      onWebRtcAnswer?.call(args[0] as String, args[1] as String, args[2] as String);
    });

    _on('OnIceCandidate', (List<Object?>? args) {
      if (args == null || args.length < 5) return;
      onIceCandidate?.call(
        args[0] as String,
        args[1] as String,
        args[2] as String,
        args[3] as String,
        args[4] as int,
      );
    });

    // Room Join Request Handlers
    _on('OnRoomSearchResult', (List<Object?>? args) {
      if (args == null || args.length < 5) return;
      onRoomSearchResult?.call(
        args[0] as String,
        args[1] as String,
        args[2] as String,
        args[3] as int,
        args[4] as bool,
      );
    });

    _on('OnIncomingJoinRequest', (List<Object?>? args) {
      if (args == null || args.length < 3) return;
      onIncomingJoinRequest?.call(
        args[0] as String,
        args[1] as String,
        args[2] as String,
      );
    });

    _on('OnJoinApproved', (List<Object?>? args) {
      if (args == null || args.length < 4) return;
      onJoinApproved?.call(
        args[0] as String,
        args[1] as String,
        args[2] as String,
        args[3] as int,
      );
    });

    _on('OnJoinDeclined', (List<Object?>? args) {
      if (args == null || args.length < 2) return;
      onJoinDeclined?.call(
        args[0] as String,
        args[1] as String,
      );
    });
  }

  void _on(String method, Function(List<Object?>?) handler) {
    _connection!.on(method, handler);
  }

  @override
  void dispose() {
    disconnect();
    _statusController.close();
    super.dispose();
  }
}
