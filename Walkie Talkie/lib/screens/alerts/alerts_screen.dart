import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';

class AlertsScreen extends StatelessWidget {
  final AppState state;

  const AlertsScreen({
    super.key,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final alerts = state.alerts;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ALERTS & DISPATCH'),
        actions: [
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('All alerts marked as acknowledged.')),
              );
            },
            child: const Text('✓ Mark Read', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: SafeArea(
        child: alerts.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.notifications_off_outlined, size: 48, color: AppColors.textMutedDark),
                    const SizedBox(height: 12),
                    Text(
                      'No active alerts',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                      ),
                    ),
                  ],
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
                itemCount: alerts.length,
                separatorBuilder: (ctx, index) => const SizedBox(height: 12),
                itemBuilder: (ctx, index) {
                  final alert = alerts[index];
                  final isEmergency = alert.type == AlertType.emergency;
                  final isSpeakingReq = alert.type == AlertType.speakingRequest;

                  Color accentColor = isEmergency
                      ? AppColors.emergencyRed
                      : (isSpeakingReq ? AppColors.meshAmber : AppColors.liveGreen);

                  return Container(
                    decoration: BoxDecoration(
                      color: isEmergency
                          ? AppColors.emergencyRed.withValues(alpha: 0.12)
                          : (isDark ? AppColors.surfaceDark : AppColors.surfaceLight),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isEmergency
                            ? AppColors.emergencyRed
                            : (isDark ? AppColors.surfaceDarkBorder : AppColors.surfaceLightBorder),
                        width: isEmergency ? 1.8 : 1.0,
                      ),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.18),
                            shape: BoxShape.circle,
                            border: Border.all(color: accentColor.withValues(alpha: 0.6)),
                          ),
                          child: Center(
                            child: Icon(
                              isEmergency
                                  ? Icons.warning_rounded
                                  : (isSpeakingReq ? Icons.pan_tool_rounded : Icons.info_outline_rounded),
                              color: accentColor,
                              size: 22,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      alert.title,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: isEmergency ? AppColors.emergencyRed : null,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    alert.timeAgo,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                alert.message,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.surfaceDarkElevated : AppColors.surfaceLightElevated,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Channel: ${alert.roomName}',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
