import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../state/app_state.dart';

class RoomSettingsScreen extends StatefulWidget {
  final AppState state;

  const RoomSettingsScreen({
    super.key,
    required this.state,
  });

  @override
  State<RoomSettingsScreen> createState() => _RoomSettingsScreenState();
}

class _RoomSettingsScreenState extends State<RoomSettingsScreen> {
  bool _speakingRuleApproval = true;
  bool _offlineMeshEnabled = true;
  bool _loudnessBoost = true;

  void _showEmergencyConfirmDialog(BuildContext context) {
    final state = widget.state;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final TextEditingController detailsCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppColors.emergencyRed, width: 2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: AppColors.emergencyRed.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.emergencyRed, width: 2),
                  ),
                  child: const Center(
                    child: Icon(Icons.warning_amber_rounded, color: AppColors.emergencyRed, size: 36),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'SEND EMERGENCY ALERT?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    color: AppColors.emergencyRed,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'This will immediately override active channels and broadcast high-priority distress alerts to Security, Medical Responders, and Incident Command.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: detailsCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Optional distress details (e.g. Gate 4 Medical)',
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('CANCEL'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          state.sendEmergencyAlert(detailsCtrl.text.trim());
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('🚨 Emergency alert broadcasted successfully!'),
                              backgroundColor: AppColors.emergencyRed,
                              duration: Duration(seconds: 4),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.emergencyRed),
                        child: const Text('BROADCAST', style: TextStyle(fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final room = state.activeRoom;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (room == null) return const Scaffold();

    return Scaffold(
      appBar: AppBar(
        title: const Text('ROOM SETTINGS & INFO'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? AppColors.surfaceDarkBorder : AppColors.surfaceLightBorder,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ROOM INFORMATION',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: AppColors.textMutedDark,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildInfoRow('Room Name', room.name, isDark),
                    const Divider(height: 18),
                    _buildInfoRow('Room ID', room.id, isDark, isMonospace: true),
                    const Divider(height: 18),
                    _buildInfoRow('Creator', room.creatorName, isDark),
                    const Divider(height: 18),
                    _buildInfoRow('Active Members', '${room.memberCount} operators', isDark),
                    const Divider(height: 18),
                    _buildInfoRow('Created', room.createdDate, isDark),
                    const Divider(height: 18),
                    _buildInfoRow('Transports', 'Internet Uplink + Offline Mesh', isDark),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Invitation link for ${room.name} copied!'),
                      backgroundColor: AppColors.liveGreen,
                    ),
                  );
                },
                icon: const Icon(Icons.share_outlined, size: 20),
                label: const Text('Share Room Invitation', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 28),

              const Text(
                'SPEAKING RULES & PERMISSIONS',
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
                    SwitchListTile(
                      title: const Text('Moderator Floor Approval', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      subtitle: const Text('Require operators to raise hand before speaking', style: TextStyle(fontSize: 12, color: AppColors.textMutedDark)),
                      value: _speakingRuleApproval,
                      activeTrackColor: AppColors.liveGreen,
                      onChanged: (val) => setState(() => _speakingRuleApproval = val),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      title: const Text('Nearby Offline Mesh Fallback', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      subtitle: const Text('Auto-connect peer hardware when Internet drops', style: TextStyle(fontSize: 12, color: AppColors.textMutedDark)),
                      value: _offlineMeshEnabled,
                      activeTrackColor: AppColors.meshAmber,
                      onChanged: (val) => setState(() => _offlineMeshEnabled = val),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      title: const Text('Loudness Boost & Compression', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      subtitle: const Text('Enhanced clarity for noisy outdoor environments', style: TextStyle(fontSize: 12, color: AppColors.textMutedDark)),
                      value: _loudnessBoost,
                      activeTrackColor: AppColors.tacticalBlueLight,
                      onChanged: (val) => setState(() => _loudnessBoost = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              const Text(
                'TACTICAL SAFETY OVERRIDE',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: AppColors.emergencyRed,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.emergencyRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.emergencyRed.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: AppColors.emergencyRed, size: 22),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Emergency Broadcast Protocol',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.emergencyRed),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Dedicated safeguarded trigger with confirmation to prevent accidental activation.',
                      style: TextStyle(fontSize: 12, color: AppColors.textMutedDark),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      onPressed: () => _showEmergencyConfirmDialog(context),
                      icon: const Icon(Icons.sos_rounded, size: 22),
                      label: const Text('TRIGGER EMERGENCY DISTRESS', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.8)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.emergencyRed,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              ElevatedButton.icon(
                onPressed: () {
                  final nav = Navigator.of(context);
                  if (nav.canPop()) nav.pop();
                  if (nav.canPop()) nav.pop();
                },
                icon: const Icon(Icons.exit_to_app_rounded),
                label: const Text('EXIT CHANNEL'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? AppColors.surfaceDarkElevated : AppColors.surfaceLightElevated,
                  foregroundColor: isDark ? AppColors.textWhite : AppColors.textDark,
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, bool isDark, {bool isMonospace = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            fontFamily: isMonospace ? 'monospace' : null,
          ),
        ),
      ],
    );
  }
}
