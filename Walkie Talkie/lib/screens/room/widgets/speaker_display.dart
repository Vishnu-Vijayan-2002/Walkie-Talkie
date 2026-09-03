import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class SpeakerDisplay extends StatelessWidget {
  final String? speakerName;
  final bool isSpeaking;
  final bool isCurrentUser;

  const SpeakerDisplay({
    super.key,
    required this.speakerName,
    required this.isSpeaking,
    this.isCurrentUser = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final initial = (speakerName != null && speakerName!.isNotEmpty)
        ? speakerName![0].toUpperCase()
        : '•';

    return Column(
      children: [
        // Speaker Header Label
        Text(
          'CURRENT SPEAKER',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
            color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
          ),
        ),
        const SizedBox(height: 12),

        // Speaker Avatar Box with Acoustic Waves
        Stack(
          alignment: Alignment.center,
          children: [
            // Acoustic Radiating Halo (when speaking)
            if (isSpeaking) ...[
              AnimatedContainer(
                duration: const Duration(milliseconds: 600),
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCurrentUser
                      ? AppColors.liveGreen.withValues(alpha: 0.15)
                      : AppColors.emergencyRed.withValues(alpha: 0.15),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCurrentUser
                      ? AppColors.liveGreen.withValues(alpha: 0.25)
                      : AppColors.emergencyRed.withValues(alpha: 0.25),
                ),
              ),
            ],

            // Main Avatar Core
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDarkElevated : AppColors.surfaceLightElevated,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSpeaking
                      ? (isCurrentUser ? AppColors.liveGreen : AppColors.emergencyRed)
                      : (isDark ? AppColors.surfaceDarkBorder : AppColors.surfaceLightBorder),
                  width: isSpeaking ? 2.5 : 1.5,
                ),
                boxShadow: isSpeaking
                    ? [
                        BoxShadow(
                          color: (isCurrentUser ? AppColors.liveGreenGlow : AppColors.emergencyRedGlow),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Text(
                  initial,
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: isSpeaking
                        ? (isCurrentUser ? AppColors.liveGreen : AppColors.emergencyRed)
                        : (isDark ? AppColors.textWhite : AppColors.textDark),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Speaker Name Badge
        Text(
          speakerName ?? 'Floor Available',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
            color: isSpeaking
                ? (isCurrentUser ? AppColors.liveGreen : (isDark ? AppColors.textWhite : AppColors.textDark))
                : (isDark ? AppColors.textMutedDark : AppColors.textMutedLight),
          ),
        ),
        const SizedBox(height: 4),

        // Live Audio Transmission Status Chip
        if (isSpeaking) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: isCurrentUser
                  ? AppColors.liveGreen.withValues(alpha: 0.2)
                  : AppColors.emergencyRed.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.volume_up_rounded,
                  size: 14,
                  color: isCurrentUser ? AppColors.liveGreen : AppColors.emergencyRed,
                ),
                const SizedBox(width: 6),
                Text(
                  isCurrentUser ? 'YOU ARE TRANSMITTING' : 'SPEAKING NOW',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: isCurrentUser ? AppColors.liveGreen : AppColors.emergencyRed,
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          Text(
            'Channel is clear. Press PTT to speak.',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
            ),
          ),
        ],
      ],
    );
  }
}
