import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_timer/models/daily_statistics.dart';
import 'package:pomodoro_timer/models/pomodoro_settings.dart';
import 'package:pomodoro_timer/models/pomodoro_state.dart';

void main() {
  group('PomodoroState Unit Tests', () {
    test('Default values are correct', () {
      const state = PomodoroState();
      expect(state.phase, PomodoroPhase.work);
      expect(state.isRunning, false);
      expect(state.isPaused, false);
      expect(state.remainingSeconds, 25 * 60);
      expect(state.currentCycle, 0);
      expect(state.totalCycles, 4);
      expect(state.completedPomodorosToday, 0);
      expect(state.formattedRemainingTime, '25:00');
      expect(state.cycleDisplay, 'Cycle 1 of 4');
      expect(state.progress, 0.0);
    });

    test('formattedRemainingTime formats correctly with padding', () {
      const state1 = PomodoroState(remainingSeconds: 65);
      expect(state1.formattedRemainingTime, '01:05');

      const state2 = PomodoroState(remainingSeconds: 9);
      expect(state2.formattedRemainingTime, '00:09');

      const state3 = PomodoroState(remainingSeconds: 0);
      expect(state3.formattedRemainingTime, '00:00');
    });

    test('progress calculates accurately', () {
      const state = PomodoroState(
        totalDurationSeconds: 100,
        remainingSeconds: 25,
      );
      expect(state.progress, 0.75);
    });

    test('copyWith updates fields without mutating unchanged values', () {
      const state = PomodoroState();
      final updated = state.copyWith(
        phase: PomodoroPhase.shortBreak,
        remainingSeconds: 300,
        currentCycle: 2,
      );

      expect(updated.phase, PomodoroPhase.shortBreak);
      expect(updated.remainingSeconds, 300);
      expect(updated.currentCycle, 2);
      expect(updated.totalCycles, 4);
      expect(updated.isRunning, false);
    });
  });

  group('PomodoroSettings Tests', () {
    test('Clamps durations to valid 1-120 range', () {
      const settings = PomodoroSettings();
      final clamped = settings.copyWith(
        workDurationMinutes: 500, // exceeds 120
        shortBreakDurationMinutes: 0, // below 1
        longBreakDurationMinutes: -10, // below 1
        cyclesBeforeLongBreak: 20, // exceeds 12
      );

      expect(clamped.workDurationMinutes, 120);
      expect(clamped.shortBreakDurationMinutes, 1);
      expect(clamped.longBreakDurationMinutes, 1);
      expect(clamped.cyclesBeforeLongBreak, 12);
    });

    test('JSON serialization & deserialization round-trip', () {
      const original = PomodoroSettings(
        workDurationMinutes: 45,
        shortBreakDurationMinutes: 10,
        longBreakDurationMinutes: 20,
        cyclesBeforeLongBreak: 6,
        autoStartBreaks: true,
        autoStartWork: true,
        vibrationEnabled: false,
        selectedAlarmSound: 'digital',
        themeMode: 'dark',
      );

      final json = original.toJson();
      final restored = PomodoroSettings.fromJson(json);

      expect(restored.workDurationMinutes, 45);
      expect(restored.shortBreakDurationMinutes, 10);
      expect(restored.longBreakDurationMinutes, 20);
      expect(restored.cyclesBeforeLongBreak, 6);
      expect(restored.autoStartBreaks, true);
      expect(restored.autoStartWork, true);
      expect(restored.vibrationEnabled, false);
      expect(restored.selectedAlarmSound, 'digital');
      expect(restored.themeMode, 'dark');
    });
  });

  group('DailyStatistics Tests', () {
    test('JSON serialization & deserialization', () {
      const stats = DailyStatistics(
        date: '2026-09-11',
        completedPomodoros: 6,
        focusMinutes: 150,
      );

      final json = stats.toJson();
      final restored = DailyStatistics.fromJson(json);

      expect(restored.date, '2026-09-11');
      expect(restored.completedPomodoros, 6);
      expect(restored.focusMinutes, 150);
    });

    test('copyWith updates correctly', () {
      const stats = DailyStatistics(date: '2026-09-11');
      final updated = stats.copyWith(
        completedPomodoros: stats.completedPomodoros + 1,
        focusMinutes: stats.focusMinutes + 25,
      );

      expect(updated.completedPomodoros, 1);
      expect(updated.focusMinutes, 25);
    });
  });

  group('Background Timestamp Recovery Math Tests', () {
    test('Calculates remaining seconds correctly from sessionEndsAt', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final sessionEndsAt = now + 90 * 1000; // 90 seconds in the future

      final diff = (sessionEndsAt - now + 999) ~/ 1000;
      expect(diff, 90);
    });

    test('Identifies session expired when sessionEndsAt is past', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final sessionEndsAt = now - 5000; // 5 seconds in the past

      final diff = (sessionEndsAt - now) ~/ 1000;
      expect(diff <= 0, true);
    });
  });

  group('Cycle Progression Logic Tests', () {
    test('Work session transitions to short break until totalCycles reached', () {
      const totalCycles = 4;
      var currentCycle = 0;
      var phase = PomodoroPhase.work;

      // Finish Work 1
      phase = PomodoroPhase.work;
      currentCycle++;
      phase = currentCycle >= totalCycles ? PomodoroPhase.longBreak : PomodoroPhase.shortBreak;
      expect(phase, PomodoroPhase.shortBreak);
      expect(currentCycle, 1);

      // Finish Work 2
      currentCycle++;
      phase = currentCycle >= totalCycles ? PomodoroPhase.longBreak : PomodoroPhase.shortBreak;
      expect(phase, PomodoroPhase.shortBreak);
      expect(currentCycle, 2);

      // Finish Work 3
      currentCycle++;
      phase = currentCycle >= totalCycles ? PomodoroPhase.longBreak : PomodoroPhase.shortBreak;
      expect(phase, PomodoroPhase.shortBreak);
      expect(currentCycle, 3);

      // Finish Work 4 -> triggers LONG BREAK
      currentCycle++;
      phase = currentCycle >= totalCycles ? PomodoroPhase.longBreak : PomodoroPhase.shortBreak;
      expect(phase, PomodoroPhase.longBreak);
      expect(currentCycle, 4);

      // Long break completes -> resets cycle to 0 and phase to work
      if (phase == PomodoroPhase.longBreak) {
        currentCycle = 0;
      }
      phase = PomodoroPhase.work;
      expect(phase, PomodoroPhase.work);
      expect(currentCycle, 0);
    });
  });
}
