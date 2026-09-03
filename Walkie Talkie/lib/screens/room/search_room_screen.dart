import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../state/app_state.dart';
import 'room_screen.dart';

class SearchRoomScreen extends StatefulWidget {
  final AppState state;

  const SearchRoomScreen({super.key, required this.state});

  @override
  State<SearchRoomScreen> createState() => _SearchRoomScreenState();
}

class _SearchRoomScreenState extends State<SearchRoomScreen> {
  final _roomIdController = TextEditingController();
  bool _isSearching = false;
  bool _isRequesting = false;
  String? _message;
  String? _requestedRoomId;

  @override
  void initState() {
    super.initState();
    widget.state.addListener(_onAppStateChanged);
  }

  @override
  void dispose() {
    widget.state.removeListener(_onAppStateChanged);
    _roomIdController.dispose();
    super.dispose();
  }

  void _onAppStateChanged() {
    if (_requestedRoomId != null && widget.state.activeRoom?.id == _requestedRoomId && mounted) {
      _requestedRoomId = null;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => RoomScreen(state: widget.state)));
    }
  }

  Future<void> _search() async {
    final roomId = _roomIdController.text.trim().toUpperCase();
    if (roomId.isEmpty) {
      setState(() => _message = 'Enter a Room ID first.');
      return;
    }
    setState(() {
      _isSearching = true;
      _message = null;
    });
    final found = await widget.state.searchRoom(roomId);
    if (!mounted) return;
    setState(() {
      _isSearching = false;
      _message = found ? null : 'No active room was found with that ID.';
    });
  }

  Future<void> _requestJoin() async {
    final room = widget.state.searchedRoom;
    if (room == null) return;
    setState(() {
      _isRequesting = true;
      _message = null;
    });
    _requestedRoomId = room.id;
    await widget.state.sendJoinRequest(room.id);
    if (!mounted) return;
    setState(() {
      _isRequesting = false;
      _message = 'Request sent. Waiting for ${room.creatorName} to respond.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.state.searchedRoom;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: const Text('JOIN BY ROOM ID')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Enter the Room ID shared by the room creator.',
                  style: TextStyle(color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight)),
              const SizedBox(height: 16),
              TextField(
                controller: _roomIdController,
                textCapitalization: TextCapitalization.characters,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Room ID',
                  hintText: 'CX-48291',
                  prefixIcon: Icon(Icons.tag_rounded),
                ),
                onSubmitted: (_) => _search(),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _isSearching ? null : _search,
                icon: _isSearching
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.search_rounded),
                label: const Text('SEARCH'),
              ),
              if (room != null) ...[
                const SizedBox(height: 28),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(room.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        Text('Room ID: ${room.id}'),
                        Text('Created by ${room.creatorName}'),
                        Text('${room.memberCount} member${room.memberCount == 1 ? '' : 's'}'),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isRequesting ? null : _requestJoin,
                            icon: const Icon(Icons.person_add_alt_1_rounded),
                            label: Text(_isRequesting ? 'SENDING REQUEST...' : 'REQUEST TO JOIN'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (_message != null) ...[
                const SizedBox(height: 16),
                Text(_message!, textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textMutedDark, fontWeight: FontWeight.w600)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
