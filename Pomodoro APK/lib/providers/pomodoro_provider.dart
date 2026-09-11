import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/pomodoro_settings.dart';
import '../models/pomodoro_state.dart';
import '../services/native_timer_service.dart';
import '../services/storage_service.dart';
import 'settings_provider.dart';
import 'statistics_provider.dart';

final nativeTimerServiceProvider = Provider<NativeTimerService>((ref) {
  return NativeTimerService();
});

final pomodoroProvider = NotifierProvider<PomodoroNotifier, PomodoroState>(PomodoroNotifier.new);

class PomodoroNotifier extends Notifier<PomodoroState> {
  StorageService get _storage => ref.read(storageServiceProvider);
  NativeTimerService get _nativeService => ref.read(nativeTimerServiceProvider);
  PomodoroSettings get _settings => ref.read(settingsProvider);

  Timer? _localTicker;
  StreamSubscription? _eventSub;

  @override
  PomodoroState build() {
    ref.onDispose(() {
      _stopLocalTicker();
      _eventSub?.cancel();
    });

    final initialState = _storage.loadState(_settings);
    Future.microtask(() => _init());
    return initialState;
  }

  void _init() {
    _recoverStateOnLaunch();

    _eventSub?.cancel();
    _eventSub = _nativeService.eventStream.listen((event) {
      _handleNativeEvent(event);
    });

    if (state.isRunning && !state.isPaused) {
      _startLocalTicker();
    }
  }

  void _recoverStateOnLaunch() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (state.isRunning && !state.isPaused && state.sessionEndsAt > 0) {
      final diff = (state.sessionEndsAt - now + 999) ~/ 1000;
      if (diff <= 0) {
        _onSessionComplete();
      } else {
        state = state.copyWith(remainingSeconds: diff);
        _storage.saveState(state);
      }
    }
  }

  void _handleNativeEvent(Map<String, dynamic> event) {
    final name = event['event'] as String?;
    switch (name) {
      case 'tick':
        final remaining = (event['remainingSeconds'] as num?)?.toInt();
        if (remaining != null) {
          state = state.copyWith(remainingSeconds: remaining);
          _storage.saveState(state);
        }
        break;

      case 'stateChanged':
        final isPaused = event['isPaused'] as bool?;
        final phaseStr = event['phase'] as String?;
        final cycle = (event['currentCycle'] as num?)?.toInt();
        final remaining = (event['remainingSeconds'] as num?)?.toInt();

        PomodoroPhase? phase;
        if (phaseStr != null) {
          phase = PomodoroPhase.values.firstWhere(
            (p) => p.name == phaseStr,
            orElse: () => state.phase,
          );
        }

        state = state.copyWith(
          isPaused: isPaused,
          phase: phase,
          currentCycle: cycle,
          remainingSeconds: remaining,
        );
        _storage.saveState(state);
        break;

      case 'alarmTriggered':
        final completedPhase = event['completedPhase'] as String?;
        if (completedPhase == 'work') {
          ref.read(statisticsProvider.notifier).recordWorkSession(_settings.workDurationMinutes);
        }
        state = state.copyWith(
          isAlarmRinging: true,
          isRunning: false,
          isPaused: false,
        );
        _storage.saveState(state);
        break;

      case 'alarmStopped':
        state = state.copyWith(isAlarmRinging: false);
        _storage.saveState(state);
        break;
    }
  }

  void updateSettings(PomodoroSettings newSettings) {
    if (!state.isRunning) {
      final durationMinutes = _getDurationMinutesForPhase(state.phase, newSettings);
      final durationSec = durationMinutes * 60;
      state = state.copyWith(
        remainingSeconds: durationSec,
        totalDurationSeconds: durationSec,
        totalCycles: newSettings.cyclesBeforeLongBreak,
      );
      _storage.saveState(state);
    }
  }

  int _getDurationMinutesForPhase(PomodoroPhase phase, [PomodoroSettings? customSettings]) {
    final s = customSettings ?? _settings;
    switch (phase) {
      case PomodoroPhase.work:
        return s.workDurationMinutes;
      case PomodoroPhase.shortBreak:
        return s.shortBreakDurationMinutes;
      case PomodoroPhase.longBreak:
        return s.longBreakDurationMinutes;
    }
  }

  Future<void> startTimer() async {
    final durationMinutes = _getDurationMinutesForPhase(state.phase);
    final durationSeconds = state.remainingSeconds > 0 && state.remainingSeconds <= (durationMinutes * 60)
        ? state.remainingSeconds
        : durationMinutes * 60;

    final now = DateTime.now().millisecondsSinceEpoch;
    final endsAt = now + (durationSeconds * 1000);

    state = state.copyWith(
      isRunning: true,
      isPaused: false,
      sessionStartedAt: now,
      sessionEndsAt: endsAt,
      remainingSeconds: durationSeconds,
      totalDurationSeconds: durationMinutes * 60,
      isAlarmRinging: false,
    );
    await _storage.saveState(state);

    await _nativeService.startTimer(
      phase: state.phase.name,
      durationSeconds: durationSeconds,
      autoStartBreaks: _settings.autoStartBreaks,
      autoStartWork: _settings.autoStartWork,
      vibrationEnabled: _settings.vibrationEnabled,
      selectedAlarmSound: _settings.selectedAlarmSound,
      currentCycle: state.currentCycle,
      totalCycles: _settings.cyclesBeforeLongBreak,
      completedPomodorosToday: state.completedPomodorosToday,
    );

    _startLocalTicker();
  }

  Future<void> pauseTimer() async {
    if (!state.isRunning || state.isPaused) return;

    _stopLocalTicker();
    await _nativeService.pauseTimer();

    state = state.copyWith(isPaused: true);
    await _storage.saveState(state);
  }

  Future<void> resumeTimer() async {
    if (!state.isRunning || !state.isPaused) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final endsAt = now + (state.remainingSeconds * 1000);

    state = state.copyWith(
      isPaused: false,
      sessionStartedAt: now,
      sessionEndsAt: endsAt,
    );
    await _storage.saveState(state);

    await _nativeService.resumeTimer();
    _startLocalTicker();
  }

  Future<void> resetTimer() async {
    _stopLocalTicker();
    await _nativeService.resetTimer();

    final workMinutes = _settings.workDurationMinutes;
    final workSeconds = workMinutes * 60;

    state = state.copyWith(
      phase: PomodoroPhase.work,
      isRunning: false,
      isPaused: false,
      sessionStartedAt: 0,
      sessionEndsAt: 0,
      remainingSeconds: workSeconds,
      totalDurationSeconds: workSeconds,
      isAlarmRinging: false,
    );
    await _storage.saveState(state);
  }

  Future<void> skipSession() async {
    _stopLocalTicker();
    await _nativeService.skipSession();

    final currentPhase = state.phase;
    var cycle = state.currentCycle;
    PomodoroPhase nextPhase;

    if (currentPhase == PomodoroPhase.work) {
      cycle++;
      if (cycle >= _settings.cyclesBeforeLongBreak) {
        nextPhase = PomodoroPhase.longBreak;
      } else {
        nextPhase = PomodoroPhase.shortBreak;
      }
    } else {
      if (currentPhase == PomodoroPhase.longBreak) {
        cycle = 0;
      }
      nextPhase = PomodoroPhase.work;
    }

    final durationSec = _getDurationMinutesForPhase(nextPhase) * 60;

    state = state.copyWith(
      phase: nextPhase,
      currentCycle: cycle,
      isRunning: false,
      isPaused: false,
      sessionStartedAt: 0,
      sessionEndsAt: 0,
      remainingSeconds: durationSec,
      totalDurationSeconds: durationSec,
      isAlarmRinging: false,
    );
    await _storage.saveState(state);
  }

  Future<void> stopAlarm() async {
    await _nativeService.stopAlarm();
    state = state.copyWith(isAlarmRinging: false);
    await _storage.saveState(state);

    final isNextBreak = state.phase == PomodoroPhase.shortBreak || state.phase == PomodoroPhase.longBreak;
    final shouldAutoStart = isNextBreak ? _settings.autoStartBreaks : _settings.autoStartWork;

    if (shouldAutoStart) {
      await startTimer();
    }
  }

  void _startLocalTicker() {
    _stopLocalTicker();
    _localTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.isRunning && !state.isPaused && state.sessionEndsAt > 0) {
        final now = DateTime.now().millisecondsSinceEpoch;
        final remaining = max(0, (state.sessionEndsAt - now + 999) ~/ 1000);

        if (remaining <= 0) {
          _onSessionComplete();
        } else {
          state = state.copyWith(remainingSeconds: remaining);
          _storage.saveState(state);
        }
      }
    });
  }

  void _stopLocalTicker() {
    _localTicker?.cancel();
    _localTicker = null;
  }

  void _onSessionComplete() {
    _stopLocalTicker();

    final currentPhase = state.phase;
    var cycle = state.currentCycle;
    var completedToday = state.completedPomodorosToday;
    PomodoroPhase nextPhase;

    if (currentPhase == PomodoroPhase.work) {
      completedToday++;
      cycle++;
      ref.read(statisticsProvider.notifier).recordWorkSession(_settings.workDurationMinutes);
      if (cycle >= _settings.cyclesBeforeLongBreak) {
        nextPhase = PomodoroPhase.longBreak;
      } else {
        nextPhase = PomodoroPhase.shortBreak;
      }
    } else {
      if (currentPhase == PomodoroPhase.longBreak) {
        cycle = 0;
      }
      nextPhase = PomodoroPhase.work;
    }

    final nextDurationSec = _getDurationMinutesForPhase(nextPhase) * 60;

    state = state.copyWith(
      phase: nextPhase,
      currentCycle: cycle,
      completedPomodorosToday: completedToday,
      isRunning: false,
      isPaused: false,
      sessionStartedAt: 0,
      sessionEndsAt: 0,
      remainingSeconds: nextDurationSec,
      totalDurationSeconds: nextDurationSec,
      isAlarmRinging: true,
    );
    _storage.saveState(state);
  }
}
