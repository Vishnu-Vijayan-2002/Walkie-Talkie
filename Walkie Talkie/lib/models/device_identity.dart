import 'dart:convert';
import 'package:crypto/crypto.dart';

class DeviceIdentity {
  final String deviceUuid;
  final String hardwareCallsign; // Auto-generated unique hardware code e.g. "CX-A91B4"
  final String publicKeyFingerprint;
  final DateTime createdTimestamp;
  String displayName;
  String unitOrTeam;
  bool isConfigured;

  DeviceIdentity({
    required this.deviceUuid,
    required this.hardwareCallsign,
    required this.publicKeyFingerprint,
    required this.createdTimestamp,
    this.displayName = '',
    this.unitOrTeam = 'General Team',
    this.isConfigured = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'deviceUuid': deviceUuid,
      'hardwareCallsign': hardwareCallsign,
      'publicKeyFingerprint': publicKeyFingerprint,
      'createdTimestamp': createdTimestamp.toIso8601String(),
      'displayName': displayName,
      'unitOrTeam': unitOrTeam,
      'isConfigured': isConfigured,
    };
  }

  factory DeviceIdentity.fromJson(Map<String, dynamic> json) {
    return DeviceIdentity(
      deviceUuid: json['deviceUuid'] as String,
      hardwareCallsign: json['hardwareCallsign'] as String,
      publicKeyFingerprint: json['publicKeyFingerprint'] as String,
      createdTimestamp: DateTime.parse(json['createdTimestamp'] as String),
      displayName: json['displayName'] as String? ?? '',
      unitOrTeam: json['unitOrTeam'] as String? ?? 'General Team',
      isConfigured: json['isConfigured'] as bool? ?? false,
    );
  }

  static String generateFingerprint(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 16).toUpperCase();
  }
}
