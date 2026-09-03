import 'dart:convert';
import 'dart:io';
import '../models/models.dart';
import '../models/device_identity.dart';

/// REST access for durable room data. SignalR is used only for live events.
class RoomApiService {
  static const _baseUrl = 'http://10.120.69.98:5211/api/v1';

  Future<void> provisionDevice(DeviceIdentity identity) async {
    await _request('POST', '/devices/provision', {
      'deviceId': identity.hardwareCallsign,
      'hardwareCallsign': identity.hardwareCallsign,
      'displayName': identity.displayName.isEmpty ? identity.hardwareCallsign : identity.displayName,
      'publicKey': identity.publicKeyFingerprint,
      'unitTeam': identity.unitOrTeam,
    });
  }

  Future<List<Room>> getRooms(String deviceId) async {
    final response = await _request('GET', '/rooms?deviceId=${Uri.encodeQueryComponent(deviceId)}');
    final records = jsonDecode(response) as List<dynamic>;
    return records.map((record) {
      final data = record as Map<String, dynamic>;
      final typeValue = data['type'];
      final typeIndex = typeValue is int ? typeValue : 0;
      return Room(
        id: data['roomId'] as String,
        name: data['name'] as String,
        type: RoomType.values[typeIndex.clamp(0, RoomType.values.length - 1)],
        creatorName: (data['creatorDeviceId'] as String?) ?? 'Commander',
        createdDate: (data['createdAt'] as String?) ?? 'Today',
        memberCount: (data['memberCount'] as num?)?.toInt() ?? 0,
        isLive: data['status'] == 'ACTIVE',
        approvalRequired: data['visibility'] != 0,
        meshFallback: data['isMeshFallback'] as bool? ?? true,
        isUserCreator: data['creatorDeviceId'] == deviceId,
        members: [],
        raisedHands: [],
      );
    }).toList();
  }

  Future<Room> createRoom({
    required String name,
    required RoomType type,
    required bool approvalRequired,
    required bool meshFallback,
    required String creatorDeviceId,
    required String creatorName,
  }) async {
    final response = await _request('POST', '/rooms', {
      'name': name,
      'type': type.index,
      'visibility': approvalRequired ? 1 : 0,
      'communicationMode': 2,
      'creatorDeviceId': creatorDeviceId,
      'isMeshFallback': meshFallback,
    });
    final data = jsonDecode(response) as Map<String, dynamic>;
    final roomId = data['roomId'] as String;
    return Room(
      id: roomId, name: name, type: type, creatorName: creatorName,
      createdDate: 'Today', memberCount: 1, approvalRequired: approvalRequired,
      meshFallback: meshFallback, isUserCreator: true,
      members: [RoomMember(id: 'creator_$roomId', name: '$creatorName (You)', role: MemberRole.creator, deviceId: creatorDeviceId)],
      raisedHands: [],
    );
  }

  Future<Room?> getRoomById(String roomId) async {
    try {
      final response = await _request('GET', '/rooms/${Uri.encodeComponent(roomId)}');
      final data = jsonDecode(response) as Map<String, dynamic>;
      final typeValue = data['type'];
      final typeIndex = typeValue is int ? typeValue : 0;
      final membersList = (data['members'] as List<dynamic>?) ?? [];
      return Room(
        id: data['roomId'] as String,
        name: data['name'] as String,
        type: RoomType.values[typeIndex.clamp(0, RoomType.values.length - 1)],
        creatorName: (data['creatorDeviceId'] as String?) ?? 'Commander',
        createdDate: (data['createdAt'] as String?) ?? 'Today',
        memberCount: (data['memberCount'] as num?)?.toInt() ?? membersList.length.clamp(1, 999),
        isLive: data['status'] == 'ACTIVE',
        approvalRequired: data['visibility'] != 0,
        meshFallback: data['isMeshFallback'] as bool? ?? true,
        isUserCreator: false,
        members: [],
        raisedHands: [],
      );
    } catch (e) {
      return null;
    }
  }

  Future<String> _request(String method, String path, [Map<String, dynamic>? body]) async {
    final client = HttpClient();
    try {
      final request = await client.openUrl(method, Uri.parse('$_baseUrl$path'));
      request.headers.contentType = ContentType.json;
      if (body != null) request.write(jsonEncode(body));
      final response = await request.close();
      final responseBody = await utf8.decodeStream(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('Server returned ${response.statusCode}: $responseBody');
      }
      return responseBody;
    } finally {
      client.close(force: true);
    }
  }
}
