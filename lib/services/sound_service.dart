import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:web/web.dart' as web;

class SoundService {
  static void playOrderAlert() {
    if (kIsWeb) {
      try {
        final ctx = web.AudioContext();
        final osc = ctx.createOscillator();
        final gain = ctx.createGain();

        osc.connect(gain);
        gain.connect(ctx.destination);

        // Friendly 2-tone order chime: D5 (587 Hz) -> A5 (880 Hz)
        final now = ctx.currentTime;
        osc.frequency.setValueAtTime(587.33, now);
        osc.frequency.setValueAtTime(880.00, now + 0.15);

        gain.gain.setValueAtTime(0.25, now);
        gain.gain.exponentialRampToValueAtTime(0.001, now + 0.55);

        osc.start(now);
        osc.stop(now + 0.55);
      } catch (_) {
        SystemSound.play(SystemSoundType.alert);
      }
    } else {
      SystemSound.play(SystemSoundType.alert);
    }
  }
}
