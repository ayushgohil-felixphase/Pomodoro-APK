import 'package:flutter/material.dart';
import '../../../../models/pomodoro_state.dart';

class AlarmDialog extends StatelessWidget {
  final PomodoroState state;
  final VoidCallback onStopAlarm;

  const AlarmDialog({
    super.key,
    required this.state,
    required this.onStopAlarm,
  });

  @override
  Widget build(BuildContext context) {
    final isWork = state.phase == PomodoroPhase.work;
    final completedLabel = isWork ? 'BREAK COMPLETE' : 'WORK COMPLETE';
    final nextLabel = state.phase.displayName;

    return Dialog.fullscreen(
      backgroundColor: const Color(0xFF121212),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              // 🍅 Tomato Icon
              const Text(
                '🍅',
                style: TextStyle(fontSize: 84),
              ),
              const SizedBox(height: 24),

              // Title
              const Text(
                "TIME'S UP!",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 12),

              // Completed Phase
              Text(
                completedLabel,
                style: const TextStyle(
                  color: Color(0xFFFF6B6B),
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 8),

              // Next Phase
              Text(
                'Up next: $nextLabel',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 16,
                ),
              ),
              const Spacer(),

              // Stop Alarm Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onStopAlarm,
                  icon: const Icon(Icons.alarm_off, size: 28),
                  label: const Text(
                    'STOP ALARM',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE53935),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(32),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
