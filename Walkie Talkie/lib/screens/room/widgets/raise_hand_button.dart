import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class RaiseHandButton extends StatelessWidget {
  final bool isHandRaised;
  final VoidCallback onTap;

  const RaiseHandButton({
    super.key,
    required this.isHandRaised,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 56,
      decoration: BoxDecoration(
        color: isHandRaised
            ? AppColors.meshAmber.withValues(alpha: 0.18)
            : (isDark ? AppColors.surfaceDarkElevated : AppColors.surfaceLightElevated),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHandRaised
              ? AppColors.meshAmber
              : (isDark ? AppColors.surfaceDarkBorder : AppColors.surfaceLightBorder),
          width: isHandRaised ? 2.0 : 1.2,
        ),
        boxShadow: isHandRaised
            ? [
                BoxShadow(
                  color: AppColors.meshAmberGlow,
                  blurRadius: 16,
                  spreadRadius: 1,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  isHandRaised ? '✋' : '✋',
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(width: 10),
                Text(
                  isHandRaised ? 'HAND RAISED  •  TAP TO CANCEL' : 'RAISE HAND TO REQUEST FLOOR',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: isHandRaised
                        ? AppColors.meshAmber
                        : (isDark ? AppColors.textWhite : AppColors.textDark),
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
