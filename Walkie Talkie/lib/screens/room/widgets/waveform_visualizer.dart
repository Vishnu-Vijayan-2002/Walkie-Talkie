import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class WaveformVisualizer extends StatelessWidget {
  final List<double> amplitudes;
  final bool isActive;
  final Color? activeColor;

  const WaveformVisualizer({
    super.key,
    required this.amplitudes,
    required this.isActive,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = activeColor ?? AppColors.liveGreen;

    return SizedBox(
      height: 36,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: amplitudes.map((amp) {
          final barHeight = isActive ? (8.0 + (amp * 28.0)).clamp(6.0, 36.0) : 4.0;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 90),
            curve: Curves.easeOut,
            margin: const EdgeInsets.symmetric(horizontal: 2.5),
            width: 4.5,
            height: barHeight,
            decoration: BoxDecoration(
              color: isActive ? color : color.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(3),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.5),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
          );
        }).toList(),
      ),
    );
  }
}
