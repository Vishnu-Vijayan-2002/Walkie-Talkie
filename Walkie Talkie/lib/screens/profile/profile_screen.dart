import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../state/app_state.dart';

class ProfileScreen extends StatefulWidget {
  final AppState state;

  const ProfileScreen({
    super.key,
    required this.state,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.state.currentUser.callSign);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final user = state.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('OPERATOR CONSOLE & AUDIO'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Identity Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark ? AppColors.surfaceDarkBorder : AppColors.surfaceLightBorder,
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppColors.tacticalBlue.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.tacticalBlueLight, width: 2),
                      ),
                      child: const Center(
                        child: Icon(Icons.person_rounded, size: 40, color: AppColors.tacticalBlueLight),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      user.callSign,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.team,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surfaceDarkElevated : AppColors.surfaceLightElevated,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'DEVICE ID: ${user.deviceId}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, fontFamily: 'monospace', letterSpacing: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // AUDIO SETTINGS
              const Text(
                'AUDIO HARDWARE SETTINGS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: AppColors.textMutedDark,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? AppColors.surfaceDarkBorder : AppColors.surfaceLightBorder,
                  ),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Microphone Input', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      subtitle: const Text('Hardware mic & hardware PTT key sync', style: TextStyle(fontSize: 12, color: AppColors.textMutedDark)),
                      value: user.micEnabled,
                      activeTrackColor: AppColors.liveGreen,
                      onChanged: (val) => setState(() => user.micEnabled = val),
                    ),
                    const Divider(),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Speaker Output', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      subtitle: const Text('Tactical loudness output buffer', style: TextStyle(fontSize: 12, color: AppColors.textMutedDark)),
                      value: user.speakerEnabled,
                      activeTrackColor: AppColors.liveGreen,
                      onChanged: (val) => setState(() => user.speakerEnabled = val),
                    ),
                    const Divider(),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.bluetooth_audio_rounded, color: AppColors.tacticalBlueLight),
                      title: const Text('Tactical Bluetooth Headset', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      subtitle: const Text('Connected • PTT Trigger Supported', style: TextStyle(fontSize: 12, color: AppColors.liveGreen, fontWeight: FontWeight.bold)),
                      trailing: const Icon(Icons.check_circle_rounded, color: AppColors.liveGreen, size: 20),
                    ),
                    const Divider(),
                    const SizedBox(height: 8),

                    // Voice Sensitivity Slider
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Voice Sensitivity', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        Text('${(user.voiceSensitivity * 100).toInt()}%', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.liveGreen)),
                      ],
                    ),
                    Slider(
                      value: user.voiceSensitivity,
                      activeColor: AppColors.liveGreen,
                      onChanged: (val) => setState(() => user.voiceSensitivity = val),
                    ),

                    // Speaker Volume Slider
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Speaker Volume', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        Text('${(user.speakerVolume * 100).toInt()}%', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.tacticalBlueLight)),
                      ],
                    ),
                    Slider(
                      value: user.speakerVolume,
                      activeColor: AppColors.tacticalBlueLight,
                      onChanged: (val) => setState(() => user.speakerVolume = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // OFFLINE MESH SETTINGS & ABOUT
              const Text(
                'SYSTEM & PRIVACY',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: AppColors.textMutedDark,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? AppColors.surfaceDarkBorder : AppColors.surfaceLightBorder,
                  ),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.wifi_tethering_rounded, color: AppColors.meshAmber),
                      title: const Text('Offline Mesh Transceiver', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      subtitle: const Text('P2P Direct BLE + Wi-Fi Direct', style: TextStyle(fontSize: 12, color: AppColors.textMutedDark)),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.meshAmber.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('3 PEERS', style: TextStyle(color: AppColors.meshAmber, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.security_rounded),
                      title: const Text('Encryption Protocol', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      subtitle: const Text('End-to-End ChaCha20-Poly1305', style: TextStyle(fontSize: 12, color: AppColors.textMutedDark)),
                      trailing: const Text('ACTIVE', style: TextStyle(color: AppColors.liveGreen, fontWeight: FontWeight.bold, fontSize: 11)),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.info_outline_rounded),
                      title: const Text('ConnectX App Version', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      subtitle: const Text('Build 1.0.0-PRO (Tactical Edition)', style: TextStyle(fontSize: 12, color: AppColors.textMutedDark)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
