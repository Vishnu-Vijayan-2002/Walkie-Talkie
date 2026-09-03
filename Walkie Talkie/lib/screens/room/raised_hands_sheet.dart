import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../state/app_state.dart';

class RaisedHandsSheet extends StatefulWidget {
  final AppState state;

  const RaisedHandsSheet({
    super.key,
    required this.state,
  });

  @override
  State<RaisedHandsSheet> createState() => _RaisedHandsSheetState();
}

class _RaisedHandsSheetState extends State<RaisedHandsSheet> {
  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final room = state.activeRoom;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final raisedHands = room?.raisedHands ?? [];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: isDark ? AppColors.surfaceDarkBorder : AppColors.surfaceLightBorder,
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: SafeArea(
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
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Text('✋', style: TextStyle(fontSize: 20)),
                    SizedBox(width: 10),
                    Text(
                      'RAISED HANDS QUEUE',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.meshAmber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${raisedHands.length} WAITING',
                    style: const TextStyle(
                      color: AppColors.meshAmber,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Moderator Console: Tap "Give Floor" to assign transmission rights.',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),

            if (raisedHands.isEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(vertical: 36),
                alignment: Alignment.center,
                child: Column(
                  children: [
                    const Icon(Icons.pan_tool_outlined, size: 42, color: AppColors.textMutedDark),
                    const SizedBox(height: 12),
                    Text(
                      'Queue is empty. No hands raised.',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: raisedHands.length,
                separatorBuilder: (ctx, index) => const SizedBox(height: 12),
                itemBuilder: (ctx, index) {
                  final hand = raisedHands[index];
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceDarkElevated : AppColors.surfaceLightElevated,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? AppColors.surfaceDarkBorder : AppColors.surfaceLightBorder,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: AppColors.tacticalBlue.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                    color: AppColors.tacticalBlueLight,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text('✋', style: TextStyle(fontSize: 18)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                hand.memberName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Text(
                              'Waiting ${hand.formattedWaitTime}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        ElevatedButton.icon(
                          onPressed: () {
                            state.giveFloorTo(hand);
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Granted speaking floor to ${hand.memberName}'),
                                backgroundColor: AppColors.liveGreen,
                              ),
                            );
                          },
                          icon: const Icon(Icons.mic_rounded, size: 18),
                          label: const Text('GIVE FLOOR', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.liveGreen,
                            minimumSize: const Size.fromHeight(44),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
