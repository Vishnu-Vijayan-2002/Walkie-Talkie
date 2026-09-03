import 'package:sqflite/sqflite.dart';
import '../../models/models.dart';
import '../app_database.dart';

class RoomRepository {
  Future<List<Room>> getAllRooms() async {
    final db = await AppDatabase.database;
    final roomRows = await db.query('rooms', orderBy: 'created_at DESC');

    final List<Room> results = [];
    for (var rMap in roomRows) {
      final roomId = rMap['room_id'] as String;
      final members = await getRoomMembers(roomId);
      final raisedHands = await getRaisedHands(roomId);

      final typeStr = (rMap['type'] as String?)?.toLowerCase() ?? 'general';
      RoomType type;
      switch (typeStr) {
        case 'event':
          type = RoomType.event;
          break;
        case 'hospital':
          type = RoomType.hospital;
          break;
        case 'school':
          type = RoomType.school;
          break;
        case 'field_team':
        case 'fieldteam':
          type = RoomType.fieldTeam;
          break;
        default:
          type = RoomType.general;
          break;
      }

      results.add(
        Room(
          id: roomId,
          name: rMap['name'] as String,
          type: type,
          creatorName: (rMap['creator_device_id'] as String?) ?? 'Commander',
          createdDate: (rMap['created_at'] as String?) ?? 'Today',
          memberCount: members.length,
          isLive: (rMap['status'] as String?) == 'ACTIVE',
          approvalRequired: (rMap['visibility'] as String?) == 'PROTECTED',
          meshFallback: (rMap['is_mesh_fallback'] as int? ?? 1) == 1,
          members: members,
          raisedHands: raisedHands,
        ),
      );
    }
    return results;
  }

  Future<void> insertRoom(Room room, String creatorDeviceId) async {
    final db = await AppDatabase.database;
    await db.insert(
      'rooms',
      {
        'room_id': room.id,
        'organization_id': null,
        'name': room.name,
        'type': room.type.name,
        'visibility': room.approvalRequired ? 'PROTECTED' : 'OPEN',
        'creator_device_id': creatorDeviceId,
        'status': room.isLive ? 'ACTIVE' : 'IDLE',
        'is_mesh_fallback': room.meshFallback ? 1 : 0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'sync_status': 'PENDING',
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    for (var m in room.members) {
      await insertMember(room.id, m);
    }
  }

  Future<List<RoomMember>> getRoomMembers(String roomId) async {
    final db = await AppDatabase.database;
    final rows = await db.query('room_members', where: 'room_id = ?', whereArgs: [roomId]);

    return rows.map((row) {
      final roleStr = (row['role'] as String?)?.toLowerCase() ?? 'member';
      MemberRole role;
      if (roleStr == 'creator') {
        role = MemberRole.creator;
      } else if (roleStr == 'moderator') {
        role = MemberRole.moderator;
      } else {
        role = MemberRole.member;
      }

      return RoomMember(
        id: row['id'] as String,
        name: row['name'] as String,
        role: role,
        isOnline: (row['status'] as String?) == 'ONLINE',
        isMuted: (row['is_muted'] as int? ?? 0) == 1,
        isSpeaking: (row['is_speaking'] as int? ?? 0) == 1,
        deviceId: row['device_id'] as String,
      );
    }).toList();
  }

  Future<void> insertMember(String roomId, RoomMember member) async {
    final db = await AppDatabase.database;
    await db.insert(
      'room_members',
      {
        'id': member.id,
        'room_id': roomId,
        'device_id': member.deviceId,
        'name': member.name,
        'role': member.role.name,
        'status': member.isOnline ? 'ONLINE' : 'OFFLINE',
        'is_muted': member.isMuted ? 1 : 0,
        'is_speaking': member.isSpeaking ? 1 : 0,
        'joined_at': DateTime.now().toIso8601String(),
        'last_active_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> removeMember(String memberId) async {
    final db = await AppDatabase.database;
    await db.delete('room_members', where: 'id = ?', whereArgs: [memberId]);
  }

  Future<List<RaisedHand>> getRaisedHands(String roomId) async {
    final db = await AppDatabase.database;
    final rows = await db.query(
      'raised_hands',
      where: 'room_id = ? AND status = ?',
      whereArgs: [roomId, 'WAITING'],
      orderBy: 'queue_position ASC',
    );

    return rows.map((row) {
      return RaisedHand(
        id: row['id'] as String,
        memberId: row['device_id'] as String,
        memberName: row['member_name'] as String,
        requestedAt: DateTime.tryParse(row['created_at'] as String) ?? DateTime.now(),
      );
    }).toList();
  }

  Future<void> insertRaisedHand(String roomId, RaisedHand hand, int position) async {
    final db = await AppDatabase.database;
    await db.insert(
      'raised_hands',
      {
        'id': hand.id,
        'room_id': roomId,
        'device_id': hand.memberId,
        'member_name': hand.memberName,
        'queue_position': position,
        'status': 'WAITING',
        'created_at': hand.requestedAt.toIso8601String(),
        'resolved_at': null,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> resolveRaisedHand(String handId, String status) async {
    final db = await AppDatabase.database;
    await db.update(
      'raised_hands',
      {
        'status': status,
        'resolved_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [handId],
    );
  }

  Future<void> recordSpeakingSession({
    required String roomId,
    required String deviceId,
    required String callsign,
    required String floorToken,
    required String transport,
    required DateTime startedAt,
    DateTime? endedAt,
    int durationMs = 0,
  }) async {
    final db = await AppDatabase.database;
    final id = 'session_${DateTime.now().millisecondsSinceEpoch}';
    await db.insert('speaking_sessions', {
      'id': id,
      'room_id': roomId,
      'device_id': deviceId,
      'speaker_callsign': callsign,
      'floor_token': floorToken,
      'transport': transport,
      'started_at': startedAt.toIso8601String(),
      'ended_at': endedAt?.toIso8601String(),
      'duration_ms': durationMs,
    });
  }
}
