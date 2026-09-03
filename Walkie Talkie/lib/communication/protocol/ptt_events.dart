import 'dart:convert';

/// Strict Wire Protocol Messages for ConnectX Floor Control Signaling
enum PttEventType {
  floorRequest,     // Operator presses PTT to ask for floor
  floorGranted,     // Server/Mesh grants floor token to operator
  floorBusy,        // Server/Mesh notifies room that an operator is speaking
  floorReleased,    // Operator releases PTT or transmission expires
  floorDenied,      // Request rejected (floor locked or speaking collision)
  raiseHand,        // Operator asks to join speaking queue
  cancelRaiseHand,  // Operator cancels hand raise
  giveFloor,        // Moderator gives floor to a queued operator
  emergencyAlert,   // High-priority override distress alert
  peerHeartbeat,    // Mesh / WebSocket peer presence ping
}

class PttEventMessage {
  final PttEventType type;
  final String roomId;
  final String senderDeviceId;
  final String senderCallsign;
  final String? targetDeviceId;
  final String? floorToken;
  final int timestampEpochMs;
  final Map<String, dynamic> metadata;

  // Floor denial context
  final String? deniedReason;

  // Hand-raise queue position
  final int? queuePosition;

  PttEventMessage({
    required this.type,
    required this.roomId,
    required this.senderDeviceId,
    required this.senderCallsign,
    this.targetDeviceId,
    this.floorToken,
    required this.timestampEpochMs,
    this.metadata = const {},
    this.deniedReason,
    this.queuePosition,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'roomId': roomId,
      'senderDeviceId': senderDeviceId,
      'senderCallsign': senderCallsign,
      'targetDeviceId': targetDeviceId,
      'floorToken': floorToken,
      'timestampEpochMs': timestampEpochMs,
      'metadata': metadata,
    };
  }

  factory PttEventMessage.fromJson(Map<String, dynamic> json) {
    return PttEventMessage(
      type: PttEventType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => PttEventType.peerHeartbeat,
      ),
      roomId: json['roomId'] as String,
      senderDeviceId: json['senderDeviceId'] as String,
      senderCallsign: json['senderCallsign'] as String,
      targetDeviceId: json['targetDeviceId'] as String?,
      floorToken: json['floorToken'] as String?,
      timestampEpochMs: json['timestampEpochMs'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? {},
    );
  }

  String toRawWireString() => jsonEncode(toJson());

  static PttEventMessage fromRawWireString(String raw) {
    return PttEventMessage.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }
}
