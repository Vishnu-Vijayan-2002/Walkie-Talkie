import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class IncomingJoinRequestDialog extends StatelessWidget {
  final String? roomId;
  final String? roomName;
  final String? requesterDeviceId;
  final String requesterCallsign;
  final VoidCallback onApprove;
  final VoidCallback onDecline;

  const IncomingJoinRequestDialog({
    super.key,
    this.roomId,
    this.roomName,
    this.requesterDeviceId,
    required this.requesterCallsign,
    required this.onApprove,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('JOIN REQUEST', style: TextStyle(fontWeight: FontWeight.w800)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$requesterCallsign is requesting to join your room.',
              style: const TextStyle(fontSize: 16)),
          if (roomName != null && roomName!.isNotEmpty)
            Text('Room: $roomName', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.tacticalBlueLight)),
          if (roomId != null && roomId!.isNotEmpty)
            Text('Room ID: $roomId', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textMutedDark)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            onDecline();
            Navigator.of(context).pop();
          },
          child: const Text('DECLINE', style: TextStyle(color: Colors.redAccent)),
        ),
        ElevatedButton(
          onPressed: () {
            onApprove();
            Navigator.of(context).pop();
          },
          child: const Text('APPROVE'),
        ),
      ],
    );
  }
}
