import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/models.dart';

class RoomCard extends StatelessWidget {
  final Room room;
  final VoidCallback onTap;

  const RoomCard({
    super.key,
    required this.room,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSpeaking = room.activeSpeaker != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSpeaking
              ? AppColors.liveGreen.withValues(alpha: 0.8)
              : (isDark ? AppColors.surfaceDarkBorder : AppColors.surfaceLightBorder),
          width: isSpeaking ? 1.8 : 1.2,
        ),
        boxShadow: isSpeaking
            ? [
                BoxShadow(
                  color: AppColors.liveGreen.withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Row
                Row(
                  children: [
                    // Emoji / Type Icon
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surfaceDarkElevated : AppColors.surfaceLightElevated,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? AppColors.surfaceDarkBorder : AppColors.surfaceLightBorder,
                        ),
                      ),
                      child: Center(
                        child: Text(room.iconEmoji, style: const TextStyle(fontSize: 22)),
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Room Name & Subtitle
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            room.name,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                '${room.memberCount} members',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (room.isLive) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.liveGreen.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.circle, color: AppColors.liveGreen, size: 7),
                                      SizedBox(width: 4),
                                      Text(
                                        'LIVE',
                                        style: TextStyle(
                                          color: AppColors.liveGreen,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: AppColors.textMutedDark, size: 24),
                  ],
                ),

                // Active Transmission Banner (if someone is speaking)
                if (isSpeaking) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.liveGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.liveGreen.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.volume_up_rounded, color: AppColors.liveGreen, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${room.activeSpeaker} is speaking...',
                            style: const TextStyle(
                              color: AppColors.liveGreen,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        // Pulsing Wave dots
                        Row(
                          children: List.generate(4, (i) {
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              width: 4,
                              height: 10 + (i % 2 == 0 ? 8.0 : 2.0),
                              decoration: BoxDecoration(
                                color: AppColors.liveGreen,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
