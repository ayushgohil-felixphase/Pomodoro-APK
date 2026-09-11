enum PomodoroPhase {
  work,
  shortBreak,
  longBreak;

  String get displayName {
    switch (this) {
      case PomodoroPhase.work:
        return 'WORK';
      case PomodoroPhase.shortBreak:
        return 'SHORT BREAK';
      case PomodoroPhase.longBreak:
        return 'LONG BREAK';
    }
  }

  String get notificationTitle {
    switch (this) {
      case PomodoroPhase.work:
        return 'Work Session';
      case PomodoroPhase.shortBreak:
        return 'Short Break';
      case PomodoroPhase.longBreak:
        return 'Long Break';
    }
  }
}

class PomodoroState {
  final PomodoroPhase phase;
  final bool isRunning;
  final bool isPaused;
  final int sessionStartedAt;
  final int sessionEndsAt;
  final int remainingSeconds;
  final int totalDurationSeconds;
  final int currentCycle; // 0-indexed internally (e.g. 0 to totalCycles-1)
  final int totalCycles;
  final int completedPomodorosToday;
  final bool isAlarmRinging;

  const PomodoroState({
    this.phase = PomodoroPhase.work,
    this.isRunning = false,
    this.isPaused = false,
    this.sessionStartedAt = 0,
    this.sessionEndsAt = 0,
    this.remainingSeconds = 25 * 60,
    this.totalDurationSeconds = 25 * 60,
    this.currentCycle = 0,
    this.totalCycles = 4,
    this.completedPomodorosToday = 0,
    this.isAlarmRinging = false,
  });

  bool get isWork => phase == PomodoroPhase.work;
  bool get isShortBreak => phase == PomodoroPhase.shortBreak;
  bool get isLongBreak => phase == PomodoroPhase.longBreak;

  /// Progress from 0.0 (just started) to 1.0 (completed)
  double get progress {
    if (totalDurationSeconds <= 0) return 0.0;
    final elapsed = totalDurationSeconds - remainingSeconds;
    return (elapsed / totalDurationSeconds).clamp(0.0, 1.0);
  }

  /// Formatted countdown display MM:SS
  String get formattedRemainingTime {
    final minutes = (remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (remainingSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  /// User-facing cycle display (e.g. "Cycle 2 of 4")
  String get cycleDisplay {
    final displayCycle = (currentCycle % totalCycles) + 1;
    return 'Cycle $displayCycle of $totalCycles';
  }

  PomodoroState copyWith({
    PomodoroPhase? phase,
    bool? isRunning,
    bool? isPaused,
    int? sessionStartedAt,
    int? sessionEndsAt,
    int? remainingSeconds,
    int? totalDurationSeconds,
    int? currentCycle,
    int? totalCycles,
    int? completedPomodorosToday,
    bool? isAlarmRinging,
  }) {
    return PomodoroState(
      phase: phase ?? this.phase,
      isRunning: isRunning ?? this.isRunning,
      isPaused: isPaused ?? this.isPaused,
      sessionStartedAt: sessionStartedAt ?? this.sessionStartedAt,
      sessionEndsAt: sessionEndsAt ?? this.sessionEndsAt,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      totalDurationSeconds: totalDurationSeconds ?? this.totalDurationSeconds,
      currentCycle: currentCycle ?? this.currentCycle,
      totalCycles: totalCycles ?? this.totalCycles,
      completedPomodorosToday: completedPomodorosToday ?? this.completedPomodorosToday,
      isAlarmRinging: isAlarmRinging ?? this.isAlarmRinging,
    );
  }
}
