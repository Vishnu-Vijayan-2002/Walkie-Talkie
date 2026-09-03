enum RoomType { general, event, hospital, school, fieldTeam }

enum MemberRole { creator, moderator, member }

enum AlertType { emergency, speakingRequest, roomEvent }

enum PttState {
  idle,             // Floor available: "HOLD TO TALK"
  requesting,       // Floor request pending: "REQUESTING..."
  speaking,         // Floor granted & transmitting: "SPEAKING - RELEASE TO STOP"
  floorBusy,        // Someone else is speaking: "Rahul is speaking"
  denied,           // Speaking unavailable / queue full
  offlineNearby,    // P2P Offline Mesh: "OFFLINE MODE - NEARBY COMM"
}

enum ConnectionMode {
  online,                // 🟢 ONLINE (Internet Connected)
  connecting,            // 🔄 CONNECTING
  offline,               // 🟠 OFFLINE
  offlineNearbyMesh,     // 🟠 OFFLINE • 📡 NEARBY AVAILABLE
}

class UserProfile {
  final String deviceId;
  String callSign;
  String team;
  bool micEnabled;
  bool speakerEnabled;
  bool bluetoothConnected;
  double voiceSensitivity;
  double speakerVolume;

  UserProfile({
    required this.deviceId,
    required this.callSign,
    required this.team,
    this.micEnabled = true,
    this.speakerEnabled = true,
    this.bluetoothConnected = false,
    this.voiceSensitivity = 0.65,
    this.speakerVolume = 0.85,
  });
}

class RoomMember {
  final String id;
  final String name;
  MemberRole role;
  bool isOnline;
  bool isMuted;
  bool isSpeaking;
  final String deviceId;

  RoomMember({
    required this.id,
    required this.name,
    this.role = MemberRole.member,
    this.isOnline = true,
    this.isMuted = false,
    this.isSpeaking = false,
    required this.deviceId,
  });
}

class RaisedHand {
  final String id;
  final String memberId;
  final String memberName;
  final DateTime requestedAt;

  RaisedHand({
    required this.id,
    required this.memberId,
    required this.memberName,
    required this.requestedAt,
  });

  String get formattedWaitTime {
    final diff = DateTime.now().difference(requestedAt);
    final minutes = diff.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = diff.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class AlertItem {
  final String id;
  final String title;
  final String message;
  final String roomName;
  final String timeAgo;
  final AlertType type;

  AlertItem({
    required this.id,
    required this.title,
    required this.message,
    required this.roomName,
    required this.timeAgo,
    required this.type,
  });
}

class Room {
  final String id;
  final String name;
  final RoomType type;
  final String creatorName;
  final String createdDate;
  int memberCount;
  bool isLive;
  String? activeSpeaker;
  bool approvalRequired;
  bool meshFallback;
  bool isUserCreator;
  List<RoomMember> members;
  List<RaisedHand> raisedHands;

  Room({
    required this.id,
    required this.name,
    required this.type,
    required this.creatorName,
    required this.createdDate,
    required this.memberCount,
    this.isLive = true,
    this.activeSpeaker,
    this.approvalRequired = true,
    this.meshFallback = true,
    this.isUserCreator = false,
    required this.members,
    required this.raisedHands,
  });

  String get iconEmoji {
    switch (type) {
      case RoomType.event:
        return '🚨';
      case RoomType.hospital:
        return '🏥';
      case RoomType.school:
        return '🏫';
      case RoomType.fieldTeam:
        return '👥';
      case RoomType.general:
        return '📻';
    }
  }

  String get typeLabel {
    switch (type) {
      case RoomType.event:
        return 'Event Security';
      case RoomType.hospital:
        return 'Hospital Emergency';
      case RoomType.school:
        return 'School Facility';
      case RoomType.fieldTeam:
        return 'Field Operations';
      case RoomType.general:
        return 'General Tactical';
    }
  }
}
