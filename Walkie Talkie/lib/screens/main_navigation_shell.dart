import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../state/app_state.dart';
import 'alerts/alerts_screen.dart';
import 'home/home_screen.dart';
import 'profile/profile_screen.dart';
import 'room/create_room_screen.dart';
import 'room/room_screen.dart';
import 'room/incoming_join_request_dialog.dart';

class MainNavigationShell extends StatefulWidget {
  final AppState state;

  const MainNavigationShell({
    super.key,
    required this.state,
  });

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;
  bool _showingJoinRequest = false;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    _showNextJoinRequest(state);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final List<Widget> pages = [
      HomeScreen(state: state),
      _RoomsDirectoryTab(state: state),
      AlertsScreen(state: state),
      ProfileScreen(state: state),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          border: Border(
            top: BorderSide(
              color: isDark ? AppColors.surfaceDarkBorder : AppColors.surfaceLightBorder,
              width: 1.2,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.radio_rounded),
              label: 'Rooms',
            ),
            BottomNavigationBarItem(
              icon: Badge(
                isLabelVisible: state.alerts.isNotEmpty,
                label: Text('${state.alerts.length}'),
                backgroundColor: AppColors.emergencyRed,
                child: const Icon(Icons.notifications_rounded),
              ),
              label: 'Alerts',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_rounded),
              label: 'Me',
            ),
          ],
        ),
      ),
    );
  }

  void _showNextJoinRequest(AppState state) {
    if (_showingJoinRequest || state.incomingJoinRequests.isEmpty) return;
    _showingJoinRequest = true;
    final request = state.incomingJoinRequests.first;
    final room = state.rooms.where((room) => room.id == request.roomId).firstOrNull;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => IncomingJoinRequestDialog(
          roomName: room?.name ?? request.roomId,
          requesterCallsign: request.requesterCallsign,
          onApprove: () async {
            Navigator.of(context).pop();
            await state.approveJoinRequest(request.roomId, request.requesterDeviceId);
          },
          onDecline: () async {
            Navigator.of(context).pop();
            await state.declineJoinRequest(request.roomId, request.requesterDeviceId);
          },
        ),
      ).whenComplete(() {
        if (mounted) setState(() => _showingJoinRequest = false);
      });
    });
  }
}

class _RoomsDirectoryTab extends StatelessWidget {
  final AppState state;

  const _RoomsDirectoryTab({required this.state});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('TACTICAL CHANNELS'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.liveGreen),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (ctx) => CreateRoomScreen(state: state)),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
          itemCount: state.rooms.length,
          separatorBuilder: (ctx, index) => const SizedBox(height: 12),
          itemBuilder: (ctx, index) {
            final room = state.rooms[index];
            return Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppColors.surfaceDarkBorder : AppColors.surfaceLightBorder,
                ),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(14),
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDarkElevated : AppColors.surfaceLightElevated,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(child: Text(room.iconEmoji, style: const TextStyle(fontSize: 24))),
                ),
                title: Text(room.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                subtitle: Text(
                  '${room.typeLabel} • ${room.memberCount} members',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMutedDark),
                onTap: () {
                  state.selectRoom(room);
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (ctx) => RoomScreen(state: state)),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
