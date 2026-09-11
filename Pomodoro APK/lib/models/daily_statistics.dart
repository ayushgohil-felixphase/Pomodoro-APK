class DailyStatistics {
  final String date; // "YYYY-MM-DD"
  final int completedPomodoros;
  final int focusMinutes;

  const DailyStatistics({
    required this.date,
    this.completedPomodoros = 0,
    this.focusMinutes = 0,
  });

  DailyStatistics copyWith({
    String? date,
    int? completedPomodoros,
    int? focusMinutes,
  }) {
    return DailyStatistics(
      date: date ?? this.date,
      completedPomodoros: completedPomodoros ?? this.completedPomodoros,
      focusMinutes: focusMinutes ?? this.focusMinutes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'completedPomodoros': completedPomodoros,
      'focusMinutes': focusMinutes,
    };
  }

  factory DailyStatistics.fromJson(Map<String, dynamic> json) {
    return DailyStatistics(
      date: json['date'] as String? ?? '',
      completedPomodoros: (json['completedPomodoros'] as num?)?.toInt() ?? 0,
      focusMinutes: (json['focusMinutes'] as num?)?.toInt() ?? 0,
    );
  }
}
