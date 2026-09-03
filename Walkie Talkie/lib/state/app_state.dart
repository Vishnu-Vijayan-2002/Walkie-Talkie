import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../communication/ptt_controller.dart';
import '../core/services/audio_feedback.dart';
import '../database/repositories/room_repository.dart';
import '../database/repositories/sync_queue_repository.dart';
import '../models/device_identity.dart';
import '../models/models.dart';
import '../services/device_identity_service.dart';
import '../services/signalr_service.dart';
import '../services/room_api_service.dart';
import '../services/webrtc_voice_service.dart';

class IncomingJoinRequest {
  final String roomId;
  final String requesterDeviceId;
  final String requesterCallsign;

  const IncomingJoinRequest(this.roomId, this.requesterDeviceId, this.requesterCallsign);
}

class AppState extends ChangeNotifier {
  // Repositories
  final RoomRepository _roomRepo = RoomRepository();
  final SyncQueueRepository _syncRepo = SyncQueueRepository();
  final RoomApiService _roomApi = RoomApiService();

  // SignalR Hub connection + PTT Orchestrator + WebRTC Voice Engine
  late final ConnectXSignalRService signalRService;
  late final WebRtcVoiceService voiceService;
  late final PttController pttController;

  // Persistent Hardware Device Identity
  DeviceIdentity? deviceIdentity;
  bool isIdentityLoaded = false;

  // Current Operator Profile
  late UserProfile currentUser;

  bool isDarkMode = true;
  ConnectionMode connectionMode = ConnectionMode.online;
  int nearbyPeerCount = 3;

  // Selected / Active Room
  Room? activeRoom;

  // Mirrored from PttController for UI convenience
  PttState get pttState => pttController.pttState;
  String? get currentSpeakerName => pttController.activeSpeakerCallsign;
  bool get isHandRaised => pttController.isHandRaised;
  int get transmissionSeconds => pttController.transmissionSeconds;
  List<RaisedHand> get liveRaisedHands => pttController.raisedHandQueue;
  HubConnectionStatus get hubStatus => signalRService.status;
  bool get isTransmittingVoice => voiceService.isTransmitting;

  // Dynamic audio waveform simulation data (16 amplitude bands)
  List<double> waveAmplitudes = List.generate(16, (_) => 0.1);
  Timer? _waveSimulationTimer;

  // Rooms Catalog
  List<Room> rooms = [];
  Room? searchedRoom;
  final List<IncomingJoinRequest> incomingJoinRequests = [];
  Completer<bool>? _roomSearchCompleter;
  StreamSubscription<HubConnectionStatus>? _hubStatusSubscription;

  // Alerts List
  List<AlertItem> alerts = [];

  AppState() {
    currentUser = UserProfile(
      deviceId: 'CX-PROVISIONING',
      callSign: 'Operator',
      team: 'General Unit',
    );

    signalRService = ConnectXSignalRService();
    voiceService = WebRtcVoiceService(signalR: signalRService);

    pttController = PttController(
      hub: signalRService,
      voiceService: voiceService,
    );
    pttController.onStateChanged = _onPttStateChanged;
    _wireJoinRequestCallbacks();
    _hubStatusSubscription = signalRService.statusStream.listen((status) {
      if (status == HubConnectionStatus.connected) _registerOwnedRooms();
    });

    _initDeviceIdentity();
  }

  Future<void> _initDeviceIdentity() async {
    final identity = await DeviceIdentityService.getOrCreateIdentity();
    deviceIdentity = identity;

    final displayName = identity.displayName.trim().isEmpty ? 'Operator' : identity.displayName.trim();

    currentUser = UserProfile(
      deviceId: identity.hardwareCallsign,
      callSign: displayName,
      team: identity.unitOrTeam,
    );

    // Initialize the PTT controller (also starts SignalR connection)
    await pttController.initialize();

    // Wire PTT state transitions to waveform simulation
    pttController.addListener(_onPttControllerChanged);

    try {
      await _roomApi.provisionDevice(identity);
      await _loadRoomsFromServer(identity.hardwareCallsign);
    } catch (error) {
      // The catalog is server-authoritative; remain empty until the server is reachable.
      debugPrint('Unable to load rooms from server: $error');
      rooms = [];
      activeRoom = null;
    }
    await _registerOwnedRooms();
    alerts = [];

    // Auto-join the first room's SignalR group
    if (activeRoom != null) {
      await pttController.joinRoom(activeRoom!.id);
    }

    isIdentityLoaded = true;
    notifyListeners();
  }

  void _wireJoinRequestCallbacks() {
    signalRService.onRoomSearchResult = (roomId, roomName, creatorName, memberCount, found) {
      searchedRoom = found
          ? Room(id: roomId, name: roomName, type: RoomType.general, creatorName: creatorName,
              createdDate: 'Today', memberCount: memberCount, members: [], raisedHands: [])
          : null;
      _roomSearchCompleter?.complete(found);
      _roomSearchCompleter = null;
      notifyListeners();
    };
    signalRService.onIncomingJoinRequest = (roomId, requesterDeviceId, requesterCallsign) {
      if (!incomingJoinRequests.any((request) => request.roomId == roomId && request.requesterDeviceId == requesterDeviceId)) {
        incomingJoinRequests.add(IncomingJoinRequest(roomId, requesterDeviceId, requesterCallsign));
        notifyListeners();
      }
    };
    signalRService.onJoinApproved = (roomId, roomName, creatorName, memberCount) {
      joinApprovedRoom(Room(id: roomId, name: roomName, type: RoomType.general, creatorName: creatorName,
          createdDate: 'Today', memberCount: memberCount, members: [], raisedHands: []));
    };
    signalRService.onJoinDeclined = (roomId, reason) {
      alerts.insert(0, AlertItem(
        id: 'join_declined_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Join request declined', message: reason, roomName: roomId,
        timeAgo: 'Just now', type: AlertType.roomEvent,
      ));
      notifyListeners();
    };
  }

  Future<void> _registerOwnedRooms() async {
    if (deviceIdentity == null) return;
    for (final room in rooms.where((room) => room.isUserCreator)) {
      await signalRService.registerRoomCreator(room.id, currentUser.deviceId, room.name, currentUser.callSign);
    }
  }

  void _onPttStateChanged() {
    // Mirror state-driven waveform control
    final state = pttController.pttState;
    if (state == PttState.speaking || state == PttState.floorBusy) {
      _startWaveSimulation();
    } else {
      _stopWaveSimulation();
    }
    notifyListeners();
  }

  void _onPttControllerChanged() {
    notifyListeners();
  }

  Future<void> _loadRoomsFromServer(String userDeviceId) async {
    rooms = await _roomApi.getRooms(userDeviceId);
    activeRoom = rooms.isEmpty ? null : rooms.first;
  }

  void toggleTheme() {
    isDarkMode = !isDarkMode;
    notifyListeners();
  }

  void setConnectionMode(ConnectionMode mode) {
    connectionMode = mode;
    notifyListeners();
  }

  Future<void> selectRoom(Room room) async {
    // Leave the previous room's SignalR group
    if (activeRoom != null && activeRoom!.id != room.id) {
      await pttController.leaveRoom();
    }

    activeRoom = room;
    await pttController.joinRoom(room.id);
    notifyListeners();
  }

  Future<bool> searchRoom(String roomId) async {
    searchedRoom = null;
    _roomSearchCompleter?.complete(false);
    final completer = Completer<bool>();
    _roomSearchCompleter = completer;

    // Ensure SignalR is connected
    if (signalRService.status != HubConnectionStatus.connected) {
      try {
        await signalRService.connect();
      } catch (e) {
        debugPrint('[AppState] SignalR connect attempt before search: $e');
      }
    }

    try {
      await signalRService.searchRoom(roomId, currentUser.deviceId);
    } catch (e) {
      debugPrint('[AppState] SignalR searchRoom error: $e');
    }

    // Try SignalR first (up to 3 seconds)
    try {
      final foundViaSignalR = await completer.future.timeout(const Duration(seconds: 3));
      if (foundViaSignalR && searchedRoom != null) {
        return true;
      }
    } catch (_) {}

    // Fallback: Check via REST API if SignalR response didn't arrive
    try {
      final restRoom = await _roomApi.getRoomById(roomId);
      if (restRoom != null) {
        searchedRoom = restRoom;
        _roomSearchCompleter = null;
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('[AppState] REST getRoomById fallback note: $e');
    }

    _roomSearchCompleter = null;
    notifyListeners();
    return false;
  }

  Future<void> sendJoinRequest(String roomId) {
    return signalRService.requestJoin(roomId, currentUser.deviceId, currentUser.callSign);
  }

  Future<void> approveJoinRequest(String roomId, String requesterId) async {
    _removeIncomingRequest(roomId, requesterId);
    await signalRService.approveJoin(roomId, currentUser.deviceId, requesterId);
  }

  Future<void> declineJoinRequest(String roomId, String requesterId) async {
    _removeIncomingRequest(roomId, requesterId);
    await signalRService.declineJoin(roomId, currentUser.deviceId, requesterId);
  }

  void _removeIncomingRequest(String roomId, String requesterId) {
    incomingJoinRequests.removeWhere((request) => request.roomId == roomId && request.requesterDeviceId == requesterId);
    notifyListeners();
  }

  Future<void> joinApprovedRoom(Room room) async {
    Room? existing;
    for (final candidate in rooms) {
      if (candidate.id == room.id) {
        existing = candidate;
        break;
      }
    }
    if (existing != null) {
      await selectRoom(existing);
      return;
    }
    final joinedRoom = Room(
      id: room.id, name: room.name, type: room.type, creatorName: room.creatorName,
      createdDate: room.createdDate, memberCount: room.memberCount,
      members: [RoomMember(
        id: 'member_${room.id}_${currentUser.deviceId}', name: '${currentUser.callSign} (You)', deviceId: currentUser.deviceId,
      )],
      raisedHands: [],
    );
    rooms.insert(0, joinedRoom);
    await selectRoom(joinedRoom);
  }

  // ─────────────────────────────────────────────────────────────────
  // PTT Actions — delegate to PttController
  // ─────────────────────────────────────────────────────────────────

  Future<void> pressPtt() async {
    await pttController.pressPtt();
  }

  Future<void> releasePtt() async {
    await pttController.releasePtt();
  }

  Future<void> toggleRaiseHand() async {
    if (pttController.isHandRaised) {
      await pttController.cancelHand();
    } else {
      await pttController.raiseHand();
    }
    notifyListeners();
  }

  Future<void> giveFloorTo(RaisedHand hand) async {
    await pttController.giveFloor(hand);
    // Remove from local seed list too
    activeRoom?.raisedHands.removeWhere((rh) => rh.id == hand.id);
    await _roomRepo.resolveRaisedHand(hand.id, 'GRANTED');
    notifyListeners();
  }

  void releaseSpeakerFloor() {
    // Used by the "simulate Rahul speaking" demo flow
    if (activeRoom != null) {
      activeRoom!.activeSpeaker = null;
      for (var m in activeRoom!.members) {
        m.isSpeaking = false;
      }
    }
    _stopWaveSimulation();
    notifyListeners();
  }

  /// Demo-mode only: simulate a remote speaker without a real SignalR connection.
  void simulateSpeaker(String callsign) {
    if (activeRoom != null) {
      activeRoom!.activeSpeaker = callsign;
      for (var m in activeRoom!.members) {
        m.isSpeaking = m.name.contains(callsign);
      }
    }
    _startWaveSimulation();
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────
  // Member Moderation
  // ─────────────────────────────────────────────────────────────────

  void toggleMemberMute(RoomMember member) {
    member.isMuted = !member.isMuted;
    notifyListeners();
  }

  void toggleMemberRole(RoomMember member) {
    if (member.role == MemberRole.member) {
      member.role = MemberRole.moderator;
    } else if (member.role == MemberRole.moderator) {
      member.role = MemberRole.member;
    }
    notifyListeners();
  }

  Future<void> removeMember(RoomMember member) async {
    if (activeRoom != null) {
      activeRoom!.members.removeWhere((m) => m.id == member.id);
      activeRoom!.memberCount = activeRoom!.members.length;
      await _roomRepo.removeMember(member.id);
    }
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────
  // Room Creation
  // ─────────────────────────────────────────────────────────────────

  Future<void> createNewRoom({
    required String name,
    required RoomType type,
    required bool approvalRequired,
    required bool meshFallback,
  }) async {
    Room newRoom;
    try {
      newRoom = await _roomApi.createRoom(
        name: name,
        type: type,
        approvalRequired: approvalRequired,
        meshFallback: meshFallback,
        creatorDeviceId: currentUser.deviceId,
        creatorName: currentUser.callSign,
      ).timeout(const Duration(seconds: 3));
    } catch (e) {
      debugPrint('[AppState] createRoom API call failed ($e), generating room locally');
      final roomId = 'CX-${10000 + Random().nextInt(89999)}';
      newRoom = Room(
        id: roomId,
        name: name,
        type: type,
        creatorName: currentUser.callSign,
        createdDate: 'Today',
        memberCount: 1,
        isLive: true,
        approvalRequired: approvalRequired,
        meshFallback: meshFallback,
        isUserCreator: true,
        members: [
          RoomMember(
            id: 'creator_$roomId',
            name: '${currentUser.callSign} (You)',
            role: MemberRole.creator,
            deviceId: currentUser.deviceId,
            isOnline: true,
          ),
        ],
        raisedHands: [],
      );
    }

    try {
      await _roomRepo.insertRoom(newRoom, currentUser.deviceId);
    } catch (e) {
      debugPrint('[AppState] insertRoom local DB note: $e');
    }

    try {
      await _syncRepo.enqueueDelta(
        entityType: 'ROOM',
        entityId: newRoom.id,
        operation: 'INSERT',
        payload: {
          'name': newRoom.name,
          'type': newRoom.type.name,
          'creator': currentUser.deviceId,
        },
      );
    } catch (e) {
      debugPrint('[AppState] syncRepo note: $e');
    }

    rooms.removeWhere((r) => r.id == newRoom.id);
    rooms.insert(0, newRoom);
    await selectRoom(newRoom);
    notifyListeners();

    try {
      await signalRService.registerRoomCreator(newRoom.id, currentUser.deviceId, newRoom.name, currentUser.callSign);
    } catch (e) {
      debugPrint('[AppState] registerRoomCreator note: $e');
    }
  }

  void sendEmergencyAlert(String details) {
    AudioFeedbackService.emergencyAlert();
    pttController.sendEmergencyAlert(
      activeRoom?.id ?? 'global',
      currentUser.deviceId,
      details.isEmpty ? 'Distress trigger sent' : details,
    );
    final alert = AlertItem(
      id: 'em_${DateTime.now().millisecondsSinceEpoch}',
      title: '🚨 EMERGENCY ALERT BROADCAST',
      message: details.isEmpty ? 'Distress trigger sent to Security and Medical responders' : details,
      roomName: activeRoom?.name ?? 'Global Priority',
      timeAgo: 'Just now',
      type: AlertType.emergency,
    );
    alerts.insert(0, alert);
    notifyListeners();
  }

  Future<void> updateProfileName(String newName, String newTeam) async {
    final cleanName = newName.trim().isEmpty ? 'Operator' : newName.trim();
    final cleanTeam = newTeam.trim().isEmpty ? 'General Unit' : newTeam.trim();

    currentUser.callSign = cleanName;
    currentUser.team = cleanTeam;

    if (deviceIdentity != null) {
      deviceIdentity!.displayName = cleanName;
      deviceIdentity!.unitOrTeam = cleanTeam;
      deviceIdentity!.isConfigured = true;
      await DeviceIdentityService.saveIdentity(deviceIdentity!);
    }

    notifyListeners();
  }

  void _startWaveSimulation() {
    _waveSimulationTimer?.cancel();
    final rnd = Random();
    _waveSimulationTimer = Timer.periodic(const Duration(milliseconds: 90), (_) {
      waveAmplitudes = List.generate(16, (index) => 0.3 + 0.7 * rnd.nextDouble());
      notifyListeners();
    });
  }

  void _stopWaveSimulation() {
    _waveSimulationTimer?.cancel();
    _waveSimulationTimer = null;
    waveAmplitudes = List.generate(16, (_) => 0.08);
    notifyListeners();
  }

  @override
  void dispose() {
    _stopWaveSimulation();
    _hubStatusSubscription?.cancel();
    pttController.removeListener(_onPttControllerChanged);
    pttController.dispose();
    voiceService.dispose();
    signalRService.dispose();
    super.dispose();
  }
}
