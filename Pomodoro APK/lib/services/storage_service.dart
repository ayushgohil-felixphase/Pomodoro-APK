import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/daily_statistics.dart';
import '../models/pomodoro_settings.dart';
import '../models/pomodoro_state.dart';

class StorageService {
  final SharedPreferences _prefs;

  StorageService(this._prefs);

  static const String _keySettings = 'pomodoro_settings';
  static const String _keyDailyStats = 'pomodoro_daily_stats';

  // --- Settings ---
  Future<void> saveSettings(PomodoroSettings settings) async {
    await _prefs.setString(_keySettings, jsonEncode(settings.toJson()));
    // Also sync key flags into root prefs for native Android service/receivers
    await _prefs.setInt('workDurationMinutes', settings.workDurationMinutes);
    await _prefs.setInt('shortBreakDurationMinutes', settings.shortBreakDurationMinutes);
    await _prefs.setInt('longBreakDurationMinutes', settings.longBreakDurationMinutes);
    await _prefs.setInt('totalCycles', settings.cyclesBeforeLongBreak);
    await _prefs.setBool('autoStartBreaks', settings.autoStartBreaks);
    await _prefs.setBool('autoStartWork', settings.autoStartWork);
    await _prefs.setBool('vibrationEnabled', settings.vibrationEnabled);
    await _prefs.setString('selectedAlarmSound', settings.selectedAlarmSound);
  }

  PomodoroSettings loadSettings() {
    final raw = _prefs.getString(_keySettings);
    if (raw != null) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        return PomodoroSettings.fromJson(map);
      } catch (_) {}
    }
    return const PomodoroSettings();
  }

  // --- State Persistence & Recovery ---
  Future<void> saveState(PomodoroState state) async {
    await _prefs.setString('phase', state.phase.name);
    await _prefs.setBool('isRunning', state.isRunning);
    await _prefs.setBool('isPaused', state.isPaused);
    await _prefs.setInt('sessionStartedAt', state.sessionStartedAt);
    await _prefs.setInt('sessionEndsAt', state.sessionEndsAt);
    await _prefs.setInt('remainingSeconds', state.remainingSeconds);
    await _prefs.setInt('totalDurationSeconds', state.totalDurationSeconds);
    await _prefs.setInt('currentCycle', state.currentCycle);
    await _prefs.setInt('totalCycles', state.totalCycles);
    await _prefs.setInt('completedPomodorosToday', state.completedPomodorosToday);
    await _prefs.setBool('isAlarmRinging', state.isAlarmRinging);
  }

  PomodoroState loadState(PomodoroSettings settings) {
    final phaseStr = _prefs.getString('phase') ?? 'work';
    final phase = PomodoroPhase.values.firstWhere(
      (p) => p.name == phaseStr,
      orElse: () => PomodoroPhase.work,
    );

    final isRunning = _prefs.getBool('isRunning') ?? false;
    final isPaused = _prefs.getBool('isPaused') ?? false;
    final sessionStartedAt = _prefs.getInt('sessionStartedAt') ?? 0;
    final sessionEndsAt = _prefs.getInt('sessionEndsAt') ?? 0;
    final totalDuration = _prefs.getInt('totalDurationSeconds') ?? (settings.workDurationMinutes * 60);
    final currentCycle = _prefs.getInt('currentCycle') ?? 0;
    final totalCycles = _prefs.getInt('totalCycles') ?? settings.cyclesBeforeLongBreak;
    final completedPomodorosToday = _prefs.getInt('completedPomodorosToday') ?? 0;
    final isAlarmRinging = _prefs.getBool('isAlarmRinging') ?? false;

    int remainingSeconds = _prefs.getInt('remainingSeconds') ?? (settings.workDurationMinutes * 60);

    // CRITICAL: Calculate remaining time using timestamp difference if actively running!
    if (isRunning && !isPaused && sessionEndsAt > 0) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final diff = (sessionEndsAt - now) ~/ 1000;
      remainingSeconds = diff > 0 ? diff : 0;
    }

    return PomodoroState(
      phase: phase,
      isRunning: isRunning,
      isPaused: isPaused,
      sessionStartedAt: sessionStartedAt,
      sessionEndsAt: sessionEndsAt,
      remainingSeconds: remainingSeconds,
      totalDurationSeconds: totalDuration,
      currentCycle: currentCycle,
      totalCycles: totalCycles,
      completedPomodorosToday: completedPomodorosToday,
      isAlarmRinging: isAlarmRinging,
    );
  }

  // --- Statistics ---
  String get _todayKey => DateFormat('yyyy-MM-dd').format(DateTime.now());

  Map<String, DailyStatistics> _loadAllStats() {
    final raw = _prefs.getString(_keyDailyStats);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((key, value) {
        return MapEntry(key, DailyStatistics.fromJson(value as Map<String, dynamic>));
      });
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveAllStats(Map<String, DailyStatistics> stats) async {
    final encoded = jsonEncode(stats.map((key, value) => MapEntry(key, value.toJson())));
    await _prefs.setString(_keyDailyStats, encoded);
  }

  Future<void> recordCompletedWorkSession(int durationMinutes) async {
    final allStats = _loadAllStats();
    final today = _todayKey;

    final current = allStats[today] ?? DailyStatistics(date: today);
    final updated = current.copyWith(
      completedPomodoros: current.completedPomodoros + 1,
      focusMinutes: current.focusMinutes + durationMinutes,
    );

    allStats[today] = updated;
    await _saveAllStats(allStats);
  }

  DailyStatistics getTodayStatistics() {
    final allStats = _loadAllStats();
    final today = _todayKey;
    return allStats[today] ?? DailyStatistics(date: today);
  }

  List<DailyStatistics> getPast7DaysStatistics() {
    final allStats = _loadAllStats();
    final now = DateTime.now();
    final list = <DailyStatistics>[];

    for (int i = 6; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      final key = DateFormat('yyyy-MM-dd').format(d);
      list.add(allStats[key] ?? DailyStatistics(date: key));
    }

    return list;
  }
}
