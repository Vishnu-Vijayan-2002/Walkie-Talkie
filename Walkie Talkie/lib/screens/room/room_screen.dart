import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import 'members_screen.dart';
import 'raised_hands_sheet.dart';
import 'room_settings_screen.dart';
import 'widgets/ptt_button.dart';
import 'widgets/raise_hand_button.dart';
import 'widgets/speaker_display.dart';
import 'widgets/waveform_visualizer.dart';

class RoomScreen extends StatefulWidget {
  final AppState state;

  const RoomScreen({
    super.key,
    required this.state,
  });

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final room = state.activeRoom;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (room == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('NO ACTIVE ROOM'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.meeting_room_outlined, size: 64, color: AppColors.textMutedDark),
                const SizedBox(height: 16),
                const Text(
                  'No room currently active',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please select an existing room or create a new one from Home.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMutedDark),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.home_rounded),
                  label: const Text('GO TO HOME'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isOfflineMesh = state.connectionMode == ConnectionMode.offlineNearbyMesh;
    final isUserTransmitting = state.pttState == PttState.speaking;
    final isSomeoneSpeaking = state.currentSpeakerName != null;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  room.iconEmoji,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    room.name.toUpperCase(),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(
                  Icons.circle,
                  color: isOfflineMesh ? AppColors.meshAmber : AppColors.liveGreen,
                  size: 8,
                ),
                const SizedBox(width: 6),
                Text(
                  isOfflineMesh
                      ? 'Offline • Nearby Available (${state.nearbyPeerCount} peers)'
                      : 'Online • ${room.memberCount} members',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isOfflineMesh ? AppColors.meshAmber : AppColors.liveGreen,
                  ),
                ),
                Text(
                  ' • ${room.id}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.tacticalBlueLight,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Copy Room ID button
          IconButton(
            tooltip: 'Copy Room ID (${room.id})',
            icon: const Icon(Icons.copy_rounded, size: 20),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: room.id));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Room ID copied: ${room.id}'),
                  backgroundColor: AppColors.liveGreen,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
          // Room Creator / Settings Menu (⋮)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            color: isDark ? AppColors.surfaceDarkElevated : AppColors.surfaceLight,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            onSelected: (value) {
              if (value == 'settings') {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (ctx) => RoomSettingsScreen(state: state),
                  ),
                );
              } else if (value == 'members') {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (ctx) => MembersScreen(state: state),
                  ),
                );
              } else if (value == 'raised_hands') {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (ctx) => RaisedHandsSheet(state: state),
                );
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings_outlined, size: 20),
                    SizedBox(width: 12),
                    Text('Room Settings & Safety', style: TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'members',
                child: Row(
                  children: [
                    Icon(Icons.people_outline_rounded, size: 20),
                    SizedBox(width: 12),
                    Text('Members Roster', style: TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'raised_hands',
                child: Row(
                  children: [
                    const Icon(Icons.pan_tool_outlined, size: 20),
                    const SizedBox(width: 12),
                    Text('Raised Hands (${room.raisedHands.length})', style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          decoration: BoxDecoration(
            // Glowing perimeter boundary when transmitting or receiving
            border: Border.all(
              color: isUserTransmitting
                  ? AppColors.liveGreen
                  : (isSomeoneSpeaking
                      ? AppColors.emergencyRed.withValues(alpha: 0.6)
                      : Colors.transparent),
              width: (isUserTransmitting || isSomeoneSpeaking) ? 3.0 : 0.0,
            ),
          ),
          child: Column(
            children: [
              // Screen 10 Offline Mesh Banner (if applicable)
              if (isOfflineMesh) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: AppColors.meshAmber.withValues(alpha: 0.15),
                  child: Row(
                    children: [
                      const Icon(Icons.wifi_tethering_rounded, color: AppColors.meshAmber, size: 18),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'OFFLINE MODE: Direct Hardware Mesh Active',
                          style: TextStyle(
                            color: AppColors.meshAmber,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.meshAmber.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${state.nearbyPeerCount} LOCAL PEERS',
                          style: const TextStyle(
                            color: AppColors.meshAmber,
                            fontWeight: FontWeight.w900,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Main Communication Console Body
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Current Speaker Section
                      SpeakerDisplay(
                        speakerName: state.currentSpeakerName,
                        isSpeaking: isSomeoneSpeaking || isUserTransmitting,
                        isCurrentUser: isUserTransmitting,
                      ),

                      // Real-time Audio Waveform Visualizer
                      WaveformVisualizer(
                        amplitudes: state.waveAmplitudes,
                        isActive: isUserTransmitting || isSomeoneSpeaking,
                        activeColor: isUserTransmitting
                            ? AppColors.liveGreen
                            : (isOfflineMesh ? AppColors.meshAmber : AppColors.emergencyRed),
                      ),

                      // Massive PTT Centerpiece Button
                      PttButton(
                        state: state,
                        onPressed: state.pressPtt,
                        onReleased: state.releasePtt,
                      ),

                      // Raise Hand Button (One-tap floor request)
                      RaiseHandButton(
                        isHandRaised: state.isHandRaised,
                        onTap: state.toggleRaiseHand,
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Console Navigation Bar: Members & Raised Hands Quick Glance
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDarkElevated : AppColors.surfaceLightElevated,
                  border: Border(
                    top: BorderSide(
                      color: isDark ? AppColors.surfaceDarkBorder : AppColors.surfaceLightBorder,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Members Count Badge (Tappable to open roster)
                    InkWell(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (ctx) => MembersScreen(state: state),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.people_outline_rounded, size: 18, color: AppColors.liveGreen),
                            const SizedBox(width: 8),
                            Text(
                              'Members  ${room.memberCount}',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Raised Hands Queue Badge (Tappable to open queue)
                    InkWell(
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (ctx) => RaisedHandsSheet(state: state),
                        );
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: room.raisedHands.isNotEmpty
                              ? AppColors.meshAmber.withValues(alpha: 0.2)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: room.raisedHands.isNotEmpty
                              ? Border.all(color: AppColors.meshAmber.withValues(alpha: 0.5))
                              : null,
                        ),
                        child: Row(
                          children: [
                            const Text('✋', style: TextStyle(fontSize: 14)),
                            const SizedBox(width: 6),
                            Text(
                              'Raised hands  ${room.raisedHands.length}',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: room.raisedHands.isNotEmpty
                                    ? AppColors.meshAmber
                                    : (isDark ? AppColors.textWhite : AppColors.textDark),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
