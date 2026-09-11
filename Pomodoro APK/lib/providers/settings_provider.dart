import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/pomodoro_settings.dart';
import '../services/storage_service.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  throw UnimplementedError('Initialize in ProviderScope overrides');
});

final settingsProvider = NotifierProvider<SettingsNotifier, PomodoroSettings>(SettingsNotifier.new);

class SettingsNotifier extends Notifier<PomodoroSettings> {
  StorageService get _storage => ref.read(storageServiceProvider);

  @override
  PomodoroSettings build() {
    return _storage.loadSettings();
  }

  Future<void> updateWorkDuration(int minutes) async {
    state = state.copyWith(workDurationMinutes: minutes);
    await _storage.saveSettings(state);
  }

  Future<void> updateShortBreakDuration(int minutes) async {
    state = state.copyWith(shortBreakDurationMinutes: minutes);
    await _storage.saveSettings(state);
  }

  Future<void> updateLongBreakDuration(int minutes) async {
    state = state.copyWith(longBreakDurationMinutes: minutes);
    await _storage.saveSettings(state);
  }

  Future<void> updateCycles(int cycles) async {
    state = state.copyWith(cyclesBeforeLongBreak: cycles);
    await _storage.saveSettings(state);
  }

  Future<void> toggleAutoStartBreaks(bool val) async {
    state = state.copyWith(autoStartBreaks: val);
    await _storage.saveSettings(state);
  }

  Future<void> toggleAutoStartWork(bool val) async {
    state = state.copyWith(autoStartWork: val);
    await _storage.saveSettings(state);
  }

  Future<void> toggleVibration(bool val) async {
    state = state.copyWith(vibrationEnabled: val);
    await _storage.saveSettings(state);
  }

  Future<void> selectAlarmSound(String sound) async {
    state = state.copyWith(selectedAlarmSound: sound);
    await _storage.saveSettings(state);
  }

  Future<void> updateTheme(String theme) async {
    state = state.copyWith(themeMode: theme);
    await _storage.saveSettings(state);
  }
}
