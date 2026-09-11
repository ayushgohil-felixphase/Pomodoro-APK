import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/statistics_provider.dart';

class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  String _formatMinutes(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m > 0 ? '${h}h ${m}m' : '${h}h';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(statisticsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final today = stats.today;
    final past7 = stats.past7Days;
    final maxMinutes = max(60, past7.map((s) => s.focusMinutes).fold(0, max));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistics'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // 1. Today's Summary Row
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  context,
                  title: "Today's Pomodoros",
                  value: '${today.completedPomodoros}',
                  icon: Icons.check_circle_rounded,
                  color: AppColors.workPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  context,
                  title: 'Focused Today',
                  value: _formatMinutes(today.focusMinutes),
                  icon: Icons.timer_rounded,
                  color: AppColors.shortBreakPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 2. Weekly Totals Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text(
                        '${stats.totalCompletedThisWeek}',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'This Week',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: isDark ? Colors.white12 : Colors.black12,
                  ),
                  Column(
                    children: [
                      Text(
                        _formatMinutes(stats.totalFocusMinutesThisWeek),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppColors.workPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Total Focus Time',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),

          // 3. 7-Day Visual Chart Section
          _buildSectionHeader(context, 'LAST 7 DAYS FOCUS TIME'),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: SizedBox(
                height: 160,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: past7.map((dayStat) {
                    final dt = DateTime.tryParse(dayStat.date) ?? DateTime.now();
                    final dayName = DateFormat('E').format(dt); // Mon, Tue, etc.
                    final isToday = dayStat.date == today.date;

                    final ratio = (dayStat.focusMinutes / maxMinutes).clamp(0.05, 1.0);

                    return Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          dayStat.focusMinutes > 0 ? '${dayStat.focusMinutes}m' : '',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isToday ? AppColors.workPrimary : (isDark ? Colors.white54 : Colors.black54),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: 24,
                          height: 100 * ratio,
                          decoration: BoxDecoration(
                            color: isToday
                                ? AppColors.workPrimary
                                : (dayStat.focusMinutes > 0
                                    ? AppColors.workPrimary.withValues(alpha: 0.4)
                                    : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06))),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          dayName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                            color: isToday
                                ? AppColors.workPrimary
                                : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),

          // 4. Daily Breakdown List
          _buildSectionHeader(context, 'DAILY LOG'),
          const SizedBox(height: 12),
          Card(
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: past7.length,
              separatorBuilder: (_, _) => const Divider(height: 1, indent: 16, endIndent: 16),
              itemBuilder: (context, index) {
                final item = past7.reversed.toList()[index];
                final dt = DateTime.tryParse(item.date) ?? DateTime.now();
                final formattedDate = DateFormat('EEEE, MMM d').format(dt);
                final isToday = item.date == today.date;

                return ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (isToday ? AppColors.workPrimary : Colors.grey).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.calendar_today_rounded,
                      size: 18,
                      color: isToday ? AppColors.workPrimary : (isDark ? Colors.white70 : Colors.black87),
                    ),
                  ),
                  title: Text(
                    isToday ? 'Today' : formattedDate,
                    style: TextStyle(
                      fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  subtitle: Text('${item.completedPomodoros} completed'),
                  trailing: Text(
                    _formatMinutes(item.focusMinutes),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.darkTextSecondary
              : AppColors.lightTextSecondary,
        ),
      ),
    );
  }
}
