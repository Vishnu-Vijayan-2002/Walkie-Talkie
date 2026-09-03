import 'package:flutter/services.dart';

class AudioFeedbackService {
  static void pttPressed() {
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.click);
  }

  static void pttReleased() {
    HapticFeedback.mediumImpact();
    SystemSound.play(SystemSoundType.click);
  }

  static void handRaised() {
    HapticFeedback.selectionClick();
    SystemSound.play(SystemSoundType.click);
  }

  static void floorGranted() {
    HapticFeedback.vibrate();
    SystemSound.play(SystemSoundType.alert);
  }

  static void emergencyAlert() {
    HapticFeedback.vibrate();
    SystemSound.play(SystemSoundType.alert);
  }

  static void pttDenied() {
    HapticFeedback.lightImpact();
    SystemSound.play(SystemSoundType.click);
  }
}
