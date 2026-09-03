import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../room/create_room_screen.dart';
import '../room/join_room_dialog.dart';
import '../room/search_room_screen.dart';
import '../room/room_screen.dart';
import 'widgets/room_card.dart';

class HomeScreen extends StatefulWidget {
  final AppState state;

  const HomeScreen({
    super.key,
    required this.state,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  RoomType? _selectedFilter;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = widget.state;
    final user = state.currentUser;

    final filteredRooms = _selectedFilter == null
        ? state.rooms
        : state.rooms.where((r) => r.type == _selectedFilter).toList();

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            setState(() {});
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Good morning, ${user.callSign}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user.team,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        // Test Invitation Dialog button
                        IconButton(
                          tooltip: 'Simulate Incoming Invitation',
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => JoinRoomDialog(
                                state: state,
                                inviterName: 'Lead Commander',
                                roomName: 'VIP Escort Security',
                                memberCount: 14,
                                onAccepted: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Joined "VIP Escort Security" successfully!'),
                                      backgroundColor: AppColors.liveGreen,
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                          icon: const Icon(Icons.mail_outline_rounded, size: 22),
                        ),
                        // Dark/Light Theme Toggle
                        IconButton(
                          tooltip: 'Toggle Console Theme',
                          onPressed: state.toggleTheme,
                          icon: Icon(
                            state.isDarkMode ? Icons.wb_sunny_outlined : Icons.nightlight_round,
                            size: 22,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Connection Status Card
                _buildConnectionStatusBanner(context, state, isDark),
                const SizedBox(height: 24),

                // Workspaces / Room Category Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All Channels', null, isDark),
                      const SizedBox(width: 8),
                      _buildFilterChip('🚨 Event', RoomType.event, isDark),
                      const SizedBox(width: 8),
                      _buildFilterChip('🏥 Hospital', RoomType.hospital, isDark),
                      const SizedBox(width: 8),
                      _buildFilterChip('🏫 School', RoomType.school, isDark),
                      const SizedBox(width: 8),
                      _buildFilterChip('👥 Field Ops', RoomType.fieldTeam, isDark),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Active Rooms Section Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'ACTIVE ROOMS',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: AppColors.textMutedDark,
                      ),
                    ),
                    Text(
                      '${filteredRooms.length} available',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMutedDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Rooms List
                if (filteredRooms.isEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(32),
                    alignment: Alignment.center,
                    child: Column(
                      children: [
                        const Icon(Icons.radio_button_off_rounded, size: 48, color: AppColors.textMutedDark),
                        const SizedBox(height: 12),
                        Text(
                          'No rooms in this category',
                          style: TextStyle(
                            color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  ...filteredRooms.map((room) {
                    return RoomCard(
                      room: room,
                      onTap: () {
                        state.selectRoom(room);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (ctx) => RoomScreen(state: state),
                          ),
                        );
                      },
                    );
                  }),
                ],

                const SizedBox(height: 16),

                // + Create Room Tactical Button
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (ctx) => CreateRoomScreen(state: state),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.liveGreen, size: 22),
                  label: const Text(
                    '+ Create Tactical Room',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(
                      color: isDark ? AppColors.surfaceDarkBorder : AppColors.surfaceLightBorder,
                      width: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (ctx) => SearchRoomScreen(state: state)),
                    );
                  },
                  icon: const Icon(Icons.tag_rounded, color: AppColors.tacticalBlueLight, size: 22),
                  label: const Text(
                    'Join by Room ID',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.3),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: isDark ? AppColors.surfaceDarkBorder : AppColors.surfaceLightBorder, width: 1.5),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, RoomType? type, bool isDark) {
    final isSelected = _selectedFilter == type;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.tacticalBlue
              : (isDark ? AppColors.surfaceDarkElevated : AppColors.surfaceLightElevated),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.tacticalBlueLight
                : (isDark ? AppColors.surfaceDarkBorder : AppColors.surfaceLightBorder),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : (isDark ? AppColors.textWhite : AppColors.textDark),
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionStatusBanner(BuildContext context, AppState state, bool isDark) {
    final isOnline = state.connectionMode == ConnectionMode.online;
    final isMesh = state.connectionMode == ConnectionMode.offlineNearbyMesh;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDarkElevated : AppColors.surfaceLightElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOnline
              ? AppColors.liveGreen.withValues(alpha: 0.4)
              : (isMesh ? AppColors.meshAmber.withValues(alpha: 0.6) : AppColors.emergencyRed.withValues(alpha: 0.4)),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isOnline ? AppColors.liveGreen : (isMesh ? AppColors.meshAmber : AppColors.emergencyRed),
                  boxShadow: [
                    BoxShadow(
                      color: isOnline ? AppColors.liveGreenGlow : AppColors.meshAmberGlow,
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CONNECTION STATUS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                        color: AppColors.textMutedDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isOnline
                          ? '🟢 Internet Connected'
                          : (isMesh
                              ? '🟠 Offline • 📡 Nearby Mesh (${state.nearbyPeerCount} Devices)'
                              : '🔴 Offline • Reconnecting...'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isOnline
                            ? AppColors.liveGreen
                            : (isMesh ? AppColors.meshAmber : AppColors.emergencyRed),
                      ),
                    ),
                  ],
                ),
              ),
              // Simulation Switch
              TextButton(
                onPressed: () {
                  if (isOnline) {
                    state.setConnectionMode(ConnectionMode.offlineNearbyMesh);
                  } else {
                    state.setConnectionMode(ConnectionMode.online);
                  }
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(
                  isOnline ? 'Test Mesh Mode' : 'Restore Online',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
