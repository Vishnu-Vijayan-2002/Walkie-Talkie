import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import 'room_screen.dart';

class CreateRoomScreen extends StatefulWidget {
  final AppState state;

  const CreateRoomScreen({
    super.key,
    required this.state,
  });

  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  final TextEditingController _nameController = TextEditingController(text: 'Event Security Alpha');
  RoomType _selectedType = RoomType.event;
  bool _approvalRequired = true;
  bool _internetEnabled = true;
  bool _meshEnabled = true;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool _isCreating = false;

  Future<void> _handleCreateRoom() async {
    if (_isCreating) return;
    setState(() => _isCreating = true);

    try {
      final name = _nameController.text.trim().isEmpty ? 'Tactical Channel' : _nameController.text.trim();
      await widget.state.createNewRoom(
        name: name,
        type: _selectedType,
        approvalRequired: _approvalRequired,
        meshFallback: _meshEnabled,
      );

      if (!mounted) return;

      if (widget.state.activeRoom != null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (ctx) => RoomScreen(state: widget.state),
          ),
        );
      } else {
        setState(() => _isCreating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to activate created room. Please select from Home.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      debugPrint('[CreateRoomScreen] Error creating room: $e');
      if (mounted) {
        setState(() => _isCreating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('CREATE ROOM'),
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
              const Text(
                'Room Name',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AppColors.textMutedDark),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                decoration: const InputDecoration(
                  hintText: 'e.g. Event Security, Emergency Core',
                  prefixIcon: Icon(Icons.meeting_room_outlined),
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'Room Type',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AppColors.textMutedDark),
              ),
              const SizedBox(height: 10),
              _buildTypeCard(RoomType.general, '📻 General', 'Open multi-purpose channel', isDark),
              _buildTypeCard(RoomType.event, '🚨 Event Security', 'Crowd control, tactical teams, VIP escort', isDark),
              _buildTypeCard(RoomType.hospital, '🏥 Hospital & Medical', 'ER, trauma team, ambulance dispatch', isDark),
              _buildTypeCard(RoomType.school, '🏫 School & Campus', 'Campus admin, faculty, facility security', isDark),
              _buildTypeCard(RoomType.fieldTeam, '👥 Field Operations', 'Wilderness, search & rescue, patrol units', isDark),

              const SizedBox(height: 24),

              const Text(
                'Member Access',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AppColors.textMutedDark),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDarkElevated : AppColors.surfaceLightElevated,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? AppColors.surfaceDarkBorder : AppColors.surfaceLightBorder,
                  ),
                ),
                child: SwitchListTile(
                  title: const Row(
                    children: [
                      Icon(Icons.lock_outline_rounded, size: 20, color: AppColors.tacticalBlueLight),
                      SizedBox(width: 10),
                      Text('Approval Required', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    ],
                  ),
                  subtitle: const Text(
                    'Creator or Moderator must accept join requests',
                    style: TextStyle(fontSize: 12, color: AppColors.textMutedDark),
                  ),
                  value: _approvalRequired,
                  activeTrackColor: AppColors.liveGreen,
                  onChanged: (val) => setState(() => _approvalRequired = val),
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                'Communication Transports',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AppColors.textMutedDark),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDarkElevated : AppColors.surfaceLightElevated,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? AppColors.surfaceDarkBorder : AppColors.surfaceLightBorder,
                  ),
                ),
                child: Column(
                  children: [
                    CheckboxListTile(
                      title: const Text('🌐 Internet Uplink', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      subtitle: const Text('High fidelity low-latency WAN streaming', style: TextStyle(fontSize: 12, color: AppColors.textMutedDark)),
                      value: _internetEnabled,
                      activeColor: AppColors.liveGreen,
                      onChanged: (val) => setState(() => _internetEnabled = val ?? true),
                    ),
                    const Divider(height: 1),
                    CheckboxListTile(
                      title: const Text('📡 Offline Nearby Mesh', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      subtitle: const Text('Auto fallback to P2P direct hardware mesh when offline', style: TextStyle(fontSize: 12, color: AppColors.textMutedDark)),
                      value: _meshEnabled,
                      activeColor: AppColors.meshAmber,
                      onChanged: (val) => setState(() => _meshEnabled = val ?? true),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: _isCreating ? null : _handleCreateRoom,
                child: _isCreating
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('CREATE ROOM', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 1.0)),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeCard(RoomType type, String title, String subtitle, bool isDark) {
    final isSelected = _selectedType == type;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? (isDark ? AppColors.surfaceDarkElevated : Colors.white)
            : (isDark ? AppColors.surfaceDark : AppColors.surfaceLight),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? AppColors.liveGreen
              : (isDark ? AppColors.surfaceDarkBorder : AppColors.surfaceLightBorder),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _selectedType = type),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: isSelected ? AppColors.liveGreen : AppColors.textMutedDark,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
