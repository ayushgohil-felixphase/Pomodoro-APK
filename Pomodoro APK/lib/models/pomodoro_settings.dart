class PomodoroSettings {
  final int workDurationMinutes;
  final int shortBreakDurationMinutes;
  final int longBreakDurationMinutes;
  final int cyclesBeforeLongBreak;
  final bool autoStartBreaks;
  final bool autoStartWork;
  final bool vibrationEnabled;
  final String selectedAlarmSound;
  final String themeMode; // "system", "light", "dark"

  const PomodoroSettings({
    this.workDurationMinutes = 25,
    this.shortBreakDurationMinutes = 5,
    this.longBreakDurationMinutes = 15,
    this.cyclesBeforeLongBreak = 4,
    this.autoStartBreaks = false,
    this.autoStartWork = false,
    this.vibrationEnabled = true,
    this.selectedAlarmSound = 'classic',
    this.themeMode = 'system',
  });

  PomodoroSettings copyWith({
    int? workDurationMinutes,
    int? shortBreakDurationMinutes,
    int? longBreakDurationMinutes,
    int? cyclesBeforeLongBreak,
    bool? autoStartBreaks,
    bool? autoStartWork,
    bool? vibrationEnabled,
    String? selectedAlarmSound,
    String? themeMode,
  }) {
    return PomodoroSettings(
      workDurationMinutes: (workDurationMinutes ?? this.workDurationMinutes).clamp(1, 120),
      shortBreakDurationMinutes: (shortBreakDurationMinutes ?? this.shortBreakDurationMinutes).clamp(1, 120),
      longBreakDurationMinutes: (longBreakDurationMinutes ?? this.longBreakDurationMinutes).clamp(1, 120),
      cyclesBeforeLongBreak: (cyclesBeforeLongBreak ?? this.cyclesBeforeLongBreak).clamp(1, 12),
      autoStartBreaks: autoStartBreaks ?? this.autoStartBreaks,
      autoStartWork: autoStartWork ?? this.autoStartWork,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      selectedAlarmSound: selectedAlarmSound ?? this.selectedAlarmSound,
      themeMode: themeMode ?? this.themeMode,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'workDurationMinutes': workDurationMinutes,
      'shortBreakDurationMinutes': shortBreakDurationMinutes,
      'longBreakDurationMinutes': longBreakDurationMinutes,
      'cyclesBeforeLongBreak': cyclesBeforeLongBreak,
      'autoStartBreaks': autoStartBreaks,
      'autoStartWork': autoStartWork,
      'vibrationEnabled': vibrationEnabled,
      'selectedAlarmSound': selectedAlarmSound,
      'themeMode': themeMode,
    };
  }

  factory PomodoroSettings.fromJson(Map<String, dynamic> json) {
    return PomodoroSettings(
      workDurationMinutes: (json['workDurationMinutes'] as num?)?.toInt() ?? 25,
      shortBreakDurationMinutes: (json['shortBreakDurationMinutes'] as num?)?.toInt() ?? 5,
      longBreakDurationMinutes: (json['longBreakDurationMinutes'] as num?)?.toInt() ?? 15,
      cyclesBeforeLongBreak: (json['cyclesBeforeLongBreak'] as num?)?.toInt() ?? 4,
      autoStartBreaks: json['autoStartBreaks'] as bool? ?? false,
      autoStartWork: json['autoStartWork'] as bool? ?? false,
      vibrationEnabled: json['vibrationEnabled'] as bool? ?? true,
      selectedAlarmSound: json['selectedAlarmSound'] as String? ?? 'classic',
      themeMode: json['themeMode'] as String? ?? 'system',
    );
  }
}
