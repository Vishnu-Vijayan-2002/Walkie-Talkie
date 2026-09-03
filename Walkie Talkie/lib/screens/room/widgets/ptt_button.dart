import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/models.dart';
import '../../../state/app_state.dart';

class PttButton extends StatefulWidget {
  final AppState state;
  final VoidCallback onPressed;
  final VoidCallback onReleased;

  const PttButton({
    super.key,
    required this.state,
    required this.onPressed,
    required this.onReleased,
  });

  @override
  State<PttButton> createState() => _PttButtonState();
}

class _PttButtonState extends State<PttButton> {
  bool _isPressedDown = false;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pttState = state.pttState;

    Color coreColor;
    Color glowColor;
    Color borderColor;
    String statusTitle;
    String statusSubtitle;
    IconData iconData;

    switch (pttState) {
      case PttState.speaking:
        coreColor = AppColors.liveGreenDark;
        glowColor = AppColors.liveGreenGlow;
        borderColor = AppColors.liveGreen;
        statusTitle = 'SPEAKING';
        statusSubtitle = 'RELEASE TO LISTEN (${state.transmissionSeconds}s)';
        iconData = Icons.mic_rounded;
        break;

      case PttState.floorBusy:
        coreColor = const Color(0xFF7F1D1D);
        glowColor = AppColors.emergencyRedGlow;
        borderColor = AppColors.emergencyRed;
        statusTitle = '${state.currentSpeakerName ?? "Someone"} is speaking';
        statusSubtitle = 'FLOOR OCCUPIED • HOLD TO INTERCEPT';
        iconData = Icons.volume_up_rounded;
        break;

      case PttState.requesting:
        coreColor = AppColors.meshAmberDark;
        glowColor = AppColors.meshAmberGlow;
        borderColor = AppColors.meshAmber;
        statusTitle = 'REQUESTING...';
        statusSubtitle = 'WAITING FOR MODERATOR';
        iconData = Icons.hourglass_top_rounded;
        break;

      case PttState.offlineNearby:
        coreColor = const Color(0xFF78350F);
        glowColor = AppColors.meshAmberGlow;
        borderColor = AppColors.meshAmber;
        statusTitle = 'OFFLINE MESH';
        statusSubtitle = 'HOLD TO TRANSMIT P2P';
        iconData = Icons.wifi_tethering_rounded;
        break;

      case PttState.denied:
        coreColor = const Color(0xFF374151);
        glowColor = Colors.transparent;
        borderColor = Colors.grey;
        statusTitle = 'FLOOR UNAVAILABLE';
        statusSubtitle = 'ROOM LOCKED BY MODERATOR';
        iconData = Icons.mic_off_rounded;
        break;

      case PttState.idle:
        coreColor = isDark ? const Color(0xFF161F30) : const Color(0xFFE2E8F0);
        glowColor = AppColors.liveGreen.withValues(alpha: 0.15);
        borderColor = isDark ? const Color(0xFF2E3E5C) : const Color(0xFFCBD5E1);
        statusTitle = 'HOLD TO TALK';
        statusSubtitle = 'PUSH AND SPEAK CLEARLY';
        iconData = Icons.mic_none_rounded;
        break;
    }

    final isTransmitting = pttState == PttState.speaking;

    return Listener(
      onPointerDown: (_) {
        setState(() => _isPressedDown = true);
        widget.onPressed();
      },
      onPointerUp: (_) {
        setState(() => _isPressedDown = false);
        widget.onReleased();
      },
      onPointerCancel: (_) {
        setState(() => _isPressedDown = false);
        widget.onReleased();
      },
      child: AnimatedScale(
        scale: _isPressedDown ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: Container(
          width: double.infinity,
          height: 240,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                isDark ? const Color(0xFF26334D) : const Color(0xFFF1F5F9),
                isDark ? const Color(0xFF0F1522) : const Color(0xFFE2E8F0),
              ],
            ),
            border: Border.all(
              color: isTransmitting ? borderColor : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
              width: isTransmitting ? 3.0 : 1.8,
            ),
            boxShadow: [
              BoxShadow(
                color: glowColor,
                blurRadius: isTransmitting ? 36 : (_isPressedDown ? 20 : 10),
                spreadRadius: isTransmitting ? 4 : 0,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.15),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.all(12),
          child: Container(
            decoration: BoxDecoration(
              color: coreColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: borderColor.withValues(alpha: 0.8),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: borderColor.withValues(alpha: 0.6),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      iconData,
                      size: 42,
                      color: isTransmitting
                          ? Colors.white
                          : (isDark ? AppColors.textWhite : AppColors.textDark),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  statusTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: isTransmitting
                        ? Colors.white
                        : (isDark ? AppColors.textWhite : AppColors.textDark),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  statusSubtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: isTransmitting
                        ? Colors.white.withValues(alpha: 0.9)
                        : (isDark ? AppColors.textMutedDark : AppColors.textMutedLight),
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
