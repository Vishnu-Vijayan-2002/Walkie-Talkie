import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/device_identity.dart';

class DeviceIdentityService {
  static const String _prefKey = 'connectx_device_identity_v1';
  static DeviceIdentity? _cachedIdentity;

  static Future<DeviceIdentity> getOrCreateIdentity() async {
    if (_cachedIdentity != null) {
      return _cachedIdentity!;
    }

    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_prefKey);

    if (jsonString != null) {
      try {
        final map = jsonDecode(jsonString) as Map<String, dynamic>;
        _cachedIdentity = DeviceIdentity.fromJson(map);
        return _cachedIdentity!;
      } catch (_) {
        // Fallthrough if corrupted
      }
    }

    // Generate fresh unique hardware UUID and tactical hardware callsign
    final random = Random.secure();
    final hexChars = List.generate(5, (_) => random.nextInt(16).toRadixString(16).toUpperCase()).join();
    final callsign = 'CX-$hexChars';
    
    final seed = '${DateTime.now().microsecondsSinceEpoch}_${random.nextDouble()}_$callsign';
    final fingerprint = DeviceIdentity.generateFingerprint(seed);
    final uuid = 'urn:cx:device:$fingerprint';

    final freshIdentity = DeviceIdentity(
      deviceUuid: uuid,
      hardwareCallsign: callsign,
      publicKeyFingerprint: fingerprint,
      createdTimestamp: DateTime.now(),
      displayName: '',
      unitOrTeam: 'General Unit',
      isConfigured: false,
    );

    await saveIdentity(freshIdentity);
    _cachedIdentity = freshIdentity;
    return freshIdentity;
  }

  static Future<void> saveIdentity(DeviceIdentity identity) async {
    _cachedIdentity = identity;
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(identity.toJson());
    await prefs.setString(_prefKey, jsonString);
  }
}
