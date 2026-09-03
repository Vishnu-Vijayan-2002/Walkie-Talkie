import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';

class MembersScreen extends StatefulWidget {
  final AppState state;

  const MembersScreen({
    super.key,
    required this.state,
  });

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showMemberModerationSheet(BuildContext context, RoomMember member) {
    final state = widget.state;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.textMutedDark.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.surfaceDarkElevated : AppColors.surfaceLightElevated,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: member.isOnline ? AppColors.liveGreen : Colors.grey,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            member.name[0].toUpperCase(),
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              member.name,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(
                                  Icons.circle,
                                  size: 8,
                                  color: member.isOnline ? AppColors.liveGreen : Colors.grey,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  member.isOnline ? 'Online • ${member.deviceId}' : 'Offline',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: member.isOnline ? AppColors.liveGreen : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.tacticalBlue.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          member.role.name.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.tacticalBlueLight,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  OutlinedButton.icon(
                    onPressed: () {
                      state.toggleMemberRole(member);
                      setSheetState(() {});
                      setState(() {});
                    },
                    icon: Icon(
                      member.role == MemberRole.moderator ? Icons.remove_moderator_outlined : Icons.verified_user_outlined,
                      size: 20,
                    ),
                    label: Text(
                      member.role == MemberRole.moderator ? 'Demote to Member' : 'Give Moderator Role',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 10),

                  OutlinedButton.icon(
                    onPressed: () {
                      state.toggleMemberMute(member);
                      setSheetState(() {});
                      setState(() {});
                    },
                    icon: Icon(
                      member.isMuted ? Icons.mic_rounded : Icons.mic_off_outlined,
                      color: member.isMuted ? AppColors.liveGreen : AppColors.meshAmber,
                      size: 20,
                    ),
                    label: Text(
                      member.isMuted ? 'Unmute Transmission' : 'Mute Member',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: member.isMuted ? AppColors.liveGreen : AppColors.meshAmber,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  ElevatedButton.icon(
                    onPressed: () {
                      state.removeMember(member);
                      Navigator.of(context).pop();
                      setState(() {});
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Removed ${member.name} from room.'),
                          backgroundColor: AppColors.emergencyRed,
                        ),
                      );
                    },
                    icon: const Icon(Icons.person_remove_outlined, size: 20),
                    label: const Text('Remove from Room', style: TextStyle(fontWeight: FontWeight.w800)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.emergencyRedDark,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final room = state.activeRoom;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final members = (room?.members ?? []).where((m) {
      if (_searchQuery.isEmpty) return true;
      return m.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          m.role.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('MEMBERS ROSTER'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Invite Member',
            icon: const Icon(Icons.person_add_alt_1_rounded),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Share this Room ID: ${room?.id ?? 'Unavailable'}'),
                  backgroundColor: AppColors.liveGreen,
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Search members by call sign or role...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'TOTAL MEMBERS (${members.length})',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: AppColors.textMutedDark,
                    ),
                  ),
                  Text(
                    '${members.where((m) => m.isOnline).length} Online',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.liveGreen,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              Expanded(
                child: ListView.separated(
                  itemCount: members.length,
                  separatorBuilder: (ctx, index) => const SizedBox(height: 8),
                  itemBuilder: (ctx, index) {
                    final member = members[index];
                    return Container(
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: member.isSpeaking
                              ? AppColors.liveGreen
                              : (isDark ? AppColors.surfaceDarkBorder : AppColors.surfaceLightBorder),
                          width: member.isSpeaking ? 1.8 : 1.0,
                        ),
                      ),
                      child: ListTile(
                        onTap: () => _showMemberModerationSheet(context, member),
                        leading: Stack(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.surfaceDarkElevated : AppColors.surfaceLightElevated,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  member.name[0].toUpperCase(),
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: member.isOnline ? AppColors.liveGreen : Colors.grey,
                                  border: Border.all(
                                    color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        title: Row(
                          children: [
                            Text(
                              member.name,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                            ),
                            if (member.isMuted) ...[
                              const SizedBox(width: 8),
                              const Icon(Icons.mic_off_rounded, size: 16, color: AppColors.meshAmber),
                            ],
                            if (member.isSpeaking) ...[
                              const SizedBox(width: 8),
                              const Icon(Icons.volume_up_rounded, size: 16, color: AppColors.liveGreen),
                            ],
                          ],
                        ),
                        subtitle: Text(
                          member.role.name.toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: member.role == MemberRole.creator
                                ? AppColors.tacticalBlueLight
                                : (member.role == MemberRole.moderator
                                    ? AppColors.liveGreen
                                    : AppColors.textMutedDark),
                          ),
                        ),
                        trailing: const Icon(Icons.more_horiz_rounded, color: AppColors.textMutedDark),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
