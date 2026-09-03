import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../state/app_state.dart';

class JoinRoomDialog extends StatelessWidget {
  final AppState state;
  final String inviterName;
  final String roomName;
  final int memberCount;
  final VoidCallback onAccepted;

  const JoinRoomDialog({
    super.key,
    required this.state,
    required this.inviterName,
    required this.roomName,
    required this.memberCount,
    required this.onAccepted,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isDark ? AppColors.surfaceDarkBorder : AppColors.surfaceLightBorder,
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.tacticalBlue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'TACTICAL INVITATION',
                style: TextStyle(
                  color: AppColors.tacticalBlueLight,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Icon
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDarkElevated : AppColors.surfaceLightElevated,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.liveGreen, width: 2),
              ),
              child: const Center(
                child: Text('🚨', style: TextStyle(fontSize: 30)),
              ),
            ),
            const SizedBox(height: 18),

            // Room Name
            Text(
              roomName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),

            // Created by & members count
            Text(
              'Created by $inviterName',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.people_outline_rounded, size: 16, color: AppColors.liveGreen),
                const SizedBox(width: 6),
                Text(
                  '$memberCount members currently active',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.liveGreen,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Action Buttons: DECLINE / REQUEST JOIN
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textMutedDark,
                      side: BorderSide(
                        color: isDark ? AppColors.surfaceDarkBorder : AppColors.surfaceLightBorder,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('DECLINE', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onAccepted();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.liveGreen,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('ACCEPT JOIN', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
