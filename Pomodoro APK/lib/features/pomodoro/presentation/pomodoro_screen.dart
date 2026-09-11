import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/pomodoro_state.dart';
import '../../../providers/pomodoro_provider.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../statistics/presentation/statistics_screen.dart';
import 'widgets/alarm_dialog.dart';
import 'widgets/circular_timer_painter.dart';

class PomodoroScreen extends ConsumerStatefulWidget {
  const PomodoroScreen({super.key});

  @override
  ConsumerState<PomodoroScreen> createState() => _PomodoroScreenState();
}

class _PomodoroScreenState extends ConsumerState<PomodoroScreen> {
  bool _dialogShowing = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pomodoroProvider);
    final notifier = ref.read(pomodoroProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Show Alarm modal if ringing and not already showing
    if (state.isAlarmRinging && !_dialogShowing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _dialogShowing) return;
        _dialogShowing = true;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlarmDialog(
            state: state,
            onStopAlarm: () {
              Navigator.of(ctx).pop();
              _dialogShowing = false;
              notifier.stopAlarm();
            },
          ),
        ).then((_) {
          _dialogShowing = false;
        });
      });
    }

    // Resolve Phase Colors
    final Color primaryColor;
    final Color secondaryColor;
    final Color containerColor;

    switch (state.phase) {
      case PomodoroPhase.work:
        primaryColor = AppColors.workPrimary;
        secondaryColor = AppColors.workSecondary;
        containerColor = isDark ? AppColors.workDarkContainer : AppColors.workContainer;
        break;
      case PomodoroPhase.shortBreak:
        primaryColor = AppColors.shortBreakPrimary;
        secondaryColor = AppColors.shortBreakSecondary;
        containerColor = isDark ? AppColors.shortBreakDarkContainer : AppColors.shortBreakContainer;
        break;
      case PomodoroPhase.longBreak:
        primaryColor = AppColors.longBreakPrimary;
        secondaryColor = AppColors.longBreakSecondary;
        containerColor = isDark ? AppColors.longBreakDarkContainer : AppColors.longBreakContainer;
        break;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('🍅 Pomodoro Timer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded),
            tooltip: 'Statistics',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const StatisticsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 1. Phase Pill Badge
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: containerColor,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: primaryColor.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      state.isWork
                          ? Icons.laptop_mac_rounded
                          : (state.isShortBreak ? Icons.coffee_rounded : Icons.spa_rounded),
                      color: primaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      state.phase.displayName,
                      style: TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              // 2. Circular Countdown Timer
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 320, maxHeight: 320),
                      child: CustomPaint(
                        painter: CircularTimerPainter(
                          progress: state.progress,
                          primaryColor: primaryColor,
                          secondaryColor: secondaryColor,
                          trackColor: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.06),
                          strokeWidth: 14.0,
                          isRunning: state.isRunning && !state.isPaused,
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Remaining Time (MM:SS)
                              Text(
                                state.formattedRemainingTime,
                                style: TextStyle(
                                  fontSize: 64,
                                  fontWeight: FontWeight.w800,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                  letterSpacing: -1,
                                  color: isDark ? Colors.white : AppColors.lightText,
                                ),
                              ),
                              const SizedBox(height: 4),

                              // State Subtitle
                              Text(
                                state.isPaused
                                    ? 'PAUSED'
                                    : (state.isRunning ? 'REMAINING' : 'READY'),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 2.0,
                                  color: state.isPaused
                                      ? AppColors.warning
                                      : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // 3. Cycle Progress & Today's Completed Stats
              Column(
                children: [
                  // Cycle info
                  Text(
                    state.cycleDisplay,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Cycle indicator dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(state.totalCycles, (index) {
                      final currentIdx = state.currentCycle % state.totalCycles;
                      final isCompleted = index < currentIdx;
                      final isCurrent = index == currentIdx;

                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: isCurrent ? 24 : 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: isCompleted
                              ? primaryColor
                              : (isCurrent
                                  ? primaryColor.withValues(alpha: 0.6)
                                  : (isDark ? Colors.white24 : Colors.black12)),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),

                  // Today's completed pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🍅 ', style: TextStyle(fontSize: 16)),
                        Text(
                          '${state.completedPomodorosToday} Pomodoros completed today',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.darkText : AppColors.lightText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 4. Timer Controls (Start / Pause / Resume / Reset / Skip)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Reset Button (visible when running or paused)
                    if (state.isRunning || state.isPaused)
                      IconButton.filledTonal(
                        onPressed: notifier.resetTimer,
                        icon: const Icon(Icons.replay_rounded),
                        tooltip: 'Reset',
                        style: IconButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                        ),
                      ),

                    const SizedBox(width: 16),

                    // Main Action Button (Start / Pause / Resume)
                    if (!state.isRunning)
                      ElevatedButton.icon(
                        onPressed: notifier.startTimer,
                        icon: const Icon(Icons.play_arrow_rounded, size: 28),
                        label: const Text('START'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
                        ),
                      )
                    else if (state.isPaused)
                      ElevatedButton.icon(
                        onPressed: notifier.resumeTimer,
                        icon: const Icon(Icons.play_arrow_rounded, size: 28),
                        label: const Text('RESUME'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 18),
                        ),
                      )
                    else
                      ElevatedButton.icon(
                        onPressed: notifier.pauseTimer,
                        icon: const Icon(Icons.pause_rounded, size: 28),
                        label: const Text('PAUSE'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.warning,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 18),
                        ),
                      ),

                    const SizedBox(width: 16),

                    // Skip Button
                    IconButton.filledTonal(
                      onPressed: notifier.skipSession,
                      icon: const Icon(Icons.skip_next_rounded),
                      tooltip: 'Skip',
                      style: IconButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
