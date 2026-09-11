import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/daily_statistics.dart';
import '../services/storage_service.dart';
import 'settings_provider.dart';

class StatisticsState {
  final DailyStatistics today;
  final List<DailyStatistics> past7Days;

  const StatisticsState({
    required this.today,
    required this.past7Days,
  });

  int get totalCompletedThisWeek => past7Days.fold(0, (sum, s) => sum + s.completedPomodoros);
  int get totalFocusMinutesThisWeek => past7Days.fold(0, (sum, s) => sum + s.focusMinutes);
}

final statisticsProvider = NotifierProvider<StatisticsNotifier, StatisticsState>(StatisticsNotifier.new);

class StatisticsNotifier extends Notifier<StatisticsState> {
  StorageService get _storage => ref.read(storageServiceProvider);

  @override
  StatisticsState build() {
    return StatisticsState(
      today: _storage.getTodayStatistics(),
      past7Days: _storage.getPast7DaysStatistics(),
    );
  }

  void refresh() {
    state = StatisticsState(
      today: _storage.getTodayStatistics(),
      past7Days: _storage.getPast7DaysStatistics(),
    );
  }

  Future<void> recordWorkSession(int durationMinutes) async {
    await _storage.recordCompletedWorkSession(durationMinutes);
    refresh();
  }
}
